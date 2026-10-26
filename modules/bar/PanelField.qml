import QtQuick
import QtQuick.Layouts
import qs.config

// Champ de saisie d'un panneau (mot de passe Wi-Fi, phrase de passe d'un disque…) : fond `base`, bordure `overlay0`,
// `green` quand il a le focus, `red` en erreur (mot de passe refusé). Entrée : `accepted(text)`. `search` (champ de recherche) :
// croix d'effacement à droite, et Échap efface le texte, puis ferme le panneau s'il est déjà vide. `validator`, `inputMask` : saisie
// acceptée seulement si valide ; `editingFinished(text)` : Entrée ou perte du focus, texte valide (heures du « ne pas déranger »).
Rectangle {
    id: root

    property alias text: input.text
    readonly property Item inputItem: input   // à focaliser (OverlayPopup.initialFocus)
    property bool password: false
    property bool error: false
    property string placeholder: ""
    property bool search: false
    property alias validator: input.validator
    property alias inputMask: input.inputMask
    // Saisie en cours (focus compris) : le panneau ne se ferme pas tout seul (Panel.qml). Par défaut : champ non vide.
    property bool pending: input.text !== ""
    signal accepted(string text)
    signal editingFinished(string text)

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
        onEditingFinished: root.editingFinished(text)
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
