pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Écrans actifs, écran principal, ordre des écrans et blocs d'espaces de travail (docs/ARCHITECTURE.md § 3.2, § 3.3).
// Les blocs sont calculés ici ; leur application au compositeur s'ajoutera en phase 3.
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

    readonly property int workspaceCount: 9

    // Bloc d'espaces de chaque écran : { "<nom de sortie>": [1, 2, 3], … }.
    // Répartition imposée par la config machine si elle couvre exactement les écrans actifs (par description),
    // sinon règle générale : blocs de floor(9 / n), le reste (+1) aux premiers écrans de `ordered`.
    readonly property var blocks: {
        const outs = ordered;
        const result = {};
        const descriptions = outs.map(o => o.description).sort().join("\n");
        const imposed = Settings.workspaceLayouts.find(l => Object.keys(l).sort().join("\n") === descriptions);
        if (imposed) {
            for (const o of outs)
                result[o.name] = imposed[o.description];
            return result;
        }
        const n = outs.length;
        let next = 1;
        outs.forEach((o, i) => {
            const size = Math.floor(workspaceCount / n) + (i < workspaceCount % n ? 1 : 0);
            result[o.name] = Array.from({ length: size }, (_, k) => next + k);
            next += size;
        });
        return result;
    }

    function blockFor(name: string): var {
        return blocks[name] ?? [];
    }

    function isPrimary(name: string): bool {
        return primary?.name === name;
    }
}
