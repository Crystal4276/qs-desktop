import QtQuick
import qs.config
import qs.services

// Débit réseau (INVENTORY.md § 1, `network`, format de la barre DP-3) : `U+F1625␣␣<descendant>␣␣U+F1628␣␣<montant>`,
// débits alignés à droite sur 9 caractères. Padding horizontal 10 px, vertical 0, largeur min. 80 px. Sans route par défaut : masqué.
InfoModule {
    shown: Network.interfaceName !== ""
    color: Theme.module.network
    horizontalPadding: Theme.bar.networkPadding
    minWidth: Theme.bar.networkMinWidth
    segments: [
        [Theme.font.inlineIcons, Theme.icon.download],
        [Theme.font.text, `  ${Network.format(Network.downBytesPerSecond)}  `],
        [Theme.font.inlineIcons, Theme.icon.upload],
        [Theme.font.text, `  ${Network.format(Network.upBytesPerSecond)}`]
    ]
}
