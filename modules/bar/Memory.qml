import QtQuick
import qs.config
import qs.services

// Mémoire (INVENTORY.md § 1, `memory`) : `U+F035B␣␣{used:2.0f}G` (Gio sans décimale, largeur 2). Clic : panneau de statistiques système.
// Pas de tooltip (décision du 2026-10-16, PROGRESS phase 4).
InfoModule {
    color: Theme.module.memory
    segments: [[Theme.font.inlineIcons, Theme.icon.memory], [Theme.font.text, `  ${SystemStats.memUsed.toFixed(0).padStart(2)}G`]]
    onClicked: Monitor.toggle()
}
