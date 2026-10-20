import QtQuick
import qs.config

// Croix d'un champ de recherche (ta demande du 2026-10-20) : efface la recherche, le champ garde le focus. Glyphe « fermer »
// de l'outil de capture (THEME.md § 7 ter) ; couleur secondaire du champ, couleur du texte au survol. Taille du texte du champ
// et `visible` (champ non vide) posés par le champ.
Text {
    id: root

    property color normalColor: Theme.panel.secondaryText
    property color hoverColor: Theme.panel.text
    signal clicked

    text: Theme.icon.close
    font.family: Theme.font.icons
    color: hover.hovered ? hoverColor : normalColor

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
