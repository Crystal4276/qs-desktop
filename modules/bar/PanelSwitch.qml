import QtQuick
import qs.config

// Interrupteur des panneaux (THEME.md § 3 « Panneaux »).
Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: Theme.panel.switchWidth
    implicitHeight: Theme.panel.switchHeight
    radius: height / 2
    color: checked ? Theme.panel.switchOn : Theme.panel.switchOff

    // Clavier (Tab, flèches) : Entrée ou Espace activent ; liseré quand l'élément est choisi.
    activeFocusOnTab: true
    border.width: activeFocus ? Theme.panel.border : 0
    border.color: Theme.panel.focusRing
    Keys.onReturnPressed: root.toggled(!root.checked)
    Keys.onEnterPressed: root.toggled(!root.checked)
    Keys.onSpacePressed: root.toggled(!root.checked)

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
        onClicked: root.toggled(!root.checked)
    }
}
