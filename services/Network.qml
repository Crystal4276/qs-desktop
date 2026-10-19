pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Réseau : débit (module `network`) et connexions NetworkManager (module natif du tray, remplace nm-applet ; ARCHITECTURE R5).
//
// Débit (INVENTORY.md § 1, module `network`), toutes les 5 s comme Waybar.
// Interface : celle de la route par défaut (/proc/net/route), au lieu du nom écrit en dur dans Waybar (`eno2`).
// Octets de /proc/net/dev, différence divisée par l'intervalle nominal (network.cpp de Waybar 0.15).
Singleton {
    id: root

    readonly property int interval: 5000
    property string interfaceName: ""
    property real downBytesPerSecond: 0
    property real upBytesPerSecond: 0
    property var previous: null
    // Graphe de trafic des cartes (TrafficGraph.qml, comme l'onglet « Speed » de KDE) : débits des 2 dernières minutes
    // ({ down, up }, un relevé toutes les 5 s) sur l'interface de la route par défaut.
    readonly property int historyLength: 24
    property var history: []

    // Format `{bandwidthDownBytes:>3}` de Waybar (util/format.hpp) : une décimale, préfixe k / M / G… en base 1000,
    // aligné à droite sur 9 caractères (« 833.6kB/s », «   2.5MB/s »).
    function format(bytesPerSecond: real): string {
        const prefixes = ["", "k", "M", "G", "T", "P"];
        let value = bytesPerSecond, pow = 0;
        while (pow < prefixes.length - 1 && value / 1000 >= 1) {
            value /= 1000;
            pow++;
        }
        return `${value.toFixed(1)}${prefixes[pow]}B/s`.padStart(9);
    }

    // Appelé à la fin de chaque lecture de /proc/net/dev (reload() est asynchrone) ; la route a été relue juste avant.
    function update(): void {
        // Route par défaut : destination 00000000 ; la plus petite métrique l'emporte.
        let best = null;
        for (const line of route.text().split("\n").slice(1)) {
            const f = line.trim().split(/\s+/);
            if (f.length > 6 && f[1] === "00000000" && (!best || Number(f[6]) < best.metric))
                best = { name: f[0], metric: Number(f[6]) };
        }
        const name = best?.name ?? "";
        if (name !== interfaceName) {
            interfaceName = name;
            previous = null;
            history = [];
        }
        const line = dev.text().split("\n").find(l => l.trim().startsWith(name + ":"));
        if (!name || !line) {
            downBytesPerSecond = upBytesPerSecond = 0;
            return;
        }
        const f = line.split(":")[1].trim().split(/\s+/).map(Number);
        const counters = { down: f[0], up: f[8] };
        if (previous) {
            downBytesPerSecond = Math.max(0, counters.down - previous.down) / (interval / 1000);
            upBytesPerSecond = Math.max(0, counters.up - previous.up) / (interval / 1000);
            history = [...history.slice(1 - historyLength), { down: downBytesPerSecond, up: upBytesPerSecond }];
        }
        previous = counters;
    }

    FileView {
        id: route
        path: "/proc/net/route"
        blockLoading: true   // lue dans update() : attend la fin de sa lecture si elle est en cours
    }

    FileView {
        id: dev
        path: "/proc/net/dev"
        onLoaded: root.update()
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            route.reload();
            dev.reload();
        }
    }

    // --- Connexions (Quickshell.Networking, NetworkManager) ---

    readonly property bool managed: Networking.backend === NetworkBackendType.NetworkManager
    readonly property var wiredDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wired)
    readonly property var wifiDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wifi)
    readonly property var wifi: wifiDevices[0] ?? null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    // Réseaux Wi-Fi visibles : connecté d'abord, puis enregistrés, puis par force du signal.
    readonly property var wifiNetworks: wifi ? wifi.networks.values.slice().sort((a, b) =>
        (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength)) : []
    readonly property var connectedWifi: wifiNetworks.find(n => n.connected) ?? null
    readonly property bool wiredConnected: wiredDevices.some(d => d.connected)

    // Connecté sans accès à Internet (vérification de connectivité de NetworkManager ; ajout du 2026-10-16, nm-applet ne le
    // signalait pas) : portail captif, accès limité ou aucun. « Unknown » (vérification désactivée) compte comme un accès complet.
    readonly property int connectivity: Networking.connectivity
    readonly property bool limited: (wiredConnected || connectedWifi !== null)
        && [NetworkConnectivity.None, NetworkConnectivity.Portal, NetworkConnectivity.Limited].includes(connectivity)

    // Icône « réseau » (ta demande du 2026-10-19 : Wi-Fi séparé ; filaire et réseaux privés ici) : visible si un câble est
    // branché, s'il n'y a pas de Wi-Fi, ou si Tailscale / ZeroTier sont là (laptop sans câble). Filaire branché : son état
    // (noms de nm-applet, Papirus-Dark) ; sinon `network-vpn`.
    readonly property bool wiredLinked: wiredDevices.some(d => d.hasLink)
    readonly property bool networkShown: managed && (wiredLinked || wifi === null) || Tailscale.installed || ZeroTier.present
    readonly property string icon: wiredConnected ? (limited ? "network-wired-no-route" : "nm-device-wired")
        : !wiredLinked && (Tailscale.installed || ZeroTier.present) ? "network-vpn" : "nm-no-connection"

    // --- Module Wi-Fi (WifiPanel.qml, WifiIcon.qml) ---

    readonly property bool wifiShown: managed && wifi !== null
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    // Radio utilisable : interrupteur logiciel et matériel (rfkill, mode avion).
    readonly property bool wifiUsable: wifiEnabled && wifiHardwareEnabled
    readonly property var connectingWifi: wifiNetworks.find(n => n.state === ConnectionState.Connecting) ?? null
    // Réseau de la carte du panneau : connecté, sinon en cours de connexion.
    readonly property var currentWifi: connectedWifi ?? connectingWifi
    // Accès limité sur le Wi-Fi (le filaire, s'il est connecté, porte la route : l'avertissement est pour lui).
    readonly property bool wifiLimited: connectedWifi !== null && !wiredConnected && limited

    // Niveau de signal 0 (aucun) … 4 (excellent) : seuils de GNOME Shell (signalToIcon, alignés sur GNOME Settings) — 20, 40,
    // 50, 80 %.
    function wifiLevel(strength: real): int {
        const p = strength * 100;
        return p < 20 ? 0 : p < 40 ? 1 : p < 50 ? 2 : p < 80 ? 3 : 4;
    }
    function qualityText(strength: real): string {
        return ["Very weak", "Weak", "Fair", "Good", "Excellent"][wifiLevel(strength)];
    }
    function securityText(security: int): string {
        switch (security) {
        case WifiSecurityType.Open:
            return "None";
        case WifiSecurityType.Owe:
            return "Enhanced Open";
        case WifiSecurityType.WpaPsk:
            return "WPA";
        case WifiSecurityType.Wpa2Psk:
            return "WPA2";
        case WifiSecurityType.Sae:
            return "WPA3";
        case WifiSecurityType.WpaEap:
            return "WPA Enterprise";
        case WifiSecurityType.Wpa2Eap:
            return "WPA2 Enterprise";
        case WifiSecurityType.Wpa3SuiteB192:
            return "WPA3 Enterprise";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
            return "WEP";
        case WifiSecurityType.Leap:
            return "LEAP";
        default:
            return "";
        }
    }

    // Panneaux ouverts : le Wi-Fi recherche les réseaux et relit ses détails ; le panneau réseau relit les détails filaires (et
    // fait relire Tailscale / ZeroTier toutes les 5 s). Liste des panneaux ouverts plutôt qu'un booléen : deux barres avec un
    // tray, ou une barre recréée, ne s'écrasent pas.
    property var openPanels: []
    readonly property bool networkPanelOpen: openPanels.some(p => p.kind === "network")
    readonly property bool wifiPanelOpen: openPanels.some(p => p.kind === "wifi")

    function setPanelOpen(kind: string, panel: QtObject, open: bool): void {
        const others = openPanels.filter(p => p.panel !== panel);
        openPanels = open ? [...others, { kind: kind, panel: panel }] : others;
    }

    Binding {
        when: root.wifi !== null
        target: root.wifi
        property: "scannerEnabled"
        value: root.wifiPanelOpen
    }

    function setWifiEnabled(enabled: bool): void {
        Networking.wifiEnabled = enabled;
    }

    // Détails que Quickshell.Networking n'expose pas (bande, canal, débit du lien, adresse), lus avec `nmcli` toutes les 5 s
    // pendant que le panneau Wi-Fi est ouvert, comme les détails du panneau réseau de KDE :
    // - par SSID, le point d'accès utilisé, sinon le plus fort : { band, channel, width, inUse, signal } ;
    // - interface Wi-Fi : débit du lien (CAPABILITIES.SPEED : débit actuel donné par le pilote) et adresse IPv4.
    property var wifiAccessPoints: ({})
    property string wifiBitrate: ""
    property string wifiAddress: ""

    // Champs de `nmcli -t` : séparés par « : », avec « \: » et « \\ » échappés.
    function splitTerse(line: string): var {
        const fields = [];
        let field = "";
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && i + 1 < line.length)
                field += line[++i];
            else if (line[i] === ":") {
                fields.push(field);
                field = "";
            } else
                field += line[i];
        }
        fields.push(field);
        return fields;
    }

    function bandOf(mhz: int): string {
        return mhz < 3000 ? "2.4 GHz" : mhz < 5925 ? "5 GHz" : "6 GHz";
    }

    Timer {
        running: root.wifiPanelOpen && root.wifi !== null && root.wifiUsable
        triggeredOnStart: true
        interval: root.interval
        repeat: true
        onTriggered: {
            apQuery.running = true;
            linkQuery.running = true;
        }
    }

    // Réseaux apparus (Wi-Fi rallumé, recherche) : leur bande sans attendre la relecture suivante. Seulement quand l'ensemble
    // des noms change : la liste est recalculée à chaque variation de signal.
    property string wifiNames: ""
    onWifiNetworksChanged: {
        const names = wifiNetworks.map(n => n.name).sort().join("\n");
        if (names === wifiNames)
            return;
        wifiNames = names;
        if (wifiPanelOpen && wifiUsable && names !== "")
            apQuery.running = true;
    }

    // Annule une connexion Wi-Fi en cours : désactive la connexion qui s'active (`nmcli connection down`), sans
    // `Device.Disconnect` qui bloquerait ensuite la connexion automatique de l'appareil (documentation de NetworkManager),
    // ni `WifiNetwork.disconnect()` que Quickshell refuse avant la connexion.
    function cancelWifi(): void {
        if (wifi)
            Quickshell.execDetached(["sh", "-c", 'u=$(nmcli -t -g GENERAL.CON-UUID device show "$1") && [ -n "$u" ] && nmcli connection down uuid "$u"', "sh", wifi.name]);
    }

    Process {
        id: apQuery
        command: ["nmcli", "-t", "-f", "IN-USE,FREQ,CHAN,BANDWIDTH,SIGNAL,SSID", "device", "wifi", "list", "ifname", root.wifi?.name ?? "", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const aps = {};
                for (const line of text.split("\n")) {
                    const f = root.splitTerse(line);
                    if (f.length < 6 || f[5] === "")
                        continue;
                    const ap = {
                        inUse: f[0] === "*",
                        band: root.bandOf(parseInt(f[1])),
                        channel: f[2],
                        width: f[3],
                        signal: parseInt(f[4])
                    };
                    const known = aps[f[5]];
                    if (!known || (ap.inUse && !known.inUse) || (!known.inUse && ap.signal > known.signal))
                        aps[f[5]] = ap;
                }
                root.wifiAccessPoints = aps;
            }
        }
    }

    Process {
        id: linkQuery
        command: ["nmcli", "-t", "-g", "CAPABILITIES.SPEED,IP4.ADDRESS", "device", "show", root.wifi?.name ?? ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const speed = lines[0] ?? "";
                root.wifiBitrate = /^\d/.test(speed) ? speed : "";
                root.wifiAddress = (lines[1] ?? "").split(" | ")[0].split("/")[0];
            }
        }
    }

    // --- Détails filaires (WiredCard.qml), lus avec `nmcli` toutes les 5 s panneau réseau ouvert, comme les détails de KDE et de
    // GNOME Settings. Un port de pont (ton `eno2` dans `bridge0`) n'a pas d'adresse : elle est lue sur le pont
    // (/sys/class/net/<port>/master). Par appareil : { ipIface, bridge, product, ipv4, gateway, dns, domain, ipv6 }.
    property var wiredDetails: ({})

    Timer {
        running: root.networkPanelOpen && root.wiredDevices.length > 0
        triggeredOnStart: true
        interval: root.interval
        repeat: true
        onTriggered: {
            wiredQuery.command = ["sh", "-c", root.wiredScript, "sh", ...root.wiredDevices.map(d => d.name)];
            wiredQuery.running = true;
        }
    }

    // Pour chaque appareil : `@@ <appareil> <interface IP>`, puis les champs (`nmcli -g` : une ligne par champ).
    readonly property string wiredScript: `for d; do
        i=$d
        [ -e /sys/class/net/$d/master ] && i=$(basename "$(readlink /sys/class/net/$d/master)")
        echo "@@ $d $i"
        nmcli -t -g GENERAL.PRODUCT device show "$d"
        nmcli -t -g IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP4.DOMAIN,IP6.ADDRESS device show "$i"
    done`

    function unescapeField(value: string): string {
        return value.replace(/\\(.)/g, "$1");
    }

    Process {
        id: wiredQuery
        stdout: StdioCollector {
            onStreamFinished: {
                const details = {};
                for (const block of text.split("@@ ").slice(1)) {
                    const lines = block.split("\n");
                    const [device, ipIface] = lines[0].trim().split(" ");
                    const field = n => root.unescapeField(lines[n] ?? "").split(" | ").filter(v => v !== "");
                    details[device] = {
                        ipIface: ipIface,
                        bridge: ipIface !== device ? ipIface : "",
                        product: root.unescapeField(lines[1] ?? ""),
                        ipv4: (field(2)[0] ?? "").split("/")[0],
                        gateway: field(3)[0] ?? "",
                        dns: field(4).join(", "),
                        domain: field(5).join(", "),
                        ipv6: (field(6).find(a => !a.startsWith("fe80")) ?? "").split("/")[0]   // adresse globale ; lien local omis
                    };
                }
                root.wiredDetails = details;
            }
        }
    }

    // Copie (IP, nom MagicDNS, identifiant ZeroTier) : `wl-copy` ; `Quickshell.clipboardText` n'atteint pas le presse-papiers
    // Wayland sans appui récent sur une surface Quickshell (vérifié 2026-10-19 : `wl-paste` vide).
    function copy(text: string): void {
        if (text !== "")
            Quickshell.execDetached(["wl-copy", "--", text]);
    }

    // Édition des connexions : `nm-connection-editor` (repli, ARCHITECTURE R5).
    function openEditor(): void {
        Quickshell.execDetached(["nm-connection-editor"]);
    }
}
