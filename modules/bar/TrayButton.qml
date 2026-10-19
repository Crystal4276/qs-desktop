import QtQuick
import qs.config

// Bouton d'un module natif du tray (réseau, Wi-Fi, disques, Bluetooth, NordVPN) : même taille que les icônes d'applications ;
// icône du thème (`icon`) ou glyphe dessiné en contenu (Wi-Fi) ; un appui (gauche ou droit) ouvre ou ferme son panneau.
Item {
    id: root

    property string icon: ""
    property Panel panel
    default property alias content: glyph.data

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

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.panel.toggle(root, Qt.LeftButton | Qt.RightButton)
    }
}
