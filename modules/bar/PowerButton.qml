import QtQuick
import qs.config

// Bouton d'extinction (INVENTORY.md § 1, `custom/powermenu`) : `U+F011` rouge, 28 px ; padding 10 px sauf à gauche (0).
// N'ouvre rien avant la phase 8 (power menu en QML).
Item {
    implicitWidth: label.implicitWidth + Theme.bar.modulePadding
    implicitHeight: label.implicitHeight + 2 * Theme.bar.modulePadding

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        text: Theme.icon.power
        font.family: Theme.font.icons
        font.pixelSize: Theme.font.powerIcon
        color: Theme.module.power
    }
}
