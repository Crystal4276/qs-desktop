pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config

// Veille des écrans (remplace swayidle et hypridle, ARCHITECTURE § 10.1 R3) : après `Settings.idle.timeout` secondes sans activité,
// écrans éteints par le compositeur ; à la reprise, tous rallumés ensemble. Les inhibitions sont respectées : règles `inhibit_idle`
// du compositeur, « Keep Screen On »
// (IdleInhibitor des barres), manette Bluetooth connectée (même inhibiteur), vidéos des applications Wayland.
// Verrouillage avant la mise en veille du système (laptop par défaut) : verrou « delay » de logind, relâché une fois l'écran verrouillé.
// Au réveil sous Hyprland : `hyprctl reload` (after_sleep_cmd de ton hypridle : la disposition des écrans ne survit pas à la veille).
// Non repris : les inhibitions D-Bus (org.freedesktop.ScreenSaver, `ignore_dbus_inhibit = false` de hypridle), faute de pouvoir
// publier un service D-Bus en QML ; les applications Wayland passent par le protocole idle-inhibit, respecté.
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
        Compositor.setPower([], false);
    }

    // Tous rallumés d'un coup, Sway et Hyprland (pas de rallumage en deux temps). Sous Sway, chaque commande `output` réapplique la
    // configuration de tous les écrans en un seul commit : rallumer un écran à part refaisait un modeset qui éteignait de nouveau
    // les autres. `output * power on` efface aussi le `power off` de la config `*` (sinon, un écran branché ensuite resterait éteint).
    function screensOn(): void {
        Compositor.setPower([], true);
    }

    // Quickshell relancé écrans éteints (rechargement, plantage) : le nouveau suivi n'est pas en veille, rien ne les rallumerait
    // avant une veille complète (`timeout` s sans activité). Vérifié 2 s après le démarrage : écrans connus, et au rechargement
    // à chaud ancienne génération détruite (rallumer pendant sa destruction faisait planter Quickshell 0.3.2, vu).
    Timer {
        running: true
        interval: 2000
        onTriggered: {
            if (!monitor.isIdle && Compositor.outputs.some(o => !o.powered))
                root.screensOn();
        }
    }

    // --- Verrouillage avant la mise en veille du système ---

    // Verrou « delay » : logind attend sa libération (quelques secondes au plus) avant de mettre en veille. Relâché le temps d'une
    // veille (`holding` faux), repris au réveil.
    property bool holding: true

    Process {
        id: inhibitor
        running: root.lockBeforeSleep && root.holding
        command: ["setpriv", "--pdeathsig", "TERM", "systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Quickshell",
            "--why=Lock the screen before sleep", "sleep", "infinity"]   // pdeathsig : verrou relâché si Quickshell plante
    }

    // Annonces de logind : PrepareForSleep(true) avant la veille, (false) au réveil.
    Process {
        running: root.lockBeforeSleep || Compositor.isHyprland
        command: ["setpriv", "--pdeathsig", "TERM", "gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                if (!line.includes("PrepareForSleep"))
                    return;
                if (line.includes("(true,)")) {
                    if (!root.lockBeforeSleep)
                        return;
                    if (Session.locked) {
                        root.holding = false;   // déjà verrouillé : rien à attendre
                    } else {
                        Session.lock();
                        release.restart();
                    }
                } else {
                    root.holding = true;   // réveil : nouveau verrou pour la prochaine veille
                    if (Compositor.isHyprland)
                        Quickshell.execDetached(["hyprctl", "reload"]);
                }
            }
        }
    }

    // Verrou relâché dès que l'écran est verrouillé (au plus 2 s : la veille ne doit pas être bloquée).
    Timer {
        id: release
        interval: 2000
        onTriggered: root.holding = false
    }

    Connections {
        target: Session
        function onLockedChanged() {
            if (Session.locked && release.running) {
                release.stop();
                root.holding = false;
            }
        }
    }
}
