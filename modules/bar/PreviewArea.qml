import QtQuick
import qs.config

// Survol et appui d'un bouton de barre qui ouvre une carte (Panel.qml) : icônes du tray (TrayButton.qml) et engrenage
// (SettingsButton.qml). Couvre le bouton, au-dessus de son contenu. Survol : `previewRequested` après un court arrêt (pas en
// passant : l'ouverture lance des recherches Bluetooth, Wi-Fi…), sauf si la carte est déjà ouverte, si un autre popup est épinglé,
// ou après une fermeture tant que le pointeur reste sur le bouton (Panel.qml). Appui d'un bouton de `panelButtons` (gauche ou
// droit par défaut) : `toggleRequested` ; d'un autre : `otherPressed` (la carte ouverte le reste).
// Bouton survolé signalé à BarState (un aperçu reste ouvert tant que le pointeur est sur l'un d'eux).
Item {
    id: root

    required property Item button
    property var panel: null   // Panel.qml ; null tant qu'elle n'est pas chargée (réglages)
    readonly property alias hovered: hover.hovered
    readonly property int buttons: Qt.LeftButton | Qt.RightButton
    property int panelButtons: buttons
    signal previewRequested
    signal toggleRequested
    signal otherPressed(int button)

    anchors.fill: parent

    HoverHandler {
        id: hover
        onHoveredChanged: BarState.setTrayHover(root.button, hovered)
    }

    // Relancé aussi quand un popup épinglé qui bloquait l'aperçu se ferme, pointeur resté sur le bouton.
    Timer {
        interval: Theme.panel.previewDelay
        running: root.button.visible && hover.hovered && !(root.panel?.previewSuppressed ?? false) && !(root.panel?.visible ?? false)
            && !BarState.popupPinned
        onTriggered: root.previewRequested()
    }

    // Bouton masqué sous le pointeur (câble débranché, Bluetooth retiré…) : ni survol restant, ni aperçu accroché à lui.
    Connections {
        target: root.button
        function onVisibleChanged() {
            if (root.button.visible)
                return;
            BarState.setTrayHover(root.button, false);
            if (root.panel?.previewing && root.panel.button === root.button)
                root.panel.close();
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: root.buttons
        onPressed: mouse => mouse.button & root.panelButtons ? root.toggleRequested() : root.otherPressed(mouse.button)
    }

    Component.onDestruction: BarState.setTrayHover(root.button, false)
}
