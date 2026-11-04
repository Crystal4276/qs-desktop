import QtQuick
import qs.config

// Croix d'un champ de recherche (ta demande du 2026-10-20) : visible si `field` n'est pas vide ; un clic l'efface et lui
// rend le focus. Glyphe « fermer » de l'outil de capture (THEME.md § 7) ; couleur secondaire du champ, couleur du texte
// au survol. Taille : celle que fixe le champ.
Text {
    id: root

    required property TextInput field
    property bool active: true   // PanelField : seulement pour un champ de recherche
    property color normalColor: Theme.panel.secondaryText
    property color hoverColor: Theme.panel.text

    visible: active && field.text !== ""
    text: Theme.icon.close
    font.family: Theme.font.icons
    color: hover.hovered ? hoverColor : normalColor

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.field.text = "";
            root.field.forceActiveFocus();
        }
    }
}
