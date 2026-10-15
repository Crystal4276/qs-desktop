import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config

// Horloge (INVENTORY.md § 1) : `U+E385␣␣%H:%M`, et sur la barre principale `␣␣U+F274␣%a-%d`.
// Texte en Inter, glyphes en Symbols Nerd Font Mono, alignés sur la même ligne de base.
// Locale et fuseau : ceux du système. Le calendrier (phase 4) s'ouvrira d'ici.
Item {
    id: root

    property bool showDate: false

    implicitWidth: row.implicitWidth + 2 * Theme.bar.modulePadding
    implicitHeight: row.implicitHeight + 2 * Theme.bar.modulePadding

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    component Glyph: Text {
        Layout.alignment: Qt.AlignBaseline
        font.family: Theme.font.icons
        font.pixelSize: Theme.font.barText
        color: Theme.module.clock
    }

    component Label: Text {
        Layout.alignment: Qt.AlignBaseline
        font.family: Theme.font.text
        font.pixelSize: Theme.font.barText
        color: Theme.module.clock
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 0

        Glyph {
            text: Theme.icon.clock
        }
        Label {
            text: "  " + clock.date.toLocaleString(Qt.locale(), "HH:mm")
        }
        Label {
            visible: root.showDate
            text: "  "
        }
        Glyph {
            visible: root.showDate
            text: Theme.icon.calendar
        }
        Label {
            visible: root.showDate
            text: " " + clock.date.toLocaleString(Qt.locale(), "ddd-dd")
        }
    }
}
