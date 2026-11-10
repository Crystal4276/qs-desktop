import QtQuick
import qs.config
import qs.services

// Lecture en cours (Waybar `mpris`) : `{player_icon} {status_icon} {dynamic}`, identique en lecture, pause et arrêt ;
// icône d'état seulement en pause ; sans place pour le texte, icône du lecteur seule. Lecteur absent → masqué.
// Clic gauche : lecture / pause ; milieu : précédent ; droit : suivant ; molette : lecteur suivant / précédent (Media.qml).
Item {
    id: root

    readonly property bool shown: Media.player !== null

    // Place au-delà de `minimumWidth` avant la pilule voisine (Bar.musicExtra), écart `spacing` déjà réservé.
    // Sans place pour le texte : icône du lecteur seule (ni icône de pause, ni texte).
    property real extraWidth: 0
    readonly property real minimumWidth: playerIcon.implicitWidth + 2 * Theme.bar.modulePadding
    readonly property real pausedWidth: Media.paused ? prefix.implicitWidth - playerIcon.implicitWidth : 0
    readonly property string artist: (Media.player?.trackArtist ?? "").trim()
    readonly property string title: (Media.player?.trackTitle ?? "").trim()
    readonly property string separator: artist && title ? " - " : ""
    readonly property string gap: Media.paused ? " " : "  "
    // Texte « artiste - titre » plafonné à mediaTextMaxWidth, même s'il reste de la place.
    readonly property real textBudget: Math.max(0, Math.min(extraWidth - pausedWidth - metrics.advanceWidth(gap), Theme.bar.mediaTextMaxWidth)
        - metrics.advanceWidth(separator))
    readonly property real artistWidth: metrics.advanceWidth(artist)
    readonly property real titleWidth: metrics.advanceWidth(title)
    readonly property real artistBudget: Math.min(artistWidth, Math.max(textBudget / 2, textBudget - titleWidth))
    // Abrégé seulement s'il dépasse son budget (largeurs fractionnaires : elideWidth arrondi couperait un texte qui tient).
    readonly property string dynamic: {
        if (textBudget < metrics.advanceWidth("…") * (artist && title ? 2 : 1))
            return "";
        const shownArtist = artistWidth <= artistBudget ? artist : artistMeasure.elidedText;
        // Artiste réduit à « … » : retiré, le titre prend toute la place (séparateur compris).
        if (title && shownArtist === "…")
            return titleWidth <= textBudget + metrics.advanceWidth(separator) ? title : titleAlone.elidedText;
        const shownTitle = titleWidth <= textBudget - artistBudget ? title : titleMeasure.elidedText;
        return [artist ? shownArtist : "", title ? shownTitle : ""].filter(s => s).join(separator);
    }
    readonly property real textWidth: metrics.advanceWidth(dynamic)
    // Place laissée en plus de `spacing` ; trop peu (écart < mediaSnapGap) : la pilule se cale sur l'écart normal.
    readonly property bool snapped: extraWidth - (dynamic ? pausedWidth + metrics.advanceWidth(gap + dynamic) : 0)
        + Theme.bar.spacing < Theme.bar.mediaSnapGap
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
    TextMetrics {
        id: titleAlone
        font: metrics.font
        text: root.title
        elide: Qt.ElideRight
        elideWidth: Math.floor(root.textBudget + metrics.advanceWidth(root.separator))
    }
    RichLabel {
        id: playerIcon
        visible: false
        segments: root.iconSegments
    }
    RichLabel {
        id: prefix
        visible: false
        segments: root.prefixSegments
    }
    readonly property var iconSegments: [[root.icon.font, root.icon.glyph]]
    readonly property var prefixSegments: Media.paused ? [
        [root.icon.font, root.icon.glyph + " "], [Theme.font.awesome4, Theme.icon.paused]
    ] : iconSegments
    readonly property var segments: dynamic ? [...prefixSegments, [Theme.font.text, gap + dynamic]] : iconSegments

    implicitWidth: snapped ? Math.floor(minimumWidth + extraWidth) : Math.ceil(label.implicitWidth) + 2 * Theme.bar.modulePadding
    implicitHeight: label.implicitHeight + 2 * Theme.bar.modulePadding

    readonly property var icon: Theme.icon.players[Media.playerName] ?? Theme.icon.players.default

    RichLabel {
        id: label
        anchors.centerIn: parent
        color: Theme.module.media
        // Pango (relevé avec `pango-view --serialize-to`) : l'espace entre deux icônes garde la police de la première
        // (13 px en Font Awesome 7 Brands contre 7 en Inter) ; les espaces suivies de texte sont en Inter.
        segments: root.segments
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
