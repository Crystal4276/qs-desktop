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

    // Dernière valeur demandée en % (-1 : aucune en cours) et dernière envoyée. Pendant une commande, seule la dernière demandée
    // est appliquée ensuite ; elle sert de base aux pas jusqu'à la relecture du fichier (asynchrone), faite dès la fin (OSD à jour).
    property int target: -1
    property int applied: -1

    // Molette et touches : ±points % depuis la dernière valeur demandée (des crans rapprochés s'additionnent, aucun n'est perdu).
    function step(points: int): void {
        setPercent((target >= 0 ? target : percent) + points);
    }

    // Curseur du panneau de réglages : valeur absolue en %.
    function setPercent(p: int): void {
        if (!available)
            return;
        target = Math.max(1, Math.min(100, p));   // jamais 0 : écran noir
        if (!setter.running)
            apply();
    }

    function apply(): void {
        applied = target;
        setter.command = ["brightnessctl", "--device", device, "set", `${target}%`];
        setter.running = true;
    }

    Process {
        id: setter
        onExited: {
            if (root.target !== root.applied)
                root.apply();
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
        onLoaded: {
            root.current = parseInt(text()) || 0;
            if (!setter.running)
                root.target = -1;
        }
    }

    Timer {
        interval: 1000
        running: root.device !== ""
        repeat: true
        onTriggered: currentFile.reload()
    }
}
