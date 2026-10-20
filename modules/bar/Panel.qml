import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Panneau d'un module natif du tray (THEME.md § 3 « Panneaux ») : cadre du calendrier, titre, interrupteur facultatif,
// contenu libre. `toggle(item, boutons)` l'ouvre sous l'icône ou le ferme.
// Surface Overlay à clavier exclusif, comme le panneau de réglages (OverlayPopup.qml) : sous Sway, un popup `grabFocus`
// ouvert depuis une barre ne reçoit jamais le clavier (ni saisie ni Échap ; vu le 2026-10-20, Sway 1.12). Fermé par un
// appui à côté du cadre, sur une barre ou sur un autre écran, ou par Échap.
OverlayPopup {
    id: root

    property string title: ""
    // Interrupteur du titre (Wi-Fi, Bluetooth…) : visible si `hasSwitch`.
    property bool hasSwitch: false
    property bool switchChecked: false
    property bool switchLocked: false   // action en cours : atténué, ignoré
    signal switchToggled(bool checked)

    default property alias content: frame.content

    // `buttons` : boutons de souris avec lesquels l'élément ouvre et ferme ce panneau (un appui de ces boutons sur lui ne le
    // fait pas fermer par la barre : c'est l'élément qui le ferme).
    function toggle(item: Item, buttons: int): void {
        if (!beginOpen(item))
            return;
        ownerButtons = buttons;
        openUnder(item);
    }

    WlrLayershell.namespace: "quickshell-panel"
    frameItem: frame

    PanelFrame {
        id: frame

        // 10 px sous la pilule ; hauteur : au plus jusqu'à 10 px du bas de l'écran.
        y: Theme.panel.gap
        width: Theme.panel.width
        maxHeight: parent.height - Theme.panel.gap - Theme.bar.marginSide
        title: root.title
        hasSwitch: root.hasSwitch
        switchChecked: root.switchChecked
        switchLocked: root.switchLocked
        onSwitchToggled: checked => root.switchToggled(checked)
        onCloseRequested: root.close()
    }
}
