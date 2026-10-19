import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Carte du réseau Wi-Fi courant (THEME.md § 3 « Module Wi-Fi »), en tête du panneau comme le réseau déplié de KDE : glyphe
// coloré selon la qualité, nom, état et qualité en mots (GNOME), jauge du signal, puis détails — bande et canal, débit du lien,
// sécurité, adresse IPv4 ; graphe du trafic si le Wi-Fi porte la route par défaut. En connexion : glyphe animé et bouton « Cancel ».
PanelCard {
    id: root

    property var network: null   // Quickshell.Networking WifiNetwork

    readonly property bool connected: network?.connected ?? false
    readonly property real strength: network?.signalStrength ?? 0
    readonly property int level: Network.wifiLevel(strength)
    readonly property color qualityColor: Theme.wifi.quality[level]
    readonly property var accessPoint: Network.wifiAccessPoints[network?.name ?? ""] ?? null
    readonly property bool carriesTraffic: Network.wifiCarriesRoute

    // [libellé, valeur] ; lignes sans valeur omises (détails pas encore lus, ou absents).
    readonly property var details: [
        ["Band", accessPoint ? [accessPoint.band, `channel ${accessPoint.channel}`, accessPoint.width].filter(s => s).join(" · ") : ""],
        ["Link speed", Network.wifiBitrate],
        ["Security", Network.securityText(network?.security ?? -1)],
        ["IP address", Network.wifiAddress]
    ]

    CardHeader {
        leading: WifiIcon {
            size: Theme.panel.cardIconSize
            level: root.level
            connecting: !root.connected
            limited: root.connected && Network.wifiLimited
            color: root.connected ? root.qualityColor : Theme.panel.secondaryText
        }
        title: root.network?.name ?? ""
        active: root.connected
        status: !root.connected ? "Connecting…"
            : Network.wifiLimited ? Network.limitedText
            : `Connected · ${Network.qualityText(root.strength).toLowerCase()} signal`
        statusColor: root.connected && Network.wifiLimited ? Theme.panel.warning : Theme.panel.secondaryText

        PanelButton {
            text: root.connected ? "Disconnect" : "Cancel"
            onClicked: root.connected ? root.network.disconnect() : Network.cancelWifi()
        }
    }

    // Jauge du signal : creux et hauteur du curseur de volume, remplissage à la couleur de la qualité.
    RowLayout {
        visible: root.connected
        Layout.fillWidth: true
        spacing: Theme.panel.spacing

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.slider.troughHeight
            radius: Theme.slider.troughRadius
            color: Theme.slider.trough

            Rectangle {
                width: Math.max(height, parent.width * root.strength)
                height: parent.height
                radius: parent.radius
                color: root.qualityColor

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.wifi.levelDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Text {
            id: percent
            text: `${Math.round(root.strength * 100)} %`
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.smallFontSize
            font.features: { "tnum": 1 }
            color: Theme.panel.text
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: percentMetrics.advanceWidth

            TextMetrics {
                id: percentMetrics
                font: percent.font
                text: "100 %"
            }
        }
    }

    DetailsGrid {
        visible: root.connected && shown.length > 0
        rows: root.details
    }

    TrafficGraph {
        visible: root.connected && root.carriesTraffic
    }
}
