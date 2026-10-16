import QtQuick
import qs.config
import qs.services

// Processeur (INVENTORY.md § 1, `cpu`) : `U+EC19␣␣{usage:2}%` (largeur 2, alignée à droite). Clic : btop dans un terminal.
InfoModule {
    color: Theme.module.cpu
    segments: [[Theme.font.inlineIcons, Theme.icon.cpu], [Theme.font.text, `  ${String(SystemStats.cpuUsage).padStart(2)}%`]]
    onClicked: SystemStats.openMonitor()
}
