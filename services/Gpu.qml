pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "IntelGpu.js" as IntelGpu

// Utilisation et température du GPU (module Waybar `custom/nvidia` ; ARCHITECTURE.md § 7.16), toutes les 5 s.
// Carte : celle qui affiche le démarrage (`boot_vga`), sinon la première. Lecture selon le constructeur :
// NVIDIA → `nvidia-smi` (aucun capteur hwmon) ; AMD → `gpu_busy_percent` et capteur hwmon (`edge` de préférence) ;
// Intel → compteurs PMU via intel_gpu_top (un seul processus persistant, toutes les 5 s).
// Aucune utilisation lisible (outil/droits absents…) → `available` faux, module de la barre masqué.
// QS_SYSFS_ROOT (tests seulement) : racine remplaçant /sys, pour simuler d'autres cartes.
Singleton {
    id: root

    readonly property string sysfs: Quickshell.env("QS_SYSFS_ROOT") || "/sys"
    property string vendor: ""        // "nvidia", "amd", "intel" ou ""
    property string cardPath: ""      // carte DRM retenue, indépendante de ses capteurs
    property string sensorPath: ""    // capteur du noyau (fichier temp*_input) : AMD, Intel, Nvidia sans nvidia-smi (nouveau)
    property string busyPath: ""      // utilisation (gpu_busy_percent) : AMD
    property bool intelTool: false
    property var intelStats: null
    property var intelStream: IntelGpu.stream()
    property bool intelWarmup: true
    property real intelLastFrame: 0
    property bool intelReportedFailure: false
    // NVIDIA : nvidia-smi, sinon capteur du noyau.
    property bool useSmi: false
    property bool smiAnswers: true    // dernier relevé de nvidia-smi réussi
    property int temperature: -1      // °C
    property int usage: -1            // %
    readonly property bool available: usage >= 0

    // Détection, une fois : constructeur, nvidia-smi présent, capteur, utilisation de la carte retenue (une ligne chacun).
    Process {
        running: true
        command: ["sh", "-c", `
            root="$1"; chosen=""
            for card in "$root"/class/drm/card[0-9]*; do
                case "\${card##*/}" in *-*) continue ;; esac
                [ -r "$card/device/vendor" ] || continue
                [ -z "$chosen" ] && chosen="$card"
                [ "$(cat "$card/device/boot_vga" 2>/dev/null)" = 1 ] && { chosen="$card"; break; }
            done
            [ -n "$chosen" ] || exit 0
            sensor=""
            for input in "$chosen"/device/hwmon/hwmon*/temp*_input; do
                [ -r "$input" ] || continue
                [ -z "$sensor" ] && sensor="$input"
                [ "$(cat "\${input%_input}_label" 2>/dev/null)" = edge ] && { sensor="$input"; break; }
            done
            busy=""; [ -r "$chosen/device/gpu_busy_percent" ] && busy="$chosen/device/gpu_busy_percent"
            smi=0; command -v nvidia-smi >/dev/null 2>&1 && smi=1
            intel=0; command -v intel_gpu_top >/dev/null 2>&1 && intel=1
            printf '%s\n' "$(cat "$chosen/device/vendor")" "$smi" "$sensor" "$busy" "$chosen" "$intel"`, "sh", root.sysfs]
        stdout: StdioCollector {
            onStreamFinished: {
                const [id, smi, sensor, busy, card, intel] = text.split("\n");
                root.vendor = ({ "0x10de": "nvidia", "0x1002": "amd", "0x8086": "intel" })[id] ?? "";
                root.cardPath = card ?? "";
                root.sensorPath = sensor ?? "";
                root.busyPath = busy ?? "";
                root.intelTool = intel === "1";
                root.useSmi = root.vendor === "nvidia" && smi === "1";
                poll.running = root.useSmi || root.sensorPath !== "" || root.busyPath !== "";
                console.info(`Gpu: carte ${id || "aucune"} (${root.vendor || "inconnue"}), lecture ${root.useSmi ? "nvidia-smi" : root.vendor === "intel" && root.intelTool ? "intel_gpu_top (PMU)" : [root.sensorPath, root.busyPath].filter(Boolean).join(", ") || "aucune"}`);
            }
        }
    }

    function clearIntel(): void {
        intelStats = null;
        usage = -1;
    }

    Process {
        id: intelTop
        running: root.vendor === "intel" && root.intelTool && root.cardPath !== ""
        command: ["intel_gpu_top", "-J", "-s", "5000", "-o", "-", "-d", "drm:/dev/dri/" + root.cardPath.split("/").pop()]
        onStarted: {
            root.intelStream = IntelGpu.stream();
            root.intelWarmup = true;
            root.intelLastFrame = Date.now();
        }
        stdout: SplitParser {
            onRead: line => {
                try {
                    for (const frame of IntelGpu.read(root.intelStream, line + "\n")) {
                        root.intelLastFrame = Date.now();
                        // The first report covers counter setup, not a full sampling interval.
                        if (root.intelWarmup) { root.intelWarmup = false; continue; }
                        const stats = IntelGpu.normalize(frame);
                        root.intelStats = stats;
                        root.usage = stats.gpu.load < 0 ? -1 : Math.round(stats.gpu.load);
                        root.intelReportedFailure = false;
                    }
                } catch (error) {
                    root.clearIntel();
                    root.intelStream = IntelGpu.stream();
                }
            }
        }
        // Do not repeat permission errors every five seconds in the desktop log.
        stderr: StdioCollector {}
        onExited: code => {
            root.clearIntel();
            if (code !== 0 && !root.intelReportedFailure) {
                console.info("Gpu: intel_gpu_top indisponible (outil ou droits PMU), nouvelle tentative dans 5 s");
                root.intelReportedFailure = true;
            }
        }
    }

    Timer {
        interval: 5000
        running: root.vendor === "intel" && root.intelTool
        repeat: true
        onTriggered: {
            if (!intelTop.running) intelTop.running = true;
            else if (Date.now() - root.intelLastFrame > 15000) {
                root.clearIntel();
                intelTop.running = false;
            }
        }
    }

    Timer {
        id: poll
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.useSmi)
                nvidiaSmi.running = true;
            if (!root.useSmi || !root.smiAnswers) {
                if (root.sensorPath !== "")
                    sensor.reload();
                if (root.busyPath !== "")
                    busy.reload();
            }
        }
    }

    Process {
        id: nvidiaSmi
        command: ["nvidia-smi", "--query-gpu=temperature.gpu,utilization.gpu", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [temperature, usage] = text.split("\n")[0].split(",").map(v => parseInt(v));
                root.temperature = isNaN(temperature) ? -1 : temperature;
                root.usage = isNaN(usage) ? -1 : usage;
            }
        }
        // nvidia-smi en échec (paquet en cours de remplacement, pilote absent ou à recharger) : module de la barre masqué, capteur du
        // noyau s'il y en a un ; toujours interrogé, le module revient dès qu'il répond.
        onExited: code => {
            const answers = code === 0;
            if (answers === root.smiAnswers)
                return;
            root.smiAnswers = answers;
            console.info(`Gpu: nvidia-smi ${answers ? "de nouveau disponible" : `en échec, capteur ${root.sensorPath || "aucun"}`}`);
        }
    }

    FileView {
        id: sensor
        path: root.sensorPath
        printErrors: false
        // reload() est asynchrone : lecture à la fin du chargement.
        onLoaded: {
            const millidegrees = parseInt(text());
            root.temperature = isNaN(millidegrees) ? -1 : Math.round(millidegrees / 1000);
        }
        onLoadFailed: root.temperature = -1
    }

    FileView {
        id: busy
        path: root.busyPath
        printErrors: false
        onLoaded: {
            const value = parseInt(text());
            root.usage = isNaN(value) ? -1 : value;
        }
        onLoadFailed: root.usage = -1
    }
}
