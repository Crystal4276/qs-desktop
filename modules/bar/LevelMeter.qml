import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.config

// Niveau capté par une entrée audio (ta demande du 2026-10-26) : trait fin de la position de la carte média (4 px, creux
// `crust`), remplissage `green`. Crête de PipeWire (0–1, avant le volume du nœud) en échelle dB sur `Theme.levelMeter.range`,
// comme les vu-mètres ; entrée coupée : remplissage atténué. Capture seulement si `active` (panneau ouvert).
Rectangle {
    id: root

    property PwNode node
    property bool active: false

    readonly property real level: {
        const peak = monitor.peak;
        return peak > 0 ? Math.max(0, Math.min(1, 1 + 20 * Math.log10(peak) / Theme.levelMeter.range)) : 0;
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

    Rectangle {
        width: root.active ? root.level * root.width : 0
        height: parent.height
        radius: parent.radius
        color: Theme.levelMeter.fill
        opacity: root.node?.audio?.muted ? Theme.panel.disabledOpacity : 1

        Behavior on width {
            NumberAnimation {
                duration: Theme.levelMeter.smoothing
            }
        }
    }
}
