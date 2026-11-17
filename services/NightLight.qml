pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Veilleuse (Night Light de GNOME) : `gammastep`. gammastep plutôt que wlsunset (ta demande du 2026-10-26) : fondu d'environ 4 s à
// l'activation et à la désactivation, là où wlsunset change la température d'un coup.
// Horaire comme « ne pas déranger » (Schedule.qml, ta demande du 2026-11-17) : `enabled` dit si l'écran est chaud en ce moment.
Singleton {
    id: root

    readonly property var config: Settings.nightLight
    readonly property bool enabled: persist.enabled

    // Température (ta demande du 2026-11-18) : réglée depuis le panneau, gardée dans un fichier d'état ; pas encore réglée : celle
    // de la config machine (`nightLight.temperature`, tes réglages GNOME). Plage du curseur de GNOME. `warmth` : position du
    // curseur, de 0 (moins chaud) à 1 (plus chaud).
    readonly property int minTemperature: 1700
    readonly property int maxTemperature: 4700
    readonly property int temperature: Math.max(minTemperature, Math.min(maxTemperature, Math.round(temperatureState.temperature ?? config.temperature)))
    readonly property real warmth: (maxTemperature - temperature) / (maxTemperature - minTemperature)

    function setWarmth(warmth: real): void {
        temperatureState.temperature = Math.round(maxTemperature - Math.max(0, Math.min(1, warmth)) * (maxTemperature - minTemperature));
    }

    FileView {
        path: Quickshell.statePath("night-light.json")   // ancien fichier d'état, repris (sa clé `enabled` est ignorée)
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: temperatureState
            property var temperature: null
        }
    }

    // Horaire réglé depuis le panneau de réglages ; heures de départ dans la config machine.
    readonly property Schedule schedule: Schedule {
        file: "night-light-schedule.json"
        defaults: root.config
        active: persist.enabled
        bySchedule: persist.bySchedule
        ready: persist.restored
        onSwitched: value => root.set(value, true)
    }

    function toggle(): void {
        set(!persist.enabled, false);
    }

    function set(on: bool, bySchedule: bool): void {
        persist.enabled = on;
        persist.bySchedule = on && bySchedule;
    }

    PersistentProperties {
        id: persist
        reloadableId: "nightlight"

        property bool enabled: false
        property bool bySchedule: false   // allumée par l'horaire (pas à la main)
        property bool restored: false   // état de la session repris

        onLoaded: {
            if (!restored)   // premier chargement de cette instance : début de session
                root.schedule.startSession();
            restored = true;
        }
    }

    // gammastep ne sert qu'à chauffer l'écran avec fondu : même température de jour comme de nuit (heures sans effet, mais
    // nécessaires : sans elles, il cherche une position géographique).
    function configText(fade: bool): string {
        return ["[general]", "adjustment-method=wayland", `fade=${fade ? 1 : 0}`, "dawn-time=06:00", "dusk-time=18:00",
            `temp-day=${temperature}`, `temp-night=${temperature}`, ""].join("\n");
    }

    // Température modifiée, veilleuse allumée : saut net (essai, ta demande du 2026-11-18). gammastep ne change pas de
    // température en marche : arrêté sec (SIGKILL : le compositeur rend aussitôt le gamma neutre, sans fondu de sortie), puis
    // relancé aussitôt, sans fondu d'entrée (`jump`). Ce gammastep-là s'éteint donc sans fondu lui aussi. Éteinte : nouvelle
    // température au prochain lancement.
    property bool jump: false

    onTemperatureChanged: {
        failures = 0;
        if (gammastep.running && gammaOn) {
            jump = true;
            ready = false;
            gammastep.signal(9);
        } else if (!gammastep.running) {
            apply();   // essais espacés en cours : relancé aussitôt
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
        const fade = !jump;
        jump = false;
        if (!enabled)
            return;   // désactivée pendant l'attente
        configFile.setText(configText(fade));   // config à jour, même changée pendant l'attente (écriture bloquante)
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
        jump = false;
        apply();
    }
    Component.onCompleted: apply()

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
            if (root.jump) {   // arrêté pour changer de température (onTemperatureChanged) : relancé aussitôt
                root.apply();
                return;
            }
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

        // Tests : température en kelvins, réglée comme depuis le curseur.
        function temperature(): int {
            return root.temperature;
        }

        function setTemperature(kelvins: int): void {
            root.setWarmth((root.maxTemperature - kelvins) / (root.maxTemperature - root.minTemperature));
        }

        // Tests : horaire en JSON ; réglage comme depuis le panneau.
        function scheduleState(): string {
            const s = root.schedule;
            return JSON.stringify({ enabled: root.enabled, scheduled: s.enabled, from: s.from, to: s.to, nightHours: s.inRange });
        }

        function setSchedule(enabled: bool, from: string, to: string): void {
            root.schedule.set(enabled, from, to);
        }
    }
}
