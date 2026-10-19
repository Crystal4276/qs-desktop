import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking as NM
import qs.config
import qs.services

// Panneau réseau (remplace le menu de nm-applet, ARCHITECTURE R5) : connexions filaires, réseaux privés, édition des connexions
// dans `nm-connection-editor`. Le Wi-Fi a son propre module (WifiPanel.qml, ta demande du 2026-10-19).
// Libellés en anglais, comme nm-applet et la locale du système. Quickshell.Networking importé sous `NM` : son type `Network`
// masquerait le service du même nom.
Panel {
    id: root

    title: "Network"

    onVisibleChanged: Network.networkPanelOpen = visible
    Component.onDestruction: Network.networkPanelOpen = false

    function stateText(network): string {
        switch (network.state) {
        case NM.ConnectionState.Connecting:
            return "Connecting…";
        case NM.ConnectionState.Disconnecting:
            return "Disconnecting…";
        case NM.ConnectionState.Connected:
            return "Connected";
        default:
            return "";
        }
    }

    // Accès limité (Network.limited) : en `red`, comme les autres avertissements des panneaux.
    PanelSection {
        visible: Network.limited && Network.wiredConnected
        text: Network.connectivity === NM.NetworkConnectivity.Portal ? "Sign-in required: captive portal" : "Connected without Internet access"
        color: Theme.panel.warning
    }

    // --- Filaire ---
    PanelSection {
        visible: Network.wiredDevices.length > 0
        text: "Wired"
    }

    Repeater {
        model: ScriptModel {
            values: Network.wiredDevices
        }

        PanelRow {
            required property NM.NetworkDevice modelData

            icon: modelData.connected ? "nm-device-wired" : "nm-no-connection"
            text: modelData.network?.name ?? modelData.name
            subtext: !modelData.hasLink ? "Cable unplugged"
                : modelData.connected ? `Connected · ${modelData.linkSpeed} Mb/s` : (root.stateText(modelData.network ?? modelData) || "Disconnected")
            active: modelData.connected
            clickable: false

            PanelButton {
                visible: modelData.hasLink && modelData.network !== null
                text: modelData.connected ? "Disconnect" : "Connect"
                onClicked: modelData.connected ? modelData.disconnect() : modelData.network.connect()
            }
        }
    }

    PrivateNetworks {}

    RowLayout {
        Layout.fillWidth: true

        Item {
            Layout.fillWidth: true
        }

        PanelButton {
            text: "Network settings…"
            onClicked: {
                root.visible = false;
                Network.openEditor();
            }
        }
    }
}
