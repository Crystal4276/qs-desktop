import QtQuick
import QtQuick.Layouts
import qs.config

// Onglets d'un panneau (réseau, NordVPN ; THEME.md § 3) : boutons de panneau de même largeur, l'onglet `current` « coché ».
// `model` : [{ key, text }] ; un clic émet `picked(key)`.
RowLayout {
    id: root

    property var model: []
    property string current: ""
    signal picked(string key)

    Layout.fillWidth: true
    spacing: Theme.panel.spacing

    Repeater {
        model: root.model

        PanelButton {
            required property var modelData

            Layout.fillWidth: true
            text: modelData.text
            checked: root.current === modelData.key
            onClicked: root.picked(modelData.key)
        }
    }
}
