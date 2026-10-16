import QtQuick
import qs.config
import qs.services

// Batterie (INVENTORY.md § 1, `battery`, pour le laptop) : 12 paliers (seuils de getIcon de Waybar), icône de charge
// en charge ; vert, rouge sous 30 % hors charge. Masquée sans batterie de portable.
// Taille : celle du texte GTK par défaut (aucune taille dans style.css, THEME.md § 3).
Item {
    readonly property bool shown: Battery.available

    implicitWidth: label.implicitWidth + 2 * Theme.bar.modulePadding
    implicitHeight: label.implicitHeight + 2 * Theme.bar.modulePadding

    Text {
        id: label
        anchors.centerIn: parent
        text: Battery.charging ? Theme.icon.batteryCharging
            : Theme.level(Theme.icon.battery, Battery.percent)
        font.family: Theme.font.icons
        font.pixelSize: Theme.font.defaultIcon
        color: Battery.warning && !Battery.charging ? Theme.module.batteryWarning : Theme.module.battery
    }
}
