pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config

// Veille des écrans (remplace swayidle et hypridle, ARCHITECTURE § 7.13) : après `Settings.idle.timeout` secondes sans activité,
// verrouillage sur laptop puis écrans éteints par le compositeur ; à la reprise, tous rallumés ensemble.
// Inhibitions respectées : règles `inhibit_idle` du compositeur, « Keep Screen On »
// (IdleInhibitor des barres), manette Bluetooth connectée (même inhibiteur), vidéos des applications Wayland.
// Verrouillage avant la mise en veille du système (laptop par défaut) : verrou « delay » de logind, relâché une fois l'écran verrouillé.
// Au réveil sous Hyprland : `hyprctl reload` (after_sleep_cmd de ton hypridle : la disposition des écrans ne survit pas à la veille).
// Inhibitions D-Bus : scripts/idle-inhibit.py, conservées hors du moteur QML par desktop.sh.
Singleton {
    id: root

    readonly property var settings: Settings.idle
    readonly property bool lockOnIdle: settings.lockOnIdle ?? Battery.available
    readonly property bool lockBeforeSleep: settings.lockBeforeSleep ?? Battery.available

    // Tests : `qs ipc call idle state` (JSON).
    IpcHandler {
        target: "idle"

        function state(): string {
            return JSON.stringify({ enabled: monitor.enabled, timeout: monitor.timeout, idle: monitor.isIdle,
                lockOnIdle: root.lockOnIdle, lockBeforeSleep: root.lockBeforeSleep, dbusReady: root.dbusReady, dbusInhibitors: root.dbusInhibitors });
        }
    }

    property bool dbusReady: false
    property int dbusInhibitors: 0
    readonly property string bridgePath: Quickshell.env("QS_IDLE_SOCKET") || ""

    Socket {
        id: bridge
        path: root.bridgePath
        connected: root.bridgePath !== ""
        parser: SplitParser {
            onRead: line => {
                try {
                    const state = JSON.parse(line);
                    if (state.ready === true && Number.isInteger(state.count) && state.count >= 0) {
                        root.dbusReady = true;
                        root.dbusInhibitors = state.count;
                    }
                } catch (error) { console.warn("Idle bridge: invalid state", error); }
            }
        }
        onConnectedChanged: {
            if (!connected) {
                root.dbusReady = false;
                root.dbusInhibitors = 0;
            }
        }
        onError: error => console.warn("Idle bridge unavailable:", error)
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.bridgePath !== "" && !bridge.connected
        onTriggered: bridge.connected = true
    }

    // Délai lu dans la config machine après la création : le suivi est relancé pour qu'il en tienne compte.
    property bool restarting: false

    IdleMonitor {
        id: monitor
        enabled: root.settings.timeout > 0 && !root.restarting && root.dbusInhibitors === 0
        timeout: root.settings.timeout
        respectInhibitors: true
        onIsIdleChanged: isIdle ? root.screensOff() : root.screensOn()
        onTimeoutChanged: {
            root.restarting = true;
            Qt.callLater(() => root.restarting = false);
        }
    }

    property bool waitingIdleLock: false

    function screensOff(): void {
        if (root.lockOnIdle && !Session.locked) {
            root.waitingIdleLock = true;
            if (!Session.lockActive)
                Session.lock();
            return;
        }
        root.waitingIdleLock = false;
        Compositor.setPower([], false);
    }

    // Tous rallumés d'un coup, Sway et Hyprland (pas de rallumage en deux temps). Sous Sway, chaque commande `output` réapplique la
    // configuration de tous les écrans en un seul commit : rallumer un écran à part refaisait un modeset qui éteignait de nouveau
    // les autres. `output * power on` efface aussi le `power off` de la config `*` (sinon, un écran branché ensuite resterait éteint).
    function screensOn(): void {
        root.waitingIdleLock = false;
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
    property bool preparingSleep: false

    Process {
        id: inhibitor
        running: root.lockBeforeSleep && root.holding
        command: ["setpriv", "--pdeathsig", "TERM", "systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Quickshell",
            "--why=Lock the screen before sleep", "sleep", "infinity"]   // pdeathsig : verrou relâché si Quickshell plante
    }

    // Réessai espacé si le processus meurt, jamais après une libération volontaire.
    // Qt.binding conserve le lien avec holding après la relance.
    Timer {
        interval: 5000
        repeat: true
        running: root.lockBeforeSleep && root.holding && !inhibitor.running
        onTriggered: inhibitor.running = Qt.binding(() => root.lockBeforeSleep && root.holding)
    }

    // Annonces de logind : PrepareForSleep(true) avant la veille, (false) au réveil.
    Process {
        id: sleepEvents
        running: root.lockBeforeSleep || Compositor.isHyprland
        command: ["setpriv", "--pdeathsig", "TERM", "gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                if (!line.includes("PrepareForSleep"))
                    return;
                if (line.includes("(true,)")) {
                    if (!root.lockBeforeSleep)
                        return;
                    root.preparingSleep = true;
                    if (Session.locked) {
                        root.holding = false;   // déjà verrouillé : rien à attendre
                    } else {
                        Session.lock();
                    }
                } else {
                    root.preparingSleep = false;
                    root.holding = true;   // réveil : nouveau verrou pour la prochaine veille
                    if (Compositor.isHyprland)
                        Quickshell.execDetached(["hyprctl", "reload"]);
                }
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: (root.lockBeforeSleep || Compositor.isHyprland) && !sleepEvents.running
        onTriggered: sleepEvents.running = Qt.binding(() => root.lockBeforeSleep || Compositor.isHyprland)
    }

    // Attendre la confirmation : logind borne déjà le délai (InhibitDelayMaxSec).
    // Un échec de verrouillage ne doit pas raccourcir cette attente à deux secondes.

    Connections {
        target: Session
        function onLockedChanged() {
            // Une reprise d'activité annule l'extinction différée, sans annuler le verrouillage.
            if (Session.locked && root.waitingIdleLock) {
                root.waitingIdleLock = false;
                if (monitor.isIdle)
                    Compositor.setPower([], false);
            }
            if (Session.locked && root.preparingSleep)
                root.holding = false;
        }
    }
}
