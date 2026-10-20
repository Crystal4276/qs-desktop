import QtQuick
import QtQuick.Layouts
import qs.config

// Cadre des panneaux (THEME.md § 3 « Panneaux ») : fond `mantle`, bordure, titre et interrupteur facultatifs, contenu libre.
// Hauteur : celle du contenu, au plus `maxHeight`. Échap demande la fermeture. Utilisé par Panel.qml (panneaux sous une icône
// du tray) et SettingsPanel.qml, deux surfaces de la couche Overlay à clavier exclusif (OverlayPopup.qml).
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

    // Élément choisi au clavier (Tab, flèches) hors de la partie visible : chaque liste qui le contient (de la plus proche au
    // cadre) défile pour le montrer.
    readonly property Item focusedItem: Window.activeFocusItem
    onFocusedItemChanged: {
        let inside = false;
        for (let a = focusedItem; a; a = a.parent)
            inside = inside || a === column;
        if (!inside)
            return;
        for (let a = focusedItem.parent; a; a = a.parent) {
            // Flickable, ListView… (repérés par leurs propriétés).
            if (a.contentY !== undefined && a.contentItem !== undefined && a.contentHeight > a.height) {
                const margin = a === scroller ? Theme.panel.padding : 0;
                const top = focusedItem.mapToItem(a.contentItem, 0, 0).y;
                const bottom = top + focusedItem.height;
                // Coordonnées du contenu et contentY partent de originY (ListView : estimée, pas toujours 0).
                const first = a.originY, last = a.originY + a.contentHeight - a.height;
                if (top - margin < a.contentY)
                    a.contentY = Math.max(first, top - margin);
                else if (bottom + margin > a.contentY + a.height)
                    a.contentY = Math.min(last, bottom + margin - a.height);
            }
            if (a === scroller)
                break;
        }
    }

    // Contenu plus haut que l'écran (onglet Tailscale sur un laptop 1080p…) : le cadre défile ; sinon il ne bouge pas.
    Flickable {
        id: scroller
        anchors.fill: parent
        contentHeight: column.implicitHeight + 2 * Theme.panel.padding
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column
            x: Theme.panel.padding
            y: Theme.panel.padding
            width: scroller.width - 2 * Theme.panel.padding
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
}
