import QtQuick
import qs.config
import qs.services

// Lecture en cours (Waybar `mpris`) : `{player_icon} {status_icon} {dynamic}`, identique en lecture, pause et arrêt ;
// icône d'état seulement en pause. Lecteur absent → masqué.
// Clic gauche : lecture / pause ; milieu : précédent ; droit : suivant ; molette : lecteur suivant / précédent (Media.qml).
Item {
    id: root

    readonly property bool shown: Media.player !== null

    property real extraWidth: 0
    readonly property real minimumWidth: prefix.implicitWidth + 2 * Theme.bar.modulePadding
    readonly property string artist: (Media.player?.trackArtist ?? "").trim()
    readonly property string title: (Media.player?.trackTitle ?? "").trim()
    readonly property string separator: artist && title ? " - " : ""
    readonly property string gap: Media.paused ? " " : "  "
    readonly property real textBudget: Math.max(0, extraWidth - metrics.advanceWidth(gap + separator))
    readonly property real artistWidth: metrics.advanceWidth(artist)
    readonly property real titleWidth: metrics.advanceWidth(title)
    readonly property real artistBudget: Math.min(artistWidth, Math.max(textBudget / 2, textBudget - titleWidth))
    readonly property string dynamic: {
        if (textBudget < metrics.advanceWidth("…") * (artist && title ? 2 : 1))
            return "";
        return [artist ? artistMeasure.elidedText : "", title ? titleMeasure.elidedText : ""].filter(s => s).join(separator);
    }
    FontMetrics {
        id: metrics
        font.family: Theme.font.text
        font.pixelSize: Theme.font.barText
    }
    TextMetrics {
        id: artistMeasure
        font: metrics.font
        text: root.artist
        elide: Qt.ElideRight
        elideWidth: Math.floor(root.artistBudget)
    }
    TextMetrics {
        id: titleMeasure
        font: metrics.font
        text: root.title
        elide: Qt.ElideRight
        elideWidth: Math.floor(root.textBudget - root.artistBudget)
    }
    RichLabel {
        id: prefix
        visible: false
        segments: root.prefixSegments
    }
    readonly property var prefixSegments: Media.paused ? [
        [root.icon.font, root.icon.glyph + " "], [Theme.font.awesome4, Theme.icon.paused]
    ] : [[root.icon.font, root.icon.glyph]]

    implicitWidth: Math.ceil(label.implicitWidth) + 2 * Theme.bar.modulePadding
    implicitHeight: label.implicitHeight + 2 * Theme.bar.modulePadding

    readonly property var icon: Theme.icon.players[Media.playerName] ?? Theme.icon.players.default

    RichLabel {
        id: label
        anchors.centerIn: parent
        color: Theme.module.media
        // Pango (relevé avec `pango-view --serialize-to`) : l'espace entre deux icônes garde la police de la première
        // (13 px en Font Awesome 7 Brands contre 7 en Inter) ; les espaces suivies de texte sont en Inter.
        segments: [...root.prefixSegments, ...(root.dynamic ? [[Theme.font.text, root.gap + root.dynamic]] : [])]
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
