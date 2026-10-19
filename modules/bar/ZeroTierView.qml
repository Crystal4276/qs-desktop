import QtQuick
import QtQuick.Layouts
import Quickshell
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

    // Un minuteur par état : copier ne prolonge pas une confirmation de départ, et inversement.
    Timer {
        id: copiedTimer
        interval: 2000   // comme les copies de l'onglet Tailscale
        onTriggered: root.copied = false
    }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirmLeave = ""
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
    PanelCard {
        CardHeader {
            icon: "zerotier-gui"
            title: "ZeroTier"
            active: ZeroTier.connectedCount > 0
            status: root.copied ? "Node ID copied"
                : !ZeroTier.authorized ? `${ZeroTier.interfaces.length} interface(s)`
                : `${ZeroTier.info?.online ? "Online" : "Offline"} · node ${ZeroTier.info?.address ?? ""}`

            PanelButton {
                visible: ZeroTier.authorized
                text: "Copy node ID"
                onClicked: {
                    if ((ZeroTier.info?.address ?? "") === "")
                        return;
                    Network.copy(ZeroTier.info.address);
                    root.copied = true;
                    copiedTimer.restart();
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

            leading: StatusIcon {
                icon: "zerotier-gui"
                online: modelData.status === "OK"
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
                        confirmTimer.restart();
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
        // Rouge seulement pour une saisie impossible (caractère non hexadécimal, plus de 16) ; vidé si la demande est partie.
        error: /[^0-9a-fA-F]/.test(text) || text.length > 16
        onAccepted: text => {
            if (/^[0-9a-fA-F]{16}$/.test(text) && ZeroTier.join(text.toLowerCase()))
                joinField.text = "";
        }
    }
}
