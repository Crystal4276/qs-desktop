import QtQuick
import qs.config
import qs.services

// Utilisation du GPU (INVENTORY.md § 1, `custom/nvidia`, qui affichait la température ; multi-constructeur, ARCHITECTURE § 11.5) :
// `U+F0379␣␣{usage}%`, comme le CPU (largeur fixe : celle de `100%`) (ta demande du 2026-10-20). Masqué sans utilisation lisible (Intel). Clic : panneau de statistiques système (avec les informations de nvtop).
InfoModule {
    shown: Gpu.available
    color: Theme.module.gpu
    segments: [[Theme.font.inlineIcons, Theme.icon.gpu], [Theme.font.text, `  ${Gpu.usage}%`, "  100%"]]
    onClicked: Monitor.toggle()
}
