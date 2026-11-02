import QtQuick
import qs.config
import qs.services

// Utilisation du GPU (INVENTORY.md § 1, `custom/nvidia`, qui affichait la température ; multi-constructeur, ARCHITECTURE § 11.5) :
// `U+F0379␣{usage}%`, comme le CPU (plafonné à 99 % ; largeur fixe : la plus large valeur de 0 à 99 %) (ta demande du 2026-10-20). Masqué sans utilisation lisible (Intel). Clic : panneau de statistiques système (avec les informations de nvtop).
InfoModule {
    shown: Gpu.available
    color: Theme.module.gpu
    pillHighlight: Theme.module.statsHighlight
    segments: [[Theme.font.inlineIcons, Theme.icon.gpu], [Theme.font.text, ` ${Math.min(Gpu.usage, 99)}%`, WidthTexts.percents]]
    onClicked: Monitor.toggle(pillRow)
}
