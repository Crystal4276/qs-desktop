import QtQuick
import QtQuick.Layouts
import qs.config

// Groupe de modules entouré d'une seule bordure arrondie (THEME.md § 3, « Groupes de pilules »).
Rectangle {
    id: root

    // Noms des modules du groupe, tels que dans hosts/*.json
    required property var modules

    default property alias content: row.data

    implicitWidth: row.implicitWidth + 2 * (Theme.bar.modulePadding + border.width)
    implicitHeight: Theme.bar.pillHeight
    radius: Theme.bar.pillRadius
    color: Theme.bar.pillColor
    border.width: Theme.bar.pillBorder
    border.color: Theme.bar.pillBorderColor

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 0
    }
}
