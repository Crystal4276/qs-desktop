import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.config

// Volume d'un nœud (panneau audio) : curseur, pourcentage, bouton muet ; `meter` : niveau capté sous le rail (entrées).
RowLayout {
    id: line

    property PwNode node
    property bool meter: false
    property bool monitoring: false   // panneau ouvert : le niveau est capté

    visible: node?.audio !== undefined && node?.audio !== null
    Layout.fillWidth: true
    spacing: Theme.panel.spacing

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.levelMeter.gap

        VolumeSlider {
            id: slider
            Layout.fillWidth: true
            inset: Theme.slider.knobSize / 2
            value: line.node?.audio?.volume ?? 0
            onMoved: v => {
                if (line.node?.audio)
                    line.node.audio.volume = v;
            }
        }

        // Aligné sur le rail du curseur.
        LevelMeter {
            visible: line.meter
            Layout.leftMargin: slider.inset
            Layout.rightMargin: slider.inset
            node: line.node
            active: line.meter && line.monitoring
        }
    }

    PercentLabel {
        value: line.node?.audio?.volume ?? 0
    }

    PanelButton {
        text: line.node?.audio?.muted ? "Unmute" : "Mute"
        onClicked: line.node.audio.muted = !line.node.audio.muted
    }
}
