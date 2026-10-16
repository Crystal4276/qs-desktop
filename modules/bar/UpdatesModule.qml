import QtQuick
import qs.config
import qs.services

// Mises à jour en attente (INVENTORY.md § 1, `custom/updates`) : `U+F01A7␣␣N`, masqué à 0. Clic : mise à jour dans un terminal.
InfoModule {
    shown: Updates.count > 0
    color: Theme.module.updates
    segments: [[Theme.font.inlineIcons, Theme.icon.updates], [Theme.font.text, `  ${Updates.count}`]]
    onClicked: Updates.update()
}
