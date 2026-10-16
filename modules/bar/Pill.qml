import QtQuick
import QtQuick.Layouts
import qs.config

// Groupe de modules entouré d'une seule bordure arrondie (THEME.md § 3, « Groupes de pilules »).
// Pas de padding ici : comme dans Waybar, chaque module porte le sien.
// Sa visibilité est décidée par Bar.qml (masquée quand aucun de ses modules ne veut s'afficher).
Rectangle {
    id: root

    default property alias content: row.data

    implicitWidth: row.implicitWidth + 2 * border.width
    implicitHeight: Theme.bar.pillHeight
    radius: Theme.bar.pillRadius
    color: Theme.bar.pillColor
    border.width: Theme.bar.pillBorder
    border.color: Theme.bar.pillBorderColor

    RowLayout {
        id: row
        x: root.border.width
        y: root.border.width
        height: root.height - 2 * root.border.width
        spacing: 0
    }
}
