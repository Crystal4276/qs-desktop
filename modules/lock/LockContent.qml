import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.modules.wallpaper

// Contenu d'un écran verrouillé (design refait, ARCHITECTURE § 10.1 R2) : fond d'écran de l'écran, flouté et assombri ; horloge et
// date ; sur l'écran principal (`primary`), initiale et nom de l'utilisateur, champ du mot de passe (points), message (vérification,
// erreur, majuscules verrouillées). L'état vient de LockScreen.qml.
Item {
    id: root

    required property var output
    property bool primary: false
    property int length: 0           // caractères saisis
    property string message: ""
    property bool error: false
    property bool capsLock: false
    property string user: ""

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Sous le flou : ses bords, à moitié transparents, ne laissent pas voir de clair.
    Rectangle {
        anchors.fill: parent
        color: Theme.color.crust
    }

    // Fond flouté (effet de calque sur le rendu du fond d'écran).
    WallpaperView {
        anchors.fill: parent
        output: root.output
        shown: Wallpapers.forOutput(root.output, Compositor.outputs)
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: Theme.lock.blur
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
    }
}
