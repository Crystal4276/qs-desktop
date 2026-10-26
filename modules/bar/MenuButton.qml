import QtQuick
import qs.config

// Bouton Arch (INVENTORY.md § 1, `custom/menu`) : logo vert sur `mantle` ; survol (ou menu ouvert) : logo `mantle` sur fond vert.
// Largeur min. 40 px + padding horizontal 10 px ; logo 38 px de large. Aucune transition.
// Un appui ouvre ou ferme le menu d'applications (modules/menus/AppMenu.qml, un seul pour toutes les barres : BarState) ;
// `qs ipc call menu toggle` passe par le bouton de l'écran focalisé.
Item {
    id: root

    readonly property bool active: hover.hovered || BarState.openedUnder("menu") === root

    function toggle(): void {
        BarState.load("menu")?.toggle(root);
    }

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

    MouseArea {
        anchors.fill: parent
        onPressed: root.toggle()
    }

    Component.onCompleted: BarState.register("menu", root)
    Component.onDestruction: BarState.unregister("menu", root)
}
