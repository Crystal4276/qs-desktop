import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services

// Carte média du centre de notifications (ton choix du 2026-10-16, comme GNOME ; refaite compacte le 2026-10-20, ta demande) :
// lecteur suivi par le module média (Media.qml), une bande sur fond de carte. Pochette 76 px ; à côté, en haut, titre (gras) et
// « artiste · album », précédent / lecture / suivant à droite (lecture en rond plein) ; en bas, temps écoulé, position en trait
// fin (bouton au survol, cliquable si le lecteur le permet), durée.
Rectangle {
    id: root

    readonly property var player: Media.player
    readonly property real length: Media.length
    // Fenêtre du panneau affichée (propriété attachée lue sur l'Item lui-même : `root.QsWindow` vaut undefined).
    readonly property bool windowShown: QsWindow.window?.visible ?? false

    visible: player !== null
    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + 2 * Theme.mediaCard.padding
    radius: Theme.panel.rowRadius
    color: Theme.panel.card

    // m:ss, ou h:mm:ss au-delà d'une heure.
    function time(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, ss = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${ss}` : `${m}:${ss}`;
    }

    // La position n'est pas signalée en continu (documentation de MprisPlayer) : relue chaque seconde pendant la lecture, et
    // seulement panneau ouvert (dans un panneau fermé, `visible` de la carte reste vrai : c'est la fenêtre qui est cachée).
    Timer {
        running: root.visible && root.windowShown && (root.player?.isPlaying ?? false)
        interval: 1000
        repeat: true
        triggeredOnStart: true   // panneau rouvert : position à jour tout de suite
        onTriggered: Media.refreshPosition()
    }

    RowLayout {
        id: row
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.mediaCard.padding
        }
        spacing: Theme.mediaCard.padding

        ClippingRectangle {
            visible: (root.player?.trackArtUrl ?? "") !== ""
            implicitWidth: Theme.mediaCard.artSize
            implicitHeight: Theme.mediaCard.artSize
            radius: Theme.mediaCard.artRadius
            color: "transparent"

            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                sourceSize.width: Theme.notification.iconSize   // assez net même agrandie
                sourceSize.height: Theme.notification.iconSize
                fillMode: Image.PreserveAspectCrop
            }
        }

        ColumnLayout {
            id: info
            Layout.fillWidth: true
            Layout.fillHeight: true   // hauteur de la pochette : titre en haut, position en bas
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.mediaCard.padding

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: root.player?.trackTitle || root.player?.identity || ""
                        font.family: Theme.font.text
                        font.pixelSize: Theme.panel.fontSize
                        font.bold: true
                        color: Theme.panel.text
                        elide: Text.ElideRight
                    }

                    PanelSection {
                        visible: text !== ""
                        text: [root.player?.trackArtist ?? "", root.player?.trackAlbum ?? ""].filter(s => s !== "").join(" · ")
                    }
                }

                RowLayout {
                    spacing: 0

                    GlyphButton {
                        glyph: Theme.icon.mediaPrevious
                        enabled: root.player?.canGoPrevious ?? false
                        onClicked: Media.previous()
                    }

                    GlyphButton {
                        glyph: root.player?.isPlaying ? Theme.icon.mediaPause : Theme.icon.mediaPlay
                        filled: true
                        enabled: root.player?.canTogglePlaying ?? false
                        onClicked: Media.togglePlaying()
                    }

                    GlyphButton {
                        glyph: Theme.icon.mediaNext
                        enabled: root.player?.canGoNext ?? false
                        onClicked: Media.next()
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            // Position (chiffres à chasse fixe : le texte ne bouge pas).
            RowLayout {
                visible: root.length > 0
                Layout.fillWidth: true
                spacing: Theme.mediaCard.padding

                PanelSection {
                    Layout.fillWidth: false
                    text: root.time(progress.value * root.length)
                    font.features: { "tnum": 1 }
                }

                Item {
                    id: progress

                    // Pendant un glisser, la position suit la souris ; elle n'est envoyée au lecteur qu'au relâchement (une seule
                    // commande D-Bus, pas une par mouvement).
                    property real dragValue: -1
                    readonly property real playerValue: root.length > 0 ? Math.max(0, Math.min(1, (root.player?.position ?? 0) / root.length)) : 0
                    readonly property real value: dragValue >= 0 ? dragValue : playerValue
                    readonly property bool seekable: root.player?.canSeek ?? false

                    function valueAt(x: real): real {
                        return Math.max(0, Math.min(1, x / width));
                    }

                    Layout.fillWidth: true
                    implicitHeight: Theme.mediaCard.knobSize

                    // Clavier : Gauche / Droite ±5 s ; bouton affiché quand la position est choisie.
                    activeFocusOnTab: seekable
                    Keys.onLeftPressed: Media.step(-5)
                    Keys.onRightPressed: Media.step(5)


                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: Theme.mediaCard.progressHeight
                        radius: height / 2
                        color: Theme.mediaCard.trough

                        Rectangle {
                            width: progress.value * parent.width
                            height: parent.height
                            radius: height / 2
                            color: Theme.mediaCard.fill
                        }
                    }

                    Rectangle {
                        visible: progress.seekable && (seekArea.containsMouse || seekArea.pressed || progress.activeFocus)
                        x: progress.value * progress.width - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.mediaCard.knobSize
                        height: Theme.mediaCard.knobSize
                        radius: width / 2
                        color: Theme.mediaCard.fill
                    }

                    MouseArea {
                        id: seekArea
                        anchors.fill: parent
                        enabled: progress.seekable
                        hoverEnabled: true
                        onPressed: mouse => progress.dragValue = progress.valueAt(mouse.x)
                        onPositionChanged: mouse => {
                            if (pressed)
                                progress.dragValue = progress.valueAt(mouse.x);
                        }
                        onReleased: mouse => {
                            Media.seek(progress.valueAt(mouse.x));
                            progress.dragValue = -1;
                        }
                        onCanceled: progress.dragValue = -1
                    }
                }

                PanelSection {
                    Layout.fillWidth: false
                    text: root.time(root.length)
                    font.features: { "tnum": 1 }
                }
            }
        }
    }
}
