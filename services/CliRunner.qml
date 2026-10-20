import QtQuick
import Quickshell
import Quickshell.Io

// Commande d'action d'un service en ligne de commande (Tailscale, ZeroTier) : présence du programme cherchée une fois
// (`command -v`), une commande à la fois (`busy`), message d'erreur gardé (`error`), `finished` à la fin.
Scope {
    id: root

    required property string program
    property bool probe: true          // chercher le programme (faux : un autre lanceur le fait déjà)
    property bool available: false
    property bool busy: false
    property string error: ""
    property int code: 0          // code de sortie de la dernière commande (-1 : pas démarrée)
    property string output: ""    // sa sortie standard
    property bool lastLineError: false   // message : dernière ligne de la sortie (nordvpn : sa progression précède l'erreur)
    property string noAnswer: `${program}: no answer (sign-in needed?)`   // arrêtée par `timeout` (124)
    signal finished

    // Renvoie faux si une autre commande est en cours (rien n'est lancé).
    function run(args: var): bool {
        return runCommand([program, ...args]);
    }

    // Commande complète (ex. bornée par `timeout`).
    function runCommand(cmd: var): bool {
        if (busy)
            return false;
        error = "";
        busy = true;
        command.command = cmd;
        command.running = true;
        return true;
    }

    Process {
        running: root.probe
        command: ["sh", "-c", 'command -v "$1"', "sh", root.program]
        onExited: code => root.available = code === 0
    }

    // Arrêt de la commande en cours par SIGINT (Ctrl+C : annulation propre, nordvpn ; `timeout` le transmet) : `finished`
    // suit, avec son code de sortie.
    function interrupt(): void {
        command.signal(2);
    }

    // Arrêt forcé (SIGTERM) : SIGINT, relayé par `timeout`, est ignoré par la commande si Quickshell a été lancé en
    // arrière-plan (`qs … &` : SIGINT ignoré, hérité à chaque exec).
    function stop(): void {
        command.running = false;
    }

    // Commande qui ne démarre pas (programme retiré pendant une mise à jour) : Quickshell n'émet pas `exited`, seulement
    // `running` faux ; sans ce rattrapage, `busy` resterait vrai pour la session.
    function settleIfFailed(): void {
        if (busy && !command.running) {
            busy = false;
            code = -1;
            output = "";
            error = `${program}: could not start`;
            finished();
        }
    }

    Process {
        id: command
        onRunningChanged: if (!running) Qt.callLater(root.settleIfFailed)
        stdout: StdioCollector {
            id: out
        }
        stderr: StdioCollector {
            id: err
        }
        onExited: code => {
            root.busy = false;
            root.code = code;
            root.output = out.text;
            // 124 : arrêtée par `timeout` (sa sortie, ex. « To authenticate, visit: » sans l'adresse, n'est pas le message).
            // Sinon la première ligne non vide (une option refusée est suivie de toute l'aide de la commande), ou la dernière
            // (`lastLineError`).
            if (code === 124) {
                root.error = root.noAnswer;
            } else if (code !== 0) {
                // Retours chariot de l'indicateur de progression (« \r-\r\\\r ») : segments séparés, ceux du seul indicateur ôtés ;
                // stderr d'abord, s'il reste quelque chose.
                const clean = t => t.split(/[\r\n]+/).map(l => l.trim()).filter(l => l !== "" && !/^[-\\|\/]+$/.test(l));
                const errLines = clean(err.text);
                const lines = errLines.length > 0 ? errLines : clean(out.text);
                root.error = (root.lastLineError ? lines[lines.length - 1] : lines[0]) ?? `${root.program}: exit code ${code}`;
            }
            root.finished();
        }
    }
}
