pragma Singleton

import QtQuick
import Quickshell

// Valeurs constantes des modules à largeur fixe (InfoModule.qml), une seule fois pour toutes les barres, sans créer leur service :
// pourcentages (CPU, GPU) ; heures de 00:00 à 23:59 ; jours de la semaine (locale) × 01 à 31.
Singleton {
    readonly property var percents: Array.from({ length: 100 }, (_, i) => ` ${i}%`)
    readonly property var times: Array.from({ length: 24 * 60 }, (_, i) => ` ${String(Math.floor(i / 60)).padStart(2, "0")}:${String(i % 60).padStart(2, "0")}`)
    readonly property var dates: [].concat(...Array.from({ length: 7 }, (_, d) => Array.from({ length: 31 }, (_, i) => ` ${Qt.locale().dayName(d, Locale.ShortFormat)}-${String(i + 1).padStart(2, "0")}`)))
}
