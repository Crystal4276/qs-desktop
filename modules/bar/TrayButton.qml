import QtQuick
import qs.config

// Bouton d'un module natif du tray (réseau, Wi-Fi, disques, Bluetooth, NordVPN) : même taille que les icônes d'applications ;
// icône du thème (`icon`) ou glyphe dessiné en contenu (Wi-Fi). Survol : aperçu du panneau ; un appui (gauche ou droit)
// l'épingle, l'ouvre ou le ferme (Panel.qml). Après une fermeture par appui, pas d'aperçu tant que le pointeur reste sur l'icône.
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

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (!hovered)
                root.previewSuppressed = false;
            else if (!root.previewSuppressed)
                root.panel.preview(root);
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: {
            const panel = root.panel;
            root.previewSuppressed = panel.visible && panel.button === root && !panel.previewing;
            panel.toggle(root, Qt.LeftButton | Qt.RightButton);
        }
    }
}
