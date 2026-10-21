import QtQuick
import Quickshell
import qs.config

// Horloge (INVENTORY.md § 1) : `U+E385␣HH:mm`, et sur la barre principale, 10 px puis `U+F274␣ddd-dd` (une espace après
// l'icône et un padding de module avant le calendrier, comme les pilules système et réseau : ta demande du 2026-10-20).
// Texte en Inter ; horloge en Hack Nerd Font, calendrier en Font Awesome 7 (THEME.md § 2).
// Largeur fixe et minimale (ta demande du 2026-10-20) : l'heure et la date prennent la largeur de la plus large de leurs valeurs.
// Locale et fuseau : ceux du système. Survol : aperçu du calendrier ; clic : calendrier épinglé (ARCHITECTURE § 8.3).
// Survol ou calendrier épinglé : contrastes inversés, fond `yellow` et texte `mantle`, comme le bouton Arch (ta demande du 2026-10-21).
InfoModule {
    id: root

    property bool showDate: false

    // Toutes les valeurs possibles, pour la largeur fixe : 00:00 à 23:59 ; jours de la semaine (locale) × 01 à 31.
    readonly property var times: Array.from({ length: 24 * 60 }, (_, i) => ` ${String(Math.floor(i / 60)).padStart(2, "0")}:${String(i % 60).padStart(2, "0")}`)
    readonly property var dates: [].concat(...Array.from({ length: 7 }, (_, d) => Array.from({ length: 31 }, (_, i) => ` ${Qt.locale().dayName(d, Locale.ShortFormat)}-${String(i + 1).padStart(2, "0")}`)))

    color: Theme.module.clock
    highlightOnHover: true
    held: calendar.pinned
    segments: [
        [Theme.font.inlineIcons, Theme.icon.clock],
        [Theme.font.text, " " + clock.date.toLocaleString(Qt.locale(), "HH:mm"), root.times],
        ...(root.showDate ? [
            [Theme.font.awesome, Theme.icon.calendar, [], Theme.bar.modulePadding],
            [Theme.font.text, " " + clock.date.toLocaleString(Qt.locale(), "ddd-dd"), root.dates]
        ] : [])
    ]

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
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
        hovered: root.hovered
    }
}
