import QtQuick
import QtQuick.Layouts
import qs.config

// Heure HH:MM (horaire du « ne pas déranger », SettingsPanel.qml) : champ de la largeur de « 00:00 » ; montre `value` tant qu'il
// n'a pas le focus. Masque HH:MM (ta demande du 2026-10-26) : deux points fixes, chiffres remplacés en place. Entrée ou sortie du
// champ : `edited(heure)` si l'heure change (Entrée : aussi `accepted`, à qui de rendre le focus au panneau ; la sortie du champ
// qui suit ne la renvoie pas). Échap annule la saisie et émet `cancelled` (rendre le focus au panneau : un second Échap le
// ferme, comme l'effacement d'un champ de recherche).
PanelField {
    id: root

    property string value
    signal edited(string time)
    signal cancelled

    pending: text !== value
    Layout.fillWidth: false
    implicitWidth: metrics.advanceWidth + 2 * Theme.panel.rowPadding
    inputMask: "99:99"
    // Heure impossible (29:99) : refusée, le champ revient à l'heure en vigueur (même lecture que les services : Settings.minutes).
    onEditingFinished: text => {
        if (Settings.minutes(text) < 0)
            root.text = root.value;
        else if (text !== root.value)
            root.edited(text);
    }

    Keys.onEscapePressed: {
        root.text = root.value;
        root.cancelled();
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
