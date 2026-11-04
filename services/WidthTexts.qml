pragma Singleton

import QtQuick
import Quickshell

// Valeurs constantes des modules à largeur fixe (InfoModule.qml), une seule fois pour toutes les barres, sans créer leur service :
// pourcentages (CPU, GPU) ; heures de 00:00 à 23:59 ; jours de la semaine (locale) × 01 à 31.
Singleton {
    id: root

    // Largeur du plus large texte d'une liste dans une police, mesurée une seule fois pour toutes les barres (les heures : 1 440
    // textes, par horloge et deux fois chacune avant, ~25 ms au démarrage). Clé : la police (attributs qui changent la largeur) et la liste résumée (longueur, premier
    // et dernier texte), qui distingue toutes les listes des modules. Pas de WeakMap par liste : le moteur JavaScript de Qt 6
    // plantait dessus (`sameValueZero`, test-outputs.sh du 2026-11-04).
    readonly property var widths: ({})

    function widest(values: var, font: font): real {
        if (!values?.length)
            return 0;
        const style = [font.family, font.pixelSize, font.pointSize, font.weight, font.italic, font.letterSpacing, font.wordSpacing, font.capitalization].join("/");
        const key = `${style}|${values.length}|${values[0]}|${values[values.length - 1]}`;
        if (widths[key] === undefined) {
            metrics.font = font;
            widths[key] = values.reduce((widest, s) => Math.max(widest, metrics.advanceWidth(s)), 0);
        }
        return widths[key];
    }

    FontMetrics {
        id: metrics
    }

    readonly property var percents: Array.from({ length: 100 }, (_, i) => ` ${i}%`)
    readonly property var times: Array.from({ length: 24 * 60 }, (_, i) => ` ${String(Math.floor(i / 60)).padStart(2, "0")}:${String(i % 60).padStart(2, "0")}`)
    readonly property var dates: [].concat(...Array.from({ length: 7 }, (_, d) => Array.from({ length: 31 }, (_, i) => ` ${Qt.locale().dayName(d, Locale.ShortFormat)}-${String(i + 1).padStart(2, "0")}`)))
}
