pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Température du GPU (INVENTORY.md § 1, module `custom/nvidia` ; ARCHITECTURE.md § 11.5), toutes les 5 s.
// Carte : celle qui affiche le démarrage (`boot_vga`), sinon la première. Lecture selon le constructeur :
// NVIDIA → `nvidia-smi` (aucun capteur hwmon) ; AMD, Intel → capteur hwmon de la carte (`edge` de préférence).
// Aucune température lisible (iGPU seul, nvidia-smi absent…) → `available` faux, module masqué.
// QS_SYSFS_ROOT (tests seulement) : racine remplaçant /sys, pour simuler d'autres cartes.
Singleton {
    id: root

    readonly property string sysfs: Quickshell.env("QS_SYSFS_ROOT") || "/sys"
    property string vendor: ""        // "nvidia", "amd", "intel" ou ""
    property string sensorPath: ""    // capteur du noyau (fichier temp*_input) : AMD, Intel, Nvidia sans nvidia-smi (nouveau)
    // Nvidia : nvidia-smi s'il est installé et répond ; sinon le capteur du noyau, comme les autres cartes.
    property bool useSmi: false
    property int temperature: -1      // °C
    readonly property bool available: temperature >= 0

    function openMonitor(): void {
        Quickshell.execDetached([...Settings.terminal, "nvtop"]);
    }

    // Détection, une fois : « <vendor> <capteur> » de la carte retenue.
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
            smi=0; command -v nvidia-smi >/dev/null 2>&1 && smi=1
            echo "$(cat "$chosen/device/vendor") $smi $sensor"`, "sh", root.sysfs]
        stdout: StdioCollector {
            onStreamFinished: {
                const [id, smi, sensor] = text.trim().split(" ");
                root.vendor = ({ "0x10de": "nvidia", "0x1002": "amd", "0x8086": "intel" })[id] ?? "";
                root.sensorPath = sensor ?? "";
                root.useSmi = root.vendor === "nvidia" && smi === "1";
                poll.running = root.useSmi || root.sensorPath !== "";
                console.info(`Gpu: carte ${id || "aucune"} (${root.vendor || "inconnue"}), capteur ${root.useSmi ? "nvidia-smi" : root.sensorPath || "aucun"}`);
            }
        }
    }

    Timer {
        id: poll
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.useSmi) {
                nvidiaSmi.running = true;
            } else {
                sensor.reload();
            }
        }
    }

    Process {
        id: nvidiaSmi
        command: ["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseInt(text.split("\n")[0]);
                root.temperature = isNaN(value) ? -1 : value;
            }
        }
        // nvidia-smi en échec (pilote propriétaire absent) : capteur du noyau à la place ; sans capteur, plus de sondage
        // (module masqué).
        onExited: code => {
            if (code === 0)
                return;
            root.temperature = -1;
            root.useSmi = false;
            poll.running = root.sensorPath !== "";
            console.info(`Gpu: nvidia-smi en échec, capteur ${root.sensorPath || "aucun"}`);
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
}
