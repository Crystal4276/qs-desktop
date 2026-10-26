import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.config

// Niveau capté par une entrée audio (ta demande du 2026-10-26) : trait fin de la position de la carte média (4 px, creux
// `crust`), remplissage en dégradé (bleu → rouge). Crête de PipeWire (avant le volume du nœud) en échelle dB sur `Theme.levelMeter.range`,
// comme les vu-mètres ; entrée coupée : remplissage atténué. Capture seulement si `active` (panneau ouvert).
Rectangle {
    id: root

    property PwNode node
    property bool active: false

    // `peak` est en échelle cubique, comme les volumes (relevé le 2026-10-26 : 0,24 en silence pour -37 dBFS mesurés avec
    // pw-record ; 0,24³ ≈ 0,014) : amplitude = peak³, soit 60 × log10(peak) dB.
    readonly property real level: {
        const peak = monitor.peak;
        return peak > 0 ? Math.max(0, Math.min(1, 1 + 60 * Math.log10(peak) / Theme.levelMeter.range)) : 0;
    }

    Layout.fillWidth: true
    implicitHeight: Theme.levelMeter.height
    radius: height / 2
    color: Theme.levelMeter.trough

    PwNodePeakMonitor {
        id: monitor
        node: root.node
        enabled: root.active && root.node !== null
    }

    // Remplissage : fenêtre sur un dégradé de toute la largeur (la couleur dépend de la position, comme un vu-mètre).
    Item {
        width: root.active ? root.level * root.width : 0
        height: parent.height
        clip: true
        opacity: root.node?.audio?.muted ? Theme.panel.disabledOpacity : 1

        Behavior on width {
            NumberAnimation {
                duration: Theme.levelMeter.smoothing
            }
        }

        Rectangle {
            width: root.width
            height: parent.height
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.levelMeter.gradient[0] }
                GradientStop { position: 0.25; color: Theme.levelMeter.gradient[1] }
                GradientStop { position: 0.5; color: Theme.levelMeter.gradient[2] }
                GradientStop { position: 0.75; color: Theme.levelMeter.gradient[3] }
                GradientStop { position: 1; color: Theme.levelMeter.gradient[4] }
            }
        }
    }
}
