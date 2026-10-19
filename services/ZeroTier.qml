pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ZeroTier (onglet du panneau réseau, ta demande du 2026-10-19) par `zerotier-cli -j`. Il exige le jeton du service :
// copie personnelle `~/.zeroTierOneAuthToken` (ton choix, install.sh la propose). Avec lui : nœud, réseaux (nom, état, adresses,
// options), rejoindre / quitter. Sans lui (`authorized` faux) : repli en lecture seule sur les interfaces `zt*` (`ip -j addr`).
// Relu toutes les 5 s panneau réseau ouvert ; panneau fermé, toutes les 60 s seulement sans câble branché ; une fois au
// démarrage ; rien si `zerotier-cli` est absent (cherché une fois). Interfaces `zt*` lues seulement sans le jeton.
Singleton {
    id: root

    readonly property bool polling: Network.networkPanelOpen
    readonly property bool available: cli.available
    // Jeton accepté. Repasse à faux sur une erreur de jeton, ou après deux autres échecs de suite (service redémarré).
    property bool authorized: false
    property int failures: 0
    // { address, online, version } du nœud local.
    property var info: null
    // [{ id, name, status, type, addresses, device, allowDns, allowDefault }]
    property var networks: []
    // Repli sans jeton : [{ name, address }].
    property var interfaces: []

    readonly property bool present: authorized || interfaces.length > 0
    readonly property int connectedCount: authorized ? networks.filter(n => n.status === "OK").length : interfaces.length

    readonly property bool busy: cli.busy
    readonly property string error: cli.error

    CliRunner {
        id: cli
        program: "zerotier-cli"
        onFinished: root.refresh()
    }

    // États de `listnetworks` en mots.
    function statusText(status: string): string {
        return ({
            OK: "Connected",
            REQUESTING_CONFIGURATION: "Waiting for configuration…",
            ACCESS_DENIED: "Access denied — authorize this device in the network",
            NOT_FOUND: "Network not found",
            PORT_ERROR: "Port error",
            CLIENT_TOO_OLD: "Client too old"
        })[status] ?? status;
    }

    function refresh(): void {
        if (!available)
            return;
        infoQuery.running = true;   // puis `listnetworks` s'il répond (jeton présent), sinon les interfaces
    }

    function run(args: var): bool {
        return cli.run(args);
    }

    function join(id: string): bool {
        return run(["join", id]);
    }

    function leave(id: string): void {
        run(["leave", id]);
    }

    // `key` : allowDNS, allowDefault…
    function setOption(id: string, key: string, on: bool): void {
        run(["set", id, `${key}=${on ? 1 : 0}`]);
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

    function fallBack(): void {
        info = null;
        authorized = false;
        addressQuery.running = true;   // repli sans jeton
    }

    Process {
        id: infoQuery
        command: ["zerotier-cli", "-j", "info"]
        stdout: StdioCollector {
            id: infoOut
        }
        stderr: StdioCollector {
            id: infoErr
        }
        onExited: code => {
            try {
                const d = JSON.parse(infoOut.text);
                root.info = { address: d.address ?? "", online: d.online ?? false, version: d.version ?? "" };
                root.authorized = true;
                root.failures = 0;
                networksQuery.running = true;
            } catch (e) {
                root.failures++;
                // « authtoken.secret not found or readable » (code 2) : pas de jeton.
                if (infoErr.text.includes("authtoken") || root.failures >= 2)
                    root.fallBack();
            }
        }
    }

    Process {
        id: networksQuery
        command: ["zerotier-cli", "-j", "listnetworks"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.networks = JSON.parse(text).map(n => ({
                        id: n.nwid ?? n.id ?? "",
                        name: n.name || n.nwid || "",
                        status: n.status ?? "",
                        type: n.type ?? "",
                        addresses: (n.assignedAddresses ?? []).map(a => a.split("/")[0]),
                        device: n.portDeviceName ?? "",
                        allowDns: n.allowDNS ?? false,
                        allowDefault: n.allowDefault ?? false
                    }));
                } catch (e) {
                    root.networks = [];
                }
            }
        }
    }

    Process {
        id: addressQuery
        command: ["ip", "-j", "addr"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.interfaces = JSON.parse(text).filter(i => i.ifname.startsWith("zt")).map(i => ({
                        name: i.ifname,
                        address: (i.addr_info ?? []).find(a => a.family === "inet")?.local ?? ""
                    })).filter(i => i.address !== "");
                } catch (e) {
                    root.interfaces = [];
                }
            }
        }
    }
}
