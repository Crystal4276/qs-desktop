import QtQuick
import qs.config

// Bouton d'un module natif du tray (réseau, Wi-Fi, disques, Bluetooth, NordVPN) : même taille que les icônes d'applications ;
// icône du thème (`icon`) ou glyphe dessiné en contenu (Wi-Fi). Survol : aperçu du panneau, après un court arrêt sur l'icône
// (pas en passant : l'ouverture lance des recherches Bluetooth, Wi-Fi…), tout de suite si un autre aperçu est ouvert ; un appui
// (gauche ou droit) l'épingle, l'ouvre ou le ferme (Panel.qml). Après une fermeture par appui, pas d'aperçu tant que le pointeur
// reste sur l'icône.
Item {
    id: root

    property string icon: ""
    property Panel panel
    default property alias content: glyph.data
    readonly property alias hovered: hover.hovered
    property bool previewSuppressed: false

    implicitWidth: Theme.bar.trayIconSize
    implicitHeight: Theme.bar.trayIconSize

    TrayIcon {
        anchors.fill: parent
        visible: root.icon !== ""
        source: root.icon
    }

    Item {
        id: glyph
        anchors.fill: parent
    }

    readonly property int buttons: Qt.LeftButton | Qt.RightButton

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (!hovered)
                root.previewSuppressed = false;
            else if (!root.previewSuppressed && BarState.openList.some(p => p.previewing))
                root.panel.preview(root, root.buttons);
        }
    }

    Timer {
        interval: Theme.panel.previewDelay
        running: hover.hovered && !root.previewSuppressed && !root.panel.visible
        onTriggered: root.panel.preview(root, root.buttons)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: root.buttons
        onPressed: {
            const panel = root.panel;
            root.previewSuppressed = panel.visible && panel.button === root && !panel.previewing;
            panel.toggle(root, root.buttons);
        }
    }
}
