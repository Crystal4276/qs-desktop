import QtQuick
import Quickshell
import Quickshell.Wayland

// Base des panneaux ouverts par un bouton ou un raccourci (réglages, menu d'applications, lanceur) : surface Overlay sur la zone
// utile de l'écran (sous les barres : `exclusiveZone` 0), clavier exclusif. Fermée par un appui à côté du cadre, sur une barre
// ou sur un autre écran ; un seul popup ouvert à la fois.
PanelWindow {
    id: root

    property Item frameItem    // cadre visible du panneau
    property Item button       // bouton sous lequel il est (ou a été) ouvert
    readonly property Item owner: visible ? button : null   // appui sur ce bouton : la barre laisse le bouton le fermer
    property int ownerButtons: Qt.LeftButton                 // boutons de souris que gère ce bouton
    property bool catchOutside: true                         // appui sur un autre écran : fermeture (OutsideClick)

    signal closing   // juste avant la fermeture (lanceur : enregistre la saisie)

    // Ouvert : se ferme (false). Sinon prépare l'ouverture sous `from` (true).
    function beginOpen(from: Item): bool {
        if (visible) {
            close();
            return false;
        }
        prepareOpen(from);
        return true;
    }

    // Les autres popups se ferment ; `from` : bouton d'ancrage, ou null (lanceur).
    function prepareOpen(from: Item): void {
        if (!visible)
            BarState.closePopups([]);
        if (from)
            button = from;
    }

    // Élément qui reçoit le focus à l'ouverture par openUnder (champ de recherche NordVPN) ; le cadre par défaut.
    property Item initialFocus: frameItem

    // Ouverture sur l'écran de `item` (un bouton de barre), cadre centré sous lui sans dépasser les marges de la barre
    // (10 px du bord) ; focus donné après l'affichage (la surface peut être recréée pour un autre écran).
    function openUnder(item: Item): void {
        const window = item.QsWindow.window;
        screen = window.screen;
        const x = item.mapToItem(null, 0, 0).x;
        frameItem.x = BarState.panelLeft(x + (item.width - frameItem.width) / 2, frameItem.width, window.width);
        visible = true;
        initialFocus?.forceActiveFocus();
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
        function onClosePopups(keep) {
            if (!keep.includes(root))
                root.close();
        }
    }

    // Écran retiré ou bouton détruit pendant l'ouverture : fermé (l'écran ne change sinon qu'avant l'affichage).
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
        active: root.visible && root.catchOutside
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
