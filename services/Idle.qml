pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config

// Veille des écrans (remplace swayidle et hypridle, ARCHITECTURE § 10.1 R3) : après `Settings.idle.timeout` secondes sans activité,
// écrans éteints par le compositeur ; à la reprise, rallumés — l'écran principal `primaryWakeDelay` secondes après les autres
// (contournement repris de hypridle). Les inhibitions sont respectées : règles `inhibit_idle` du compositeur, « Keep Screen On »
// (IdleInhibitor des barres), vidéos des applications Wayland.
// Verrouillage avant la mise en veille du système (laptop par défaut) : verrou « delay » de logind, relâché une fois l'écran verrouillé.
Singleton {
    id: root

    readonly property var settings: Settings.idle
    readonly property bool lockBeforeSleep: settings.lockBeforeSleep ?? Battery.available

    // Tests : `qs ipc call idle state` (JSON).
    IpcHandler {
        target: "idle"

        function state(): string {
            return JSON.stringify({ enabled: monitor.enabled, timeout: monitor.timeout, idle: monitor.isIdle,
                lockBeforeSleep: root.lockBeforeSleep });
        }
    }

    // Délai lu dans la config machine après la création : le suivi est relancé pour qu'il en tienne compte.
    property bool restarting: false

    IdleMonitor {
        id: monitor
        enabled: root.settings.timeout > 0 && !root.restarting
        timeout: root.settings.timeout
        respectInhibitors: true
        onIsIdleChanged: isIdle ? root.screensOff() : root.screensOn()
        onTimeoutChanged: {
            root.restarting = true;
            Qt.callLater(() => root.restarting = false);
        }
    }

    function screensOff(): void {
        wake.stop();
        Compositor.setPower([], false);
    }

    function screensOn(): void {
        const primary = Outputs.primary?.name ?? "";
        const others = Compositor.outputs.map(o => o.name).filter(n => n !== primary);
        if (root.settings.primaryWakeDelay > 0 && primary !== "" && others.length > 0) {
            Compositor.setPower(others, true);
            wake.restart();
        } else {
            Compositor.setPower([], true);
        }
    }

    Timer {
        id: wake
        interval: root.settings.primaryWakeDelay * 1000
        onTriggered: Compositor.setPower([Outputs.primary?.name ?? ""].filter(n => n !== ""), true)
    }

    // --- Verrouillage avant la mise en veille du système ---

    // Verrou « delay » : logind attend sa libération (quelques secondes au plus) avant de mettre en veille.
    Process {
        id: inhibitor
        running: root.lockBeforeSleep
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Quickshell", "--why=Lock the screen before sleep",
            "sleep", "infinity"]
    }

    // Annonces de logind : PrepareForSleep(true) avant la veille, (false) au réveil.
    Process {
        running: root.lockBeforeSleep
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                if (!line.includes("PrepareForSleep"))
                    return;
                if (line.includes("(true,)")) {
                    Session.lock();
                    release.restart();
                } else {
                    inhibitor.running = root.lockBeforeSleep;   // réveil : nouveau verrou pour la prochaine veille
                }
            }
        }
    }

    // Verrou relâché dès que l'écran est verrouillé (au plus 2 s : la veille ne doit pas être bloquée).
    Timer {
        id: release
        interval: 2000
        onTriggered: inhibitor.running = false
    }

    Connections {
        target: Session
        function onLockedChanged() {
            if (Session.locked && release.running) {
                release.stop();
                inhibitor.running = false;
            }
        }
    }
}
