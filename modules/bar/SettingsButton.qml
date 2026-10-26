import QtQuick
import qs.config

// Bouton des réglages, à la place du bouton power (INVENTORY.md § 1, `custom/powermenu` : padding 10 px sauf à gauche, 28 px) :
// engrenage `U+F013` couleur `text` (ton choix du 2026-10-16). Un appui ouvre ou ferme le panneau de réglages (un seul pour
// toutes les barres : BarState) ; `qs ipc call settings toggle` passe par le bouton de l'écran focalisé.
// Survol : aperçu du panneau après un court arrêt, comme les icônes du tray (TrayButton.qml ; ta demande du 2026-10-26).
Item {
    id: root

    readonly property alias hovered: hover.hovered
    readonly property int buttons: Qt.LeftButton | Qt.RightButton
    readonly property var panel: BarState.loaders.settings?.item ?? null   // null avant la première ouverture

    // Comme TrayButton.qml, sur le panneau chargé à la demande (Panel.qml).
    function toggle(): void {
        BarState.load("settings")?.toggle(root, root.buttons);
    }

    implicitWidth: label.implicitWidth + Theme.bar.modulePadding
    implicitHeight: label.implicitHeight + 2 * Theme.bar.modulePadding

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        text: Theme.icon.settings
        font.family: Theme.font.icons
        font.pixelSize: Theme.font.powerIcon
        color: Theme.module.settings
    }

    HoverHandler {
        id: hover
        onHoveredChanged: BarState.setTrayHover(root, hovered)
    }

    // Relancé aussi quand un popup épinglé qui bloquait l'aperçu se ferme, pointeur resté sur l'engrenage.
    Timer {
        interval: Theme.panel.previewDelay
        running: root.visible && hover.hovered && !(root.panel?.previewSuppressed ?? false) && !(root.panel?.visible ?? false)
            && !BarState.popupPinned
        onTriggered: BarState.load("settings")?.preview(root, root.buttons)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: root.buttons
        onPressed: root.toggle()
    }

    Component.onCompleted: BarState.register("settings", root)
    Component.onDestruction: {
        BarState.setTrayHover(root, false);
        BarState.unregister("settings", root);
    }
}
