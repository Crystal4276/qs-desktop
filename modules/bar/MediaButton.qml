import QtQuick
import qs.config

// Bouton rond à glyphe de la carte média (MediaCard.qml) : sans fond (survol `surface0`), ou plein (`filled`, lecture).
Rectangle {
    id: root

    property string glyph: ""
        property bool filled: false
    signal clicked

    implicitWidth: Theme.mediaCard.buttonSize
    implicitHeight: Theme.mediaCard.buttonSize
    radius: width / 2
    color: filled ? Theme.mediaCard.play : hover.hovered && enabled ? Theme.mediaCard.buttonHover : "transparent"
    opacity: enabled ? 1 : Theme.panel.disabledOpacity

    // Clavier, comme PanelButton : Entrée ou Espace, liseré quand le bouton est choisi.
    activeFocusOnTab: enabled
    border.width: activeFocus ? Theme.panel.border : 0
    border.color: Theme.panel.focusRing
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Text {
        anchors.centerIn: parent
        text: root.glyph
        font.family: Theme.font.icons
        font.pixelSize: Theme.mediaCard.glyphSize
        color: root.filled ? Theme.mediaCard.playGlyph : Theme.panel.text
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
