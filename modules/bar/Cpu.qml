import QtQuick
import qs.config
import qs.services

// Processeur (INVENTORY.md § 1, `cpu`) : `U+EC19␣␣{usage}%`, aligné à droite sur la largeur de `100%` (largeur fixe, 2026-10-20). Clic : panneau de statistiques système.
InfoModule {
    color: Theme.module.cpu
    segments: [[Theme.font.inlineIcons, Theme.icon.cpu], [Theme.font.text, `  ${SystemStats.cpuUsage}%`, "  100%"]]
    onClicked: Monitor.toggle()
}
