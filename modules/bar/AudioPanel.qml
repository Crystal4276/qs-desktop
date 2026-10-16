import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.services

// Panneau audio (ton choix du 2026-10-16 : remplace pavucontrol au clic droit sur le volume) : interrupteur du son (muet),
// sortie et entrée par défaut avec leur volume, volume par application ; réglages avancés dans pavucontrol.
Panel {
    id: root

    title: "Audio"
    hasSwitch: true
    switchChecked: !Audio.muted
    onSwitchToggled: checked => {
        if (Audio.muted === checked)
            Audio.toggleMute();
    }

    function appName(node: PwNode): string {
        return node.properties["application.name"] || node.description || node.name;
    }

    // Icône de l'application (nom d'icône annoncé, sinon nom du programme), icône audio générique à défaut.
    function appIcon(node: PwNode): string {
        const p = node.properties;
        const name = p["application.icon-name"] || p["application.process.binary"] || (p["application.name"] ?? "").toLowerCase();
        return Quickshell.iconPath(name, "audio-x-generic");
    }

    // --- Sortie ---
    PanelSection {
        text: "Output"
    }

    AudioDevices {}

    VolumeLine {
        node: Audio.sink
    }

    // --- Entrée ---
    PanelSection {
        visible: Audio.sources.length > 0
        text: "Input"
    }

    AudioDevices {
        input: true
    }

    VolumeLine {
        node: Audio.source
    }

    // --- Applications ---
    PanelSection {
        visible: Audio.streams.length > 0
        text: "Applications"
    }

    Repeater {
        model: ScriptModel {
            values: Audio.streams
        }

        ColumnLayout {
            id: stream

            required property PwNode modelData

            Layout.fillWidth: true
            spacing: 0

            PanelRow {
                clickable: false
                icon: root.appIcon(stream.modelData)
                text: root.appName(stream.modelData)
                subtext: stream.modelData.properties["media.name"] !== root.appName(stream.modelData)
                    ? (stream.modelData.properties["media.name"] ?? "") : ""
            }

            VolumeLine {
                node: stream.modelData
            }
        }
    }

    MixerButton {
        onOpened: root.visible = false
    }

    // Volume d'un nœud : curseur, pourcentage, bouton muet.
    component VolumeLine: RowLayout {
        id: line

        property PwNode node

        visible: node?.audio !== undefined && node?.audio !== null
        Layout.fillWidth: true
        Layout.leftMargin: Theme.panel.rowPadding
        Layout.rightMargin: Theme.panel.rowPadding
        spacing: Theme.panel.spacing

        VolumeSlider {
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
}
