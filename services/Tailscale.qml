pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tailscale (onglet du panneau réseau, ta demande du 2026-10-19) : état, appareils du tailnet, nœud de sortie et options, par
// la commande `tailscale` (pas de bibliothèque native). Lecture sans droits (`status --json`, `debug prefs`) ; les actions
// demandent que ton utilisateur soit « operator » du démon (`sudo tailscale set --operator=$USER`, une fois — install.sh) :
// sans cela, l'erreur de la commande est affichée.
// Relu toutes les 5 s panneau réseau ouvert, toutes les 60 s sinon (icône du tray quand il n'y a pas de câble) ; rien si la
// commande est absente (cherchée une fois au démarrage). Préférences lues panneau ouvert seulement.
Singleton {
    id: root

    readonly property bool polling: Network.networkPanelOpen
    // Commande présente (`command -v`, au démarrage).
    property bool available: false
    // Commande présente et démon joignable (une réponse JSON).
    property bool installed: false
    property var status: null
    property var prefs: null

    readonly property string state: status?.BackendState ?? ""   // Running, Stopped, NeedsLogin, Starting, NoState
    readonly property bool running: state === "Running"
    readonly property bool canAct: (prefs?.OperatorUser ?? "") === Quickshell.env("USER")
    readonly property string tailnet: status?.CurrentTailnet?.Name ?? ""
    readonly property string authUrl: status?.AuthURL ?? ""
    readonly property var health: status?.Health ?? []
    readonly property var self: status?.Self ? peer(status.Self) : null
    // Appareils : en ligne d'abord, puis par nom.
    readonly property var peers: Object.values(status?.Peer ?? {}).map(p => peer(p))
        .sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name))
    readonly property int onlineCount: peers.filter(p => p.online).length
    readonly property var exitNodes: peers.filter(p => p.exitNodeOption)
    readonly property var exitNode: peers.find(p => p.exitNode) ?? null

    // Options (prefs du démon) et drapeau `tailscale set` correspondant.
    readonly property bool acceptRoutes: prefs?.RouteAll ?? false
    readonly property bool acceptDns: prefs?.CorpDNS ?? false
    readonly property bool shieldsUp: prefs?.ShieldsUp ?? false
    readonly property bool allowLanAccess: prefs?.ExitNodeAllowLANAccess ?? false

    // Dernière commande : en cours, et son erreur ("" : aucune).
    property bool busy: false
    property string error: ""

    // Nom d'affichage : nom de la machine, sinon (iOS : « localhost ») le premier label du nom MagicDNS.
    function peer(p: var): var {
        const dns = (p.DNSName ?? "").replace(/\.$/, "");
        const ips = p.TailscaleIPs ?? [];
        return {
            id: p.ID ?? "",
            name: p.HostName && p.HostName !== "localhost" ? p.HostName : dns.split(".")[0],
            dns: dns,
            os: p.OS ?? "",
            ip: ips.find(a => !a.includes(":")) ?? "",
            online: p.Online ?? false,
            direct: (p.CurAddr ?? "") !== "",
            relay: p.Relay ?? "",
            lastSeen: p.LastSeen && !p.LastSeen.startsWith("0001") ? new Date(p.LastSeen) : null,
            exitNode: p.ExitNode ?? false,
            exitNodeOption: p.ExitNodeOption ?? false
        };
    }

    function osName(os: string): string {
        return ({ linux: "Linux", windows: "Windows", macOS: "macOS", iOS: "iOS", android: "Android", freebsd: "FreeBSD" })[os] ?? os;
    }

    // Icône Papirus selon le système (téléphones / ordinateurs).
    function osIcon(os: string): string {
        return ["iOS", "android"].includes(os) ? "smartphone" : "computer";
    }

    // « 5 min ago », « 3 h ago », « 2 d ago ».
    function ago(date: var): string {
        if (!date)
            return "";
        const minutes = Math.max(1, Math.round((Date.now() - date.getTime()) / 60000));
        return minutes < 60 ? `${minutes} min ago` : minutes < 2880 ? `${Math.round(minutes / 60)} h ago` : `${Math.round(minutes / 1440)} d ago`;
    }

    function refresh(): void {
        if (!available)
            return;
        statusQuery.running = true;
        if (polling)
            prefsQuery.running = true;
    }

    function run(args: var): void {
        if (busy)
            return;
        error = "";
        busy = true;
        command.command = ["tailscale", ...args];
        command.running = true;
    }

    function setRunning(on: bool): void {
        run([on ? "up" : "down"]);
    }

    // `ip` : IP Tailscale de l'appareil de sortie, "" pour aucun.
    function setExitNode(ip: string): void {
        run(["set", `--exit-node=${ip}`]);
    }

    function setOption(flag: string, on: bool): void {
        run(["set", `--${flag}=${on}`]);
    }

    // `tailscale login` attend la fin de l'authentification : lancé détaché, son adresse revient par `status` (AuthURL) et
    // s'ouvre au clic suivant.
    function login(): void {
        if (authUrl !== "")
            Quickshell.execDetached(["xdg-open", authUrl]);
        else
            Quickshell.execDetached(["tailscale", "login"]);
        refresh();
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v tailscale"]
        onExited: code => root.available = code === 0
    }

    Timer {
        interval: root.polling ? 5000 : 60000
        running: root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    onPollingChanged: if (polling) refresh()

    Process {
        id: statusQuery
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Démon injoignable (« failed to connect to local tailscaled », code 1 aussi) : pas de JSON.
                try {
                    root.status = JSON.parse(text);
                    root.installed = true;
                } catch (e) {
                    root.status = null;
                    root.installed = false;
                }
            }
        }
        onExited: code => {
            if (code !== 0 && code !== 1) {   // 1 : arrêté (« Tailscale is stopped »), JSON quand même
                root.status = null;
                root.installed = false;
            }
        }
    }

    Process {
        id: prefsQuery
        command: ["tailscale", "debug", "prefs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.prefs = JSON.parse(text);
                } catch (e) {
                    root.prefs = null;
                }
            }
        }
    }

    Process {
        id: command
        stderr: StdioCollector {
            id: commandErr
        }
        onExited: code => {
            root.busy = false;
            if (code !== 0)
                root.error = commandErr.text.trim().split("\n").filter(l => l.trim() !== "").slice(-1)[0] ?? `tailscale: exit code ${code}`;
            root.refresh();
        }
    }
}
