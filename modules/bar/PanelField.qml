import QtQuick
import QtQuick.Layouts
import qs.config

// Champ de saisie d'un panneau (mot de passe Wi-Fi, phrase de passe d'un disque…) : fond `base`, bordure `overlay0`,
// `green` quand il a le focus, `red` en erreur (mot de passe refusé). Entrée : `accepted(text)`. `search` (champ de recherche) :
// croix d'effacement à droite, et Échap efface le texte, puis ferme le panneau s'il est déjà vide.
Rectangle {
    id: root

    property alias text: input.text
    property bool password: false
    property bool error: false
    property string placeholder: ""
    property bool search: false
    signal accepted(string text)

    function focusInput(): void {
        input.forceActiveFocus();
    }

    Layout.fillWidth: true
    implicitHeight: input.implicitHeight + 2 * Theme.panel.rowPadding
    radius: Theme.panel.rowRadius
    color: Theme.panel.fieldBackground
    border.width: Theme.panel.border
    border.color: root.error ? Theme.panel.fieldError : input.activeFocus ? Theme.panel.fieldFocus : Theme.panel.fieldBorder

    TextInput {
        id: input
        anchors {
            left: parent.left
            right: clear.visible ? clear.left : parent.right
            verticalCenter: parent.verticalCenter
            margins: Theme.panel.rowPadding
        }
        font.family: Theme.font.text
        font.pixelSize: Theme.panel.fontSize
        color: Theme.panel.text
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        clip: true
        onAccepted: root.accepted(text)
        Keys.onEscapePressed: event => {
            if (root.search && text !== "")
                text = "";
            else
                event.accepted = false;
        }

        Text {
            visible: input.text === ""
            text: root.placeholder
            font: input.font
            color: Theme.panel.secondaryText
        }
    }

    ClearButton {
        id: clear
        field: input
        active: root.search
        font.pixelSize: Theme.panel.fontSize
        anchors {
            right: parent.right
            rightMargin: Theme.panel.rowPadding
            verticalCenter: parent.verticalCenter
        }
    }
}
