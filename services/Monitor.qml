pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Statistiques système détaillées (ARCHITECTURE § 7.16 « moniteur système », panneau modules/monitor/) : relevées seulement tant que
// le panneau est ouvert (`users`) : processeur et mémoire chaque seconde, processus et GPU toutes les 2,6 s (`update_ms` de ton btop : une liste plus
// rapide saute trop pour qu'on y choisisse une ligne). Processeur (total, par cœur, température), mémoire et swap, GPU (comme nvtop :
// charge, mémoire vidéo, température, consommation, ventilateur, fréquence ; processus qui l'utilisent), disques, processus (charge
// instantanée comme top : temps CPU écoulé depuis le relevé précédent, en % d'un cœur).
Singleton {
    id: root

    property int users: 0
    readonly property bool active: users > 0
    // Ouvrir ou fermer le panneau : modules/monitor/SystemMonitor.qml écoute. `from` : rangée de modules de la pilule cliquée (null : raccourci).
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
    property real lastIntelSample: 0
    property var gpuProcesses: ({})    // pid → mémoire vidéo NVIDIA (Mio)

    // --- Disques ---
    property var disks: []             // [{ mount, size, used }] (octets)

    // --- Processus ---
    property var processes: []         // [{ pid, name, user, cpu (%), memory (octets), gpu (Mio) }]
    property var applicationGroups: []
    property var membership: ({})
    property string stopError: ""
    property var stopRequest: null
    readonly property var catalog: DesktopEntries.applications.values.map(e => ({ id: e.id, name: e.name, startupClass: e.startupClass, command: Array.from(e.command) }))
    function gpuMemory(members): real {
        const clients = {};
        for (const p of members)
            Object.assign(clients, p.gpuClients ?? {});
        return Object.keys(clients).length ? Object.values(clients).reduce((n, v) => n + v, 0)
            : members.reduce((n, p) => n + p.gpu, 0);
    }
    readonly property var applications: applicationGroups.map(g => {
        const members = processes.filter(p => g.members.includes(p.key));
        return { key: g.id, id: g.id, name: g.name, count: members.length, user: me,
            cpu: members.reduce((n, p) => n + p.cpu, 0), memory: members.reduce((n, p) => n + p.memory, 0),
            gpu: gpuMemory(members), members: g.members, roots: g.roots, blocked: g.blocked };
    }).filter(g => g.count > 0)
    property var previousTimes: ({})   // PID + start time → CPU ticks
    property real previousTotal: 0     // tics de tous les cœurs
    readonly property string me: Quickshell.env("USER") ?? ""

    // Arrêt d'un de tes processus : SIGTERM (`force` : SIGKILL). Pas d'élévation de droits. Relevé peu après : le processus quitte
    // la liste s'il est vraiment parti ; s'il survit (SIGTERM ignoré), il reste choisi, prêt à être forcé.
    function requestData(): var {
        return { entries: catalog, previous: membership, windows: Compositor.isHyprland
            ? Hyprland.toplevels.values.map(t => ({ pid: t.lastIpcObject.pid ?? -1,
                appId: t.wayland?.appId || t.lastIpcObject.class || "" })).filter(w => w.pid > 0 && w.appId !== "") : [] };
    }

    function stop(pid: int, force: bool): void {
        const p = processes.find(p => p.pid === pid);
        if (p) stopProcess(p.key, force);
    }

    function stopProcess(key: string, force: bool): void {
        const p = processes.find(p => p.key === key);
        if (!p || p.user !== me)
            return;
        executeStop({ members: [key], roots: [key], force: force });
    }

    function stopApplication(id: string, force: bool, confirmed: var): void {
        if (confirmed?.id !== id)
            return;
        executeStop({ application: id, members: confirmed.members, roots: confirmed.roots, force: force });
    }

    function executeStop(request: var): void {
        if (stopper.running)
            return;
        stopError = "";
        stopRequest = Object.assign(requestData(), request, { action: "stop" });
        stopper.running = true;
    }

    Process {
        id: stopper
        command: ["python", Quickshell.shellPath("scripts/monitor-processes.py")]
        stdinEnabled: true
        onStarted: { write(JSON.stringify(root.stopRequest)); stdinEnabled = false; }
        onRunningChanged: if (!running) stdinEnabled = true
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.stopError = JSON.parse(text).errors.join("; "); }
                catch (e) { root.stopError = "Unable to stop the selected application or process"; }
                secondSample.restart();
            }
        }
    }

    // Panneau fermé : relevés précédents oubliés, sinon le premier % CPU à la réouverture serait une moyenne sur toute la fermeture.
    onActiveChanged: {
        if (!active) {
            previousCores = [];
            previousTimes = {};
            previousTotal = 0;
            gpu = null;
            lastIntelSample = 0;
            gpuProcesses = {};
            processes = processes.map(p => Object.assign({}, p, {gpu: 0, gpuClients: {}}));
        }
    }

    Timer {
        id: fastTimer
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
        id: processTimer
        interval: 2600
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!processList.running) {
                if (Compositor.isHyprland) Hyprland.refreshToplevels();
                processList.running = true;
            }
        }
    }

    // GPU au rythme de la liste des processus, juste après elle : ces commandes n'y figurent pas.
    function sampleGpu(): void {
        if (!gpuQuery.running && (Gpu.useSmi || Gpu.cardPath !== "")) {
            // Intel exposes frequency/memory here: avoid rescanning descriptors every 2.6 s.
            const now = Date.now();
            const elapsed = now - lastIntelSample;
            if (Gpu.vendor !== "intel" || lastIntelSample === 0 || elapsed < 0 || elapsed >= 10000) {
                lastIntelSample = now;
                gpuQuery.running = true;
            }
        }
        if (!gpuProcessList.running && Gpu.vendor === "nvidia" && Gpu.useSmi)
            gpuProcessList.running = true;
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
    // jusqu'au prochain tour des minuteries. Minuteries repartant de ce relevé (un redémarrage relève aussitôt) : le suivant ne
    // peut pas tomber quelques millisecondes après, sur une durée trop courte pour mesurer une charge.
    Timer {
        id: secondSample
        interval: 300
        onTriggered: {
            if (!root.active)
                return;
            fastTimer.restart();
            processTimer.restart();
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

    // One snapshot supplies raw CPU times and stable application membership.
    Process {
        id: processList
        command: ["python", Quickshell.shellPath("scripts/monitor-processes.py")]
        stdinEnabled: true
        onStarted: { write(JSON.stringify(root.requestData())); stdinEnabled = false; }
        onRunningChanged: if (!running) stdinEnabled = true
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active)
                    return;
                let data;
                try { data = JSON.parse(text); }
                catch (e) { console.warn("Monitor: invalid process snapshot", e); return; }
                const elapsed = data.total - root.previousTotal;
                const count = Math.max(1, root.cores.length);
                const times = {}, membership = {};
                const previousGpu = {};
                for (const old of root.processes) previousGpu[old.key] = old;
                const list = data.processes.map(p => {
                    const before = root.previousTimes[p.key];
                    times[p.key] = p.ticks;
                    return Object.assign(p, { cpu: before !== undefined && elapsed > 0
                        ? Math.max(0, Math.round(1000 * (p.ticks - before) / (elapsed / count)) / 10) : 0,
                        gpu: previousGpu[p.key]?.gpu ?? root.gpuProcesses[p.pid] ?? 0,
                        gpuClients: previousGpu[p.key]?.gpuClients ?? {} });
                });
                for (const g of data.applications)
                    for (const key of g.members)
                        membership[key] = { id: g.id, name: g.name };
                const first = root.previousTotal === 0;
                root.previousTimes = times;
                root.previousTotal = data.total;
                root.membership = membership;
                root.processes = list;
                root.applicationGroups = data.applications;
                root.sampleGpu();
                if (first)
                    secondSample.start();
            }
        }
    }

    // Mémoire vidéo par processus (nvidia-smi). Relevée après la liste des processus : mise à jour ici, seulement si une valeur a changé.
    Process {
        id: gpuProcessList
        command: ["nvidia-smi", "pmon", "-c", "1", "-s", "m"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active)
                    return;
                const procs = {};
                for (const line of text.split("\n")) {
                    if (line.startsWith("#"))
                        continue;
                    const c = line.trim().split(/\s+/);
                    if (c.length >= 4 && /^\d+$/.test(c[1]))
                        procs[c[1]] = Number(c[3]) || 0;   // colonne fb (Mio)
                }
                if (JSON.stringify(procs) === JSON.stringify(root.gpuProcesses))
                    return;
                root.gpuProcesses = procs;
                root.processes = root.processes.map(p => Object.assign({}, p, { gpu: procs[p.pid] ?? 0 }));
            }
        }
    }

    // GPU : NVIDIA conserve nvidia-smi ; autres cartes : mesures sysfs et mémoire DRM déclarée.
    Process {
        id: gpuQuery
        command: Gpu.vendor === "nvidia" && Gpu.useSmi
            ? ["nvidia-smi", "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,fan.speed,clocks.gr", "--format=csv,noheader,nounits"]
            : ["python", Quickshell.shellPath("scripts/gpu-stats.py"), Gpu.cardPath, Gpu.vendor]
        stdinEnabled: !(Gpu.vendor === "nvidia" && Gpu.useSmi)
        onStarted: {
            if (stdinEnabled) {
                write(JSON.stringify({ processes: root.processes.map(p => ({pid: p.pid, key: p.key})) }));
                stdinEnabled = false;
            }
        }
        onRunningChanged: if (!running) stdinEnabled = !(Gpu.vendor === "nvidia" && Gpu.useSmi)
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active)
                    return;
                if (Gpu.vendor === "nvidia" && Gpu.useSmi) {
                    const f = text.split("\n")[0].split(",").map(s => s.trim());
                    if (f.length < 8) {   // nvidia-smi en échec : message d'erreur à la place des valeurs
                        root.gpu = null;
                        return;
                    }
                    const num = s => isNaN(Number(s)) ? -1 : Number(s);
                    root.gpu = { name: f[0] ?? "", load: num(f[1]), memUsed: num(f[2]), memTotal: num(f[3]), temperature: num(f[4]),
                        power: num(f[5]), fan: num(f[6]), clock: num(f[7]) };
                } else {
                    try {
                        const data = JSON.parse(text);
                        root.gpu = data.gpu;
                        root.gpuProcesses = {};
                        root.processes = root.processes.map(p => {
                            const clients = data.clients[p.key] ?? {};
                            return Object.assign({}, p, { gpuClients: clients,
                                gpu: Object.values(clients).reduce((n, v) => n + v, 0) });
                        });
                    } catch (error) {
                        root.gpu = null;
                        root.gpuProcesses = {};
                        root.processes = root.processes.map(p => Object.assign({}, p, {gpu: 0, gpuClients: {}}));
                        console.warn("Monitor: invalid GPU snapshot", error);
                    }
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
