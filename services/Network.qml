pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Réseau : débit (module `network`) et connexions NetworkManager (module natif du tray, remplace nm-applet ; ARCHITECTURE § 7.6).
//
// Débit (module Waybar `network`), toutes les 2,5 s (5 s dans Waybar ; ta demande du 2026-10-20).
// Interface : celle de la route par défaut (/proc/net/route), au lieu du nom écrit en dur dans Waybar (`eno2`).
// Octets de /proc/net/dev, différence divisée par l'intervalle nominal (network.cpp de Waybar 0.15).
Singleton {
    id: root

    readonly property int interval: 2500
    // Détails nmcli des cartes Wi-Fi et filaire : toutes les 5 s.
    readonly property int detailsInterval: 5000
    property string interfaceName: ""
    property string interfaceNames: ""   // toutes les interfaces ; celle de NordVPN fait relire son statut (Vpn.qml)
    property real downBytesPerSecond: 0
    property real upBytesPerSecond: 0
    property var previous: null
    // Graphe de trafic des cartes (TrafficGraph.qml, comme l'onglet « Speed » de KDE) : débits des 2 dernières minutes
    // ({ down, up }, un relevé toutes les 2,5 s) sur l'interface de la route par défaut.
    readonly property int historyLength: 48
    property var history: []

    // Textes les plus larges que `format` peut produire, pour la largeur fixe du module : chaque chiffre répété (la largeur
    // d'un chiffre ne dépend pas de sa place), chaque forme (d.dd, dd.d, ddd), chaque préfixe jusqu'à G.
    readonly property var widestRates: [].concat(...Array.from({ length: 10 }, (_, d) => [].concat(...[`${d}.${d}${d}`, `${d}${d}.${d}`, `${d}${d}${d}`].map(n => ["", "k", "M", "G"].map(p => `${n}${p}B/s`.padStart(8))))))
    readonly property var widestLabels: widestRates.map(r => ` ${r}`)   // avec l'espace après l'icône du module

    // Préfixe k / M / G… en base 1000 comme Waybar (`{bandwidthDownBytes}`), mais 3 chiffres significatifs au lieu d'une
    // décimale, pour une pilule plus étroite (ta demande du 2026-10-20) : « 4.32MB/s », « 14.3MB/s », « 833kB/s » ; aligné
    // à droite sur 8 caractères.
    function format(bytesPerSecond: real): string {
        const prefixes = ["", "k", "M", "G", "T", "P"];
        let value = bytesPerSecond, pow = 0;
        // 999.5 et plus s'arrondit à « 1000 » : unité suivante, pour ne jamais dépasser 3 chiffres (largeur fixe du module).
        while (pow < prefixes.length - 1 && value >= 999.5) {
            value /= 1000;
            pow++;
        }
        // Décimales selon la valeur arrondie : 9.996 s'affiche « 10.0 », pas « 10.00 ».
        const decimals = value >= 99.95 ? 0 : value >= 9.995 ? 1 : 2;
        return `${value.toFixed(decimals)}${prefixes[pow]}B/s`.padStart(8);
    }

    // Appelé à la fin de chaque lecture de /proc/net/dev (reload() est asynchrone) ; la route a été relue juste avant.
    function update(): void {
        const names = dev.text().split("\n").slice(2).map(l => l.split(":")[0].trim()).filter(n => n).join(" ");
        if (names !== interfaceNames)
            interfaceNames = names;
        // Route par défaut : destination et masque 00000000 (pas les 0.0.0.0/1 d'un VPN) ; la plus petite métrique l'emporte.
        let best = null;
        for (const line of route.text().split("\n").slice(1)) {
            const f = line.trim().split(/\s+/);
            if (f.length > 7 && f[1] === "00000000" && f[7] === "00000000" && (!best || Number(f[6]) < best.metric))
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
    readonly property bool connectivityChecksEnabled: managed && Networking.canCheckConnectivity && Networking.connectivityCheckEnabled
    readonly property int connectivity: connectivityChecksEnabled ? Networking.connectivity : NetworkConnectivity.Unknown
    readonly property bool limited: (wiredConnected || connectedWifi !== null)
        && [NetworkConnectivity.None, NetworkConnectivity.Portal, NetworkConnectivity.Limited].includes(connectivity)

    // Filaire de l'icône « réseau » (Tray.qml, qui y ajoute Tailscale / ZeroTier : ce service ne les lit pas, eux lisent
    // celui-ci — pas de dépendance circulaire entre singletons, qui donnait des liaisons `undefined` au démarrage) : câble
    // branché, état (noms de nm-applet, Papirus-Dark).
    readonly property bool wiredLinked: wiredDevices.some(d => d.hasLink)
    readonly property bool wiredShown: managed && (wiredLinked || wifi === null)
    // Le bouton « réseau » sert d'entrée aux réseaux privés (Tray, onglet ouvert d'abord : NetworkPanel) : sans câble mais avec
    // le Wi-Fi (qui a son icône), ou sans NetworkManager.
    readonly property bool privateEntry: !wiredShown
    readonly property string icon: wiredConnected ? (wiredLimited ? "network-wired-no-route" : "nm-device-wired") : "nm-no-connection"

    // --- Module Wi-Fi (WifiPanel.qml, WifiIcon.qml) ---

    readonly property bool wifiShown: managed && wifi !== null
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    // Radio utilisable : interrupteur logiciel et matériel (rfkill, mode avion).
    readonly property bool wifiUsable: wifiEnabled && wifiHardwareEnabled
    readonly property var connectingWifi: wifiNetworks.find(n => n.state === ConnectionState.Connecting) ?? null
    // Réseau de la carte du panneau : connecté, sinon en cours de connexion.
    readonly property var currentWifi: connectedWifi ?? connectingWifi
    // Accès limité (vérification globale de NetworkManager) attribué à l'interface de la route par défaut : le Wi-Fi s'il la
    // porte ou s'il est seul connecté (route sur un VPN : tun0, wg0…), sinon le filaire.
    readonly property bool wifiCarriesRoute: wifi !== null && interfaceName === wifi.name
    readonly property bool wifiLimited: limited && connectedWifi !== null && (wifiCarriesRoute || !wiredConnected)
    readonly property bool wifiCaptivePortal: wifiUsable && wifiLimited && connectivity === NetworkConnectivity.Portal
    // Même entrée HTTP que la sonde NetworkManager (dotfiles/NetworkManager) : le navigateur suit la redirection du portail.
    readonly property string captivePortalUrl: "http://ping.omacom.io/nm-check.txt"

    function checkConnectivity(): void {
        if (connectivityChecksEnabled && (connectedWifi !== null || wiredConnected))
            Networking.checkConnectivity();
    }

    // Appelé seulement après un clic ; ne jamais lancer une URL fournie par le réseau ni modifier un VPN.
    function openCaptivePortal(network: var): void {
        if (wifiCaptivePortal && network === connectedWifi)
            Launch.exec(["xdg-open", captivePortalUrl]);
    }

    onConnectivityChecksEnabledChanged: Qt.callLater(checkConnectivity)
    onWifiScanningChanged: {
        if (wifiScanning)
            Qt.callLater(checkConnectivity);
    }

    // Unique pour toutes les barres ; continue pendant l'identification, panneau fermé. Au repos, NetworkManager s'en charge.
    Timer {
        interval: 10000
        repeat: true
        running: root.wifiUsable && root.wifiLimited
            && [NetworkConnectivity.Portal, NetworkConnectivity.Limited].includes(root.connectivity)
        onTriggered: root.checkConnectivity()
    }
    // Libellé des cartes (filaire, Wi-Fi) quand l'accès est limité.
    readonly property string limitedText: connectivity === NetworkConnectivity.Portal ? "Sign-in required: captive portal"
        : "Connected without Internet access"
    readonly property bool wiredLimited: limited && wiredConnected && !wifiCarriesRoute
    // Câble qui porte la route (son pont si c'est un port de pont : détails lus panneau ouvert) ; "" : aucun (VPN, Wi-Fi).
    readonly property string routeWiredDevice: wiredDevices.find(d => d.connected
        && interfaceName === (wiredDetails[d.name]?.ipIface ?? d.name))?.name ?? ""

    // Autre réseau connecté : débit et adresse du précédent effacés, relus aussitôt panneau ouvert. Comparé au précédent : la
    // liaison est réévaluée à chaque variation de signal.
    property var lastConnectedWifi: null
    onConnectedWifiChanged: {
        if (connectedWifi === lastConnectedWifi)
            return;
        lastConnectedWifi = connectedWifi;
        Qt.callLater(checkConnectivity);
        wifiBitrate = "";
        wifiAddress = "";
        if (wifiPanelOpen && connectedWifi)
            linkQuery.running = true;
    }

    // Niveau de signal 0 (aucun) … 4 (excellent) : seuils de GNOME Shell (signalToIcon, alignés sur GNOME Settings) — 20, 40,
    // 50, 80 %.
    function wifiLevel(strength: real): int {
        const p = strength * 100;
        return p < 20 ? 0 : p < 40 ? 1 : p < 50 ? 2 : p < 80 ? 3 : 4;
    }
    function qualityText(strength: real): string {
        return ["Very weak", "Weak", "Fair", "Good", "Excellent"][wifiLevel(strength)];
    }
    // Réseau qui se connecte avec une clé WPA (le panneau la demande s'il est inconnu : connectWithPsk fait un profil WPA) ;
    // Open et OWE : sans mot de passe ; entreprise (EAP, LEAP) et WEP : à régler dans l'éditeur de connexions.
    function needsPsk(security: int): bool {
        return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(security);
    }
    function needsEditor(security: int): bool {
        return [WifiSecurityType.WpaEap, WifiSecurityType.Wpa2Eap, WifiSecurityType.Wpa3SuiteB192, WifiSecurityType.Leap,
            WifiSecurityType.DynamicWep, WifiSecurityType.StaticWep].includes(security);
    }

    // Sans mot de passe : ouvert, ou OWE (chiffré, sans clé).
    function isOpen(security: int): bool {
        return security === WifiSecurityType.Open || security === WifiSecurityType.Owe;
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
    // Onglet affiché du panneau réseau (NetworkPanel) : Tailscale et ZeroTier ne sont relus toutes les 5 s que sur le leur.
    property string networkTab: ""
    readonly property bool wifiPanelOpen: openPanels.some(p => p.kind === "wifi")
    // Recherche des réseaux : panneau Wi-Fi épinglé seulement, pas pendant un aperçu au survol (Panel.qml, `pinned`).
    readonly property bool wifiScanning: openPanels.some(p => p.kind === "wifi" && p.panel.pinned === true)

    function setPanelOpen(kind: string, panel: QtObject, open: bool): void {
        const others = openPanels.filter(p => p.panel !== panel);
        openPanels = open ? [...others, { kind: kind, panel: panel }] : others;
    }

    Binding {
        when: root.wifi !== null
        target: root.wifi
        property: "scannerEnabled"
        value: root.wifiScanning
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
        interval: root.detailsInterval
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

    // `running = true` pendant une lecture : Quickshell la relance à sa fin (Process.targetRunning), ce qu'il faut après un
    // changement (autre réseau, réseaux apparus) pour ne pas laisser la lecture faite avant.
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
        running: root.networkPanelOpen && root.networkTab === "wired" && root.wiredDevices.length > 0
        triggeredOnStart: true
        interval: root.detailsInterval
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

    // Ligne de `nmcli -g` (un seul champ, « : » échappés) : même désescapage que splitTerse.
    function unescapeField(value: string): string {
        return splitTerse(value).join(":");
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

    // Édition des connexions : `nm-connection-editor` (repli, ARCHITECTURE § 7.6).
    function openEditor(): void {
        Launch.exec(["nm-connection-editor"]);
    }
}
