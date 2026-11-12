import QtQuick
import qs.config
import qs.services

// Rétroéclairage (Waybar `backlight`, pour le laptop) : 9 paliers (getIcon de Waybar), pêche.
// Molette : ±5 % par cran (comme les touches et la molette du volume). Masqué sans rétroéclairage. Taille : celle du texte
// GTK par défaut (THEME.md § 3).
Item {
    readonly property bool shown: Brightness.available

    implicitWidth: label.implicitWidth + 2 * Theme.bar.modulePadding
    implicitHeight: label.implicitHeight + 2 * Theme.bar.modulePadding

    Text {
        id: label
        anchors.centerIn: parent
        text: Theme.level(Theme.icon.backlight, Brightness.percent)
        font.family: Theme.font.icons
        font.pixelSize: Theme.font.defaultIcon
        color: Theme.module.backlight
    }

    WheelSteps {
        onStep: direction => Brightness.step(5 * direction)
    }
}
