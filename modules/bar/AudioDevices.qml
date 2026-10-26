import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.services

// Sorties (ou entrées, `input`) audio, comme le panneau Wi-Fi (ta demande du 2026-10-26) : celle par défaut en carte, en tête
// (icône 48 px, nom `green`, curseur de volume si `withVolume`), les autres en lignes dessous ; un clic en fait la sortie
// (l'entrée) par défaut. Entrées : niveau capté par chacune, sous le curseur ou sous le nom, pendant `monitoring`.
// Panneau audio et panneau de réglages (sans curseur : il est au-dessus).
ColumnLayout {
    id: root

    property bool input: false
    property bool withVolume: false
    property bool monitoring: false

    readonly property var devices: input ? Audio.sources : Audio.sinks
    readonly property PwNode current: devices.find(n => n.id === (input ? Audio.source : Audio.sink)?.id) ?? null
    readonly property string icon: input ? "audio-input-microphone" : "audio-speakers"

    Layout.fillWidth: true
    spacing: Theme.panel.spacing

    PanelCard {
        visible: root.current !== null

        CardHeader {
            icon: root.icon
            title: root.current ? Audio.nodeName(root.current) : ""
            active: true
            status: root.input ? "Default input" : "Default output"
        }

        VolumeLine {
            visible: root.withVolume && node?.audio !== undefined && node?.audio !== null
            node: root.current
            meter: root.input
            monitoring: root.monitoring
        }

        // Sans curseur, le niveau d'une entrée reste affiché.
        LevelMeter {
            visible: root.input && !root.withVolume
            node: root.current
            active: visible && root.monitoring
        }
    }

    Repeater {
        model: ScriptModel {
            values: root.devices.filter(n => n.id !== root.current?.id)
        }

        PanelRow {
            id: row

            required property PwNode modelData

            icon: root.icon
            text: Audio.nodeName(modelData)
            below: LevelMeter {
                visible: root.input
                node: row.modelData
                active: root.input && root.monitoring
            }
            onClicked: root.input ? Audio.setDefaultSource(modelData) : Audio.setDefaultSink(modelData)
        }
    }
}
