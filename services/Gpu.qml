pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Utilisation et température du GPU (module Waybar `custom/nvidia` ; ARCHITECTURE.md § 7.16), toutes les 5 s.
// Carte : celle qui affiche le démarrage (`boot_vga`), sinon la première. Lecture selon le constructeur :
// NVIDIA → `nvidia-smi` (aucun capteur hwmon) ; AMD → `gpu_busy_percent` et capteur hwmon (`edge` de préférence) ;
// Intel → capteur hwmon seulement (aucune utilisation dans sysfs).
// Aucune utilisation lisible (Intel, nvidia-smi absent…) → `available` faux, module de la barre masqué.
// QS_SYSFS_ROOT (tests seulement) : racine remplaçant /sys, pour simuler d'autres cartes.
Singleton {
    id: root

    readonly property string sysfs: Quickshell.env("QS_SYSFS_ROOT") || "/sys"
    property string vendor: ""        // "nvidia", "amd", "intel" ou ""
    property string cardPath: ""      // carte DRM retenue, indépendante de ses capteurs
    property string sensorPath: ""    // capteur du noyau (fichier temp*_input) : AMD, Intel, Nvidia sans nvidia-smi (nouveau)
    property string busyPath: ""      // utilisation (gpu_busy_percent) : AMD
    // Nvidia : nvidia-smi s'il est installé et répond ; sinon le capteur du noyau, comme les autres cartes.
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
            printf '%s\n' "$(cat "$chosen/device/vendor")" "$smi" "$sensor" "$busy" "$chosen"`, "sh", root.sysfs]
        stdout: StdioCollector {
            onStreamFinished: {
                const [id, smi, sensor, busy, card] = text.split("\n");
                root.vendor = ({ "0x10de": "nvidia", "0x1002": "amd", "0x8086": "intel" })[id] ?? "";
                root.cardPath = card ?? "";
                root.sensorPath = sensor ?? "";
                root.busyPath = busy ?? "";
                root.useSmi = root.vendor === "nvidia" && smi === "1";
                poll.running = root.useSmi || root.sensorPath !== "" || root.busyPath !== "";
                console.info(`Gpu: carte ${id || "aucune"} (${root.vendor || "inconnue"}), lecture ${root.useSmi ? "nvidia-smi" : [root.sensorPath, root.busyPath].filter(Boolean).join(", ") || "aucune"}`);
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
