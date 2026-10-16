import QtQuick
import Quickshell
import qs.config
import qs.modules.menus

// Bouton Arch (INVENTORY.md § 1, `custom/menu`) : logo vert sur `mantle` ; survol (ou menu ouvert) : logo `mantle` sur fond vert.
// Largeur min. 40 px + padding horizontal 10 px ; logo 38 px de large. Aucune transition.
// Un appui ouvre ou ferme le menu d'applications (modules/menus/AppMenu.qml, chargé à sa première ouverture) ;
// `qs ipc call menu toggle` passe par le bouton de l'écran focalisé (BarState).
Item {
    id: root

    readonly property bool open: menu.item?.visible ?? false
    readonly property bool active: hover.hovered || open

    function toggle(): void {
        menu.active = true;
        menu.item.toggle(root);
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

    LazyLoader {
        id: menu

        AppMenu {}
    }

    Component.onCompleted: BarState.registerMenu(root)
    Component.onDestruction: BarState.unregisterMenu(root)
}
