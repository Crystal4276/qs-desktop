import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services

// Onglet Tailscale du panneau réseau (ta demande du 2026-10-19 ; services/Tailscale.qml) : carte (interrupteur up / down,
// connexion, cet appareil), nœud de sortie, options (DNS, routes, Shields Up, accès au LAN), appareils du tailnet (en ligne,
// système, liaison directe ou relayée ; clic : copie de l'IP).
ColumnLayout {
    id: root

    // Appareil dont l'IP vient d'être copiée (affiché 2 s) : `id`, ou "self".
    property string copied: ""

    function copy(text: string, id: string): void {
        Network.copy(text);
        copied = id;
        copiedTimer.restart();
    }

    Layout.fillWidth: true
    spacing: Theme.panel.spacing

    Timer {
        id: copiedTimer
        interval: 2000
        onTriggered: root.copied = ""
    }

    // --- Erreurs : dernière commande, santé du démon, droits ---
    PanelSection {
        visible: Tailscale.error !== ""
        text: Tailscale.error
        color: Theme.panel.warning
        wrapMode: Text.Wrap
    }

    // Santé du démon, connecté seulement (arrêté, elle ne dit que « Tailscale is stopped », déjà dans la carte).
    Repeater {
        model: ScriptModel {
            values: Tailscale.running ? Tailscale.health : []
        }

        PanelSection {
            required property string modelData
            text: modelData
            color: Theme.panel.warning
            wrapMode: Text.Wrap
        }
    }

    PanelSection {
        visible: !Tailscale.canAct
        text: "Read only: run « sudo tailscale set --operator=$USER » once to control Tailscale from here"
        wrapMode: Text.Wrap
    }

    // --- Carte ---
    PanelCard {
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.panel.spacing

            IconImage {
                implicitSize: Theme.wifi.cardIconSize
                source: "image://icon/network-vpn"
                opacity: Tailscale.running ? 1 : Theme.panel.disabledOpacity
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: "Tailscale"
                    font.family: Theme.font.text
                    font.pixelSize: Theme.panel.fontSize
                    color: Tailscale.running ? Theme.panel.accent : Theme.panel.text
                }

                PanelSection {
                    text: Tailscale.busy ? "Working…"
                        : Tailscale.running ? `Connected · ${Tailscale.onlineCount} of ${Tailscale.peers.length} devices online`
                        : Tailscale.state === "NeedsLogin" ? "Signed out"
                        : Tailscale.state === "Stopped" ? "Disconnected"
                        : Tailscale.state
                }
            }

            PanelButton {
                visible: Tailscale.state === "NeedsLogin"
                text: Tailscale.authUrl !== "" ? "Open sign-in page" : "Sign in…"
                onClicked: Tailscale.login()
            }

            PanelSwitch {
                visible: Tailscale.state !== "NeedsLogin"
                enabled: Tailscale.canAct && !Tailscale.busy
                opacity: enabled ? 1 : Theme.panel.disabledOpacity
                checked: Tailscale.running
                onToggled: checked => Tailscale.setRunning(checked)
            }
        }

        DetailsGrid {
            visible: Tailscale.running && shown.length > 0
            rows: [
                ["Tailnet", Tailscale.tailnet],
                ["This device", Tailscale.self?.name ?? ""],
                ["IPv4 address", root.copied === "self" ? "Copied" : (Tailscale.self?.ip ?? "")],
                ["MagicDNS name", Tailscale.self?.dns ?? ""],
                ["Exit node", Tailscale.exitNode ? Tailscale.exitNode.name : "None"]
            ]
        }

        RowLayout {
            visible: Tailscale.running && Tailscale.self !== null
            Layout.fillWidth: true

            Item {
                Layout.fillWidth: true
            }

            PanelButton {
                text: "Copy IP"
                onClicked: root.copy(Tailscale.self.ip, "self")
            }

            PanelButton {
                text: "Copy name"
                onClicked: root.copy(Tailscale.self.dns, "self")
            }
        }
    }

    // --- Nœud de sortie ---
    PanelSection {
        visible: Tailscale.running
        text: Tailscale.exitNodes.length === 0 ? "Exit node · none offered in your tailnet" : "Exit node"
    }

    // Listes relues toutes les 5 s : ScriptModel avec clé, pour garder les lignes (focus clavier, survol) d'une relecture à
    // l'autre. « None » : clé vide.
    Repeater {
        model: ScriptModel {
            values: Tailscale.running && Tailscale.exitNodes.length > 0 ? [{ id: "", none: true }, ...Tailscale.exitNodes] : []
            objectProp: "id"
        }

        PanelRow {
            required property var modelData
            readonly property bool none: modelData.none ?? false

            icon: none ? "network-vpn" : Tailscale.osIcon(modelData.os)
            text: none ? "None" : modelData.name
            subtext: none ? "Use your own Internet connection" : (modelData.online ? modelData.ip : "Offline")
            active: none ? Tailscale.exitNode === null : modelData.exitNode
            enabled: Tailscale.canAct && !Tailscale.busy && (none || modelData.online)
            onClicked: Tailscale.setExitNode(none ? "" : (modelData.ip || modelData.dns))
        }
    }

    // --- Options ---
    PanelSection {
        visible: Tailscale.running
        text: "Options"
    }

    Repeater {
        model: ScriptModel {
            objectProp: "flag"
            values: Tailscale.running ? [
            { flag: "accept-dns", text: "Use Tailscale DNS", subtext: "MagicDNS names and tailnet DNS settings", on: Tailscale.acceptDns, shown: true },
            { flag: "accept-routes", text: "Accept subnet routes", subtext: "Reach networks shared by other devices", on: Tailscale.acceptRoutes, shown: true },
            { flag: "shields-up", text: "Shields up", subtext: "Block incoming connections from the tailnet", on: Tailscale.shieldsUp, shown: true },
            { flag: "exit-node-allow-lan-access", text: "Allow local network access", subtext: "Keep the LAN reachable through the exit node", on: Tailscale.allowLanAccess, shown: Tailscale.exitNode !== null }
            ].filter(o => o.shown) : []
        }

        PanelRow {
            required property var modelData

            text: modelData.text
            subtext: modelData.subtext
            enabled: Tailscale.canAct && !Tailscale.busy
            onClicked: Tailscale.setOption(modelData.flag, !modelData.on)

            PanelSwitch {
                enabled: Tailscale.canAct && !Tailscale.busy
                opacity: enabled ? 1 : Theme.panel.disabledOpacity
                checked: modelData.on
                onToggled: checked => Tailscale.setOption(modelData.flag, checked)
            }
        }
    }

    // --- Appareils ---
    PanelSection {
        visible: Tailscale.running && Tailscale.peers.length > 0
        text: `Devices · ${Tailscale.onlineCount} online · click to copy the IP`
    }

    Flickable {
        visible: Tailscale.running && Tailscale.peers.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(peerList.implicitHeight, Theme.panel.maxListHeight)
        contentHeight: peerList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: peerList
            width: parent.width
            spacing: 0

            Repeater {
                model: ScriptModel {
                    values: Tailscale.peers
                    objectProp: "id"
                }

                PanelRow {
                    required property var modelData

                    leading: Item {
                        implicitWidth: Theme.panel.iconSize
                        implicitHeight: Theme.panel.iconSize

                        IconImage {
                            anchors.fill: parent
                            source: `image://icon/${Tailscale.osIcon(modelData.os)}`
                            opacity: modelData.online ? 1 : Theme.panel.disabledOpacity
                        }

                        // Point d'état, en bas à droite, cerclé du fond du panneau.
                        Rectangle {
                            width: Theme.network.dotSize
                            height: width
                            radius: width / 2
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            color: modelData.online ? Theme.network.online : Theme.network.offline
                            border.width: Theme.panel.border
                            border.color: Theme.panel.background
                        }
                    }
                    text: modelData.name
                    subtext: root.copied === modelData.id ? `Copied ${modelData.ip}`
                        : modelData.online ? [modelData.ip, Tailscale.osName(modelData.os), modelData.direct ? "direct" : `relayed (${modelData.relay})`].filter(s => s).join(" · ")
                        : ["Offline", Tailscale.osName(modelData.os), modelData.lastSeen ? `seen ${Tailscale.ago(modelData.lastSeen)}` : ""].filter(s => s).join(" · ")
                    active: modelData.online
                    onClicked: root.copy(modelData.ip, modelData.id)
                }
            }
        }
    }
}
