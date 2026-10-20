import QtQuick
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.modules.bar

// Une notification, géométrie de Dunst 1.13 (draw.c) : cadre de 1 px compris, largeur 600 + 3 × cadre comme Dunst ;
// icône à gauche (100 px), texte centré verticalement, barre de progression centrée sous le texte. Ajout (ton choix du
// 2026-10-16) : boutons des actions nommées sous le texte. Souris (ton choix du 2026-10-20, comme GNOME et KDE ; dunstrc avait
// gauche et milieu inversés) : gauche ouvre (action par défaut ou lien, puis fenêtre de l'application affichée) et ferme,
// milieu ferme, droit ferme tout.
Item {
    id: card

    required property QtObject modelData
    readonly property QtObject entry: modelData

    readonly property var t: Theme.notification
    readonly property color frameColor: entry.urgency === NotificationUrgency.Critical ? t.frameCritical : t.frame
    readonly property int innerWidth: t.width + t.border
    readonly property bool hasIcon: entry.icon !== "" && icon.status !== Image.Error
    readonly property int textX: t.paddingH + (hasIcon ? t.iconSize + t.textPadding : 0)
    readonly property int textWidth: innerWidth - t.paddingH - textX
    readonly property bool hasProgress: entry.progress >= 0
    readonly property var buttons: entry.actions.filter(a => !Notifs.hiddenActions.includes(a.identifier))
    readonly property int progressPart: hasProgress ? t.progressHeight + t.paddingV : 0
    readonly property int buttonsPart: buttons.length > 0 ? buttonRow.implicitHeight + t.paddingV : 0
    readonly property int textHeight: Math.min(label.implicitHeight, Math.max(0, t.maxHeight - progressPart - 2 * t.paddingV))
    readonly property int mainHeight: Math.min(t.maxHeight, 2 * t.paddingV + Math.max(textHeight, hasIcon ? t.iconSize : 0) + progressPart)
    readonly property int textY: Math.floor((mainHeight - progressPart) / 2) - Math.floor(textHeight / 2)

    implicitWidth: innerWidth + 2 * t.border
    implicitHeight: mainHeight + buttonsPart + 2 * t.border

    Rectangle {
        anchors.fill: parent
        radius: card.t.radius
        color: card.t.background
        border.width: card.t.border
        border.color: card.frameColor
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Notifs.open(card.entry);
            else if (mouse.button === Qt.MiddleButton)
                Notifs.close(card.entry);
            else
                Notifs.closeAll();
        }
    }

    // Contenu, dans le cadre.
    Item {
        x: card.t.border
        y: card.t.border
        width: card.innerWidth
        height: card.mainHeight + card.buttonsPart

        Image {
            id: icon
            visible: card.hasIcon
            x: card.t.paddingH
            y: card.textY + Math.floor(card.textHeight / 2) - Math.floor(card.t.iconSize / 2)
            width: card.t.iconSize
            height: card.t.iconSize
            sourceSize.width: card.t.iconSize
            sourceSize.height: card.t.iconSize
            fillMode: Image.PreserveAspectFit
            // Image illisible (fichier effacé, nom absent du thème) : icône de l'application, comme dans l'historique.
            property bool failed: false
            source: failed && card.entry.fallbackIcon !== "" ? card.entry.fallbackIcon : card.entry.icon
            onStatusChanged: {
                if (status === Image.Error && !failed)
                    failed = true;
            }
            Connections {
                target: card.entry
                function onIconChanged() { icon.failed = false; }
            }
        }

        Text {
            id: label
            x: card.textX
            y: card.textY
            width: card.textWidth
            height: card.textHeight
            text: card.entry.text
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            color: card.t.foreground
            font.family: Theme.font.notification
            font.pointSize: Theme.font.notificationPt
        }

        // Barre de progression (draw.c) : cadre de 4 px, centrée, 300 px au plus.
        Rectangle {
            id: progress
            visible: card.hasProgress
            readonly property int frameWidth: Math.min(card.innerWidth - 2 * card.t.paddingH, card.t.progressMaxWidth)
            x: Math.floor(card.innerWidth / 2) - Math.floor(frameWidth / 2) + 1
            y: card.mainHeight - card.progressPart - card.t.progressFrame / 2
            width: frameWidth - 2
            height: card.t.progressHeight
            color: card.t.background
            border.width: card.t.progressFrame
            border.color: card.frameColor

            Rectangle {
                x: card.t.progressFrame
                y: card.t.progressFrame
                width: (progress.width - 2 * card.t.progressFrame) * Math.min(card.entry.progress, 100) / 100
                height: progress.height - 2 * card.t.progressFrame
                color: card.t.progressFill
            }
        }

        // Boutons des actions nommées, sauf celles de Notifs.hiddenActions (« default » : clic gauche sur la notification).
        Flow {
            id: buttonRow
            visible: card.buttons.length > 0
            x: card.textX
            y: card.mainHeight
            width: card.textWidth
            spacing: Theme.panel.spacing

            Repeater {
                model: card.buttons

                PanelButton {
                    required property NotificationAction modelData
                    text: modelData.text
                    onClicked: Notifs.invoke(modelData)
                }
            }
        }
    }
}
