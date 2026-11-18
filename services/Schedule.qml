import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Horaire d'une bascule : « ne pas déranger » (Notifs.qml, ta demande du 2026-10-26) et veilleuse (NightLight.qml, même horaire
// le 2026-11-17). Allumée à l'heure de début, éteinte à l'heure de fin ; entre les deux, la bascule à la main reste libre jusqu'à
// la prochaine heure. Appliqué aussi au début de la session. Horaire activé, ou heures changées, de sorte qu'on entre dans la
// plage : allumée (sauf si elle l'est déjà) ; qu'on en sorte : éteinte, seulement si l'horaire l'avait allumée.
// Réglé depuis le panneau de réglages, gardé dans le fichier d'état `file` ; valeur pas encore réglée (null) : celle de la config
// machine (`defaults` : { schedule, from, to }).
// Le service garde l'état de la bascule (`active`, `bySchedule` : allumée par l'horaire) et l'applique dans `switched` ; il
// appelle `startSession()` au premier chargement de son état (PersistentProperties) et met `ready` une fois cet état repris.
Scope {
    id: root

    required property string file
    required property var defaults
    property bool active: false
    property bool bySchedule: false
    property bool ready: false
    signal switched(bool value)   // l'horaire allume ou éteint la bascule

    readonly property bool enabled: adapter.enabled ?? defaults.schedule
    // Toujours "HH:MM" (le fichier d'état ou hosts/*.json peuvent contenir "7:00") : format du champ d'heure.
    readonly property string from: Settings.timeText(Settings.minutes(adapter.from ?? defaults.from))
    readonly property string to: Settings.timeText(Settings.minutes(adapter.to ?? defaults.to))
    readonly property string summary: enabled && from && to ? `${from} – ${to}` : ""   // sous-titre de la bascule
    // clock.date, pas hours et minutes : changés l'un après l'autre, ils donneraient un instant une heure fausse (06:59 → 06:00 →
    // 07:00) et une bascule de trop.
    readonly property bool inRange: Settings.within(clock.date.getHours() * 60 + clock.date.getMinutes(), from, to)
    property bool editing: false   // set() en cours : la plage change par réglage, pas par l'heure

    // Heure mal formée (IPC) : refusée seule, le champ revient à l'ancienne. Heures identiques acceptées (plage vide : inversion des
    // heures en deux saisies possible). Une seule écriture du fichier.
    function set(enabled: bool, from: string, to: string): void {
        const was = root.enabled && inRange;
        const f = Settings.minutes(from), t = Settings.minutes(to);
        editing = true;
        adapter.enabled = enabled;
        if (f >= 0)
            adapter.from = Settings.timeText(f);
        if (t >= 0)
            adapter.to = Settings.timeText(t);
        editing = false;
        fileView.writeAdapter();
        const now = root.enabled && inRange;
        if (now && !was && !active)   // déjà allumée à la main : elle le reste (pas reprise par l'horaire)
            switched(true);
        else if (!now && was && bySchedule)
            switched(false);
    }

    // Heure de début ou de fin atteinte, ou début de la session.
    function apply(): void {
        if (enabled)
            switched(inRange);
    }

    // Pas avant la lecture du fichier d'état (un JsonAdapter garde ses valeurs par défaut jusque-là, blockLoading ou non) ; au
    // début de la session, une fois l'état du service repris et ce fichier lu (ou absent).
    property bool sessionStart: false
    property bool read: false
    onInRangeChanged: if (ready && read && !editing) apply()

    function startSession(): void {
        sessionStart = true;
        begin();
    }

    function begin(): void {
        if (sessionStart && read) {
            sessionStart = false;
            apply();
        }
    }

    function fileRead(): void {
        read = true;
        begin();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Pas de liaison vers Settings dans l'adaptateur : la config machine, souvent lue après ce fichier, remplacerait ses valeurs
    // (et le fichier avec, par onAdapterUpdated).
    FileView {
        id: fileView
        path: Quickshell.statePath(root.file)
        printErrors: false
        onAdapterUpdated: if (!root.editing) writeAdapter()
        onLoaded: root.fileRead()
        onLoadFailed: root.fileRead()   // pas encore de fichier : config machine

        JsonAdapter {
            id: adapter
            property var enabled: null
            property var from: null
            property var to: null
        }
    }
}
