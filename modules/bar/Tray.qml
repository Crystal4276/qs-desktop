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
    readonly property bool shown: items.length > 0 || Vpn.available || Network.managed || Disks.loaded || Bluez.available

    implicitWidth: row.implicitWidth + 2 * Theme.bar.trayPadding
    implicitHeight: Theme.bar.trayIconSize

    Row {
        id: row
        x: Theme.bar.trayPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.bar.traySpacing

        Repeater {
            model: root.items

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
                                menu.openAt(item.menu, icon, mouse.x, mouse.y);
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

        // Modules natifs, après les applications (remplacent l'icône NordVPN, nm-applet, udiskie, blueman ; phase 5).
        TrayButton {
            visible: Vpn.available
            icon: Vpn.icon
            panel: vpnPanel
        }

        TrayButton {
            visible: Network.managed
            icon: Network.icon
            panel: networkPanel
        }

        TrayButton {
            visible: Disks.loaded
            icon: "drive-removable-media-usb-panel"   // icône d'udiskie, toujours affichée comme lui
            panel: disksPanel
        }

        TrayButton {
            visible: Bluez.available
            icon: Bluez.icon
            panel: bluetoothPanel
        }
    }

    VpnPanel {
        id: vpnPanel
    }

    NetworkPanel {
        id: networkPanel
    }

    DisksPanel {
        id: disksPanel
    }

    BluetoothPanel {
        id: bluetoothPanel
    }

    // Un seul menu à la fois, ouvert au pointeur (coin haut-gauche), basculé s'il déborde de l'écran.
    TrayMenu {
        id: menu

        function openAt(handle: var, item: Item, x: real, y: real): void {
            open = false;
            menu.menu = handle;
            anchor.item = item;
            anchor.rect.x = x;
            anchor.rect.y = y;
            open = true;
        }

        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        onVisibleChanged: visible ? BarState.popupOpened() : BarState.popupClosed()

        Connections {
            target: BarState
            function onClosePopups() {
                menu.open = false;
            }
        }
    }
}
