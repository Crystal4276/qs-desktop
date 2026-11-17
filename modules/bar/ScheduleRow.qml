import QtQuick
import qs.config
import qs.services

// Horaire d'une bascule (services/Schedule.qml : « ne pas déranger », veilleuse ; SettingsPanel.qml) : heures modifiables (Entrée
// ou sortie du champ), interrupteur. `fieldLeft` : Entrée ou Échap dans un champ, le panneau doit reprendre le clavier (Échap,
// flèches).
PanelRow {
    id: row

    required property Schedule schedule
    signal fieldLeft

    clickable: false
    text: "Schedule"

    TimeField {
        value: row.schedule.from
        onEdited: time => row.schedule.set(row.schedule.enabled, time, row.schedule.to)
        onAccepted: row.fieldLeft()
        onCancelled: row.fieldLeft()
    }

    Text {
        text: "–"
        font.family: Theme.font.text
        font.pixelSize: Theme.panel.fontSize
        color: Theme.panel.text
    }

    TimeField {
        value: row.schedule.to
        onEdited: time => row.schedule.set(row.schedule.enabled, row.schedule.from, time)
        onAccepted: row.fieldLeft()
        onCancelled: row.fieldLeft()
    }

    PanelSwitch {
        checked: row.schedule.enabled
        onToggled: checked => row.schedule.set(checked, row.schedule.from, row.schedule.to)
    }
}
