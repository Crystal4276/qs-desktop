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

    signal closing   // juste avant la fermeture (lanceur : enregistre la saisie)

    // Ouverture demandée sous `from` : false si le panneau était ouvert (il se ferme, quel que soit son écran) ou si l'appui sur
    // ce même bouton vient de le fermer en passant par la barre (`fromPress` : BarState.pressClosed ; jamais pour un raccourci).
    // Sinon les autres popups se ferment et le panneau peut s'ouvrir.
    function beginOpen(from: Item, fromPress: bool): bool {
        if (visible) {
            close();
            return false;
        }
        if (fromPress && from === button && BarState.pressClosed.includes(root))
            return false;
        prepareOpen(from);
        return true;
    }

    // Avant de s'afficher : les autres popups se ferment (pas celui-ci s'il est déjà ouvert). `from` : bouton d'ancrage, ou null
    // (lanceur, sans bouton).
    function prepareOpen(from: Item): void {
        if (!visible)
            BarState.closePopups();
        if (from)
            button = from;
    }

    function close(): void {
        if (visible)
            closing();
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

    // Écran ou bouton disparu pendant que le panneau est ouvert (écran débranché ou éteint) : il se ferme, au lieu de rester au
    // clavier sur un autre écran.
    // Le panneau ne change d'écran qu'avant de s'afficher : un changement pendant qu'il est ouvert vient de Quickshell (écran
    // retiré, fenêtre déplacée ailleurs) ; c'est le seul cas pour le lanceur, qui n'a pas de bouton.
    onButtonChanged: if (!button && visible) close()
    onScreenChanged: if (visible) close()
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.visible && !Quickshell.screens.includes(root.screen))
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
