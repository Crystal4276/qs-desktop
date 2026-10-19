import QtQuick
import QtQuick.Layouts
import qs.config

// Carte d'un panneau (THEME.md § 3 « Module Wi-Fi » et « Panneau réseau ») : fond `base`, coins 10 px, padding 15 px ; contenu
// en colonne. Cartes Wi-Fi, filaire, Tailscale, ZeroTier.
Rectangle {
    default property alias content: column.data

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + 2 * Theme.panel.padding
    radius: Theme.panel.rowRadius
    color: Theme.wifi.card

    ColumnLayout {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.panel.padding
        }
        spacing: Theme.panel.spacing
    }
}
