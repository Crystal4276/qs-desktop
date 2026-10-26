import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.config
import qs.services

// Volume d'un nœud (panneau audio) : curseur, pourcentage, bouton muet ; `meter` : niveau capté sous le rail (entrées).
ColumnLayout {
    id: line

    property PwNode node
    property bool meter: false
    property bool monitoring: false   // panneau épinglé : le niveau est capté
    property bool shown: true

    visible: shown && node?.audio !== undefined && node?.audio !== null
    Layout.fillWidth: true
    spacing: Theme.levelMeter.gap

    // Pourcentage et bouton centrés sur le curseur (le niveau est sous la ligne).
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.panel.spacing

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

        PercentLabel {
            value: line.node?.audio?.volume ?? 0
        }

        PanelButton {
            text: line.node?.audio?.muted ? "Unmute" : "Mute"
            onClicked: line.node.audio.muted = !line.node.audio.muted
        }
    }

    // Aligné sur le rail du curseur ; créé seulement pour une entrée qui le permet.
    Loader {
        active: line.meter && Audio.hasLevel(line.node)
        visible: active
        Layout.leftMargin: slider.inset
        Layout.preferredWidth: slider.width - 2 * slider.inset

        sourceComponent: LevelMeter {
            node: line.node
            active: line.monitoring
        }
    }
}
