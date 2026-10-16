import QtQuick
import qs.config

// Bouton Arch (INVENTORY.md § 1, `custom/menu`) : logo vert sur `mantle` ; survol (ou menu ouvert) : logo `mantle` sur fond vert.
// Largeur min. 40 px + padding horizontal 10 px ; logo 38 px de large. Aucune transition.
// N'ouvre rien avant la phase 8 (menu d'applications maison, ARCHITECTURE § 8 Q3).
Item {
    id: root

    property bool active: hover.hovered

    implicitWidth: Theme.bar.menuButtonMin + 2 * Theme.bar.menuButtonPadding
    implicitHeight: Theme.bar.menuButtonMin

    Rectangle {
        anchors.fill: parent
        visible: root.active
        // Le fond suit l'arrondi intérieur de la pilule.
        radius: Theme.bar.pillRadius - Theme.bar.pillBorder
        color: Theme.module.menuActiveBackground
    }

    Image {
        anchors.centerIn: parent
        source: root.active ? Theme.image.archMantle : Theme.image.archGreen
        sourceSize.width: Theme.bar.menuIconSize
        width: Theme.bar.menuIconSize
        fillMode: Image.PreserveAspectFit
    }

    HoverHandler {
        id: hover
    }
}
