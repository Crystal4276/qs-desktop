import QtQuick
import QtQuick.Layouts
import qs.config

// Heure HH:MM (horaire du « ne pas déranger », SettingsPanel.qml) : champ de la largeur de « 00:00 » ; montre `value` tant qu'il
// n'a pas le focus. Entrée ou sortie du champ : `edited(heure)`, « 9:5 » donnant 09:05.
PanelField {
    id: root

    property string value
    signal edited(string time)

    Layout.fillWidth: false
    implicitWidth: metrics.advanceWidth + 2 * Theme.panel.rowPadding
    validator: RegularExpressionValidator {
        regularExpression: /^([01]?\d|2[0-3]):[0-5]?\d$/
    }
    onEditingFinished: text => {
        const [h, m] = text.split(":");
        root.edited(`${h.padStart(2, "0")}:${m.padStart(2, "0")}`);
        root.inputItem.focus = false;
    }

    Binding {
        target: root
        property: "text"
        value: root.value
        when: !root.inputItem.activeFocus
        restoreMode: Binding.RestoreNone
    }

    TextMetrics {
        id: metrics
        text: "00:00"
        font.family: Theme.font.text
        font.pixelSize: Theme.panel.fontSize
    }
}
