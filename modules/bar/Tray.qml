import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.services

// Zone de notification (INVENTORY.md § 1, `tray`) : icônes 32 px espacées de 5 px, padding horizontal 6 px ;
// éléments « passifs » masqués (défaut de Waybar). Ordre : celui d'enregistrement des applications.
// Actions à l'appui, comme Waybar (sni/item.cpp) : gauche → Activate (ou le menu si l'application n'a qu'un menu),
// milieu → SecondaryActivate, droit → menu (TrayMenu.qml) ou ContextMenu de l'application ; molette → Scroll(∓1).
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

            TrayIcon {
                id: icon

                required property SystemTrayItem modelData

                source: modelData.icon

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onPressed: mouse => {
                        const item = icon.modelData;
                        if ((mouse.button === Qt.LeftButton && item.onlyMenu) || mouse.button === Qt.RightButton) {
                            if (item.hasMenu)
                                menu.openAt(item.menu, icon, mouse.x, mouse.y, Qt.RightButton | (item.onlyMenu ? Qt.LeftButton : 0));
                            else {
                                const p = icon.mapToItem(null, mouse.x, mouse.y);
                                item.display(icon.QsWindow.window, p.x, p.y);
                            }
                        } else if (mouse.button === Qt.LeftButton) {
                            item.activate();
                        } else if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        }
                    }
                }

                WheelSteps {
                    onStep: direction => icon.modelData.scroll(-direction, false)
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

            visible: Disks.loaded
            icon: "drive-removable-media-usb-panel"   // icône d'udiskie, toujours affichée comme lui
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

    // Disque chiffré branché : phrase de passe demandée par le tray d'un seul écran (focalisé, sinon principal).
    Connections {
        target: Disks

        function onUnlockRequested(volume) {
            if (BarState.preferredButton("disks") === disksButton)
                disksPanel.askPassphrase(disksButton, volume);
        }
    }

    BluetoothPanel {
        id: bluetoothPanel
    }

    NotificationsPanel {
        id: notificationsPanel
    }

    // Un seul menu à la fois, ouvert au pointeur (coin haut-gauche), basculé s'il déborde de l'écran.
    TrayMenu {
        id: menu

        // Clic qui ouvre ce menu sur son icône (`buttons`) : la barre le laisse, ce clic le ferme.
        readonly property Item owner: open ? anchor.item : null
        property int ownerButtons: Qt.RightButton

        function openAt(handle: var, item: Item, x: real, y: real, buttons: int): void {
            if (open && anchor.item === item) {
                open = false;
                return;
            }
            open = false;
            ownerButtons = buttons;
            menu.menu = handle;
            anchor.item = item;
            anchor.rect.x = x;
            anchor.rect.y = y;
            open = true;
        }

        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        onVisibleChanged: BarState.setPopupOpen(menu, visible)
        Component.onDestruction: BarState.setPopupOpen(menu, false)

        Connections {
            target: BarState
            function onClosePopups(keep) {
                if (!keep.includes(menu))
                    menu.open = false;
            }
        }
    }
}
