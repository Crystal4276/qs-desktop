import QtQuick
import QtQuick.Layouts

// Pourcentage d'un niveau (0–1) en texte secondaire, aligné à droite et de la largeur de « 100 % » : les pourcentages de
// plusieurs lignes restent alignés (panneau audio, panneau de réglages, OSD). Largeur mesurée sur le rendu natif du texte,
// que TextMetrics ne reproduit pas.
PanelSection {
    property real value: 0

    Layout.fillWidth: false
    Layout.preferredWidth: widest.implicitWidth
    horizontalAlignment: Text.AlignRight
    text: `${Math.round(value * 100)} %`

    PanelSection {
        id: widest
        visible: false
        text: "100 %"
    }
}
