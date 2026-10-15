pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Écrans actifs, écran principal et ordre des écrans (docs/ARCHITECTURE.md § 3.3).
// La répartition des espaces de travail s'ajoutera ici en phase 3.
Singleton {
    id: root

    // Principal : celui de la config machine s'il est actif, sinon le plus grand en surface logique (égalité : le plus à gauche).
    readonly property var primary: {
        const outs = Compositor.outputs;
        const configured = outs.find(o => o.description === Settings.primaryOutput);
        if (configured)
            return configured;
        return outs.reduce((best, o) => {
            if (!best)
                return o;
            const area = o.width * o.height, bestArea = best.width * best.height;
            return area > bestArea || (area === bestArea && o.x < best.x) ? o : best;
        }, null);
    }

    // Principal d'abord, puis les autres de gauche à droite (x, puis y).
    readonly property var ordered: {
        const p = primary;
        const others = Compositor.outputs.filter(o => o.name !== p?.name).sort((a, b) => a.x - b.x || a.y - b.y);
        return p ? [p, ...others] : others;
    }

    function isPrimary(name: string): bool {
        return primary?.name === name;
    }
}
