import QtQuick
import Quickshell
import Quickshell.Io

// Commande d'action d'un service en ligne de commande (Tailscale, ZeroTier) : présence du programme cherchée une fois
// (`command -v`), une commande à la fois (`busy`), message d'erreur gardé (`error`), `finished` à la fin.
Scope {
    id: root

    required property string program
    property bool available: false
    property bool busy: false
    property string error: ""
    signal finished

    // Renvoie faux si une autre commande est en cours (rien n'est lancé).
    function run(args: var): bool {
        if (busy)
            return false;
        error = "";
        busy = true;
        command.command = [program, ...args];
        command.running = true;
        return true;
    }

    Process {
        running: true
        command: ["sh", "-c", 'command -v "$1"', "sh", root.program]
        onExited: code => root.available = code === 0
    }

    Process {
        id: command
        stdout: StdioCollector {
            id: out
        }
        stderr: StdioCollector {
            id: err
        }
        onExited: code => {
            root.busy = false;
            // Première ligne non vide : le message (une option refusée est suivie de toute l'aide de la commande).
            if (code !== 0)
                root.error = (err.text.trim() || out.text.trim()).split("\n").find(l => l.trim() !== "")?.trim()
                    ?? `${root.program}: exit code ${code}`;
            root.finished();
        }
    }
}
