pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Mises à jour en attente (module Waybar `custom/updates`) : `checkupdates | wc -l` toutes les 8600 s,
// comme Waybar. `checkupdates` absent (autre distribution) ou 0 mise à jour → module masqué.
// Clic : `Settings.updateCommand` dans un terminal, qui attend Entrée, puis nouveau comptage (update-wrapper.sh).
Singleton {
    id: root

    property int count: 0

    function refresh(): void {
        check.running = true;
    }

    // Sans commande dans la config machine : paru, sinon yay, sinon pacman (comme l'ancien update-wrapper.sh).
    readonly property string fallbackCommand: "if command -v paru >/dev/null; then paru -Syu; elif command -v yay >/dev/null; then yay -Syu; else sudo pacman -Syu; fi"

    function update(): void {
        if (upgrade.running)
            return;
        const command = Settings.updateCommand || fallbackCommand;
        upgrade.command = [...Settings.terminal, "bash", "-c", `${command}; echo -e "\\nPress Enter to close..."; read`];
        upgrade.running = true;
    }

    Process {
        id: check
        command: ["checkupdates"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "")   // aucune mise à jour ou erreur : traité à la sortie
                    return;
                root.count = text.split("\n").filter(l => l.trim() !== "").length;
                console.info(`Updates: ${root.count} mise(s) à jour en attente`);
            }
        }
        // Code 2 : aucune mise à jour ; 1 : erreur (réseau…) : dernier compte gardé, nouvel essai bientôt ; absent : ne démarre pas.
        onExited: code => {
            if (code === 2)
                root.count = 0;
            else if (code !== 0)
                retry.start();
        }
    }

    Timer {
        id: retry
        interval: 300 * 1000
        onTriggered: root.refresh()
    }

    // Le terminal est lancé avec attente (`--wait` de gnome-terminal) : sa fin déclenche le nouveau comptage.
    Process {
        id: upgrade
        environment: Launch.environment
        onExited: {
            console.info("Updates: terminal de mise à jour fermé, nouveau comptage");
            root.refresh();
        }
    }

    Timer {
        interval: 8600 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
