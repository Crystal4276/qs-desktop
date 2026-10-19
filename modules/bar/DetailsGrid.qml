import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config

// Détails d'une carte (Wi-Fi, filaire, Tailscale) : libellés Inter 16 px `subtext0` en première colonne, valeurs `text`.
// `rows` : [[libellé, valeur], …] ; lignes sans valeur omises.
GridLayout {
    id: root

    property var rows: []
    property bool shownWhen: true   // condition de l'appelant (ex. connecté), en plus des lignes à afficher
    // Objets clés par libellé (ScriptModel) : les lignes sont gardées d'une relecture à l'autre, pas recréées.
    readonly property var shown: rows.filter(r => r[1] !== "" && r[1] !== undefined && r[1] !== null)
        .map((r, i) => ({ label: r[0], value: r[1], row: i }))

    visible: shownWhen && shown.length > 0
    Layout.fillWidth: true
    columns: 2
    columnSpacing: Theme.panel.spacing
    rowSpacing: 0

    Repeater {
        model: ScriptModel {
            values: root.shown
            objectProp: "label"
        }

        Text {
            required property var modelData

            Layout.row: modelData.row
            Layout.column: 0
            Layout.alignment: Qt.AlignTop
            text: modelData.label
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.smallFontSize
            color: Theme.panel.secondaryText
        }
    }

    Repeater {
        model: ScriptModel {
            values: root.shown
            objectProp: "label"
        }

        Text {
            required property var modelData

            Layout.row: modelData.row
            Layout.column: 1
            Layout.fillWidth: true
            text: modelData.value
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.smallFontSize
            color: Theme.panel.text
            wrapMode: Text.Wrap
        }
    }
}
