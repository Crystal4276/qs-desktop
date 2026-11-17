import QtQuick
import Quickshell.Widgets

// Remplissage arrondi, fenêtre de largeur `width` sur un dégradé de toute la largeur `span` (la couleur dépend de la position,
// comme un vu-mètre), fait d'un segment par paire de couleurs voisines. Niveau d'une entrée audio (LevelMeter.qml), température
// de la veilleuse (VolumeSlider.qml).
ClippingRectangle {
    id: root

    required property list<color> colors
    required property real span
    property real cornerRadius: 0

    radius: Math.min(cornerRadius, width / 2)
    color: "transparent"

    Row {
        Repeater {
            model: Math.max(0, root.colors.length - 1)   // pas de couleurs (curseur sans dégradé) : rien

            Rectangle {
                id: segment

                required property int index

                // Arrondi au pixel supérieur : pas de jointure entre segments (le dernier déborde, coupé).
                width: Math.ceil(root.span / (root.colors.length - 1))
                height: root.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: root.colors[segment.index]
                    }
                    GradientStop {
                        position: 1
                        color: root.colors[segment.index + 1]
                    }
                }
            }
        }
    }
}
