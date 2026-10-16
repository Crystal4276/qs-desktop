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

    // Icône du tray, mêmes noms que nm-applet (thème Papirus-Dark) : filaire, force du signal Wi-Fi, ou aucune connexion ;
    // accès limité : icônes Papirus `network-wired-no-route` / `network-wireless-<0…100>-limited`.
    readonly property string icon: wiredConnected ? (limited ? "network-wired-no-route" : "nm-device-wired")
        : connectedWifi ? (limited ? `network-wireless-${Math.round(connectedWifi.signalStrength * 5) * 20}-limited`
            : `nm-signal-${signalStep(connectedWifi.signalStrength)}${connectedWifi.security === WifiSecurityType.Open ? "" : "-secure"}`)
        : "nm-no-connection"

    // Palier d'icône : 0, 25, 50, 75, 100 (force 0–1).
    function signalStep(strength: real): string {
        return ["00", "25", "50", "75", "100"][Math.min(4, Math.round(strength * 4))];
    }

    // Recherche des réseaux Wi-Fi tant que le panneau est ouvert.
    property bool scanning: false
    Binding {
        when: root.wifi !== null
        target: root.wifi
        property: "scannerEnabled"
        value: root.scanning
    }

    function setWifiEnabled(enabled: bool): void {
        Networking.wifiEnabled = enabled;
    }

    // Édition des connexions : `nm-connection-editor` (repli, ARCHITECTURE R5).
    function openEditor(): void {
        Quickshell.execDetached(["nm-connection-editor"]);
    }
}
