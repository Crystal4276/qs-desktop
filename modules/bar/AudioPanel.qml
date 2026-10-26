import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.services

// Panneau audio (ton choix du 2026-10-16 : remplace pavucontrol au clic droit sur le volume) : interrupteur du son (muet),
// sortie et entrée par défaut en carte avec leur volume, niveau capté par chaque entrée (2026-10-26), volume par application ;
// réglages avancés dans pavucontrol.
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

    AudioDevices {
        withVolume: true
    }

    // --- Entrée ---
    PanelSection {
        visible: Audio.sources.length > 0
        text: "Input"
    }

    AudioDevices {
        input: true
        withVolume: true
        monitoring: root.visible
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
                Layout.leftMargin: Theme.panel.rowPadding
                Layout.rightMargin: Theme.panel.rowPadding
                node: stream.modelData
            }
        }
    }

    MixerButton {
        onOpened: root.close()
    }
}
