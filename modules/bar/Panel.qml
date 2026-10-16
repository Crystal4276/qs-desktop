import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config

// Panneau d'un module natif du tray (THEME.md § 3 « Panneaux ») : cadre du calendrier, titre, interrupteur facultatif,
// contenu libre. Popup avec prise du clavier (saisie possible) : fermé par un clic sur une autre application (wlroots),
// sur une barre (BarState.closePopups) ou par Échap. `toggle(item)` l'ouvre sous l'icône ou le ferme.
// La fenêtre a une taille fixe (toute la hauteur sous la barre) et seul le cadre reçoit les clics (`mask`) : un popup déjà
// affiché ne se redimensionne pas proprement sous Sway (l'ancienne image est étirée), or le contenu change (Wi-Fi coupé…).
PopupWindow {
    id: root

    property string title: ""
    // Interrupteur du titre (Wi-Fi, Bluetooth…) : visible si `hasSwitch`.
    property bool hasSwitch: false
    property bool switchChecked: false
    signal switchToggled(bool checked)

    default property alias content: frame.content

    function toggle(item: Item): void {
        if (visible) {
            visible = false;
            return;
        }
        anchor.item = item;
        // Centré sous l'élément, sans dépasser les marges de la barre (10 px du bord de l'écran).
        const itemX = item.mapToItem(null, 0, 0).x;
        const windowWidth = item.QsWindow.window?.width ?? 0;
        const left = Math.max(Theme.bar.marginSide, Math.min(itemX + (item.width - width) / 2, windowWidth - Theme.bar.marginSide - width));
        anchor.rect.x = left - itemX;
        // 10 px sous la pilule (bas de la zone réservée de la barre), quel que soit l'élément d'origine ;
        // hauteur : tout l'espace jusqu'à 10 px du bas de l'écran.
        anchor.rect.y = Theme.bar.exclusiveZone + Theme.panel.gap - item.mapToItem(null, 0, 0).y;
        implicitHeight = (item.QsWindow.window?.screen?.height ?? 1000) - Theme.bar.exclusiveZone - Theme.panel.gap - Theme.bar.marginSide;
        visible = true;
    }

    grabFocus: true
    color: "transparent"
    implicitWidth: Theme.panel.width
    implicitHeight: 1
    mask: Region {
        item: frame
    }
    anchor.adjustment: PopupAdjustment.Slide

    onVisibleChanged: BarState.setPopupOpen(root, visible)
    Component.onDestruction: BarState.setPopupOpen(root, false)

    Connections {
        target: BarState
        function onClosePopups() {
            root.visible = false;
        }
    }

    PanelFrame {
        id: frame

        width: parent.width
        maxHeight: parent.height
        title: root.title
        hasSwitch: root.hasSwitch
        switchChecked: root.switchChecked
        onSwitchToggled: checked => root.switchToggled(checked)
        onCloseRequested: root.visible = false
    }
}
