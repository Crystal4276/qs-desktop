import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.services

// Sorties (ou entrées, `input`) audio, comme le panneau Wi-Fi (ta demande du 2026-10-26) : celle par défaut en carte, en tête
// (icône 48 px, nom `green`, curseur de volume si `withVolume`), les autres en lignes dessous ; un clic en fait la sortie
// (l'entrée) par défaut. Entrées : niveau capté par chacune (sauf Bluetooth, Audio.hasLevel), sous le curseur ou sous le nom,
// pendant `monitoring`.
// Panneau audio et panneau de réglages (sans curseur : il est au-dessus).
ColumnLayout {
    id: root

    property bool input: false
    property bool withVolume: false
    property bool monitoring: false

    readonly property PwNode current: input ? Audio.source : Audio.sink
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
            shown: root.withVolume
            node: root.current
            meter: root.input
            monitoring: root.monitoring
        }
    }

    Repeater {
        model: ScriptModel {
            values: (root.input ? Audio.sources : Audio.sinks).filter(n => n.id !== root.current?.id)
        }

        PanelRow {
            id: row

            required property PwNode modelData

            icon: root.icon
            text: Audio.nodeName(modelData)
            belowShown: root.input && Audio.hasLevel(modelData)
            below: Loader {
                Layout.fillWidth: true
                active: row.belowShown

                sourceComponent: LevelMeter {
                    node: row.modelData
                    active: root.monitoring
                }
            }
            onClicked: root.input ? Audio.setDefaultSource(modelData) : Audio.setDefaultSink(modelData)
        }
    }
}
