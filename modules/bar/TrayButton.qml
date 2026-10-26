import QtQuick
import qs.config

// Bouton d'un module natif du tray (réseau, Wi-Fi, disques, Bluetooth, NordVPN) : même taille que les icônes d'applications ;
// icône du thème (`icon`) ou glyphe dessiné en contenu (Wi-Fi). Survol : aperçu du panneau après un court arrêt sur l'icône ; un
// appui (gauche ou droit) l'épingle, l'ouvre ou le ferme (PreviewArea.qml, Panel.qml).
Item {
    id: root

    property string icon: ""
    property Panel panel
    default property alias content: glyph.data
    readonly property alias hovered: area.hovered
    readonly property alias buttons: area.buttons

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

    PreviewArea {
        id: area
        button: root
        panel: root.panel
        onPreviewRequested: root.panel.preview(root, root.buttons)
        onToggleRequested: root.panel.toggle(root, root.buttons)
    }
}
