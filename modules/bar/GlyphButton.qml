import QtQuick
import qs.config

// Bouton rond à glyphe (Symbols Nerd Font Mono) : carte média (précédent / lecture / suivant) et croix des lignes du centre de
// notifications. Sans fond, rond `hoverColor` au survol ; ou plein (`filled`, lecture).
Rectangle {
    id: root

    property string glyph: ""
    property int size: Theme.mediaCard.buttonSize
    property int glyphSize: Theme.mediaCard.glyphSize
    property bool filled: false
    property color glyphColor: Theme.panel.text
    property color glyphHoverColor: glyphColor
    property color hoverColor: Theme.mediaCard.buttonHover
    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: width / 2
    color: filled ? Theme.mediaCard.play : hover.hovered && enabled ? hoverColor : "transparent"
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
        font.pixelSize: root.glyphSize
        color: root.filled ? Theme.mediaCard.playGlyph : hover.hovered ? root.glyphHoverColor : root.glyphColor
    }

    HoverHandler {
        id: hover
    }

    // MouseArea (et non TapHandler) : le clic est consommé ici et n'atteint pas la ligne qui contient le bouton.
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
