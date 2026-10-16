import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services

// Carte média du centre de notifications (ton choix du 2026-10-16, comme GNOME) : lecteur suivi par le module média (Media.qml) —
// pochette (taille des images de notification), titre, artiste, position (curseur du volume, cliquable si le lecteur le permet),
// précédent / lecture / suivant.
RowLayout {
    id: root

    readonly property var player: Media.player
    readonly property real length: player?.lengthSupported ? player.length : 0
    // Fenêtre du panneau affichée (propriété attachée lue sur l'Item lui-même : `root.QsWindow` vaut undefined).
    readonly property bool windowShown: QsWindow.window?.visible ?? false

    visible: player !== null
    Layout.fillWidth: true
    spacing: Theme.panel.spacing

    function time(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    // La position n'est pas signalée en continu (documentation de MprisPlayer) : relue chaque seconde pendant la lecture, et
    // seulement panneau ouvert (dans un panneau fermé, `visible` de la carte reste vrai : c'est la fenêtre qui est cachée).
    Timer {
        running: root.visible && root.windowShown && (root.player?.isPlaying ?? false)
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    ClippingRectangle {
        visible: (root.player?.trackArtUrl ?? "") !== ""
        implicitWidth: Theme.notification.iconSize
        implicitHeight: Theme.notification.iconSize
        radius: Theme.panel.rowRadius
        color: "transparent"

        Image {
            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            sourceSize.width: Theme.notification.iconSize
            sourceSize.height: Theme.notification.iconSize
            fillMode: Image.PreserveAspectCrop
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            Layout.fillWidth: true
            text: root.player?.trackTitle || root.player?.identity || ""
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.fontSize
            color: Theme.panel.text
            elide: Text.ElideRight
        }

        PanelSection {
            visible: text !== ""
            text: root.player?.trackArtist ?? ""
        }

        RowLayout {
            visible: root.length > 0
            Layout.fillWidth: true
            spacing: Theme.panel.spacing

            VolumeSlider {
                Layout.fillWidth: true
                inset: Theme.slider.knobSize / 2
                enabled: root.player?.canSeek ?? false
                value: root.length > 0 ? (root.player?.position ?? 0) / root.length : 0
                onMoved: v => root.player.position = v * root.length
            }

            PanelSection {
                Layout.fillWidth: false
                text: `${root.time(root.player?.position ?? 0)} / ${root.time(root.length)}`
            }
        }

        RowLayout {
            spacing: Theme.panel.spacing

            PanelButton {
                fontFamily: Theme.font.icons
                text: Theme.icon.mediaPrevious
                enabled: root.player?.canGoPrevious ?? false
                onClicked: Media.previous()
            }

            PanelButton {
                fontFamily: Theme.font.icons
                text: root.player?.isPlaying ? Theme.icon.mediaPause : Theme.icon.mediaPlay
                enabled: root.player?.canTogglePlaying ?? false
                onClicked: Media.togglePlaying()
            }

            PanelButton {
                fontFamily: Theme.font.icons
                text: Theme.icon.mediaNext
                enabled: root.player?.canGoNext ?? false
                onClicked: Media.next()
            }
        }
    }
}
