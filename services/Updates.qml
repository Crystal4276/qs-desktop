pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Mises à jour en attente (INVENTORY.md § 1, module `custom/updates`) : `checkupdates | wc -l` toutes les 8600 s,
// comme Waybar. `checkupdates` absent (autre distribution) ou 0 mise à jour → module masqué.
// Clic : `Settings.updateCommand` dans un terminal, qui attend Entrée, puis nouveau comptage (update-wrapper.sh).
Singleton {
    id: root

    property int count: 0

    function refresh(): void {
        check.running = true;
    }

    function update(): void {
        if (upgrade.running || Settings.updateCommand === "")
            return;
        upgrade.command = [...Settings.terminal, "bash", "-c", `${Settings.updateCommand}; echo -e "\\nPress Enter to close..."; read`];
        upgrade.running = true;
    }

    Process {
        id: check
        command: ["checkupdates"]
        stdout: StdioCollector {
            onStreamFinished: root.count = text.split("\n").filter(l => l.trim() !== "").length
        }
        // Code 2 : aucune mise à jour ; 1 : erreur (réseau…) ; absent : ne démarre pas.
        onExited: code => {
            if (code !== 0)
                root.count = 0;
        }
    }

    // Le terminal est lancé avec attente (`--wait` de gnome-terminal) : sa fin déclenche le nouveau comptage.
    Process {
        id: upgrade
        onExited: root.refresh()
    }

    Timer {
        interval: 8600 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
