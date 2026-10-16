import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.services

// Sorties (ou entrées, `input`) audio : une ligne par périphérique, celui par défaut en `green` ; un clic le choisit.
// Panneau audio et panneau de réglages.
ColumnLayout {
    id: root

    property bool input: false

    Layout.fillWidth: true
    spacing: Theme.panel.spacing

    Repeater {
        model: ScriptModel {
            values: root.input ? Audio.sources : Audio.sinks
        }

        PanelRow {
            required property PwNode modelData

            icon: root.input ? "audio-input-microphone" : "audio-speakers"
            text: Audio.nodeName(modelData)
            active: modelData.id === (root.input ? Audio.source : Audio.sink)?.id
            onClicked: root.input ? Audio.setDefaultSource(modelData) : Audio.setDefaultSink(modelData)
        }
    }
}
