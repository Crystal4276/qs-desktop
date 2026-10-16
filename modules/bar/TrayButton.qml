import QtQuick
import Quickshell.Widgets
import qs.config

// Icône d'un module natif du tray (réseau, disques, Bluetooth, NordVPN) : même taille que les icônes d'applications ;
// un appui (gauche ou droit) ouvre ou ferme son panneau.
IconImage {
    id: root

    property string icon: ""
    property Panel panel

    implicitSize: Theme.bar.trayIconSize
    source: icon === "" ? "" : `image://icon/${icon}`

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.panel.toggle(root)
    }
}
