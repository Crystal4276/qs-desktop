import QtQuick
import qs.config

// Bouton carré à image SVG (verrouiller, déconnexion, redémarrer, éteindre) ou glyphe (capture d'écran). Par défaut, bouton de
// panneau (fond `surface0`, survol `surface1`, coins 10 px), aussi dans le menu d'applications.
Rectangle {
    id: root

    property string glyph: ""
    property url image: ""
    property int imageSize: Theme.quickSettings.imageSize
    property int padding: Theme.quickSettings.buttonPadding
    property color background: Theme.panel.button
    property color hoverBackground: Theme.panel.buttonHover
    property color hoverBorder: "transparent"
    signal clicked

    implicitWidth: imageSize + 2 * padding
    implicitHeight: implicitWidth
    radius: Theme.panel.rowRadius
    color: hover.hovered ? hoverBackground : background

    // Clavier (Tab, flèches) : Entrée ou Espace activent ; liseré quand l'élément est choisi.
    activeFocusOnTab: true
    border.width: activeFocus || (hover.hovered && hoverBorder.a > 0) ? Theme.panel.border : 0
    border.color: activeFocus ? Theme.panel.focusRing : hoverBorder
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Image {
        anchors.centerIn: parent
        visible: root.glyph === ""
        source: root.image
        sourceSize.width: root.imageSize
        sourceSize.height: root.imageSize
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
