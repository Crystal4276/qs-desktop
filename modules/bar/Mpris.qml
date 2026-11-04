import QtQuick
import qs.config
import qs.services

// Lecture en cours (Waybar `mpris`) : `{player_icon} {status_icon} {dynamic}`, identique en lecture, pause et arrêt ;
// icône d'état seulement en pause. Lecteur absent → masqué.
// Clic gauche : lecture / pause ; milieu : précédent ; droit : suivant ; molette : lecteur suivant / précédent (Media.qml).
Item {
    id: root

    readonly property bool shown: Media.player !== null

    implicitWidth: label.implicitWidth + 2 * Theme.bar.modulePadding
    implicitHeight: label.implicitHeight + 2 * Theme.bar.modulePadding

    readonly property var icon: Theme.icon.players[Media.playerName] ?? Theme.icon.players.default

    RichLabel {
        id: label
        anchors.centerIn: parent
        color: Theme.module.media
        // Pango (relevé avec `pango-view --serialize-to`) : l'espace entre deux icônes garde la police de la première
        // (13 px en Font Awesome 7 Brands contre 7 en Inter) ; les espaces suivies de texte sont en Inter.
        segments: Media.paused ? [
            [root.icon.font, root.icon.glyph + " "],
            [Theme.font.awesome4, Theme.icon.paused],
            [Theme.font.text, " " + Media.dynamic]
        ] : [
            [root.icon.font, root.icon.glyph],
            [Theme.font.text, "  " + Media.dynamic]
        ]
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Media.togglePlaying();
            else if (mouse.button === Qt.MiddleButton)
                Media.previous();
            else
                Media.next();
        }
    }

    WheelSteps {
        onStep: direction => Media.shift(direction > 0)
    }
}
