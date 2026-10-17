import QtQuick
import qs.config

// Icône d'un module natif du tray (réseau, disques, Bluetooth, NordVPN) : même taille que les icônes d'applications ;
// un appui (gauche ou droit) ouvre ou ferme son panneau.
TrayIcon {
    id: root

    property string icon: ""
    property Panel panel

    source: icon

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.panel.toggle(root, Qt.LeftButton | Qt.RightButton)
    }
}
