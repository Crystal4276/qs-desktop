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

    signal clicked

    implicitWidth: Math.max(minWidth, label.implicitWidth + 2 * horizontalPadding)
    implicitHeight: label.implicitHeight + 2 * Theme.bar.modulePadding

    // `segments` de RichLabel : [[police, texte], …]
    property alias segments: label.segments

    RichLabel {
        id: label
        anchors.centerIn: parent
        color: root.color
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
