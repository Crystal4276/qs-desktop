import QtQuick
import Quickshell.Widgets
import qs.config

// Icône 24 px avec point d'état en bas à droite, cerclé du fond du panneau (THEME.md § 3 « Panneau réseau ») : `green` actif,
// `surface2` sinon, icône atténuée. Appareils Tailscale, réseaux ZeroTier.
Item {
    property string icon: ""
    property bool online: false

    implicitWidth: Theme.panel.iconSize
    implicitHeight: Theme.panel.iconSize

    IconImage {
        anchors.fill: parent
        source: `image://icon/${parent.icon}`
        opacity: parent.online ? 1 : Theme.panel.disabledOpacity
    }

    Rectangle {
        width: Theme.network.dotSize
        height: width
        radius: width / 2
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: parent.online ? Theme.network.online : Theme.network.offline
        border.width: Theme.panel.border
        border.color: Theme.panel.background
    }
}
