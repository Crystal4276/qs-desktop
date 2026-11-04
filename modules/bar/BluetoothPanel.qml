import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.services

// Panneau Bluetooth (remplace blueman, ARCHITECTURE § 7.7) : interrupteur, appareils appairés (BluetoothDeviceItem.qml : connecter,
// déconnecter, oublier, batterie, détails dépliables), appareils à proximité (recherche tant que le panneau est ouvert) et
// appairage avec confirmation (Bluez.qml).
Panel {
    id: root

    title: "Bluetooth"
    hasSwitch: true
    switchChecked: Bluez.enabled
    onSwitchToggled: checked => Bluez.setEnabled(checked)

    // Adresse de l'appareil dont les détails sont dépliés (un seul à la fois, comme KDE).
    property string expanded: ""
    // Ordre des appareils appairés figé à l'ouverture (GNOME) : une ligne ne bouge pas sous le pointeur quand son appareil se
    // connecte ; les nouveaux (appairés panneau ouvert) vont à la fin. Retrié à la prochaine ouverture.
    property var order: []
    readonly property var pairedShown: Bluez.paired.map((d, i) => ({ d: d, rank: order.indexOf(d.address), i: i }))
        .sort((a, b) => ((a.rank < 0 ? Infinity : a.rank) - (b.rank < 0 ? Infinity : b.rank)) || a.i - b.i).map(e => e.d)

    // Recherche : panneau épinglé seulement (pas pendant un aperçu au survol). Fermer le panneau l'arrête et annule un appairage
    // en cours (l'agent ne tourne jamais sans le panneau).
    onPinnedChanged: Bluez.scanning = pinned
    onVisibleChanged: {
        if (visible) {
            order = Bluez.paired.map(d => d.address);
            return;
        }
        expanded = "";
        Bluez.cancelPairing();
    }
    // Barre détruite panneau épinglé (écran retiré) : ni recherche ni appairage sans panneau.
    Component.onDestruction: {
        if (!pinned)
            return;
        Bluez.scanning = false;
        Bluez.cancelPairing();
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
            values: Bluez.enabled ? root.pairedShown : []
        }

        BluetoothDeviceItem {
            required property BluetoothDevice modelData

            device: modelData
            expanded: root.expanded === (modelData?.address ?? "")
            onToggled: root.expanded = expanded ? "" : modelData.address
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
                    subtext: modelData.pairing ? "Pairing…" : Bluez.typeName(modelData)
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
