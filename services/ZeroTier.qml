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

    readonly property bool polling: poller.fast
    readonly property bool available: cli.available
    // Jeton accepté. Repasse à faux sur une erreur de jeton, ou après deux autres échecs de suite (service redémarré).
    property bool authorized: false
    property int failures: 0
    // { address, online } du nœud local.
    property var info: null
    // [{ id, name, status, type, addresses, allowDns }]
    property var networks: []
    // Repli sans jeton : [{ name, address }].
    property var interfaces: []

    // Onglet visible aussi sans jeton ni réseau (machine neuve) : il donne la commande qui installe le jeton.
    readonly property bool present: authorized || (tokenMissing && serviceReady) || interfaces.length > 0
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

    // Demande de lecture (regroupée, refaite après une lecture en cours : Poller) ; `info`, puis `listnetworks` s'il répond
    // (jeton présent), sinon les interfaces.
    function refresh(): void {
        if (available)
            poller.request();
    }
    function clearErrors(): void {
        cli.error = "";
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

    // Relecture : onglet affiché (5 s) ; sinon 60 s, câble débranché (icône du tray) ou service pas encore joint (démarrage
    // avant le démon, redémarrage), sans quoi l'onglet ne reviendrait jamais sur une machine câblée.
    // Lecture en deux temps (`info`, puis `listnetworks` ou les interfaces) : `reading` la couvre entière, pour que Poller ne
    // relance rien entre les deux ; remis à faux quand plus rien ne tourne (y compris une commande qui n'a pas démarré).
    property bool reading: false
    function endIfIdle(): void {
        if (!infoQuery.running && !networksQuery.running && !addressQuery.running)
            reading = false;
    }
    // Pourquoi le mode lecture seule : jeton absent (sinon : service injoignable). Seulement si le service a créé son jeton
    // (`serviceReady`) : installé mais jamais démarré, zerotier-cli dit aussi « authtoken… », et il n'y a rien à copier.
    property bool tokenMissing: false
    property bool readOnce: false   // une lecture `info` terminée (avant : ni « jeton » ni « injoignable » à annoncer)
    property bool serviceReady: false

    // Vérifié au démarrage et à chaque jeton manquant (service démarré après Quickshell).
    Process {
        id: serviceCheck
        running: root.available
        // Dossier du service pas toujours lisible (0700 selon la distribution) : `systemctl` en second.
        command: ["sh", "-c", "test -e /var/lib/zerotier-one/authtoken.secret || systemctl is-active --quiet zerotier-one"]
        onExited: code => root.serviceReady = code === 0
    }
    onTokenMissingChanged: if (tokenMissing) serviceCheck.running = true

    Poller {
        id: poller
        tab: "zerotier"
        active: root.available && (root.polling || !Network.wiredLinked || !root.present)
        busy: root.reading
        onRead: {
            if (!root.available)
                return;
            root.reading = true;
            infoQuery.running = true;
        }
        onPanelClosed: root.clearErrors()
    }

    // Plus de jeton (ou service injoignable) : réseaux oubliés, repli sur les interfaces `zt*`.
    function fallBack(): void {
        info = null;
        networks = [];
        authorized = false;
        addressQuery.running = true;
    }

    Process {
        id: infoQuery
        command: ["timeout", "10", "zerotier-cli", "-j", "info"]   // bornée : service figé
        onRunningChanged: if (!running) Qt.callLater(root.endIfIdle)
        stdout: StdioCollector {
            id: infoOut
        }
        stderr: StdioCollector {
            id: infoErr
        }
        onExited: code => {
            root.readOnce = true;
            try {
                const d = JSON.parse(infoOut.text);
                root.info = { address: d.address ?? "", online: d.online ?? false };
                root.authorized = true;
                root.tokenMissing = false;
                root.failures = 0;
                networksQuery.running = true;
            } catch (e) {
                root.failures++;
                // « authtoken.secret not found or readable » (code 2) : pas de jeton.
                // Jeton absent (« authtoken.secret not found », stderr) ou refusé (jeton périmé après réinstallation du service :
                // « 401 info {} » sur stdout).
                // Autre échec (délai, service figé) : rien n'est appris sur le jeton, la valeur précédente reste.
                if (infoErr.text.includes("authtoken") || infoOut.text.trim().startsWith("401"))
                    root.tokenMissing = true;
                if (root.tokenMissing || root.failures >= 2)
                    root.fallBack();
            }
        }
    }

    Process {
        id: networksQuery
        command: ["timeout", "10", "zerotier-cli", "-j", "listnetworks"]
        onRunningChanged: if (!running) Qt.callLater(root.endIfIdle)
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.networks = JSON.parse(text).map(n => ({
                        id: n.nwid ?? n.id ?? "",
                        name: n.name || n.nwid || "",
                        status: n.status ?? "",
                        type: n.type ?? "",
                        addresses: (n.assignedAddresses ?? []).map(a => a.split("/")[0]),
                        allowDns: n.allowDNS ?? false
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
        onRunningChanged: if (!running) Qt.callLater(root.endIfIdle)
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
