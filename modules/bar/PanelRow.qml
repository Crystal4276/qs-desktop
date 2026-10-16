import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config

// Ligne d'un panneau : icône 24 px, texte et texte secondaire, contenu à droite (boutons, état). Survol `surface0`.
// `active` : élément connecté / monté, texte en `green`.
Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property string subtext: ""
    property bool active: false
    property bool clickable: true
    default property alias trailing: trailingRow.data
    signal clicked

    Layout.fillWidth: true
    implicitHeight: Math.max(iconItem.implicitHeight, texts.implicitHeight, trailingRow.implicitHeight) + 2 * Theme.panel.rowPadding
    radius: Theme.panel.rowRadius
    color: clickable && hover.hovered ? Theme.panel.rowHover : "transparent"

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Theme.panel.rowPadding
            rightMargin: Theme.panel.rowPadding
        }
        spacing: Theme.panel.spacing

        IconImage {
            id: iconItem
            visible: root.icon !== ""
            implicitSize: Theme.panel.iconSize
            source: root.icon === "" ? "" : root.icon.startsWith("image:") || root.icon.startsWith("file:") ? root.icon : `image://icon/${root.icon}`
        }

        ColumnLayout {
            id: texts
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.text
                font.family: Theme.font.text
                font.pixelSize: Theme.panel.fontSize
                color: root.active ? Theme.panel.accent : Theme.panel.text
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtext !== ""
                text: root.subtext
                font.family: Theme.font.text
                font.pixelSize: Theme.panel.smallFontSize
                color: Theme.panel.secondaryText
                elide: Text.ElideRight
            }
        }

        RowLayout {
            id: trailingRow
            spacing: Theme.panel.spacing
        }
    }

    HoverHandler {
        id: hover
        enabled: root.clickable
    }

    TapHandler {
        enabled: root.clickable
        onTapped: root.clicked()
    }
}
