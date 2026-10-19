import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Réseaux privés (Tailscale, ZeroTier), en lecture seule : dans le panneau réseau, ou dans le panneau Wi-Fi quand l'icône
// réseau est masquée (laptop sans câble, Network.wiredShown).
ColumnLayout {
    property bool wanted: true

    Layout.fillWidth: true
    spacing: Theme.panel.spacing
    visible: wanted && (Network.tailscale !== null || Network.zerotier.length > 0)

    PanelSection {
        text: "Private networks"
    }

    PanelRow {
        visible: Network.tailscale !== null
        clickable: false
        icon: "network-vpn"
        text: "Tailscale"
        subtext: Network.tailscale?.state === "Running"
            ? [Network.tailscale.address, `${Network.tailscale.peers} devices`].filter(s => s).join(" · ")
            : (Network.tailscale?.state ?? "")
        active: Network.tailscale?.state === "Running"
    }

    Repeater {
        model: ScriptModel {
            values: Network.zerotier
            objectProp: "name"
        }

        PanelRow {
            required property var modelData

            clickable: false
            icon: "zerotier-gui"
            text: "ZeroTier"
            subtext: `${modelData.name} · ${modelData.address}`
            active: true
        }
    }
}
