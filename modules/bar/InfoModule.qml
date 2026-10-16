import QtQuick
import qs.config

// Module texte de la barre : icône en Hack Nerd Font collée à du texte Inter (THEME.md § 2), dans une seule ligne.
// Utilisé par les mises à jour, le GPU, le CPU, la mémoire et le réseau.
Item {
    id: root

    property string text: ""
    property color color: Theme.color.text
    property bool shown: true
    property int horizontalPadding: Theme.bar.modulePadding
    property int minWidth: 0
    // Survol : contrastes inversés, comme le bouton Arch (fond de la couleur du module, texte `mantle`).
    property bool highlightOnHover: false
    readonly property bool highlighted: highlightOnHover && hover.hovered

    signal clicked

    implicitWidth: Math.max(minWidth, label.implicitWidth + 2 * horizontalPadding)
    implicitHeight: label.implicitHeight + 2 * Theme.bar.modulePadding

    // `segments` de RichLabel : [[police, texte], …]
    property alias segments: label.segments

    Rectangle {
        anchors.fill: parent
        visible: root.highlighted
        // Le fond suit l'arrondi intérieur de la pilule (module seul dans sa pilule).
        radius: Theme.bar.pillRadius - Theme.bar.pillBorder
        color: root.color
    }

    RichLabel {
        id: label
        anchors.centerIn: parent
        color: root.highlighted ? Theme.module.highlightText : root.color
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
