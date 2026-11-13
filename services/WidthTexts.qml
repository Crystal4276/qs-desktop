pragma Singleton

import QtQuick
import Quickshell

// Valeurs constantes des modules à largeur fixe (InfoModule.qml), une seule fois pour toutes les barres, sans créer leur service :
// pourcentages (CPU, GPU) ; heures de 00:00 à 23:59.
Singleton {
    id: root

    // Largeur du plus large texte d'une liste dans une police, mesurée une seule fois pour toutes les barres et rangée sur la liste
    // elle-même (pas de WeakMap : plantage de Qt).
    function widest(values: var, font: font): real {
        if (!values?.length)
            return 0;
        const style = [font.family, font.pixelSize, font.pointSize, font.weight, font.italic, font.letterSpacing, font.wordSpacing,
            font.capitalization].join("/");
        const widths = values.__widths ?? (values.__widths = {});
        if (widths[style] === undefined) {
            metrics.font = font;
            widths[style] = values.reduce((widest, s) => Math.max(widest, metrics.advanceWidth(s)), 0);
        }
        return widths[style];
    }

    FontMetrics {
        id: metrics
    }

    readonly property var percents: Array.from({ length: 100 }, (_, i) => ` ${i}%`)
    readonly property var times: Array.from({ length: 24 * 60 }, (_, i) => ` ${String(Math.floor(i / 60)).padStart(2, "0")}:${String(i % 60).padStart(2, "0")}`)
}
