pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Statistiques système détaillées (ARCHITECTURE § 11.5 « moniteur système », panneau modules/monitor/) : relevées seulement tant que
// le panneau est ouvert (`users`) : processeur et mémoire chaque seconde, processus et GPU toutes les 2,6 s (`update_ms` de ton btop : une liste plus
// rapide saute trop pour qu'on y choisisse une ligne). Processeur (total, par cœur, température), mémoire et swap, GPU (comme nvtop :
// charge, mémoire vidéo, température, consommation, ventilateur, fréquence ; processus qui l'utilisent), disques, processus (charge
// instantanée comme top : temps CPU écoulé depuis le relevé précédent, en % d'un cœur).
Singleton {
    id: root

    property int users: 0
    readonly property bool active: users > 0
    // Ouvrir ou fermer le panneau : modules/monitor/SystemMonitor.qml écoute. `from` : pilule du module cliqué (null : raccourci).
    signal toggleRequested(Item from)

    function toggle(from: Item): void {
        toggleRequested(from);
    }

    // --- Processeur ---
    property int cpuTotal: 0
    property var cores: []             // % par cœur
    property int cpuTemperature: -1    // °C (capteur coretemp, k10temp ou zenpower)
    property var previousCores: []

    // --- Mémoire (octets) ---
    property real memTotal: 0
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0

    // --- GPU ---
    property var gpu: null             // { name, load, memUsed, memTotal (Mio), temperature, power (W), fan (%), clock (MHz) }
    property var gpuProcesses: ({})    // pid → mémoire vidéo (Mio)

    // --- Disques ---
    property var disks: []             // [{ mount, size, used }] (octets)

    // --- Processus ---
    property var processes: []         // [{ pid, name, user, cpu (%), memory (octets), gpu (Mio) }]
    property var previousTimes: ({})   // pid → temps CPU (tics)
    property real previousTotal: 0     // tics de tous les cœurs
    readonly property string me: Quickshell.env("USER") ?? ""

    // Arrêt d'un de tes processus : SIGTERM (`force` : SIGKILL). Pas d'élévation de droits. SIGKILL : retiré de la liste tout de
    // suite. SIGTERM : le processus peut l'ignorer ; il reste choisi jusqu'au relevé suivant, pour pouvoir le forcer s'il survit.
    function stop(pid: int, force: bool): void {
        Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM", String(pid)]);
        if (force)
            processes = processes.filter(p => p.pid !== pid);
    }

    // Panneau fermé : relevés précédents oubliés, sinon le premier % CPU à la réouverture serait une moyenne sur toute la fermeture.
    onActiveChanged: {
        if (!active) {
            previousCores = [];
            previousTimes = {};
            previousTotal = 0;
        }
    }

    Timer {
        interval: 1000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpu.reload();
            mem.reload();
        }
    }

    Timer {
        interval: 2600
        running: root.active
        repeat: true
        triggeredOnStart: true
        // GPU au même rythme : `nvidia-smi pmon` mesure pendant 1 s, une requête par seconde le ferait tourner sans arrêt.
        onTriggered: {
            if (!processList.running)
                processList.running = true;
            if (!gpuQuery.running && (Gpu.useSmi || Gpu.sensorPath !== ""))
                gpuQuery.running = true;
        }
    }

    Timer {
        interval: 5000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!diskList.running)
                diskList.running = true;
        }
    }

    // Une charge se mesure entre deux relevés : second relevé peu après le premier, pour ne pas montrer des 0 % à l'ouverture
    // jusqu'au prochain tour des minuteries.
    Timer {
        id: secondSample
        interval: 300
        onTriggered: {
            if (!root.active)
                return;
            cpu.reload();
            if (!processList.running)
                processList.running = true;
        }
    }

    // Lignes cpuN de /proc/stat : charge de chaque cœur depuis le relevé précédent, tronquée comme SystemStats (Waybar), pour que
    // la barre et le panneau donnent la même valeur au même relevé.
    FileView {
        id: cpu
        path: "/proc/stat"
        onLoaded: {
            if (!root.active)   // relevé fini après la fermeture : ignoré (relevés précédents remis à zéro)
                return;
            const rows = text().split("\n").filter(l => /^cpu\d* /.test(l)).map(l => {
                const t = l.trim().split(/\s+/).slice(1).map(Number);
                return { idle: t[3] + t[4], total: t.reduce((a, b) => a + b, 0) };
            });
            const usage = rows.map((r, i) => {
                const p = root.previousCores[i];
                return p && r.total > p.total ? Math.floor(100 * (1 - (r.idle - p.idle) / (r.total - p.total))) : 0;
            });
            root.previousCores = rows;
            root.cpuTotal = usage[0] ?? 0;
            root.cores = usage.slice(1);
        }
    }

    FileView {
        id: mem
        path: "/proc/meminfo"
        onLoaded: {
            const kib = {};
            for (const line of text().split("\n")) {
                const m = line.match(/^(\w+):\s+(\d+)/);
                if (m)
                    kib[m[1]] = Number(m[2]) * 1024;
            }
            root.memTotal = kib.MemTotal ?? 0;
            root.memUsed = (kib.MemTotal ?? 0) - (kib.MemAvailable ?? 0);
            root.swapTotal = kib.SwapTotal ?? 0;
            root.swapUsed = (kib.SwapTotal ?? 0) - (kib.SwapFree ?? 0);
        }
    }

    // Température du processeur : premier capteur coretemp / k10temp / zenpower (temp1 : boîtier ou Tctl), toutes les 5 s.
    Timer {
        interval: 5000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuTemp.running = true
    }

    Process {
        id: cpuTemp
        command: ["sh", "-c", 'for h in /sys/class/hwmon/hwmon*; do case "$(cat "$h/name" 2>/dev/null)" in coretemp|k10temp|zenpower) cat "$h/temp1_input"; exit 0;; esac; done; exit 0']
        stdout: StdioCollector {
            onStreamFinished: root.cpuTemperature = text.trim() !== "" ? Math.round(Number(text) / 1000) : -1
        }
    }

    // Processus : temps CPU (/proc/PID/stat), mémoire résidente et utilisateurs (ps), total des cœurs (/proc/stat), en un seul
    // passage. `user:64` : nom complet (8 caractères par défaut, au-delà tronqué ou remplacé par l'UID).
    Process {
        id: processList
        command: ["sh", "-c", 'head -1 /proc/stat; echo ---; cat /proc/[0-9]*/stat 2>/dev/null; echo ---; ps -eo pid=,rss=,user:64=']
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active)
                    return;
                const [head, stats, users] = text.split("\n---\n");
                const total = head.trim().split(/\s+/).slice(1).map(Number).reduce((a, b) => a + b, 0);
                const owner = {}, rss = {};
                for (const line of (users ?? "").split("\n")) {
                    const m = line.trim().match(/^(\d+)\s+(\d+)\s+(\S+)/);
                    if (m) {
                        rss[m[1]] = Number(m[2]);   // Kio : pas de taille de page supposée
                        owner[m[1]] = m[3];
                    }
                }
                const elapsed = total - root.previousTotal;
                const coresCount = Math.max(1, root.cores.length);
                const times = {};
                const list = [];
                for (const line of (stats ?? "").split("\n")) {
                    const open = line.indexOf("("), close = line.lastIndexOf(")");
                    if (open < 0 || close < 0)
                        continue;
                    const pid = line.slice(0, open).trim();
                    const rest = line.slice(close + 2).split(" ");
                    const time = Number(rest[11]) + Number(rest[12]);
                    times[pid] = time;
                    const before = root.previousTimes[pid];
                    list.push({
                        pid: Number(pid),
                        name: line.slice(open + 1, close),
                        user: owner[pid] ?? "",
                        cpu: before !== undefined && elapsed > 0 ? Math.round(1000 * (time - before) / (elapsed / coresCount)) / 10 : 0,
                        memory: (rss[pid] ?? 0) * 1024,
                        gpu: root.gpuProcesses[pid] ?? 0
                    });
                }
                const first = root.previousTotal === 0;
                root.previousTimes = times;
                root.previousTotal = total;
                root.processes = list;
                if (first)
                    secondSample.start();
            }
        }
    }

    // GPU : nvidia-smi (requête + processus) ; AMD : sysfs ; autres : température seule (service Gpu).
    Process {
        id: gpuQuery
        command: Gpu.vendor === "nvidia" && Gpu.useSmi
            ? ["sh", "-c", "nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,fan.speed,clocks.gr --format=csv,noheader,nounits; echo ---; nvidia-smi pmon -c 1 -s m"]
            // Fichier absent (Intel, Nvidia sans nvidia-smi) : ligne « nom » sans valeur, mesure masquée.
            : ["sh", "-c", 'd="$(dirname "$(dirname "$(dirname "$0")")")"; for f in gpu_busy_percent mem_info_vram_used mem_info_vram_total; do echo "$f $(cat "$d/$f" 2>/dev/null)"; done', Gpu.sensorPath]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active)
                    return;
                if (Gpu.vendor === "nvidia" && Gpu.useSmi) {
                    const [query, pmon] = text.split("\n---\n");
                    const f = (query ?? "").split("\n")[0].split(",").map(s => s.trim());
                    const num = s => isNaN(Number(s)) ? -1 : Number(s);
                    root.gpu = { name: f[0] ?? "", load: num(f[1]), memUsed: num(f[2]), memTotal: num(f[3]), temperature: num(f[4]),
                        power: num(f[5]), fan: num(f[6]), clock: num(f[7]) };
                    const procs = {};
                    for (const line of (pmon ?? "").split("\n")) {
                        if (line.startsWith("#"))
                            continue;
                        const c = line.trim().split(/\s+/);
                        if (c.length >= 4 && /^\d+$/.test(c[1]))
                            procs[c[1]] = Number(c[3]) || 0;   // colonne fb (Mio)
                    }
                    root.gpuProcesses = procs;
                    // `pmon` dure 1 s : la liste des processus, relevée en même temps, a fini avant lui.
                    root.processes = root.processes.map(p => Object.assign({}, p, { gpu: procs[p.pid] ?? 0 }));
                } else {
                    const v = {};
                    for (const line of text.split("\n")) {
                        const [name, value] = line.trim().split(" ");
                        if (value !== undefined && value !== "" && !isNaN(Number(value)))
                            v[name] = Number(value);
                    }
                    const vram = v.mem_info_vram_used !== undefined && v.mem_info_vram_total !== undefined;
                    root.gpu = { name: Gpu.vendor.toUpperCase(), load: v.gpu_busy_percent ?? -1,
                        memUsed: vram ? v.mem_info_vram_used / 1048576 : -1, memTotal: vram ? v.mem_info_vram_total / 1048576 : -1,
                        temperature: Gpu.temperature, power: -1, fan: -1, clock: -1 };
                }
            }
        }
    }

    Process {
        id: diskList
        command: ["df", "-B1", "-l", "--output=target,size,used", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay",
            "-x", "squashfs"]
        stdout: StdioCollector {
            onStreamFinished: root.disks = text.split("\n").slice(1).map(l => l.trim().split(/\s+/)).filter(c => c.length === 3)
                .map(c => ({ mount: c[0], size: Number(c[1]), used: Number(c[2]) }))
        }
    }

    // `qs ipc call monitor toggle` (raccourci, phase 10) : panneau modules/monitor/MonitorPanel.qml.
    IpcHandler {
        target: "monitor"

        function toggle(): void {
            root.toggle(null);
        }
    }
}
