import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.config

// Niveau capté par une entrée audio (ta demande du 2026-10-26) : trait fin de la position de la carte média (4 px, creux
// `crust`), remplissage arrondi en dégradé (`Theme.levelMeter.gradient`, bleu → rouge). Crête de PipeWire en échelle dB sur
// `Theme.levelMeter.range`, comme les vu-mètres : montée immédiate, descente lissée. Capture seulement si `active` (panneau
// épinglé), affiché et entrée non coupée (coupée, elle ne transmet que des zéros, vérifié le 2026-10-26) ; sinon, creux
// atténué : rien n'est mesuré.
Rectangle {
    id: root

    property PwNode node
    property bool active: false

    // `peak` est en échelle cubique, comme les volumes (relevé le 2026-10-26 : 0,24 en silence pour -37 dBFS mesurés avec
    // pw-record ; 0,24³ ≈ 0,014) : amplitude = peak³, soit 60 × log10(peak) dB.
    function levelOf(peak: real): real {
        return peak > 0 ? Math.max(0, Math.min(1, 1 + 60 * Math.log10(peak) / Theme.levelMeter.range)) : 0;
    }

    // Dernier relevé, et niveau affiché (0–1) : il le rejoint aussitôt en montée, en descente exponentielle de constante
    // `smoothing` à chaque image (le relevé peut ne plus changer, en silence numérique).
    property real target: 0
    property real level: 0

    function reset(): void {
        target = 0;
        level = 0;
    }

    onNodeChanged: reset()

    // Le moniteur est actif dès sa création : il ne reçoit le nœud qu'une fois la capture voulue (pas d'ouverture brève du
    // micro à la création, en aperçu).
    readonly property bool capturing: active && visible && node !== null && !(node.audio?.muted ?? false)

    implicitHeight: Theme.levelMeter.height
    radius: height / 2
    color: Theme.levelMeter.trough
    opacity: capturing ? 1 : Theme.panel.disabledOpacity

    PwNodePeakMonitor {
        id: monitor
        node: root.capturing ? root.node : null
        enabled: root.capturing
        onEnabledChanged: root.reset()
        onPeakChanged: {
            root.target = root.levelOf(peak);
            if (root.target > root.level)
                root.level = root.target;
        }
    }

    FrameAnimation {
        running: root.capturing && root.level > root.target
        onTriggered: {
            root.level += (root.target - root.level) * (1 - Math.exp(-frameTime * 1000 / Theme.levelMeter.smoothing));
            if (root.level - root.target < 0.001)
                root.level = root.target;
        }
    }

    // Remplissage : fenêtre arrondie sur un dégradé de toute la largeur (la couleur dépend de la position, comme un vu-mètre),
    // fait d'un segment par paire de couleurs voisines.
    ClippingRectangle {
        visible: root.capturing
        width: root.level * root.width
        height: root.height
        radius: Math.min(root.radius, width / 2)
        color: "transparent"

        Row {
            Repeater {
                model: Theme.levelMeter.gradient.length - 1

                Rectangle {
                    id: segment

                    required property int index

                    // Arrondi au pixel supérieur : pas de jointure entre segments (le dernier déborde, coupé).
                    width: Math.ceil(root.width / (Theme.levelMeter.gradient.length - 1))
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
