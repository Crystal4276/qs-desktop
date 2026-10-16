import QtQuick
import qs.config
import qs.services

// Icône du tray à 32 px, choisie comme GTK (Icons.qml). `source` : nom d'icône ou URL fournie par l'application.
Item {
    id: root

    property string source: ""

    implicitWidth: Theme.bar.trayIconSize
    implicitHeight: Theme.bar.trayIconSize

    Image {
        anchors.fill: parent
        source: root.source === "" ? "" : Icons.trayIcon(root.source)
        sourceSize: Qt.size(Theme.bar.trayIconSize, Theme.bar.trayIconSize)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }
}
