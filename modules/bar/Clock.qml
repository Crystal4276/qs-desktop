import QtQuick
import Quickshell
import qs.config

// Horloge (INVENTORY.md § 1) : `U+E385␣␣%H:%M`, et sur la barre principale `␣␣U+F274␣%a-%d`.
// Texte en Inter ; horloge en Hack Nerd Font, calendrier en Font Awesome 7 (THEME.md § 2).
// Une seule ligne de texte, comme le label Pango de Waybar : mêmes avances et même ligne de base
// (avec des Text séparés, Qt compterait le débordement du glyphe dans sa largeur).
// Locale et fuseau : ceux du système. Le calendrier (phase 4) s'ouvrira d'ici.
Item {
    id: root

    property bool showDate: false

    implicitWidth: label.implicitWidth + 2 * Theme.bar.modulePadding
    implicitHeight: label.implicitHeight + 2 * Theme.bar.modulePadding

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function span(family: string, text: string): string {
        return `<span style="font-family:'${family}'; white-space:pre">${text}</span>`;
    }

    Text {
        id: label
        anchors.centerIn: parent
        textFormat: Text.RichText
        font.family: Theme.font.text
        font.pixelSize: Theme.font.barText
        color: Theme.module.clock
        text: root.span(Theme.font.inlineIcons, Theme.icon.clock)
            + root.span(Theme.font.text, "  " + clock.date.toLocaleString(Qt.locale(), "HH:mm"))
            + (root.showDate
                ? root.span(Theme.font.text, "  ")
                    + root.span(Theme.font.awesome, Theme.icon.calendar)
                    + root.span(Theme.font.text, " " + clock.date.toLocaleString(Qt.locale(), "ddd-dd"))
                : "")
    }
}
