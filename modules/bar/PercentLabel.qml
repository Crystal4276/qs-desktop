import QtQuick
import QtQuick.Layouts

// Pourcentage d'un niveau (0–1) en texte secondaire, aligné à droite et de la largeur de « 100 % » : les pourcentages de
// plusieurs lignes restent alignés (panneau audio, panneau de réglages, OSD). Largeur mesurée sur le rendu natif du texte,
// que TextMetrics ne reproduit pas. Chiffres tabulaires : même largeur pour tous (la température « 2050 K » dépassait « 4700 K »),
// et une valeur qui change ne bouge pas.
PanelSection {
    id: root

    property real value: 0
    property string alsoFits: ""   // autre texte à faire tenir (températures, panneau de réglages)

    Layout.fillWidth: false
    Layout.preferredWidth: Math.max(widest.implicitWidth, other.implicitWidth)
    horizontalAlignment: Text.AlignRight
    font.features: ({ "tnum": 1 })
    text: `${Math.round(value * 100)} %`

    PanelSection {
        id: widest
        visible: false
        font.features: root.font.features
        text: "100 %"
    }

    PanelSection {
        id: other
        visible: false
        font.features: root.font.features
        text: root.alsoFits
    }
}
