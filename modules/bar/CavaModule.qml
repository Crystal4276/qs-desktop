import QtQuick
import qs.config
import qs.services

// Visualiseur (INVENTORY.md § 1, `cava`) : 12 barres `▁`…`█`, chacune suivie d'une espace ; affiché pendant une lecture.
// Masqué tant que cava n'a rien envoyé (démarrage, relance, cava absent) : pas de case vide dans la pilule.
// Barres en DejaVu Sans, espaces en Inter (la CSS demande Inter, qui n'a pas ces caractères : THEME.md § 2).
// Padding : 10 px à gauche et à droite, 12 px en haut, 10 px en bas (style.css).
Item {
    id: root

    readonly property bool shown: Cava.active && Cava.bars.length > 0

    implicitWidth: label.implicitWidth + 2 * Theme.bar.modulePadding
    implicitHeight: label.implicitHeight + Theme.bar.cavaPaddingTop + Theme.bar.modulePadding

    Component.onCompleted: Cava.users++
    Component.onDestruction: Cava.users--

    RichLabel {
        id: label
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (Theme.bar.cavaPaddingTop - Theme.bar.modulePadding) / 2
        font.pixelSize: Theme.font.cava
        color: Theme.module.cava
        segments: Array.from(Cava.bars).reduce((list, v) => list.concat([[Theme.font.bars, Theme.icon.cavaBars[Math.min(v, Theme.icon.cavaBars.length - 1)]], [Theme.font.text, " "]]), [])
    }
}
