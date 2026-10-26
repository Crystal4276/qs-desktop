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
    // Appareil connecté seulement : une carte gardée d'un appareil supprimé connecté (BlueZ relancé) n'est pas montrée.
    readonly property var audioCard: device?.connected ? Bluez.audioCards[device.address] ?? null : null
    property bool copied: false

    Layout.fillWidth: true
    spacing: 0

    function stateText(): string {
        if (!device)
            return "";
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

    // Détails dépliés (ou ligne recréée dépliée) : nom remis à celui de l'appareil (une saisie abandonnée n'y reste pas) ;
    // profils audio lus (appareil connecté), puis relus quand ses nœuds PipeWire apparaissent ou changent (carte créée après la
    // connexion, profil changé). Nœuds absents un instant pendant un changement de profil : la carte reste affichée.
    readonly property string audioNodes: expanded && device ? Bluez.audioNodes(device) : ""
    function refresh(): void {
        if (!expanded || !device)
            return;
        nameField.text = device.name;
        Bluez.readAudioCard(device);
    }
    onExpandedChanged: refresh()
    Component.onCompleted: refresh()
    onAudioNodesChanged: {
        if (audioNodes !== "")
            Bluez.readAudioCard(device);
    }

    // Appareil supprimé (oublié, adaptateur retiré) avant le retrait de sa ligne : `device` nul, liaisons protégées par `?.`.

    Timer {
        id: copiedTimer
        interval: 2000
        onTriggered: root.copied = false
    }

    PanelRow {
        text: (root.device?.name ?? "")
        subtext: [root.stateText(), Bluez.typeName(root.device),
            root.device?.connected && root.device.batteryAvailable ? `battery ${Bluez.batteryPercent(root.device)} %` : ""]
            .filter(s => s).join(" · ")
        active: root.device?.connected ?? false
        onClicked: root.toggled()

        leading: IconImage {
            id: deviceIcon
            implicitSize: Theme.panel.iconSize
            source: `image://icon/${root.device?.icon || "bluetooth"}`

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
            text: root.device?.connected ? "Disconnect" : "Connect"
            enabled: root.device !== null && !root.busy   // atténué pendant une action (sinon un clic sans effet)
            onClicked: {
                if (root.device.connected)
                    Bluez.disconnectDevice(root.device);
                else
                    Bluez.connectDevice(root.device);
            }
        }

        PanelButton {
            visible: !(root.device?.connected ?? true)
            text: "Forget"
            onClicked: Bluez.forget(root.device)
        }
    }

    PanelCard {
        visible: root.expanded && root.device !== null

        DetailsGrid {
            rows: !root.device ? [] : [
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
            placeholder: root.device?.deviceName ?? ""
            // Saisie en cours : nom modifié, pas encore validé (le panneau ne se ferme pas tout seul).
            pending: inputItem.activeFocus && text !== (root.device?.name ?? "")
            // Champ remis au nom attendu : sinon (vide ou espaces) il ne correspondrait jamais au nom et resterait « en saisie ».
            onAccepted: name => {
                Bluez.rename(root.device, name);
                text = name.trim() || root.device.deviceName;
            }

            Connections {
                target: root.device

                function onNameChanged(): void {
                    if (root.device && !nameField.inputItem.activeFocus)
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
