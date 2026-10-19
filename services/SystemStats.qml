pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Processeur et mémoire (INVENTORY.md § 1, modules `cpu` et `memory`), toutes les 5 s comme Waybar.
// Calculs repris de Waybar 0.15 (cpu_usage/linux.cpp, memory/common.cpp).
Singleton {
    id: root

    // Utilisation totale du processeur en %, tronquée à l'entier comme Waybar.
    property int cpuUsage: 0
    // Mémoire en Gio, arrondie au centième comme Waybar ; utilisée = totale - disponible (MemAvailable).
    property real memUsed: 0
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0

    property var previousCpu: null

    // Première ligne de /proc/stat : temps cumulés de tous les cœurs ; inactif = idle + iowait.
    function parseCpu(text: string): void {
        const times = text.split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        const cpu = { idle: times[3] + times[4], total: times.reduce((a, b) => a + b, 0) };
        if (isNaN(cpu.total))
            return;
        if (previousCpu && cpu.total > previousCpu.total)
            cpuUsage = Math.floor(100 * (1 - (cpu.idle - previousCpu.idle) / (cpu.total - previousCpu.total)));
        previousCpu = cpu;
    }

    function parseMemory(text: string): void {
        const kib = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                kib[m[1]] = Number(m[2]);
        }
        const gib = v => Math.round(v / 10485.76) / 100;
        memTotal = gib(kib.MemTotal ?? 0);
        memUsed = gib((kib.MemTotal ?? 0) - (kib.MemAvailable ?? 0));
        swapTotal = gib(kib.SwapTotal ?? 0);
        swapUsed = gib((kib.SwapTotal ?? 0) - (kib.SwapFree ?? 0));
    }

    // reload() est asynchrone : les calculs se font à la fin de chaque lecture.
    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: root.parseCpu(text())
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: root.parseMemory(text())
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
        }
    }
}
