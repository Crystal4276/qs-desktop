import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Base des panneaux ouverts par un bouton ou un raccourci (réglages, menu d'applications, lanceur) : surface Overlay sur la zone
// utile de l'écran (sous les barres : `exclusiveZone` 0), clavier exclusif. Fermée par un appui à côté du cadre, sur une barre
// ou sur un autre écran ; un seul popup ouvert à la fois. Jamais pendant le verrouillage (Session.lockActive) : il prendrait le
// clavier de l'écran de verrouillage.
PanelWindow {
    id: root

    property Item frameItem    // cadre visible du panneau
    property Item button       // bouton sous lequel il est (ou a été) ouvert
    readonly property Item owner: visible ? button : null   // appui sur ce bouton : la barre laisse le bouton le fermer
    property int ownerButtons: Qt.LeftButton                 // boutons de souris que gère ce bouton
    property bool catchOutside: true                         // appui sur un autre écran : fermeture (OutsideClick)

    // Juste avant la fermeture (lanceur : enregistre la saisie) ; juste après si le compositeur a fermé la surface (écran retiré).
    signal closing

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
            BarState.closePopups([], false);
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

    property bool hiding: false   // masquée par close() (sinon : par le compositeur)

    function close(): void {
        if (visible)
            emitClosing(closingLost);
        hiding = true;
        visible = false;
        hiding = false;
    }

    // Vrai pendant la fermeture due à la perte de l'écran ou du bouton, ou au verrouillage (lu dans `closing` : rien n'a été
    // abandonné par toi).
    property bool closingLost: false

    function closeLost(): void {
        closingLost = true;
        close();
        closingLost = false;
    }

    function emitClosing(lost: bool): void {
        const was = closingLost;
        closingLost = lost;
        closing();
        closingLost = was;
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
            // Ouvert pendant le verrouillage (raccourci, script, demande arrivée juste avant) : refermé aussitôt, comme perdu.
            if (root.visible && Session.lockActive) {
                root.closeLost();
                return;
            }
            BarState.setPopupOpen(root, root.visible);
            // Surface fermée par le compositeur (écran retiré) : Quickshell la masque sans passer par close().
            if (!root.visible && !root.hiding)
                root.emitClosing(true);
        }
    }
    Component.onDestruction: BarState.setPopupOpen(root, false)

    Connections {
        target: BarState
        function onClosePopups(keep, lost) {
            if (keep.includes(root))
                return;
            if (lost)
                root.closeLost();
            else
                root.close();
        }
    }

    // Écran retiré ou bouton détruit pendant l'ouverture : fermé (l'écran ne change sinon qu'avant l'affichage).
    onButtonChanged: if (!button && visible) closeLost()
    onScreenChanged: if (visible) closeLost()
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.visible && !Quickshell.screens.includes(root.screen))
                root.closeLost();
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
