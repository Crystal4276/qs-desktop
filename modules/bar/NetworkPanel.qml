import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking as NM
import qs.config
import qs.services

// Panneau réseau (remplace le menu de nm-applet, ARCHITECTURE R5) : connexions filaires, Wi-Fi (interrupteur, réseaux visibles,
// mot de passe demandé pour un réseau protégé inconnu), édition des connexions dans `nm-connection-editor`.
// Libellés en anglais, comme nm-applet et la locale du système. Quickshell.Networking importé sous `NM` : son type `Network`
// masquerait le service du même nom.
Panel {
    id: root

    title: "Network"
    hasSwitch: Network.wifi !== null
    switchChecked: Network.wifiEnabled
    onSwitchToggled: checked => Network.setWifiEnabled(checked)

    // Réseau protégé inconnu en attente de mot de passe.
    property var passwordFor: null

    onVisibleChanged: {
        Network.scanning = visible;
        if (!visible)
            passwordFor = null;
    }

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

    function activate(network): void {
        if (network.connected || network.stateChanging)
            return;
        if (!network.known && network.security !== NM.WifiSecurityType.Open) {
            passwordFor = network;
            return;
        }
        network.connect();
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

    // --- Wi-Fi ---
    PanelSection {
        visible: Network.wifi !== null
        text: !Network.wifiEnabled ? "Wi-Fi is off" : Network.wifiNetworks.length === 0 ? "Wi-Fi · searching…" : "Wi-Fi"
    }

    Flickable {
        visible: Network.wifi !== null && Network.wifiEnabled && Network.wifiNetworks.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(wifiList.implicitHeight, Theme.panel.maxListHeight)
        contentHeight: wifiList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: wifiList
            width: parent.width
            spacing: 0

            Repeater {
                model: ScriptModel {
                    values: Network.wifiNetworks
                }

                PanelRow {
                    required property NM.WifiNetwork modelData

                    icon: `nm-signal-${Network.signalStep(modelData.signalStrength)}${modelData.security === NM.WifiSecurityType.Open ? "" : "-secure"}`
                    text: modelData.name
                    subtext: root.stateText(modelData) || (modelData.known ? "Saved" : modelData.security === NM.WifiSecurityType.Open ? "Open" : "")
                    active: modelData.connected
                    onClicked: root.activate(modelData)

                    PanelButton {
                        visible: modelData.connected
                        text: "Disconnect"
                        onClicked: modelData.disconnect()
                    }

                    PanelButton {
                        visible: modelData.known && !modelData.connected
                        text: "Forget"
                        onClicked: modelData.forget()
                    }
                }
            }
        }
    }

    // Mot de passe d'un réseau protégé inconnu.
    PanelSection {
        visible: root.passwordFor !== null
        text: `Password for ${root.passwordFor?.name ?? ""}`
    }

    PanelField {
        id: password
        visible: root.passwordFor !== null
        password: true
        placeholder: "Password"
        onVisibleChanged: {
            text = "";
            if (visible)
                focusInput();
        }
        onAccepted: text => {
            if (text !== "")
                root.passwordFor.connectWithPsk(text);
            root.passwordFor = null;
        }
    }

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
