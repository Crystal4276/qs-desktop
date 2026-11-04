pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Rétroéclairage de l'écran interne (module Waybar `backlight`, défini dans Waybar mais placé dans aucune barre).
// Premier périphérique de /sys/class/backlight (Waybar : `intel_backlight` écrit en dur). Absent → `available` faux.
// Lecture : sysfs, relu chaque seconde ; écriture : `brightnessctl` (sysfs n'est pas inscriptible sans droits).
// QS_SYSFS_ROOT (tests seulement) : racine remplaçant /sys.
Singleton {
    id: root

    readonly property string sysfs: Quickshell.env("QS_SYSFS_ROOT") || "/sys"
    property string device: ""
    readonly property bool available: device !== "" && max > 0
    property int max: 0
    property int current: 0
    readonly property int percent: max > 0 ? Math.round(100 * current / max) : 0

    // Changement fait au clavier (IPC ci-dessous) : affiché par l'OSD (modules/osd).
    signal changedByKey

    // Molette : ±1 %, pas par défaut du module `backlight` de Waybar. Valeur relue dès la fin de la commande (OSD à jour).
    function step(points: int): void {
        if (!available || setter.running)
            return;
        setter.command = ["brightnessctl", "--device", device, "set", `${Math.abs(points)}%${points > 0 ? "+" : "-"}`];
        setter.running = true;
    }

    // Curseur du panneau de réglages : valeur absolue en %. Pendant un glissement, seule la dernière valeur demandée est appliquée.
    property int pending: -1

    function setPercent(p: int): void {
        if (!available)
            return;
        pending = Math.max(1, Math.min(100, p));   // jamais 0 : écran noir
        if (!setter.running)
            applyPending();
    }

    function applyPending(): void {
        setter.command = ["brightnessctl", "--device", device, "set", `${pending}%`];
        pending = -1;
        setter.running = true;
    }

    Process {
        id: setter
        onExited: {
            if (root.pending >= 0)
                root.applyPending();
            else
                currentFile.reload();
        }
    }

    // Touches de luminosité (raccourcis, phase 10 ; Sway : brightnessctl ±5 %) : `qs ipc call brightness up|down`.
    IpcHandler {
        target: "brightness"

        function up(): void {
            root.step(5);
            root.changedByKey();
        }

        function down(): void {
            root.step(-5);
            root.changedByKey();
        }
    }

    Process {
        running: true
        command: ["sh", "-c", 'for d in "$1"/class/backlight/*; do [ -r "$d/max_brightness" ] && { echo "${d##*/}"; exit; }; done', "sh", root.sysfs]
        stdout: StdioCollector {
            onStreamFinished: {
                root.device = text.trim();
                if (root.device !== "")
                    console.info(`Brightness: ${root.device}`);
            }
        }
    }

    FileView {
        id: maxFile
        path: root.device ? `${root.sysfs}/class/backlight/${root.device}/max_brightness` : ""
        blockLoading: true
        onLoaded: root.max = parseInt(text()) || 0
    }

    FileView {
        id: currentFile
        path: root.device ? `${root.sysfs}/class/backlight/${root.device}/brightness` : ""
        blockLoading: true
        onLoaded: root.current = parseInt(text()) || 0
    }

    Timer {
        interval: 1000
        running: root.device !== ""
        repeat: true
        onTriggered: currentFile.reload()
    }
}
