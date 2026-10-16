pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Rétroéclairage de l'écran interne (INVENTORY.md § 1, module `backlight`, défini dans Waybar mais placé dans aucune barre).
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

    // Molette : ±1 %, pas par défaut du module `backlight` de Waybar.
    function step(points: int): void {
        if (available)
            Quickshell.execDetached(["brightnessctl", "--device", device, "set", `${Math.abs(points)}%${points > 0 ? "+" : "-"}`]);
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
