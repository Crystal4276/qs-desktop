import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Widgets
import qs.config
import qs.services

// Appareil appairé du panneau Bluetooth (ta demande du 2026-10-26, modèle de KDE) : ligne (icône qui pulse pendant une action,
// nom, état · type · batterie, « Connection failed » après un échec), Connect / Disconnect et Forget ; un clic sur la ligne déplie
// ses détails dans une carte : nom d'origine, type, adresse (copiable), batterie, appairé, approuvé, adaptateur ; reconnexion
// automatique ; profil audio d'un casque connecté (blueman) ; nouveau nom.
ColumnLayout {
    id: root

    required property BluetoothDevice device
    property bool expanded: false
    signal toggled

    readonly property bool busy: Bluez.isBusy(device)
    readonly property var audioCard: Bluez.audioCards[device.address] ?? null
    property bool copied: false

    Layout.fillWidth: true
    spacing: 0

    function stateText(): string {
        if (device.pairing)
            return "Pairing…";
        if (Bluez.isConnecting(device))
            return "Connecting…";
        switch (device.state) {
        case BluetoothDeviceState.Disconnecting:
            return "Disconnecting…";
        case BluetoothDeviceState.Connected:
            return "Connected";
        default:
            return Bluez.failed[device.address] ? "Connection failed" : "";
        }
    }

    // Profils audio relus à chaque dépliage et à chaque connexion pendant qu'il est déplié.
    onExpandedChanged: {
        if (expanded)
            Bluez.readAudioCard(device);
    }

    Connections {
        target: root.device

        function onConnectedChanged(): void {
            if (root.expanded)
                Bluez.readAudioCard(root.device);
        }
    }

    Timer {
        id: copiedTimer
        interval: 2000
        onTriggered: root.copied = false
    }

    PanelRow {
        text: root.device.name
        subtext: [root.stateText(), Bluez.typeName(root.device),
            root.device.connected && root.device.batteryAvailable ? `battery ${Bluez.batteryPercent(root.device)} %` : ""]
            .filter(s => s).join(" · ")
        active: root.device.connected
        onClicked: root.toggled()

        leading: IconImage {
            id: deviceIcon
            implicitSize: Theme.panel.iconSize
            source: `image://icon/${root.device.icon || "bluetooth"}`

            SequentialAnimation {
                running: root.busy
                loops: Animation.Infinite
                alwaysRunToEnd: true   // finit à pleine opacité

                NumberAnimation {
                    target: deviceIcon
                    property: "opacity"
                    to: Theme.panel.disabledOpacity
                    duration: Theme.bluetooth.busyDuration / 2
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    target: deviceIcon
                    property: "opacity"
                    to: 1
                    duration: Theme.bluetooth.busyDuration / 2
                    easing.type: Easing.InOutSine
                }
            }
        }

        PanelButton {
            text: root.device.connected ? "Disconnect" : "Connect"
            onClicked: {
                if (root.busy)
                    return;
                if (root.device.connected)
                    Bluez.disconnectDevice(root.device);
                else
                    Bluez.connectDevice(root.device);
            }
        }

        PanelButton {
            visible: !root.device.connected
            text: "Forget"
            onClicked: root.device.forget()
        }
    }

    PanelCard {
        visible: root.expanded

        DetailsGrid {
            rows: [
                ["Original name", root.device.deviceName !== root.device.name ? root.device.deviceName : ""],
                ["Type", Bluez.typeName(root.device)],
                ["Address", root.copied ? "Copied" : root.device.address],
                ["Battery", root.device.connected && root.device.batteryAvailable ? `${Bluez.batteryPercent(root.device)} %` : ""],
                ["Paired", root.device.paired ? "Yes" : "No"],
                ["Trusted", root.device.trusted ? "Yes" : "No"],
                ["Adapter", root.device.adapter ? `${root.device.adapter.name} (${root.device.adapter.adapterId})` : ""]
            ]
        }

        PanelRow {
            text: "Connect automatically"
            subtext: "Every minute, when it is disconnected"
            onClicked: Bluez.setAutoConnect(root.device, !Bluez.isAutoConnect(root.device))

            PanelSwitch {
                checked: Bluez.isAutoConnect(root.device)
                onToggled: checked => Bluez.setAutoConnect(root.device, checked)
            }
        }

        PanelSection {
            visible: root.audioCard !== null
            text: "Audio profile"
        }

        Repeater {
            model: root.audioCard?.profiles ?? []

            PanelRow {
                required property var modelData

                text: modelData.description
                active: modelData.index === root.audioCard?.active
                onClicked: {
                    if (!active)
                        Bluez.setAudioProfile(root.device, modelData.index);
                }
            }
        }

        PanelSection {
            text: "Name"
        }

        PanelField {
            id: nameField
            placeholder: root.device.deviceName
            // Saisie en cours : nom modifié, pas encore validé (le panneau ne se ferme pas tout seul).
            pending: inputItem.activeFocus && text !== root.device.name
            Component.onCompleted: text = root.device.name
            onAccepted: name => Bluez.rename(root.device, name)

            Connections {
                target: root.device

                function onNameChanged(): void {
                    if (!nameField.inputItem.activeFocus)
                        nameField.text = root.device.name;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Item {
                Layout.fillWidth: true
            }

            PanelButton {
                text: "Copy address"
                onClicked: {
                    Network.copy(root.device.address);
                    root.copied = true;
                    copiedTimer.restart();
                }
            }
        }
    }
}
