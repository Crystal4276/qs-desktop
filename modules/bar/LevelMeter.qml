import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.config

// Niveau capté par une entrée audio (ta demande du 2026-10-26) : trait fin de la position de la carte média (4 px, creux
// `crust`), remplissage arrondi en dégradé (`Theme.levelMeter.gradient`, bleu → rouge). Crête de PipeWire (avant le volume du
// nœud) en échelle dB sur `Theme.levelMeter.range`, comme les vu-mètres : montée immédiate, descente lissée ; entrée coupée :
// remplissage atténué. Capture seulement si `active` (panneau épinglé) et affiché.
Rectangle {
    id: root

    property PwNode node
    property bool active: false

    // `peak` est en échelle cubique, comme les volumes (relevé le 2026-10-26 : 0,24 en silence pour -37 dBFS mesurés avec
    // pw-record ; 0,24³ ≈ 0,014) : amplitude = peak³, soit 60 × log10(peak) dB.
    function levelOf(peak: real): real {
        return peak > 0 ? Math.max(0, Math.min(1, 1 + 60 * Math.log10(peak) / Theme.levelMeter.range)) : 0;
    }

    // Niveau affiché (0–1), recalculé à chaque relevé (environ 45 par seconde) ; descente exponentielle de constante
    // `smoothing`, selon le temps écoulé depuis le relevé précédent.
    property real level: 0
    property real lastUpdate: 0

    Layout.fillWidth: true
    implicitHeight: Theme.levelMeter.height
    radius: height / 2
    color: Theme.levelMeter.trough

    PwNodePeakMonitor {
        id: monitor
        node: root.node
        enabled: root.active && root.visible && root.node !== null
        onEnabledChanged: {
            root.level = 0;
            root.lastUpdate = 0;
        }
        onPeakChanged: {
            const now = Date.now();
            const target = root.levelOf(peak);
            const decay = root.lastUpdate > 0 ? 1 - Math.exp(-(now - root.lastUpdate) / Theme.levelMeter.smoothing) : 1;
            root.level = target >= root.level ? target : root.level + (target - root.level) * decay;
            root.lastUpdate = now;
        }
    }

    // Remplissage : fenêtre arrondie sur un dégradé de toute la largeur (la couleur dépend de la position, comme un vu-mètre),
    // fait d'un segment par paire de couleurs voisines.
    ClippingRectangle {
        visible: monitor.enabled
        width: root.level * root.width
        height: root.height
        radius: root.radius
        color: "transparent"
        opacity: root.node?.audio?.muted ? Theme.panel.disabledOpacity : 1

        Row {
            Repeater {
                model: Theme.levelMeter.gradient.length - 1

                Rectangle {
                    id: segment

                    required property int index

                    width: root.width / (Theme.levelMeter.gradient.length - 1)
                    height: root.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: Theme.levelMeter.gradient[segment.index]
                        }
                        GradientStop {
                            position: 1
                            color: Theme.levelMeter.gradient[segment.index + 1]
                        }
                    }
                }
            }
        }
    }
}
