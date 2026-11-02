import QtQuick
import qs.config

// Interrupteur des panneaux (THEME.md § 3 « Panneaux »). `locked` (action en cours) : atténué comme un élément indisponible,
// bascules ignorées ; reste focalisable (pas `enabled`, qui ferait perdre le focus clavier au panneau).
Rectangle {
    id: root

    property bool checked: false
    property bool locked: false
    signal toggled(bool checked)

    function flip(event: KeyEvent): void {
        if (event?.isAutoRepeat)   // touche maintenue : une seule bascule
            return;
        if (!locked)
            toggled(!checked);
        else if (event)
            event.accepted = false;   // comme une ligne verrouillée : la touche remonte au panneau
    }

    implicitWidth: Theme.panel.switchWidth
    implicitHeight: Theme.panel.switchHeight
    radius: height / 2
    color: checked ? Theme.panel.switchOn : Theme.panel.switchOff
    opacity: locked ? Theme.panel.disabledOpacity : 1

    // Clavier (Tab, flèches) : Entrée ou Espace activent ; liseré quand l'élément est choisi.
    activeFocusOnTab: true
    border.width: activeFocus ? Theme.panel.border : 0
    border.color: Theme.panel.focusRing
    Keys.onReturnPressed: event => root.flip(event)
    Keys.onEnterPressed: event => root.flip(event)
    Keys.onSpacePressed: event => root.flip(event)

    Rectangle {
        width: parent.height - 6
        height: width
        radius: width / 2
        x: root.checked ? parent.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        color: root.checked ? Theme.panel.switchKnobOn : Theme.panel.switchKnobOff
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.flip(null)
    }
}
