import QtQuick
import qs.config

// Bouton d'un panneau : fond `surface0`, survol `surface1`, Inter 16 px.
Rectangle {
    id: root

    property string text: ""
    property color textColor: Theme.panel.text
    property string fontFamily: Theme.font.text   // Theme.font.icons pour un bouton à glyphe (carte média)
    signal clicked

    implicitWidth: label.implicitWidth + 2 * Theme.panel.buttonPaddingH
    implicitHeight: label.implicitHeight + 2 * Theme.panel.buttonPaddingV
    radius: Theme.panel.rowRadius
    color: hover.hovered ? Theme.panel.buttonHover : Theme.panel.button
    opacity: enabled ? 1 : 0.5

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: root.fontFamily
        font.pixelSize: Theme.panel.smallFontSize
        color: root.textColor
    }

    HoverHandler {
        id: hover
    }

    // MouseArea (et non TapHandler) : le clic est consommé ici et n'atteint pas la ligne qui contient le bouton.
    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
