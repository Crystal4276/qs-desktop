import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.services

// Zone de notification (INVENTORY.md § 1, `tray`) : icônes 32 px espacées de 5 px, padding horizontal 6 px ;
// éléments « passifs » masqués (défaut de Waybar). Ordre : celui d'enregistrement des applications.
// Actions à l'appui, comme Waybar (sni/item.cpp) : gauche → Activate (ou le menu si l'application n'a qu'un menu),
// milieu → SecondaryActivate, droit → menu (TrayMenu.qml) ou ContextMenu de l'application ; molette → Scroll(∓1), verticale
// ou horizontale.
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
                    hoverEnabled: true
                    onPositionChanged: root.keyboardReleased = false
                    onPressed: mouse => {
                        const item = icon.modelData;
                        if ((mouse.button === Qt.LeftButton && item.onlyMenu) || mouse.button === Qt.RightButton) {
                            if (item.hasMenu)
                                menu.openAt(item.menu, icon, mouse.x, mouse.y, Qt.RightButton | (item.onlyMenu ? Qt.LeftButton : 0));
                            else {
                                root.keyboardReleased = true;
                                const p = icon.mapToItem(null, mouse.x, mouse.y);
                                item.display(icon.QsWindow.window, p.x, p.y);
                            }
                        } else if (mouse.button === Qt.LeftButton) {
                            root.keyboardReleased = true;
                            item.activate();
                        } else if (mouse.button === Qt.MiddleButton) {
                            root.keyboardReleased = true;
                            item.secondaryActivate();
                        }
                    }
                }

                WheelSteps {
                    onStep: direction => icon.modelData.scroll(-direction, false)
                }

                WheelSteps {
                    orientation: Qt.Horizontal
                    onStep: direction => icon.modelData.scroll(-direction, true)
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered)
                            root.hoveredIcon = icon;
                        else if (root.hoveredIcon === icon)
                            root.hoveredIcon = null;
                    }
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

    // Clavier des menus : sous Sway, un popup n'a le clavier que si sa barre l'accepte. La barre l'accepte « à la demande »
    // pendant le survol des icônes d'applications (le clic qui ouvre un menu lui donne alors le focus) et tant qu'un menu est
    // demandé ou affiché ; ensuite Sway rend le focus à la fenêtre qui l'avait (comme l'horloge). Un clic qui n'ouvre pas de
    // menu (Activate…) ou la fermeture d'un menu rend le clavier jusqu'au prochain mouvement sur l'icône (sinon la frappe irait
    // à la barre). Limite : un clic droit juste après, sans bouger, ouvre un menu sans clavier.
    property Item hoveredIcon: null
    property bool keyboardReleased: false
    readonly property bool wantsKeyboard: (hoveredIcon !== null && !keyboardReleased) || menu.open
    readonly property bool menuOpen: menu.open
    onMenuOpenChanged: {
        if (!menuOpen)
            keyboardReleased = true;
    }
    readonly property string keyboardScreen: wantsKeyboard ? QsWindow.window?.screen?.name ?? "" : ""
    onKeyboardScreenChanged: BarState.claimKeyboard(root, keyboardScreen)
    Component.onDestruction: BarState.claimKeyboard(root, "")

    // Un seul menu à la fois, ouvert au pointeur, basculé s'il déborde de l'écran.
    TrayMenu {
        id: menu

        // Clic qui ouvre ce menu sur son icône (`buttons`) : la barre le laisse, ce clic le ferme.
        readonly property Item owner: open ? anchor.item : null
        property int ownerButtons: Qt.RightButton

        // Menu affiché sur cette icône : fermé. Demandé mais pas encore affiché (entrées pas encore reçues, ou menu vide) :
        // redemandé.
        function openAt(handle: var, item: Item, x: real, y: real, buttons: int): void {
            if (visible && anchor.item === item) {
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

        // Comme GTK (gtk_menu_popup_at_pointer) : rectangle de 1 px au pointeur, menu sous son coin bas-droit. Un appui au
        // point du clic reste sur l'icône (le menu commencerait sinon sous le pointeur : Qt 6.12 y plante sur un clic droit).
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Bottom | Edges.Right
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
