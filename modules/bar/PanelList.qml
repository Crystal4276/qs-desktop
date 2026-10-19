import QtQuick
import QtQuick.Layouts
import qs.config

// Liste d'un panneau : sa hauteur, au plus `Theme.panel.maxListHeight` ; au-delà elle défile (THEME.md § 3 « Panneaux »).
Flickable {
    default property alias content: column.data
    property real maxHeight: Theme.panel.maxListHeight

    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(column.implicitHeight, maxHeight)
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 0
    }
}
