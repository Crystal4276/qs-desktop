import QtQuick
import QtQuick.Layouts
import qs.config

// Champ de saisie d'un panneau (mot de passe Wi-Fi, phrase de passe d'un disque…) : fond `base`, bordure `overlay0`,
// `green` quand il a le focus. Entrée : `accepted(text)`.
Rectangle {
    id: root

    property alias text: input.text
    property bool password: false
    property string placeholder: ""
    signal accepted(string text)

    function focusInput(): void {
        input.forceActiveFocus();
    }

    Layout.fillWidth: true
    implicitHeight: input.implicitHeight + 2 * Theme.panel.rowPadding
    radius: Theme.panel.rowRadius
    color: Theme.panel.fieldBackground
    border.width: Theme.panel.border
    border.color: input.activeFocus ? Theme.panel.fieldFocus : Theme.panel.fieldBorder

    TextInput {
        id: input
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Theme.panel.rowPadding
        }
        font.family: Theme.font.text
        font.pixelSize: Theme.panel.fontSize
        color: Theme.panel.text
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        clip: true
        onAccepted: root.accepted(text)

        Text {
            visible: input.text === ""
            text: root.placeholder
            font: input.font
            color: Theme.panel.secondaryText
        }
    }
}
