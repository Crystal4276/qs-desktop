import QtQuick
import qs.config

// Bouton carré de la ligne du haut du panneau de réglages : image SVG (verrouiller, déconnexion, redémarrer, éteindre) ou
// glyphe (capture d'écran), sur un bouton de panneau (fond `surface0`, survol `surface1`, coins 10 px).
Rectangle {
    id: root

    property string glyph: ""
    property url image: ""
    signal clicked

    implicitWidth: Theme.quickSettings.imageSize + 2 * Theme.quickSettings.buttonPadding
    implicitHeight: implicitWidth
    radius: Theme.panel.rowRadius
    color: hover.hovered ? Theme.panel.buttonHover : Theme.panel.button

    // Clavier (Tab, flèches) : Entrée ou Espace activent ; liseré quand l'élément est choisi.
    activeFocusOnTab: true
    border.width: activeFocus ? Theme.panel.border : 0
    border.color: Theme.panel.focusRing
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Image {
        anchors.centerIn: parent
        visible: root.glyph === ""
        source: root.image
        sourceSize.width: Theme.quickSettings.imageSize
        sourceSize.height: Theme.quickSettings.imageSize
    }

    Text {
        anchors.centerIn: parent
        visible: root.glyph !== ""
        text: root.glyph
        font.family: Theme.font.icons
        font.pixelSize: Theme.quickSettings.glyphSize
        color: Theme.panel.text
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
