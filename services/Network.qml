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

    // Le Wi-Fi a son propre module (ta demande du 2026-10-19) ; l'icône « réseau » ne montre plus que le filaire, et seulement
    // si un câble est branché (ou s'il n'y a pas de Wi-Fi), comme GNOME. Mêmes noms que nm-applet (thème Papirus-Dark).
    readonly property bool wiredShown: managed && (wiredDevices.some(d => d.hasLink) || wifi === null)
    readonly property string icon: wiredConnected ? (limited ? "network-wired-no-route" : "nm-device-wired") : "nm-no-connection"

    // --- Module Wi-Fi (WifiPanel.qml, WifiIcon.qml) ---

    readonly property bool wifiShown: managed && wifi !== null
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
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

    // Panneaux ouverts : le Wi-Fi recherche les réseaux et relit ses détails ; les réseaux privés sont relus pour le panneau
    // réseau, ou pour le panneau Wi-Fi quand l'icône réseau est masquée (laptop sans câble). Deux drapeaux plutôt qu'un : un
    // panneau qui s'ouvre et l'autre qui se ferme ne s'écrasent pas.
    property bool networkPanelOpen: false
    property bool wifiPanelOpen: false
    readonly property bool privateNeeded: networkPanelOpen || (wifiPanelOpen && !wiredShown)

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
        running: root.wifiPanelOpen && root.wifi !== null && root.wifiEnabled
        triggeredOnStart: true
        interval: root.interval
        repeat: true
        onTriggered: {
            apQuery.running = true;
            linkQuery.running = true;
        }
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

    // --- Réseaux privés (ton choix du 2026-10-16) : Tailscale et ZeroTier, en lecture seule, relus toutes les 5 s pendant que le
    // panneau est ouvert. Tailscale : `tailscale status --json` (lisible sans droits) ; ZeroTier : `zerotier-cli` exige le jeton de
    // root, donc seules ses interfaces `zt*` et leurs adresses sont lues (`ip -j addr`). Section masquée si aucun des deux n'existe.

    // { state ("Running", "Stopped", "NeedsLogin"…), address, peers } ou null si Tailscale est absent.
    property var tailscale: null
    // [{ name, address }] : interfaces ZeroTier ayant une adresse.
    property var zerotier: []

    Timer {
        running: root.privateNeeded
        triggeredOnStart: true
        interval: root.interval
        repeat: true
        onTriggered: {
            tailscaleQuery.running = true;
            addressQuery.running = true;
        }
    }

    Process {
        id: tailscaleQuery
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.tailscale = {
                        state: d.BackendState ?? "",
                        address: (d.Self?.TailscaleIPs ?? []).find(a => !a.includes(":")) ?? "",
                        peers: Object.keys(d.Peer ?? {}).length
                    };
                } catch (e) {
                    root.tailscale = null;
                }
            }
        }
        onExited: code => {
            if (code !== 0 && code !== 1)   // 1 : arrêté (« Tailscale is stopped »), sortie JSON quand même
                root.tailscale = null;
        }
    }

    Process {
        id: addressQuery
        command: ["ip", "-j", "addr"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.zerotier = JSON.parse(text).filter(i => i.ifname.startsWith("zt")).map(i => ({
                        name: i.ifname,
                        address: (i.addr_info ?? []).find(a => a.family === "inet")?.local ?? ""
                    })).filter(i => i.address !== "");
                } catch (e) {
                    root.zerotier = [];
                }
            }
        }
    }

    // Édition des connexions : `nm-connection-editor` (repli, ARCHITECTURE R5).
    function openEditor(): void {
        Quickshell.execDetached(["nm-connection-editor"]);
    }
}
