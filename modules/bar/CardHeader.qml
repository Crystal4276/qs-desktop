import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config

// En-tête d'une carte (PanelCard) : icône 48 px (du thème, ou dessinée via `leading`), titre Inter 20 px (`green` si actif),
// ligne d'état Inter 16 px, contrôles à droite. Cartes Wi-Fi, filaire, Tailscale, ZeroTier.
RowLayout {
    id: root

    property string icon: ""
    property real iconOpacity: 1
    property alias leading: leadingSlot.data
    property string title: ""
    property string status: ""
    property color statusColor: Theme.panel.secondaryText
    property bool active: false
    default property alias trailing: trailingSlot.data

    Layout.fillWidth: true
    spacing: Theme.panel.spacing

    RowLayout {
        id: leadingSlot
        visible: children.length > 0
        spacing: 0
    }

    IconImage {
        visible: root.icon !== ""
        implicitSize: Theme.panel.cardIconSize
        source: root.icon === "" ? "" : `image://icon/${root.icon}`
        opacity: root.iconOpacity
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            Layout.fillWidth: true
            text: root.title
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.fontSize
            color: root.active ? Theme.panel.accent : Theme.panel.text
            elide: Text.ElideRight
        }

        PanelSection {
            visible: text !== ""
            text: root.status
            color: root.statusColor
        }
    }

    RowLayout {
        id: trailingSlot
        spacing: Theme.panel.spacing
    }
}
