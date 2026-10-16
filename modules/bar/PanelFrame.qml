import QtQuick
import QtQuick.Layouts
import qs.config

// Cadre des panneaux (THEME.md § 3 « Panneaux ») : fond `mantle`, bordure, titre et interrupteur facultatifs, contenu libre.
// Hauteur : celle du contenu, au plus `maxHeight`. Échap demande la fermeture. Utilisé par Panel.qml (popup sous une icône
// du tray) et SettingsPanel.qml (surface de la couche Overlay, ouvrable au clavier).
Rectangle {
    id: root

    property string title: ""
    property bool hasSwitch: false
    property bool switchChecked: false
    property real maxHeight: Infinity
    signal switchToggled(bool checked)
    signal closeRequested

    default property alias content: body.data

    height: Math.min(column.implicitHeight + 2 * Theme.panel.padding, maxHeight)
    clip: true
    radius: Theme.panel.radius
    color: Theme.panel.background
    border.width: Theme.panel.border
    border.color: Theme.panel.borderColor

    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onEscapePressed: root.closeRequested()
    // Haut / Bas : élément précédent / suivant, comme Tab (touches que les éléments eux-mêmes n'utilisent pas).
    Keys.onUpPressed: (Window.activeFocusItem ?? root).nextItemInFocusChain(false)?.forceActiveFocus()
    Keys.onDownPressed: (Window.activeFocusItem ?? root).nextItemInFocusChain(true)?.forceActiveFocus()

    ColumnLayout {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.panel.padding
        }
        spacing: Theme.panel.spacing

        RowLayout {
            Layout.fillWidth: true
            visible: root.title !== "" || root.hasSwitch   // panneau de réglages : pas de titre

            Text {
                Layout.fillWidth: true
                text: root.title
                font.family: Theme.font.text
                font.pixelSize: Theme.panel.fontSize
                font.bold: true
                color: Theme.panel.title
            }

            PanelSwitch {
                visible: root.hasSwitch
                checked: root.switchChecked
                onToggled: checked => root.switchToggled(checked)
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: Theme.panel.spacing
        }
    }
}
