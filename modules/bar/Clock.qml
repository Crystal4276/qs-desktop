import QtQuick
import Quickshell
import qs.config

// Horloge (INVENTORY.md § 1) : `U+E385␣␣HH:mm`, et sur la barre principale `␣␣U+F274␣ddd-dd`.
// Texte en Inter ; horloge en Hack Nerd Font, calendrier en Font Awesome 7 (THEME.md § 2).
// Locale et fuseau : ceux du système. Survol : aperçu du calendrier ; clic : calendrier épinglé (ARCHITECTURE § 8.3).
Item {
    id: root

    property bool showDate: false

    implicitWidth: label.implicitWidth + 2 * Theme.bar.modulePadding
    implicitHeight: label.implicitHeight + 2 * Theme.bar.modulePadding

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RichLabel {
        id: label
        anchors.centerIn: parent
        color: Theme.module.clock
        segments: [
            [Theme.font.inlineIcons, Theme.icon.clock],
            [Theme.font.text, "  " + clock.date.toLocaleString(Qt.locale(), "HH:mm")],
            ...(root.showDate ? [
                [Theme.font.text, "  "],
                [Theme.font.awesome, Theme.icon.calendar],
                [Theme.font.text, " " + clock.date.toLocaleString(Qt.locale(), "ddd-dd")]
            ] : [])
        ]
    }

    HoverHandler {
        id: hover
    }

    // Calendrier épinglé : fermé dès l'appui (même long ou glissé) ; sinon épinglé au clic.
    TapHandler {
        property bool closedOnPress: false
        onPressedChanged: {
            if (!pressed)
                return;
            closedOnPress = calendar.pinned;
            if (closedOnPress)
                calendar.toggle();
        }
        onTapped: if (!closedOnPress) calendar.toggle()
    }

    CalendarPopup {
        id: calendar
        anchorItem: root
        hovered: hover.hovered
    }
}
