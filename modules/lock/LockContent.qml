import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.modules.wallpaper

// Contenu d'un écran verrouillé (design refait, ARCHITECTURE § 7.12) : fond d'écran de l'écran, flouté et assombri ; horloge et
// date ; sur l'écran principal (`primary`), initiale et nom de l'utilisateur, champ du mot de passe (points), message (vérification,
// erreur, majuscules verrouillées), boutons éteindre / redémarrer / veille (`showPower`). L'état vient de LockScreen.qml, ou de
// modules/greeter pour l'écran de connexion : fond exporté par le bureau (`background`), choix de la session (`sessions`).
Item {
    id: root

    required property var output
    property bool primary: false
    property int length: 0           // caractères saisis
    property string message: ""
    property bool error: false
    property bool capsLock: false
    property string user: ""
    property bool showPower: false   // éteindre, redémarrer, veille (PowerRow)
    // Écran de connexion (`exported`) : fond = image exportée par le bureau (`background`, "" : uni), jamais Wallpapers ; noms des
    // sessions et session choisie (vide : pas de choix), liste ouverte.
    property bool exported: false
    property string background: ""
    property var sessions: []
    property int sessionIndex: 0
    property bool sessionsOpen: false
    signal sessionsToggled
    signal sessionChosen(int index)
    signal userClicked

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Sous le flou : ses bords, à moitié transparents, ne laissent pas voir de clair.
    Rectangle {
        anchors.fill: parent
        color: Theme.color.crust
    }

    // Fond flouté (effet de calque sur le rendu du fond d'écran). Écran de connexion : l'image exportée, sans lire Wallpapers.
    Loader {
        anchors.fill: parent
        sourceComponent: !root.exported ? desktop : root.background !== "" ? exportedImage : null
        layer.enabled: sourceComponent !== null
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: Theme.lock.blur
        }
    }

    Component {
        id: desktop

        WallpaperView {
            output: root.output
            shown: Wallpapers.forOutput(root.output, Compositor.outputs)
        }
    }

    Component {
        id: exportedImage

        Image {
            source: root.background
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.lock.dim
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.lock.spacing

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(clock.date, "HH:mm")
            font.family: Theme.font.text
            font.weight: Theme.lock.clockWeight
            font.pixelSize: Theme.lock.clockSize
            color: Theme.lock.clock
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: clock.date.toLocaleDateString(Qt.locale(), "dddd d MMMM")
            font.family: Theme.font.text
            font.pixelSize: Theme.lock.dateSize
            color: Theme.lock.date
        }

        Item {
            visible: root.primary
            Layout.preferredHeight: Theme.lock.gap - 2 * Theme.lock.spacing
        }

        Rectangle {
            visible: root.primary
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Theme.lock.avatarSize
            implicitHeight: Theme.lock.avatarSize
            radius: width / 2
            color: Theme.lock.avatar

            Text {
                anchors.centerIn: parent
                text: root.user.charAt(0).toUpperCase()
                font.family: Theme.font.text
                font.weight: Theme.lock.avatarWeight
                font.pixelSize: Theme.lock.avatarTextSize
                color: Theme.lock.avatarText
            }
        }

        Text {
            visible: root.primary
            Layout.alignment: Qt.AlignHCenter
            text: root.user
            font.family: Theme.font.text
            font.pixelSize: Theme.lock.userSize
            color: Theme.lock.user

            TapHandler {
                onTapped: root.userClicked()
            }
        }

        // Champ du mot de passe : un point par caractère, texte d'invite vide.
        Rectangle {
            visible: root.primary
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Theme.lock.fieldWidth
            implicitHeight: Theme.lock.fieldHeight
            radius: height / 2
            color: Theme.lock.field
            border.width: Theme.panel.border
            border.color: root.error ? Theme.lock.fieldError : root.length > 0 ? Theme.lock.fieldFocus : Theme.lock.fieldBorder

            Text {
                anchors.centerIn: parent
                visible: root.length === 0
                text: "Password"
                font.family: Theme.font.text
                font.pixelSize: Theme.lock.fieldFontSize
                color: Theme.lock.message
            }

            // Plus de points que de place : les derniers restent visibles (la frappe se voit toujours), sans point coupé.
            Item {
                readonly property int fit: Math.floor((parent.width - parent.height + dots.spacing) / (Theme.lock.dotSize + dots.spacing))

                anchors.centerIn: parent
                width: Math.min(dots.implicitWidth, fit * (Theme.lock.dotSize + dots.spacing) - dots.spacing)
                height: Theme.lock.dotSize
                clip: true

                Row {
                    id: dots
                    anchors.right: parent.right
                    spacing: Theme.lock.dotSize

                    Repeater {
                        model: root.length

                        Rectangle {
                            width: Theme.lock.dotSize
                            height: width
                            radius: width / 2
                            color: Theme.lock.dot
                        }
                    }
                }
            }
        }

        Text {
            visible: root.primary
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Theme.lock.messageHeight
            text: root.capsLock && !root.error ? "Caps Lock is on" : root.message
            font.family: Theme.font.text
            font.pixelSize: Theme.lock.messageSize
            color: root.error ? Theme.lock.error : root.capsLock ? Theme.lock.warning : Theme.lock.message
        }

        // Session à ouvrir : pastille au style du champ ; clic : liste juste dessous (par-dessus la rangée), ↑/↓ : voisines.
        Rectangle {
            id: pill

            visible: root.primary && root.sessions.length > 0
            z: 1
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Theme.lock.fieldWidth
            implicitHeight: Theme.lock.sessionHeight
            radius: height / 2
            color: Theme.lock.field
            border.width: Theme.panel.border
            border.color: pillHover.hovered || root.sessionsOpen ? Theme.lock.fieldFocus : Theme.lock.fieldBorder

            Row {
                anchors.centerIn: parent
                spacing: Theme.panel.spacing

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.sessions[root.sessionIndex] ?? ""
                    font.family: Theme.font.text
                    font.pixelSize: Theme.lock.messageSize
                    color: Theme.lock.user
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.icon.expanded
                    font.family: Theme.font.icons
                    font.pixelSize: Theme.lock.messageSize
                    color: Theme.lock.message
                }
            }

            HoverHandler {
                id: pillHover
            }

            TapHandler {
                onTapped: root.sessionsToggled()
            }

            // Liste des sessions : style des panneaux de la barre.
            Rectangle {
                visible: root.sessionsOpen
                anchors.top: parent.bottom
                anchors.topMargin: Theme.panel.gap
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: list.implicitHeight + 2 * Theme.panel.padding
                radius: Theme.panel.radius
                color: Theme.panel.background
                border.width: Theme.panel.border
                border.color: Theme.panel.borderColor

                // La liste couvre la rangée éteindre / redémarrer / veille : ses clics (marges comprises) s'arrêtent à elle.
                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    id: list

                    anchors.fill: parent
                    anchors.margins: Theme.panel.padding

                    Repeater {
                        model: root.sessions

                        Rectangle {
                            required property string modelData
                            required property int index

                            width: list.width
                            height: label.implicitHeight + 2 * Theme.panel.rowPadding
                            radius: Theme.panel.rowRadius
                            color: rowHover.hovered || index === root.sessionIndex ? Theme.panel.rowHover : "transparent"

                            Text {
                                id: label
                                anchors.verticalCenter: parent.verticalCenter
                                x: Theme.panel.rowPadding
                                width: parent.width - 2 * Theme.panel.rowPadding
                                elide: Text.ElideRight
                                text: parent.modelData
                                font.family: Theme.font.text
                                font.pixelSize: Theme.lock.messageSize
                                color: parent.index === root.sessionIndex ? Theme.panel.accent : Theme.panel.text
                            }

                            HoverHandler {
                                id: rowHover
                            }

                            // MouseArea (prise exclusive), pas TapHandler (prise passive : le clic atteindrait aussi le bouton dessous).
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.sessionChosen(parent.index)
                            }
                        }
                    }
                }
            }
        }

        PowerRow {
            visible: root.primary && root.showPower
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
