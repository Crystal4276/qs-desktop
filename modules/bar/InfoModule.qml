import QtQuick
import qs.config

// Module texte de la barre : icône en Hack Nerd Font collée à du texte Inter (THEME.md § 2), dans une seule ligne.
// Utilisé par les mises à jour, le GPU, le CPU, la mémoire et le réseau.
Item {
    id: root

    property color color: Theme.color.text
    property bool shown: true
    property int horizontalPadding: Theme.bar.modulePadding
    property int minWidth: 0
    // Survol : contrastes inversés, comme le bouton Arch (fond de la couleur du module, texte `mantle`).
    property bool highlightOnHover: false
    readonly property bool highlighted: highlightOnHover && hover.hovered

    // [[police, texte, gabarit?], …] ; gabarit : le texte le plus large que le segment puisse afficher. Le segment prend
    // sa largeur et s'aligne à droite dedans : la pilule ne change pas de taille quand la valeur change (ta demande du 2026-10-20).
    property var segments: []

    signal clicked

    implicitWidth: Math.max(minWidth, row.implicitWidth + 2 * horizontalPadding)
    implicitHeight: reference.implicitHeight + 2 * Theme.bar.modulePadding

    Rectangle {
        anchors.fill: parent
        visible: root.highlighted
        // Le fond suit l'arrondi intérieur de la pilule (module seul dans sa pilule).
        radius: Theme.bar.pillRadius - Theme.bar.pillBorder
        color: root.color
    }

    // Un Text par segment, pour la largeur fixe ; chiffres à chasse fixe (`tnum`), comme le graphe réseau.
    Row {
        id: row
        anchors.centerIn: parent
        height: reference.implicitHeight

        // Hauteur et ligne de base de la ligne entière (texte d'un seul tenant), que suivent les segments.
        RichLabel {
            id: reference
            visible: false
            segments: Array.from(root.segments ?? []).map(([family, content]) => [family, content])
        }

        Repeater {
            // Le nombre de segments, pas le tableau : les Text restent en place quand seules les valeurs changent.
            model: root.segments?.length ?? 0

            Text {
                id: label

                required property int index
                readonly property var segment: root.segments[index] ?? []

                anchors.baseline: reference.baseline
                width: Math.max(implicitWidth, gauge.implicitWidth)
                horizontalAlignment: Text.AlignRight
                font.family: segment[0] ?? Theme.font.text
                font.pixelSize: Theme.font.barText
                font.features: { "tnum": 1 }
                color: root.highlighted ? Theme.module.highlightText : root.color
                text: segment[1] ?? ""

                Text {
                    id: gauge
                    visible: false
                    font: label.font
                    text: label.segment[2] ?? ""
                }
            }
        }
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
