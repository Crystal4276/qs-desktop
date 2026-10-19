import QtQuick
import QtQuick.Layouts
import Quickshell.Networking as NM
import qs.config
import qs.services

// Carte d'une connexion filaire (THEME.md § 3 « Panneau réseau ») : même cadre que la carte Wi-Fi. En-tête (icône, état et
// vitesse du lien, Connect / Disconnect), graphe du trafic si ce câble porte la route par défaut (KDE), puis détails comme GNOME
// Settings et KDE : adaptateur, IPv4, passerelle, DNS, domaine, IPv6, adresse matérielle, pont.
PanelCard {
    id: root

    property NM.NetworkDevice device: null   // WiredDevice

    readonly property var details: Network.wiredDetails[device?.name ?? ""] ?? null
    readonly property bool connected: device?.connected ?? false
    readonly property bool carriesTraffic: connected && Network.interfaceName !== ""
        && Network.interfaceName === (details?.ipIface ?? device?.name)
    // Accès limité : sur la carte qui porte la route, ou sur le seul câble connecté (route sur un VPN).
    readonly property bool limited: Network.wiredLimited && (carriesTraffic || Network.wiredDevices.filter(d => d.connected).length === 1)

    function speed(mbps: int): string {
        return mbps >= 1000 ? `${mbps / 1000} Gb/s` : `${mbps} Mb/s`;
    }

    function stateText(): string {
        if (!device.hasLink)
            return "Cable unplugged";
        switch (device.state) {
        case NM.ConnectionState.Connecting:
            return "Connecting…";
        case NM.ConnectionState.Disconnecting:
            return "Disconnecting…";
        case NM.ConnectionState.Connected:
            return limited ? Network.limitedText : device.linkSpeed > 0 ? `Connected · ${speed(device.linkSpeed)}` : "Connected";   // 0 : vitesse inconnue (VM, certains adaptateurs USB)
        default:
            return "Disconnected";
        }
    }

    CardHeader {
        icon: root.connected ? "nm-device-wired" : "nm-no-connection"
        iconOpacity: root.device?.hasLink ? 1 : Theme.panel.disabledOpacity
        // Plusieurs cartes réseau (dock, deux ports) : l'interface les distingue.
        title: Network.wiredDevices.length > 1 ? `Ethernet · ${root.device?.name ?? ""}` : "Ethernet"
        active: root.connected
        status: root.device ? root.stateText() : ""
        statusColor: root.connected && root.limited ? Theme.panel.warning : Theme.panel.secondaryText

        PanelButton {
            visible: (root.device?.hasLink ?? false) && root.device.network !== null
            text: root.connected ? "Disconnect" : "Connect"
            onClicked: root.connected ? root.device.disconnect() : root.device.network.connect()
        }
    }

    TrafficGraph {
        visible: root.carriesTraffic
    }

    DetailsGrid {
        visible: root.connected && shown.length > 0
        rows: [
            ["Adapter", (root.details?.product ?? "").replace(/^Ethernet Connection\s*(\(\d+\))?\s*/, "")],
            ["IPv4 address", root.details?.ipv4 ?? ""],
            ["Gateway", root.details?.gateway ?? ""],
            ["DNS", root.details?.dns ?? ""],
            ["Domain", root.details?.domain ?? ""],
            ["IPv6 address", root.details?.ipv6 ?? ""],
            ["Hardware address", root.device?.address ?? ""],
            ["Bridge", root.details?.bridge ? `${root.details.bridge} (port ${root.device.name})` : ""]
        ]
    }
}
