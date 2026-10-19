import QtQuick
import QtQuick.Layouts
import Quickshell.Networking as NM
import qs.config
import qs.services

// Carte du réseau Wi-Fi courant (THEME.md § 3 « Module Wi-Fi »), en tête du panneau comme le réseau déplié de KDE : glyphe
// coloré selon la qualité, nom, état et qualité en mots (GNOME), jauge du signal, puis détails — bande et canal, débit du lien,
// sécurité, adresse IPv4, trafic (si le Wi-Fi porte la route par défaut). En connexion : glyphe animé et bouton « Cancel ».
Rectangle {
    id: root

    property var network: null   // Quickshell.Networking WifiNetwork

    readonly property bool connected: network?.connected ?? false
    readonly property real strength: network?.signalStrength ?? 0
    readonly property int level: Network.wifiLevel(strength)
    readonly property color qualityColor: Theme.wifi.quality[level]
    readonly property var accessPoint: Network.wifiAccessPoints[network?.name ?? ""] ?? null
    readonly property bool carriesTraffic: Network.interfaceName !== "" && Network.interfaceName === (Network.wifi?.name ?? "")

    // [libellé, valeur] ; lignes sans valeur omises (détails pas encore lus, ou absents).
    readonly property var details: [
        ["Band", accessPoint ? [accessPoint.band, `channel ${accessPoint.channel}`, accessPoint.width].filter(s => s).join(" · ") : ""],
        ["Link speed", Network.wifiBitrate],
        ["Security", Network.securityText(network?.security ?? -1)],
        ["IP address", Network.wifiAddress]
    ].filter(d => d[1] !== "")

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

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.panel.spacing

            WifiIcon {
                size: Theme.wifi.cardIconSize
                level: root.level
                connecting: !root.connected
                limited: root.connected && Network.wifiLimited
                color: root.connected ? root.qualityColor : Theme.panel.secondaryText
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.network?.name ?? ""
                    font.family: Theme.font.text
                    font.pixelSize: Theme.panel.fontSize
                    color: root.connected ? Theme.panel.accent : Theme.panel.text
                    elide: Text.ElideRight
                }

                PanelSection {
                    text: !root.connected ? "Connecting…"
                        : Network.wifiLimited ? (Network.connectivity === NM.NetworkConnectivity.Portal ? "Sign-in required: captive portal" : "Connected without Internet access")
                        : `Connected · ${Network.qualityText(root.strength).toLowerCase()} signal`
                    color: root.connected && Network.wifiLimited ? Theme.panel.warning : Theme.panel.secondaryText
                }
            }

            PanelButton {
                text: root.connected ? "Disconnect" : "Cancel"
                onClicked: root.network.disconnect()
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

        // Détails : libellés `subtext0` en première colonne, valeurs `text`.
        GridLayout {
            visible: root.connected && (root.details.length > 0 || root.carriesTraffic)
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.panel.spacing
            rowSpacing: 0

            Repeater {
                model: root.details

                Text {
                    required property var modelData
                    required property int index

                    Layout.row: index
                    Layout.column: 0
                    text: modelData[0]
                    font.family: Theme.font.text
                    font.pixelSize: Theme.panel.smallFontSize
                    color: Theme.panel.secondaryText
                }
            }

            Repeater {
                model: root.details

                Text {
                    required property var modelData
                    required property int index

                    Layout.row: index
                    Layout.column: 1
                    Layout.fillWidth: true
                    text: modelData[1]
                    font.family: Theme.font.text
                    font.pixelSize: Theme.panel.smallFontSize
                    color: Theme.panel.text
                    elide: Text.ElideRight
                }
            }

            Text {
                visible: root.carriesTraffic
                Layout.row: root.details.length
                Layout.column: 0
                text: "Traffic"
                font.family: Theme.font.text
                font.pixelSize: Theme.panel.smallFontSize
                color: Theme.panel.secondaryText
            }

            RichLabel {
                visible: root.carriesTraffic
                Layout.row: root.details.length
                Layout.column: 1
                Layout.fillWidth: true
                font.pixelSize: Theme.panel.smallFontSize
                color: Theme.panel.text
                segments: [
                    [Theme.font.inlineIcons, Theme.icon.download],
                    [Theme.font.text, ` ${Network.format(Network.downBytesPerSecond).trim()}   `],
                    [Theme.font.inlineIcons, Theme.icon.upload],
                    [Theme.font.text, ` ${Network.format(Network.upBytesPerSecond).trim()}`]
                ]
            }
        }
    }
}
