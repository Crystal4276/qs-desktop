import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Onglet Tailscale du panneau réseau (ta demande du 2026-10-19 ; services/Tailscale.qml) : carte (interrupteur up / down,
// connexion, cet appareil), nœud de sortie, options (DNS, routes, Shields Up, accès au LAN), appareils du tailnet (en ligne,
// système, liaison directe ou relayée ; clic : copie de l'IP).
ColumnLayout {
    id: root

    // Ce qui vient d'être copié (affiché 2 s) : `id` d'un appareil, "self-ip" ou "self-name". Rien sans valeur.
    property string copied: ""

    function copy(text: string, id: string): void {
        if (text === "")
            return;
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
        CardHeader {
            icon: "network-vpn"
            iconOpacity: Tailscale.running ? 1 : Theme.panel.disabledOpacity
            title: "Tailscale"
            active: Tailscale.running
            status: Tailscale.busy ? "Working…"
                : Tailscale.loggingIn && Tailscale.state === "NeedsLogin" ? "Waiting for sign-in in the browser…"
                : Tailscale.running ? `Connected · ${Tailscale.onlineCount} of ${Tailscale.devices.length} devices online`
                : Tailscale.state === "NeedsLogin" ? "Signed out"
                : Tailscale.state === "Stopped" ? "Disconnected"
                : Tailscale.state

            PanelButton {
                visible: Tailscale.state === "NeedsLogin"
                text: Tailscale.authUrl !== "" ? "Open sign-in page" : "Sign in…"
                enabled: Tailscale.canAct && (Tailscale.authUrl !== "" || !Tailscale.loggingIn)
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
            shownWhen: Tailscale.running
            rows: [
                ["Tailnet", Tailscale.tailnet],
                ["This device", Tailscale.self?.name ?? ""],
                ["IPv4 address", root.copied === "self-ip" ? "Copied" : (Tailscale.self?.ip ?? "")],
                ["MagicDNS name", root.copied === "self-name" ? "Copied" : (Tailscale.self?.dns ?? "")],
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
                onClicked: root.copy(Tailscale.self.ip, "self-ip")
            }

            PanelButton {
                text: "Copy name"
                onClicked: root.copy(Tailscale.self.dns, "self-name")
            }
        }
    }

    // --- Nœud de sortie ---
    PanelSection {
        visible: Tailscale.running
        text: Tailscale.exitNodes.length === 0 ? "Exit node · none offered in your tailnet" : "Exit node"
    }

    // Listes relues toutes les 5 s : ScriptModel avec clé, pour garder les lignes (focus clavier, survol) d'une relecture à
    // l'autre. « None » : clé vide. Nœuds de sortie : ListView (seules les lignes visibles sont créées : des centaines avec
    // Mullvad), qui défile au-delà de la hauteur des listes.
    ListView {
        id: exitList
        visible: Tailscale.running && Tailscale.exitNodes.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, Theme.panel.maxListHeight)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: Tailscale.running && Tailscale.exitNodes.length > 0 ? [{ id: "", none: true }, ...Tailscale.exitNodes] : []
            objectProp: "id"
        }

        delegate: PanelRow {
            required property var modelData
            readonly property bool none: modelData.none ?? false

            width: exitList.width
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

            // Atténué avec sa ligne (PanelRow) : pas d'opacité propre, qui se cumulerait.
            PanelSwitch {
                checked: modelData.on
                onToggled: checked => Tailscale.setOption(modelData.flag, checked)
            }
        }
    }

    // --- Appareils ---
    PanelSection {
        visible: Tailscale.running && Tailscale.devices.length > 0
        text: `Devices · ${Tailscale.onlineCount} online · click to copy the IP`
    }

    PanelList {
        id: devicesList
        visible: Tailscale.running && Tailscale.devices.length > 0

        Repeater {
            model: ScriptModel {
                values: Tailscale.devices
                objectProp: "id"
            }

            PanelRow {
                required property var modelData

                leading: StatusIcon {
                    icon: Tailscale.osIcon(modelData.os)
                    online: modelData.online
                }
                text: modelData.name
                subtext: root.copied === modelData.id ? `Copied ${modelData.ip}`
                    : modelData.online ? [modelData.ip, Tailscale.osName(modelData.os), modelData.direct ? "direct" : !modelData.active ? "idle" : modelData.relay ? `relayed (${modelData.relay})` : "relayed"].filter(s => s).join(" · ")
                    : ["Offline", Tailscale.osName(modelData.os), modelData.lastSeen ? `seen ${Tailscale.ago(modelData.lastSeen)}` : ""].filter(s => s).join(" · ")
                active: modelData.online
                onClicked: root.copy(modelData.ip, modelData.id)
            }
        }
    }
}
