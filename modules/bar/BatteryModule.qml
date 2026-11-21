import QtQuick
import qs.config
import qs.services

// Batterie (Waybar `battery`, pour le laptop) : 12 paliers (seuils de getIcon de Waybar), icône de charge
// en charge ; turquoise, rouge sous 30 % hors charge. Masquée sans batterie de portable.
// Taille : celle du texte GTK par défaut (aucune taille dans style.css, THEME.md § 3).
Item {
    id: root

    readonly property alias hovered: area.hovered
    readonly property alias buttons: area.buttons
    function toggle(): void { BarState.load("battery")?.toggle(root, root.buttons); }

    readonly property bool shown: Battery.available

    implicitWidth: label.implicitWidth + 2 * Theme.bar.modulePadding
    implicitHeight: label.implicitHeight + 2 * Theme.bar.modulePadding

    BatteryIcon {
        id: label
        anchors.centerIn: parent
        percent: Battery.percent
        charging: Battery.charging
        warning: Battery.warning
    }
    PreviewArea {
        id: area
        button: root
        panel: BarState.loaders.battery?.item ?? null
        onPreviewRequested: BarState.load("battery")?.preview(root, root.buttons)
        onToggleRequested: root.toggle()
    }
    Component.onCompleted: BarState.register("battery", root)
    Component.onDestruction: BarState.unregister("battery", root)
}
