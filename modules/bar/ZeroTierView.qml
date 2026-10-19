import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services

// Onglet ZeroTier du panneau réseau (ta demande du 2026-10-19 ; services/ZeroTier.qml) : carte du nœud (en ligne, identifiant
// à copier), réseaux (nom, état, adresses ; DNS du réseau, quitter avec confirmation), rejoindre un réseau par son identifiant.
// Sans le jeton : interfaces `zt*` en lecture seule et la commande qui l'active.
ColumnLayout {
    id: root

    property bool copied: false
    // Réseau dont le départ attend confirmation (second clic).
    property string confirmLeave: ""

    Layout.fillWidth: true
    spacing: Theme.panel.spacing

    Timer {
        id: resetTimer
        interval: 3000
        onTriggered: {
            root.copied = false;
            root.confirmLeave = "";
        }
    }

    PanelSection {
        visible: ZeroTier.error !== ""
        text: ZeroTier.error
        color: Theme.panel.warning
        wrapMode: Text.Wrap
    }

    PanelSection {
        visible: !ZeroTier.authorized
        text: "Read only: copy the service token once to manage networks here —\nsudo install -m 600 -o $USER -g $USER /var/lib/zerotier-one/authtoken.secret ~/.zeroTierOneAuthToken"
        wrapMode: Text.Wrap
    }

    // --- Carte du nœud ---
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: card.implicitHeight + 2 * Theme.panel.padding
        radius: Theme.panel.rowRadius
        color: Theme.wifi.card

        RowLayout {
            id: card
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.panel.padding
            }
            spacing: Theme.panel.spacing

            IconImage {
                implicitSize: Theme.wifi.cardIconSize
                source: "image://icon/zerotier-gui"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: "ZeroTier"
                    font.family: Theme.font.text
                    font.pixelSize: Theme.panel.fontSize
                    color: ZeroTier.connectedCount > 0 ? Theme.panel.accent : Theme.panel.text
                }

                PanelSection {
                    text: root.copied ? "Node ID copied"
                        : !ZeroTier.authorized ? `${ZeroTier.interfaces.length} interface(s)`
                        : `${ZeroTier.info?.online ? "Online" : "Offline"} · node ${ZeroTier.info?.address ?? ""}`
                }
            }

            PanelButton {
                visible: ZeroTier.authorized
                text: "Copy node ID"
                onClicked: {
                    Network.copy(ZeroTier.info?.address ?? "");
                    root.copied = true;
                    resetTimer.restart();
                }
            }
        }
    }

    // --- Réseaux ---
    PanelSection {
        text: ZeroTier.authorized ? `Networks · ${ZeroTier.connectedCount} connected` : "Networks"
        visible: ZeroTier.authorized ? ZeroTier.networks.length > 0 : ZeroTier.interfaces.length > 0
    }

    Repeater {
        model: ScriptModel {
            values: ZeroTier.authorized ? ZeroTier.networks : []
            objectProp: "id"
        }

        PanelRow {
            required property var modelData

            leading: Item {
                implicitWidth: Theme.panel.iconSize
                implicitHeight: Theme.panel.iconSize

                IconImage {
                    anchors.fill: parent
                    source: "image://icon/zerotier-gui"
                    opacity: modelData.status === "OK" ? 1 : Theme.panel.disabledOpacity
                }

                // Point d'état, comme les appareils Tailscale.
                Rectangle {
                    width: Theme.network.dotSize
                    height: width
                    radius: width / 2
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    color: modelData.status === "OK" ? Theme.network.online : Theme.network.offline
                    border.width: Theme.panel.border
                    border.color: Theme.panel.background
                }
            }
            text: modelData.name
            subtext: [ZeroTier.statusText(modelData.status), modelData.addresses.join(", "), modelData.type.toLowerCase()].filter(s => s).join(" · ")
            active: modelData.status === "OK"
            clickable: false

            PanelButton {
                text: "DNS"
                checked: modelData.allowDns
                enabled: !ZeroTier.busy
                onClicked: ZeroTier.setOption(modelData.id, "allowDNS", !modelData.allowDns)
            }

            PanelButton {
                text: root.confirmLeave === modelData.id ? "Confirm" : "Leave"
                enabled: !ZeroTier.busy
                onClicked: {
                    if (root.confirmLeave === modelData.id) {
                        root.confirmLeave = "";
                        ZeroTier.leave(modelData.id);
                    } else {
                        root.confirmLeave = modelData.id;
                        resetTimer.restart();
                    }
                }
            }
        }
    }

    Repeater {
        model: ScriptModel {
            values: ZeroTier.authorized ? [] : ZeroTier.interfaces
            objectProp: "name"
        }

        PanelRow {
            required property var modelData

            clickable: false
            icon: "zerotier-gui"
            text: modelData.name
            subtext: modelData.address
            active: true
        }
    }

    // --- Rejoindre ---
    PanelSection {
        visible: ZeroTier.authorized
        text: "Join a network"
    }

    PanelField {
        id: joinField
        visible: ZeroTier.authorized
        placeholder: "Network ID (16 characters)"
        error: text !== "" && !/^[0-9a-fA-F]{16}$/.test(text)
        onAccepted: text => {
            if (/^[0-9a-fA-F]{16}$/.test(text)) {
                ZeroTier.join(text.toLowerCase());
                joinField.text = "";
            }
        }
    }
}
