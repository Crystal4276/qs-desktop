import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Panneau réseau (remplace le menu de nm-applet, ARCHITECTURE § 7.6 ; THEME.md § 3 « Panneau réseau ») : une carte par câble
// (WiredCard.qml). Le Wi-Fi a son propre module (WifiPanel.qml), Tailscale et ZeroTier sont dans le panneau VPN (VpnPanel.qml).
// Libellés en anglais, comme nm-applet et la locale du système.
Panel {
    id: root

    title: "Network"

    onVisibleChanged: Network.setPanelOpen("network", root, visible)
    Component.onDestruction: Network.setPanelOpen("network", root, false)

    Repeater {
        model: ScriptModel {
            values: Network.wiredDevices
        }

        WiredCard {
            required property var modelData
            device: modelData
        }
    }

    NetworkSettingsButton {
        panel: root
    }
}
