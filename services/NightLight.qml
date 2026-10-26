pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Veilleuse (Night Light de GNOME) : `gammastep`, avec l'horaire et la température de la config (`nightLight` dans
// hosts/*.json ; valeurs par défaut reprises de tes réglages GNOME). gammastep plutôt que wlsunset (ta demande du 2026-10-26) :
// fondu d'environ 4 s à l'activation, à la désactivation et aux heures de l'horaire, là où wlsunset change la température d'un
// coup. Activée ou non : gardé dans un fichier d'état local, donc retrouvé à la session suivante.
Singleton {
    id: root

    readonly property var config: Settings.nightLight
    readonly property bool enabled: state.enabled
    readonly property string schedule: `${Settings.timeText(fromMinutes)} – ${Settings.timeText(toMinutes)}`

    function toggle(): void {
        state.enabled = !state.enabled;
    }

    FileView {
        path: Quickshell.statePath("night-light.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: state
            property bool enabled: false
        }
    }

    // Horaire : gammastep ne connaît qu'une nuit qui passe minuit (dusk-time : passage à la nuit, dawn-time : retour au jour).
    // Nuit dans la même journée (00:30 – 06:00) : sa « journée » devient la nuit, températures inversées. Heures mal formées ou
    // identiques : veilleuse sans effet (avertissement).
    readonly property int fromMinutes: Settings.minutes(config.from)
    readonly property int toMinutes: Settings.minutes(config.to)
    readonly property bool validSchedule: fromMinutes >= 0 && toMinutes >= 0 && fromMinutes !== toMinutes

    readonly property string configText: {
        const crossesMidnight = fromMinutes > toMinutes;
        const night = String(config.temperature), day = "6500";
        return ["[general]", "adjustment-method=wayland", "fade=1",
            `${crossesMidnight ? "dusk" : "dawn"}-time=${Settings.timeText(fromMinutes)}`,
            `${crossesMidnight ? "dawn" : "dusk"}-time=${Settings.timeText(toMinutes)}`,
            `temp-day=${crossesMidnight ? day : night}`, `temp-night=${crossesMidnight ? night : day}`, ""].join("\n");
    }

    // Config machine modifiée : gammastep arrêté puis relancé avec elle (retry) ; pas lancé (horaire invalide corrigé, abandon) :
    // nouvel essai.
    onConfigTextChanged: {
        failures = 0;
        if (gammastep.running) {
            ready = false;
            gammastep.signal(15);
        } else {
            apply();
        }
    }

    // Écrit avant chaque lancement (les heures ne passent que par un fichier de config).
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

    function start(): void {
        if (!validSchedule) {
            console.warn(`NightLight: horaire ${schedule} invalide`);
            return;
        }
        configFile.setText(configText);
        gammaOn = true;
        ready = false;
        startedAt = Date.now();
        gammastep.running = true;
        readyDelay.restart();
    }

    function apply(): void {
        release.stop();
        if (!gammastep.running) {
            if (enabled)
                start();
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
    Component.onCompleted: apply()

    Process {
        id: gammastep
        command: ["gammastep", "-c", configFile.path]
        // Réglage gamma tenu par un autre client (au rechargement, l'ancienne instance le garde le temps de son fondu) : gammastep
        // ne quitte pas, il tourne sans effet en le signalant ; arrêté, donc relancé (onExited). Vérifié le 2026-10-26.
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
    }
}
