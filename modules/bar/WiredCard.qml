import QtQuick
import QtQuick.Layouts
import Quickshell.Networking as NM
import Quickshell.Widgets
import qs.config
import qs.services

// Carte d'une connexion filaire (THEME.md § 3 « Panneau réseau ») : même cadre que la carte Wi-Fi. En-tête (icône, état et
// vitesse du lien, Connect / Disconnect), graphe du trafic si ce câble porte la route par défaut (KDE), puis détails comme GNOME
// Settings et KDE : adaptateur, IPv4, passerelle, DNS, domaine, IPv6, adresse matérielle, pont.
Rectangle {
    id: root

    property NM.NetworkDevice device: null   // WiredDevice

    readonly property var details: Network.wiredDetails[device?.name ?? ""] ?? null
    readonly property bool connected: device?.connected ?? false
    readonly property bool carriesTraffic: connected && Network.interfaceName !== ""
        && Network.interfaceName === (details?.ipIface ?? device?.name)

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
            return Network.limited ? (Network.connectivity === NM.NetworkConnectivity.Portal ? "Sign-in required: captive portal"
                : "Connected without Internet access") : `Connected · ${speed(device.linkSpeed)}`;
        default:
            return "Disconnected";
        }
    }

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + 2 * Theme.panel.padding
    radius: Theme.panel.rowRadius
    color: Theme.wifi.card

    ColumnLayout {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.panel.padding
        }
        spacing: Theme.panel.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.panel.spacing

            IconImage {
                implicitSize: Theme.wifi.cardIconSize
                source: `image://icon/${root.connected ? "nm-device-wired" : "nm-no-connection"}`
                opacity: root.device?.hasLink ? 1 : Theme.panel.disabledOpacity
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: "Ethernet"
                    font.family: Theme.font.text
                    font.pixelSize: Theme.panel.fontSize
                    color: root.connected ? Theme.panel.accent : Theme.panel.text
                    elide: Text.ElideRight
                }

                PanelSection {
                    text: root.device ? root.stateText() : ""
                    color: root.connected && Network.limited ? Theme.panel.warning : Theme.panel.secondaryText
                }
            }

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
}
