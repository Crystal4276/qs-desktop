import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.services

// Zone de notification (INVENTORY.md § 1, `tray`) : icônes 32 px espacées de 5 px, padding horizontal 6 px ;
// éléments « passifs » masqués (défaut de Waybar). Ordre : celui d'enregistrement des applications.
// Applications : gauche ou droit → menu, présenté en carte (AppMenuPanel.qml), ou ContextMenu de l'application ; milieu →
// SecondaryActivate ; molette → Scroll(∓1), verticale ou horizontale (comme Waybar, sni/item.cpp).
Item {
    id: root

    // Applications remplacées par un module natif (identifiant StatusNotifier → module présent) : leur icône est masquée tant
    // que le module natif est là (ta demande du 2026-10-16 : pas de doublon ; ces applications tournent encore jusqu'à la phase 10).
    readonly property var replaced: ({
        "nm-applet": Network.managed,
        "blueman": Bluez.available,
        "udiskie": Disks.loaded,
        "NordVPN": Vpn.available
    })
    readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive && !replaced[i.id])
    readonly property bool shown: true   // la cloche des notifications est toujours là

    implicitWidth: row.implicitWidth + 2 * Theme.bar.trayPadding
    implicitHeight: Theme.bar.trayIconSize

    Row {
        id: row
        x: Theme.bar.trayPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.bar.traySpacing

        Repeater {
            model: ScriptModel {
                values: root.items
            }

            // Carte de l'application (AppMenuPanel.qml), comme les modules natifs : aperçu au survol, épinglée au clic gauche ou
            // droit (Steam, Spotify : leur menu est tout ce qu'elles offrent au clic).
            TrayButton {
                id: appButton

                required property SystemTrayItem modelData

                icon: modelData.icon
                panel: appPanel
                // Pas de menu D-Bus : menu de l'application elle-même (ContextMenu), comme Waybar.
                panelButtons: modelData.hasMenu ? Qt.LeftButton | Qt.RightButton : 0
                onOtherPressed: {
                    const p = appButton.mapToItem(null, appButton.width / 2, appButton.height);
                    modelData.display(appButton.QsWindow.window, p.x, p.y);
                }

                // Milieu (la zone d'aperçu ne prend que gauche et droit) : SecondaryActivate.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.MiddleButton
                    onPressed: appButton.modelData.secondaryActivate()
                }

                WheelSteps {
                    onStep: direction => appButton.modelData.scroll(-direction, false)
                }

                WheelSteps {
                    orientation: Qt.Horizontal
                    onStep: direction => appButton.modelData.scroll(-direction, true)
                }

                AppMenuPanel {
                    id: appPanel
                    item: appButton.modelData
                }
            }
        }

        // Modules natifs, après les applications (remplacent l'icône NordVPN, nm-applet, udiskie, blueman ; phase 5 ; Wi-Fi séparé
        // du réseau le 2026-10-19).
        TrayButton {
            visible: Vpn.available
            icon: Vpn.icon
            panel: vpnPanel
        }

        TrayButton {
            // Réseau : filaire, et Tailscale / ZeroTier (visibles aussi sans câble, icône `network-vpn`).
            readonly property bool privateNetworks: Tailscale.installed || ZeroTier.present
            readonly property bool privateUp: Tailscale.running || ZeroTier.connectedCount > 0
            visible: Network.wiredShown || privateNetworks
            // Sans câble mais avec le Wi-Fi (qui a son icône), ou sans NetworkManager, le bouton sert aux réseaux privés :
            // `network-vpn`, atténuée si aucun n'est actif. Sinon l'état filaire (sans câble ni Wi-Fi : « aucune connexion »,
            // même si Tailscale se dit actif).
            icon: Network.privateEntry ? "network-vpn" : Network.icon
            opacity: Network.privateEntry && !privateUp ? Theme.panel.disabledOpacity : 1
            panel: networkPanel
        }

        // Wi-Fi (ta demande du 2026-10-19) : glyphe dessiné et animé (WifiIcon.qml), niveau du signal à la manière de GNOME.
        TrayButton {
            visible: Network.wifiShown
            panel: wifiPanel

            WifiIcon {
                anchors.fill: parent
                off: !Network.wifiUsable
                connecting: Network.connectedWifi === null && Network.connectingWifi !== null
                level: Network.connectedWifi ? Network.wifiLevel(Network.connectedWifi.signalStrength) : -1
                limited: Network.wifiLimited
            }
        }

        TrayButton {
            id: disksButton

            visible: Disks.drives.length > 0   // seulement avec un disque branché (ta demande du 2026-11-02)
            icon: "drive-removable-media-usb-panel"   // icône d'udiskie
            panel: disksPanel

            Component.onCompleted: BarState.register("disks", disksButton)
            Component.onDestruction: BarState.unregister("disks", disksButton)
        }

        // Action en cours (allumage, connexion…) : alterne entre allumé et connecté à chaque demi-cycle (GNOME, KDE).
        TrayButton {
            id: bluetoothButton

            property bool blink: false

            visible: Bluez.available
            icon: Bluez.trayIcon(blink)
            panel: bluetoothPanel

            Timer {
                running: Bluez.busy
                repeat: true
                interval: Theme.bluetooth.busyDuration / 2
                onTriggered: bluetoothButton.blink = !bluetoothButton.blink
                onRunningChanged: bluetoothButton.blink = false
            }
        }

        // Centre de notifications (Papirus : cloche, point bleu si non vues, barrée en « ne pas déranger »). Clic droit : bascule
        // « ne pas déranger » (ta demande du 2026-10-27).
        TrayButton {
            icon: Notifs.doNotDisturb ? "notification-disabled" : Notifs.unseen ? "notification-active" : "notification-inactive"
            panel: notificationsPanel
            panelButtons: Qt.LeftButton
            onOtherPressed: Notifs.setDoNotDisturb(!Notifs.doNotDisturb)
        }
    }

    VpnPanel {
        id: vpnPanel
    }

    NetworkPanel {
        id: networkPanel
    }

    WifiPanel {
        id: wifiPanel
    }

    DisksPanel {
        id: disksPanel
    }

    // Disque chiffré branché (Disks.pending) : le panneau des disques déjà ouvert l'affiche (épinglé s'il n'était qu'un aperçu) ;
    // sinon celui du tray de l'écran préféré (focalisé, sinon principal) s'ouvre. Jamais par-dessus un autre popup épinglé ni
    // l'outil de capture (saisie en cours qui serait perdue, clavier pris), ni pendant le verrouillage : ouvert à leur fin.
    // Décidé après coup (callLater) : pas pendant la diffusion qui ferme un popup, ni avant qu'un clic en ait ouvert un autre.
    readonly property var openDisksPanel: BarState.openList.find(p => p instanceof DisksPanel) ?? null
    readonly property bool promptHere: Disks.pending.length > 0 && !Screenshot.active && !Session.lockActive
        && (openDisksPanel ? openDisksPanel === disksPanel && disksPanel.previewing
            : !BarState.popupPinned && BarState.preferredButton("disks") === disksButton)
    onPromptHereChanged: if (promptHere) Qt.callLater(root.openPrompt)

    function openPrompt(): void {
        if (promptHere)
            disksPanel.openPrompt(disksButton);
    }

    BluetoothPanel {
        id: bluetoothPanel
    }

    NotificationsPanel {
        id: notificationsPanel
    }
}
