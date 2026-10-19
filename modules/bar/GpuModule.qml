import QtQuick
import qs.config
import qs.services

// Température du GPU (INVENTORY.md § 1, `custom/nvidia` ; multi-constructeur, ARCHITECTURE § 11.5) : `U+F0379␣␣N°C`.
// Masqué sans température lisible. Clic : panneau de statistiques système (avec les informations de nvtop).
InfoModule {
    shown: Gpu.available
    color: Theme.module.gpu
    segments: [[Theme.font.inlineIcons, Theme.icon.gpu], [Theme.font.text, `  ${Gpu.temperature}°C`]]
    onClicked: Monitor.toggle()
}
