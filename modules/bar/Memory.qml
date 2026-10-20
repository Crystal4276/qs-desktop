import QtQuick
import qs.config
import qs.services

// Mémoire (INVENTORY.md § 1, `memory`) : `U+EFC5␣␣{used:.0f}G` (barrette de RAM ; U+F035B, une puce, avant le 2026-10-20),
// aligné à droite sur autant de chiffres que la mémoire totale (largeur fixe, 2026-10-20) (Gio sans décimale, largeur 2). Clic : panneau de statistiques système.
// Pas de tooltip (décision du 2026-10-16, PROGRESS phase 4).
InfoModule {
    color: Theme.module.memory
    segments: [[Theme.font.inlineIcons, Theme.icon.memory], [Theme.font.text, `  ${SystemStats.memUsed.toFixed(0)}G`, `  ${"9".repeat(SystemStats.memTotal.toFixed(0).length)}G`]]
    onClicked: Monitor.toggle()
}
