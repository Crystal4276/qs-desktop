pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Veilleuse (Night Light de GNOME) : `gammastep`, avec l'horaire et la température de la config (`nightLight` dans
// hosts/*.json ; valeurs par défaut reprises de tes réglages GNOME). gammastep plutôt que wlsunset (ta demande du 2026-10-26) :
// fondu d'environ 4 s à l'activation et à la désactivation, là où wlsunset change la température d'un coup.
// Horaire comme « ne pas déranger » (services/Notifs.qml, ta demande du 2026-11-17) : allumée à l'heure de début, éteinte à
// l'heure de fin, libre à la main entre les deux jusqu'à la prochaine heure ; appliqué au démarrage de la session, gardé au
// rechargement. `enabled` dit donc si l'écran est chaud en ce moment (bouton du panneau de réglages). Horaire coupé (clic droit
// sur le bouton, gardé dans un fichier d'état) : seulement à la main. Le couper ou le rétablir dans la plage fait comme
// Notifs.setSchedule : rétabli, allumée ; coupé, éteinte si elle l'avait été par l'horaire.
Singleton {
    id: root

    readonly property var config: Settings.nightLight
    readonly property bool enabled: persist.enabled
    readonly property bool scheduled: scheduleState.enabled
    readonly property string schedule: [config.from, config.to].map(t => Settings.timeText(Settings.minutes(t))).join(" – ")
    // Heures valides et différentes ; sinon veilleuse seulement à la main (avertissement), sans heures affichées.
    readonly property bool validSchedule: {
        const from = Settings.minutes(config.from), to = Settings.minutes(config.to);
        return from >= 0 && to >= 0 && from !== to;
    }
    // clock.date, pas hours et minutes : changés l'un après l'autre, ils donneraient un instant une heure fausse (06:59 → 06:00 →
    // 07:00) et une bascule de trop.
    readonly property bool nightHours: Settings.within(clock.date.getHours() * 60 + clock.date.getMinutes(), config.from, config.to)

    function toggle(): void {
        set(!persist.enabled, false);
    }

    function set(on: bool, bySchedule: bool): void {
        persist.enabled = on;
        persist.bySchedule = on && bySchedule;
    }

    function setScheduled(on: bool): void {
        if (on === scheduleState.enabled)
            return;
        scheduleState.enabled = on;
        if (on && nightHours && !persist.enabled)
            set(true, true);
        else if (!on && nightHours && persist.bySchedule)
            set(false, false);
    }

    // Heure de début ou de fin atteinte, ou démarrage de la session.
    function applySchedule(): void {
        if (scheduleState.enabled)
            set(nightHours, true);
    }

    // Heure atteinte, ou heures changées (config machine lue après le démarrage, ou modifiée).
    onNightHoursChanged: if (persist.loaded && scheduleRead) applySchedule()

    // Début de session : horaire appliqué une fois l'état de la session repris (persist) et le fichier lu (ou absent) ; les
    // propriétés d'un JsonAdapter gardent leur valeur par défaut tant que la lecture n'est pas finie, blockLoading ou non.
    property bool sessionStart: false
    property bool scheduleRead: false

    function startSession(): void {
        if (sessionStart && scheduleRead) {
            sessionStart = false;
            applySchedule();
        }
    }

    function readSchedule(): void {
        scheduleRead = true;
        startSession();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FileView {
        path: Quickshell.statePath("night-light-schedule.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: root.readSchedule()
        onLoadFailed: root.readSchedule()   // pas encore de fichier : horaire activé

        JsonAdapter {
            id: scheduleState
            property bool enabled: true
        }
    }

    PersistentProperties {
        id: persist
        reloadableId: "nightlight"

        property bool enabled: false
        property bool bySchedule: false   // allumée par l'horaire (pas à la main)
        property bool loaded: false

        onLoaded: {
            if (!loaded) {   // premier chargement de cette instance : début de session
                root.sessionStart = true;
                root.startSession();
            }
            loaded = true;
        }
    }

    // gammastep ne sert qu'à chauffer l'écran avec fondu : même température de jour comme de nuit (heures sans effet, mais
    // nécessaires : sans elles, il cherche une position géographique).
    readonly property string configText: ["[general]", "adjustment-method=wayland", "fade=1", "dawn-time=06:00",
        "dusk-time=18:00", `temp-day=${config.temperature}`, `temp-night=${config.temperature}`, ""].join("\n")

    // Température modifiée : gammastep arrêté puis relancé avec elle (retry).
    onConfigTextChanged: {
        failures = 0;
        if (gammastep.running) {
            ready = false;
            gammastep.signal(15);
        } else {
            apply();
        }
    }

    // Écrit avant chaque lancement (la config ne passe que par un fichier).
    FileView {
        id: configFile
        path: Quickshell.statePath("gammastep.ini")
        blockWrites: true
        printErrors: false
    }

    // État dans gammastep : il démarre activé, SIGUSR1 bascule (fondu dans les deux sens, réversible à tout moment : la réactiver
    // pendant le fondu de retour repart aussitôt vers la nuit). Désactivée, il est arrêté une fois revenu au neutre (`release`),
    // pour libérer le réglage gamma des écrans (exclusif). SIGUSR1 seulement une fois son gestionnaire installé (`ready`) :
    // l'action par défaut du signal le tuerait.
    property bool gammaOn: false
    property bool ready: false
    property real startedAt: 0
    property int failures: 0   // arrêts juste après le lancement, à la suite

    function launch(): void {
        if (!enabled)
            return;   // désactivée pendant l'attente
        configFile.setText(configText);   // config à jour, même changée pendant l'attente (écriture bloquante)
        gammaOn = true;
        ready = false;
        startedAt = Date.now();
        gammastep.running = true;
        readyDelay.restart();
    }

    // Jamais deux gammastep à la fois. Hyprland 0.57 : un contrôle gamma demandé pour un écran déjà tenu échoue, et cet échec
    // reste enregistré (protocols/GammaControl.cpp, lu) : l'écran est refusé à tout client jusqu'au redémarrage d'Hyprland.
    // Vu le 2026-11-03 : veilleuse sur le seul Dell, après des relances de Quickshell pendant lesquelles l'ancien gammastep
    // faisait encore son fondu de sortie. Le précédent (instance arrêtée ou rechargée) est donc attendu, 10 s au plus ; au-delà
    // (orphelin), pas de lancement, nouvel essai dans une minute. Seul compte un gammastep de cette session Wayland (même
    // WAYLAND_DISPLAY) : celui d'un banc imbriqué ne tient pas ces écrans.
    Process {
        id: previous
        command: ["sh", "-c", 'for _ in $(seq 50); do
                held=; for p in $(pgrep -xf "gammastep -c $1"); do
                    tr "\\0" "\\n" <"/proc/$p/environ" 2>/dev/null | grep -qx "WAYLAND_DISPLAY=$WAYLAND_DISPLAY" && held=1
                done
                [ -z "$held" ] && exit 0; sleep 0.2
            done; exit 1', "sh", configFile.path]
        onExited: code => {
            if (code === 0) {
                root.launch();
            } else if (root.enabled) {
                console.warn("NightLight: un gammastep précédent ne s'arrête pas, nouvel essai dans une minute");
                retry.interval = 60000;
                retry.start();
            }
        }
    }

    function apply(): void {
        release.stop();
        if (previous.running)
            return;   // launch() suivra
        if (!gammastep.running) {
            if (enabled)
                previous.running = true;   // lancement une fois le gammastep précédent arrêté (launch)
            return;
        }
        if (!ready)
            return;   // readyDelay rappelle apply()
        if (gammaOn !== enabled) {
            gammastep.signal(10);   // SIGUSR1
            gammaOn = enabled;
        }
        if (!enabled)
            release.restart();
    }

    onEnabledChanged: {
        failures = 0;
        apply();
    }
    Component.onCompleted: {
        checkHours();
        apply();
    }

    // Config machine lue après le démarrage, ou modifiée.
    onValidScheduleChanged: checkHours()

    function checkHours(): void {
        if (!validSchedule)
            console.warn(`NightLight: horaire ${config.from} – ${config.to} invalide, veilleuse seulement à la main`);
    }

    Process {
        id: gammastep
        // Arrêté avec Quickshell (`qs kill`) : un gammastep orphelin garderait le gamma, la veilleuse ne répondrait plus (vu le 2026-10-27).
        command: ["setpriv", "--pdeathsig", "TERM", "gammastep", "-c", configFile.path]
        // Réglage gamma tenu par un autre client (programme tiers ; sous Hyprland, écran bloqué, voir `previous`) : gammastep ne
        // quitte pas, il tourne sans effet en le signalant ; arrêté, donc relancé (onExited). Vérifié le 2026-10-26.
        stderr: SplitParser {
            onRead: line => {
                if (line.includes("Zero outputs support gamma adjustment")) {
                    root.ready = false;
                    gammastep.signal(15);
                }
            }
        }
        // Arrêt : relancé 1 s plus tard si la veilleuse est activée ; après 10 arrêts de suite dans les 5 s qui suivent le lancement
        // (autre client gamma qui garde la main, aucun écran, config refusée), une fois par minute seulement, et aussitôt qu'un
        // écran apparaît ou que la config change.
        onExited: {
            readyDelay.stop();
            root.gammaOn = false;
            root.ready = false;
            root.failures = Date.now() - root.startedAt < 5000 ? root.failures + 1 : 0;
            if (root.failures === 10)
                console.warn("NightLight: gammastep s'arrête aussitôt lancé, nouvel essai chaque minute (autre client gamma ?)");
            if (root.enabled) {
                retry.interval = root.failures >= 10 ? 60000 : 1000;
                retry.start();
            }
        }
    }

    Timer {
        id: readyDelay
        interval: 1000
        onTriggered: {
            root.ready = true;
            root.apply();
        }
    }

    // Fondu de retour terminé (environ 4 s) : arrêt, sans effet visible.
    Timer {
        id: release
        interval: 6000
        onTriggered: {
            root.ready = false;
            gammastep.signal(15);
        }
    }

    Timer {
        id: retry
        interval: 1000
        onTriggered: root.apply()
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.failures = 0;
            if (retry.running) {
                retry.stop();
                root.apply();
            }
        }
    }

    // `qs ipc call nightlight toggle` (raccourci éventuel, tests).
    IpcHandler {
        target: "nightlight"

        function toggle(): void {
            root.toggle();
        }

        function isEnabled(): bool {
            return root.enabled;
        }

        function setScheduled(on: bool): void {
            root.setScheduled(on);
        }

        function isScheduled(): bool {
            return root.scheduled;
        }
    }
}
