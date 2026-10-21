import QtQuick
import QtQuick.Layouts
import qs.config

// Groupe de modules entouré d'une seule bordure arrondie (THEME.md § 3, « Groupes de pilules »).
// Pas de padding ici : comme dans Waybar, chaque module porte le sien.
// Sa visibilité est décidée par Bar.qml (masquée quand aucun de ses modules ne veut s'afficher).
// Survol en bloc (`highlightColor` non nul, choisi par Bar.qml) : fond de cette couleur dans la bordure, comme le bouton Arch.
Rectangle {
    id: root

    default property alias content: row.data
    property var highlightColor: null
    readonly property bool highlighted: highlightColor !== null && hover.hovered

    implicitWidth: row.implicitWidth + 2 * border.width
    implicitHeight: Theme.bar.pillHeight
    radius: Theme.bar.pillRadius
    color: Theme.bar.pillColor
    border.width: Theme.bar.pillBorder
    border.color: Theme.bar.pillBorderColor

    Rectangle {
        x: root.border.width
        y: root.border.width
        width: root.width - 2 * root.border.width
        height: root.height - 2 * root.border.width
        visible: root.highlighted
        radius: root.radius - root.border.width
        color: root.highlightColor ?? root.color
    }

    HoverHandler {
        id: hover
    }

    RowLayout {
        id: row
        x: root.border.width
        y: root.border.width
        height: root.height - 2 * root.border.width
        spacing: 0
    }
}
