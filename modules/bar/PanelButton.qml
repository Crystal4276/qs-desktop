import QtQuick
import qs.config

// Bouton d'un panneau : fond `surface0`, survol `surface1`, Inter 16 px.
Rectangle {
    id: root

    property string text: ""
    property bool checked: false   // choisi (onglet) : contrastes inversés, comme une bascule activée
    property color textColor: checked ? Theme.quickSettings.checkedText : Theme.panel.text
    property string fontFamily: Theme.font.text   // Theme.font.icons pour un bouton à glyphe (carte média)
    signal clicked

    implicitWidth: label.implicitWidth + 2 * Theme.panel.buttonPaddingH
    implicitHeight: label.implicitHeight + 2 * Theme.panel.buttonPaddingV
    radius: Theme.panel.rowRadius
    color: checked ? Theme.quickSettings.checked : hover.hovered ? Theme.panel.buttonHover : Theme.panel.button
    opacity: enabled ? 1 : Theme.panel.disabledOpacity

    // Clavier (Tab, flèches) : Entrée ou Espace activent ; liseré quand l'élément est choisi.
    activeFocusOnTab: enabled
    border.width: activeFocus ? Theme.panel.border : 0
    border.color: Theme.panel.focusRing
    Keys.onReturnPressed: event => root.press(event)
    Keys.onEnterPressed: event => root.press(event)
    Keys.onSpacePressed: event => root.press(event)

    // Touche maintenue : une seule action (Mute basculerait en rafale).
    function press(event: KeyEvent): void {
        if (!event.isAutoRepeat)
            clicked();
    }

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

    // MouseArea (et non TapHandler) : le clic est consommé ici et n'atteint pas la ligne qui contient le bouton. Bouton désactivé :
    // cette zone l'est aussi, c'est PanelRow qui ignore le clic.
    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
