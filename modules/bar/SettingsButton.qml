import QtQuick
import qs.config

// Bouton des réglages, à la place du bouton power (INVENTORY.md § 1, `custom/powermenu` : padding 10 px sauf à gauche, 28 px) :
// engrenage `U+F013` couleur `text` (ton choix du 2026-10-16). Un appui ouvre ou ferme le panneau de réglages (un seul pour
// toutes les barres : BarState) ; `qs ipc call settings toggle` passe par le bouton de l'écran focalisé.
Item {
    id: root

    implicitWidth: label.implicitWidth + Theme.bar.modulePadding
    implicitHeight: label.implicitHeight + 2 * Theme.bar.modulePadding

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        text: Theme.icon.settings
        font.family: Theme.font.icons
        font.pixelSize: Theme.font.powerIcon
        color: Theme.module.settings
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: BarState.toggle("settings", root)
    }

    Component.onCompleted: BarState.register("settings", root)
    Component.onDestruction: BarState.unregister("settings", root)
}
