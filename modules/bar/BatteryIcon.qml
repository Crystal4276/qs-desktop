import QtQuick
import qs.config

// Glyphe partagé : la rotation échange aussi les dimensions réservées dans la ligne.
Item {
    id: root

    property int percent: 0
    property bool charging: false
    property bool warning: false
    property bool horizontal: false
    property alias pixelSize: glyph.font.pixelSize
    property alias color: glyph.color

    implicitWidth: horizontal ? glyph.implicitHeight : glyph.implicitWidth
    implicitHeight: horizontal ? glyph.implicitWidth : glyph.implicitHeight

    Text {
        id: glyph
        anchors.centerIn: parent
        text: root.charging ? Theme.icon.batteryCharging : Theme.level(Theme.icon.battery, root.percent)
        font.family: Theme.font.icons
        font.pixelSize: Theme.font.defaultIcon
        color: root.warning && !root.charging ? Theme.module.batteryWarning : Theme.module.battery
        rotation: root.horizontal ? 90 : 0
    }
}
