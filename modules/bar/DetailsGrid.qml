import QtQuick
import QtQuick.Layouts
import qs.config

// Détails d'une carte (Wi-Fi, filaire, Tailscale) : libellés Inter 16 px `subtext0` en première colonne, valeurs `text`.
// `rows` : [[libellé, valeur], …] ; lignes sans valeur omises.
GridLayout {
    id: root

    property var rows: []
    readonly property var shown: rows.filter(r => r[1] !== "" && r[1] !== undefined && r[1] !== null)

    visible: shown.length > 0
    Layout.fillWidth: true
    columns: 2
    columnSpacing: Theme.panel.spacing
    rowSpacing: 0

    Repeater {
        model: root.shown

        Text {
            required property var modelData
            required property int index

            Layout.row: index
            Layout.column: 0
            Layout.alignment: Qt.AlignTop
            text: modelData[0]
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.smallFontSize
            color: Theme.panel.secondaryText
        }
    }

    Repeater {
        model: root.shown

        Text {
            required property var modelData
            required property int index

            Layout.row: index
            Layout.column: 1
            Layout.fillWidth: true
            text: modelData[1]
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.smallFontSize
            color: Theme.panel.text
            wrapMode: Text.Wrap
        }
    }
}
