import QtQuick
import QtQuick.Layouts
import qs.config

// Titre de section d'un panneau : Inter 16 px, `subtext0`.
Text {
    Layout.fillWidth: true
    font.family: Theme.font.text
    font.pixelSize: Theme.panel.smallFontSize
    color: Theme.panel.secondaryText
    elide: Text.ElideRight
}
