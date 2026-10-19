pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tailscale (onglet du panneau réseau, ta demande du 2026-10-19) : état, appareils du tailnet, nœud de sortie et options, par
// la commande `tailscale` (pas de bibliothèque native). Lecture sans droits (`status --json`, `debug prefs`) ; les actions
// demandent que ton utilisateur soit « operator » du démon (`sudo tailscale set --operator=$USER`, une fois — install.sh) :
// sans cela, l'erreur de la commande est affichée.
// Relu toutes les 5 s panneau réseau ouvert ; panneau fermé, toutes les 60 s seulement sans câble branché (l'icône réseau en
// dépend alors) ; une fois au démarrage ; rien si la commande est absente. Préférences lues panneau ouvert seulement.
Singleton {
    id: root

    readonly property bool polling: Network.networkPanelOpen && Network.networkTab === "tailscale"
    // Commande présente (`command -v`, au démarrage).
    readonly property bool available: cli.available
    // Démon joignable (réponse JSON) ; ne repasse à faux qu'après deux échecs de suite (redémarrage du démon).
    property bool installed: false
    property int failures: 0
    property var status: null
    property var prefs: null

    readonly property string state: status?.BackendState ?? ""   // Running, Stopped, NeedsLogin, Starting, NoState
    readonly property bool running: state === "Running"
    readonly property bool canAct: (prefs?.OperatorUser ?? "") === (Quickshell.env("USER") || Quickshell.env("LOGNAME"))
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

    // Dernière commande : en cours, et son erreur ("" : aucune) ; connexion au compte à part (elle attend le navigateur).
    readonly property bool busy: cli.busy
    readonly property string error: cli.error || (state === "NeedsLogin" ? loginCli.error : "")
    readonly property bool loggingIn: loginCli.busy

    CliRunner {
        id: cli
        program: "tailscale"
        onFinished: root.refresh()
    }

    CliRunner {
        id: loginCli
        program: "tailscale"
        onFinished: root.refresh()
    }

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
            active: p.Active ?? false,   // session en cours ; sans elle, ni directe ni relayée
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

    // Préférences : panneau ouvert, ou pas encore lues (droits connus dès l'ouverture, sans message « Read only » passager).
    function refresh(): void {
        if (!available)
            return;
        statusQuery.running = true;
        if (polling || prefs === null)
            prefsQuery.running = true;
    }

    function run(args: var): bool {
        return cli.run(args);
    }

    // `up` seul : avec une option (même `--timeout`), tailscale exige de répéter tous les réglages faits par `set` (vérifié).
    // Il attend une authentification si la clé du nœud a expiré : borné par `timeout` (coreutils), pour ne pas bloquer.
    function setRunning(on: bool): void {
        if (on)
            cli.runCommand(["timeout", "30", "tailscale", "up"]);
        else
            run(["down"]);
    }

    // `node` : IP ou nom MagicDNS de l'appareil de sortie (`tailscale set` accepte les deux), "" pour aucun.
    function setExitNode(node: string): void {
        run(["set", `--exit-node=${node}`]);
    }

    function setOption(flag: string, on: bool): void {
        run(["set", `--${flag}=${on}`]);
    }

    // `tailscale login` attend la fin de l'authentification (10 min au plus) : lanceur à part (les autres actions restent
    // libres), une seule à la fois ; son adresse revient par `status` (AuthURL) et s'ouvre au clic suivant.
    function login(): void {
        if (authUrl !== "")
            Quickshell.execDetached(["xdg-open", authUrl]);
        else
            loginCli.run(["login", "--timeout=10m"]);
        refresh();
    }

    Timer {
        interval: root.polling ? 5000 : 60000
        running: root.available && (root.polling || !Network.wiredLinked)
        repeat: true
        triggeredOnStart: true   // relu dès le démarrage du minuteur (câble débranché, panneau ouvert)
        onTriggered: root.refresh()
    }
    onPollingChanged: if (polling) refresh()
    onAvailableChanged: if (available) refresh()

    Process {
        id: statusQuery
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Code 1 quand Tailscale est arrêté (JSON quand même) comme quand le démon est injoignable (pas de JSON) : le
                // JSON fait foi.
                try {
                    root.status = JSON.parse(text);
                    root.installed = true;
                    root.failures = 0;
                } catch (e) {
                    root.failures++;
                    if (root.failures >= 2) {
                        root.status = null;
                        root.installed = false;
                    }
                }
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
}
