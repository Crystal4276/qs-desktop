import QtQuick
import qs.config
import qs.services

// Débit réseau (Waybar `network`, format de la barre DP-3) : `U+F1625␣<descendant>`, 10 px, `U+F1628␣<montant>`
// (une espace après les icônes, un padding de module avant la 2e au lieu de deux espaces : ta demande du 2026-10-20),
// débits alignés à droite sur la largeur du plus large possible (Network.widestRates ; largeur fixe, 2026-10-20). Padding horizontal 10 px, vertical 0, largeur min. 80 px. Sans route par défaut : masqué.
InfoModule {
    shown: Network.interfaceName !== ""
    color: Theme.module.network
    horizontalPadding: Theme.bar.networkPadding
    minWidth: Theme.bar.networkMinWidth
    segments: [
        [Theme.font.inlineIcons, Theme.icon.download],
        [Theme.font.text, ` ${Network.format(Network.downBytesPerSecond)}`, Network.widestLabels],
        [Theme.font.inlineIcons, Theme.icon.upload, undefined, Theme.bar.modulePadding],
        [Theme.font.text, ` ${Network.format(Network.upBytesPerSecond)}`, Network.widestLabels]
    ]
}
