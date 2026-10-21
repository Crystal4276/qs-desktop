import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.services

// Panneau Bluetooth (remplace blueman, ARCHITECTURE R6) : interrupteur, appareils appairés (connecter, déconnecter, oublier,
// batterie), appareils à proximité (recherche tant que le panneau est ouvert) et appairage avec confirmation (Bluez.qml).
Panel {
    id: root

    title: "Bluetooth"
    hasSwitch: true
    switchChecked: Bluez.enabled
    onSwitchToggled: checked => Bluez.setEnabled(checked)

    // Recherche : panneau épinglé seulement (pas pendant un aperçu au survol). Fermer le panneau l'arrête et annule un appairage
    // en cours (l'agent ne tourne jamais sans le panneau).
    onPinnedChanged: Bluez.scanning = pinned
    onVisibleChanged: {
        if (!visible)
            Bluez.cancelPairing();
    }
    // Barre détruite panneau épinglé (écran retiré) : ni recherche ni appairage sans panneau.
    Component.onDestruction: {
        if (!pinned)
            return;
        Bluez.scanning = false;
        Bluez.cancelPairing();
    }

    function stateText(device: BluetoothDevice): string {
        if (device.pairing)
            return "Pairing…";
        switch (device.state) {
        case BluetoothDeviceState.Connecting:
            return "Connecting…";
        case BluetoothDeviceState.Disconnecting:
            return "Disconnecting…";
        case BluetoothDeviceState.Connected:
            return device.batteryAvailable ? `Connected · battery ${Math.round(device.battery * 100)} %` : "Connected";
        default:
            return "";
        }
    }

    PanelSection {
        visible: !Bluez.enabled
        text: "Bluetooth is off"
    }

    // --- Appareils appairés ---
    PanelSection {
        visible: Bluez.enabled && Bluez.paired.length > 0
        text: "Devices"
    }

    Repeater {
        model: ScriptModel {
            values: Bluez.enabled ? Bluez.paired : []
        }

        PanelRow {
            required property BluetoothDevice modelData

            icon: modelData.icon || "bluetooth"
            text: modelData.name
            subtext: root.stateText(modelData)
            active: modelData.connected
            onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()

            PanelButton {
                text: modelData.connected ? "Disconnect" : "Connect"
                onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
            }

            PanelButton {
                visible: !modelData.connected
                text: "Forget"
                onClicked: modelData.forget()
            }
        }
    }

    // --- Appareils à proximité ---
    PanelSection {
        visible: Bluez.enabled
        text: Bluez.others.length === 0 ? "Nearby devices · searching…" : "Nearby devices"
    }

    Flickable {
        visible: Bluez.enabled && Bluez.others.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(nearby.implicitHeight, Theme.panel.maxListHeight)
        contentHeight: nearby.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: nearby
            width: parent.width
            spacing: 0

            Repeater {
                model: ScriptModel {
                    values: Bluez.others
                }

                PanelRow {
                    required property BluetoothDevice modelData

                    icon: modelData.icon || "bluetooth"
                    text: modelData.name
                    subtext: root.stateText(modelData)
                    onClicked: Bluez.pair(modelData)

                    PanelButton {
                        text: "Pair"
                        onClicked: Bluez.pair(modelData)
                    }
                }
            }
        }
    }

    // --- Appairage : demandes de l'agent, jamais acceptées sans toi ---
    PanelSection {
        visible: Bluez.pairingDevice !== null
        text: Bluez.pairingError !== "" ? `Pairing with ${Bluez.pairingDevice?.name} failed: ${Bluez.pairingError}`
            : Bluez.requestType === "confirm" ? `Does ${Bluez.pairingDevice?.name} show the code ${Bluez.request}?`
            : Bluez.requestType === "authorize" ? `Allow ${Bluez.pairingDevice?.name} to pair?`
            : Bluez.requestType === "pin" ? `PIN code for ${Bluez.pairingDevice?.name}`
            : Bluez.requestType === "passkey" ? `Code shown on ${Bluez.pairingDevice?.name}`
            : Bluez.requestType === "display" ? `Type ${Bluez.request} on ${Bluez.pairingDevice?.name}`
            : `Pairing with ${Bluez.pairingDevice?.name}…`
        wrapMode: Text.WordWrap
    }

    PanelField {
        visible: Bluez.requestType === "pin" || Bluez.requestType === "passkey"
        placeholder: Bluez.requestType === "pin" ? "PIN code" : "Code"
        onVisibleChanged: {
            text = "";
            if (visible)
                focusInput();
        }
        onAccepted: text => Bluez.answer(text)
    }

    RowLayout {
        visible: Bluez.pairingDevice !== null
        Layout.fillWidth: true

        Item {
            Layout.fillWidth: true
        }

        PanelButton {
            visible: Bluez.requestType === "confirm" || Bluez.requestType === "authorize"
            text: "Yes"
            textColor: Theme.panel.accent
            onClicked: Bluez.answer("yes")
        }

        PanelButton {
            visible: Bluez.requestType === "confirm" || Bluez.requestType === "authorize"
            text: "No"
            onClicked: Bluez.answer("no")
        }

        PanelButton {
            text: Bluez.pairingError !== "" ? "Close" : "Cancel"
            onClicked: Bluez.cancelPairing()
        }
    }
}
