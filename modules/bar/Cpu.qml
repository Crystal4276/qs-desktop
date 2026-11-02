import QtQuick
import qs.config
import qs.services

// Processeur (INVENTORY.md § 1, `cpu`) : `U+EC19␣{usage}%`, plafonné à 99 % et aligné à droite sur la plus large
// valeur de 0 à 99 % (largeur fixe et minimale, ta demande du 2026-10-20). Clic : panneau de statistiques système.
InfoModule {
    color: Theme.module.cpu
    pillHighlight: Theme.module.statsHighlight
    segments: [[Theme.font.inlineIcons, Theme.icon.cpu], [Theme.font.text, ` ${Math.min(SystemStats.cpuUsage, 99)}%`, SystemStats.percentTexts]]
    onClicked: Monitor.toggle(pillRow)
}
