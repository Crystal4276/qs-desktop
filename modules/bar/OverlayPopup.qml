import QtQuick
import Quickshell
import Quickshell.Wayland

// Base des panneaux ouverts par un bouton de barre ou un raccourci (panneau de réglages, menu d'applications, lanceur) : surface de la couche
// Overlay sur tout l'écran, ouvrable au clavier (un popup ne peut pas prendre le clavier sans clic), clavier réservé.
// Fermeture : un appui hors de `frameItem`, sur une barre (BarState.closePopups) ou sur un autre écran (OutsideClick).
// À l'ouverture (`beginOpen`), les autres popups se ferment : jamais deux surfaces au clavier exclusif l'une sur l'autre.
PanelWindow {
    id: root

    property Item frameItem    // cadre visible du panneau
    property Item button       // bouton sous lequel il est (ou a été) ouvert
    property real closedAt: 0

    signal closing   // juste avant la fermeture (lanceur : enregistre la saisie)

    // Ouverture demandée sous `from` : false si le panneau était ouvert (il se ferme, quel que soit son écran) ou si c'est l'appui
    // sur ce même bouton qui vient de le fermer (la barre ferme les popups avant que le bouton ne reçoive l'appui : `fromPress`,
    // jamais pour un raccourci). Sinon les autres popups se ferment et le panneau peut s'ouvrir.
    function beginOpen(from: Item, fromPress: bool): bool {
        if (visible) {
            close();
            return false;
        }
        if (fromPress && from === button && Date.now() - closedAt < 400)   // ms
            return false;
        BarState.closePopups();
        button = from;
        return true;
    }

    function close(): void {
        if (visible) {
            closedAt = Date.now();
            closing();
        }
        visible = false;
    }

    function run(action: var): void {
        close();
        action();
    }

    visible: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    color: "transparent"

    Connections {
        target: root
        function onVisibleChanged() {
            BarState.setPopupOpen(root, root.visible);
        }
    }
    Component.onDestruction: BarState.setPopupOpen(root, false)

    Connections {
        target: BarState
        function onClosePopups() {
            root.close();
        }
    }

    OutsideClick {
        active: root.visible
        screen: root.screen
        onPressed: root.close()
    }

    // Appui à côté du cadre : fermeture.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            if (!root.frameItem || !root.frameItem.contains(mapToItem(root.frameItem, mouse.x, mouse.y)))
                root.close();
        }
    }
}
