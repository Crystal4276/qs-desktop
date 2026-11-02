import QtQuick
import Quickshell
import qs.config
import qs.services

// Horloge (INVENTORY.md § 1) : `U+E385␣HH:mm`, et sur la barre principale, 10 px puis `U+F274␣ddd-dd` (une espace après
// l'icône et un padding de module avant le calendrier, comme les pilules système et réseau : ta demande du 2026-10-20).
// Texte en Inter ; horloge en Hack Nerd Font, calendrier en Font Awesome 7 (THEME.md § 2).
// Largeur fixe et minimale (ta demande du 2026-10-20) : l'heure et la date prennent la largeur de la plus large de leurs valeurs.
// Locale et fuseau : ceux du système. Survol : aperçu du calendrier ; clic : calendrier épinglé (CalendarPanel.qml, comme le tray).
// Survol ou calendrier épinglé : contrastes inversés, fond `yellow` et texte `mantle`, comme le bouton Arch (ta demande du 2026-10-21).
InfoModule {
    id: root

    property bool showDate: false

    color: Theme.module.clock
    highlightOnHover: true
    held: calendar.pinned
    segments: [
        [Theme.font.inlineIcons, Theme.icon.clock],
        [Theme.font.text, " " + clock.date.toLocaleString(Qt.locale(), "HH:mm"), WidthTexts.times],
        ...(root.showDate ? [
            [Theme.font.awesome, Theme.icon.calendar, [], Theme.bar.modulePadding],
            [Theme.font.text, " " + clock.date.toLocaleString(Qt.locale(), "ddd-dd"), WidthTexts.dates]
        ] : [])
    ]

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PreviewArea {
        id: area
        button: root
        panel: calendar
        panelButtons: Qt.LeftButton
        onPreviewRequested: calendar.preview(root, Qt.LeftButton)
        onToggleRequested: calendar.toggle(root, Qt.LeftButton)
    }

    CalendarPanel {
        id: calendar
    }
}
