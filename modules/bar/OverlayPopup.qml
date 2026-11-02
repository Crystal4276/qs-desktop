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
    property bool outsideReady: false                        // popup affiché : surfaces d'OutsideClick à créer

    // Juste avant la fermeture (lanceur : enregistre la saisie) ; juste après si le compositeur a fermé la surface (écran retiré).
    signal closing

    // Ouvert : se ferme (false). Sinon prépare l'ouverture sous `from` (true). Pendant le verrouillage : rien (false).
    function beginOpen(from: Item): bool {
        if (visible) {
            close();
            return false;
        }
        if (Session.lockActive)
            return false;
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
        screen = item.QsWindow.window.screen;
        placeUnder(item);
        visible = true;
        initialFocus?.forceActiveFocus();
    }

    // Cadre centré sous `item` (aussi quand sa largeur change, ouvert : carte d'une application du tray).
    function placeUnder(item: Item): void {
        const window = item.QsWindow.window;
        const x = item.mapToItem(null, 0, 0).x;
        frameItem.x = BarState.panelLeft(x + (item.width - frameItem.width) / 2, frameItem.width, window.width);
    }

    // Vrai pendant `closing` quand la fermeture ne vient pas de toi (rien n'a été abandonné) : écran ou bouton disparu,
    // verrouillage, surface fermée par le compositeur.
    property bool closingLost: false
    property bool hiding: false   // masquée par close() (sinon : par le compositeur)

    // `lost` : voir closingLost.
    function close(lost): void {
        if (visible)
            emitClosing(!!lost);
        hiding = true;
        visible = false;
        hiding = false;
    }

    function emitClosing(lost: bool): void {
        closingLost = lost;
        closing();
        closingLost = false;
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
            // Ouvert pendant le verrouillage (raccourci, script…) : refermé aussitôt, comme perdu.
            if (root.visible && Session.lockActive) {
                root.close(true);
                return;
            }
            BarState.setPopupOpen(root, root.visible);
            // Rouvert avant que le compositeur ait retiré le clavier : déjà actif, aucun changement à attendre.
            root.outsideReady = root.visible && keyboardProbe.active;
            // Surface fermée par le compositeur (écran retiré) : Quickshell la masque sans passer par close().
            if (!root.visible && !root.hiding)
                root.emitClosing(true);
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

    // Verrouillage : fermé, comme perdu (ce qui était en cours est gardé : demande polkit, phrase de passe d'un disque).
    Connections {
        target: Session
        function onLockActiveChanged() {
            if (Session.lockActive && root.visible)
                root.close(true);
        }
    }

    // Écran retiré ou bouton détruit pendant l'ouverture : fermé (l'écran ne change sinon qu'avant l'affichage).
    onButtonChanged: if (!button && visible) close(true)
    onScreenChanged: if (visible) close(true)
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.visible && !Quickshell.screens.includes(root.screen))
                root.close(true);
        }
    }

    // Surfaces créées une fois le popup affiché, pas avant lui : chacune crée un thread et un contexte graphique (~43 ms, à la suite),
    // l'ouverture passait de ~125 à ~240 ms (docs/PERFORMANCE.md). Signal : le clavier obtenu ; ou le délai, s'il ne vient pas (une
    // autre surface exclusive le garde).
    Item {
        id: keyboardProbe
        readonly property bool active: Window.active
        onActiveChanged: {
            if (active)
                root.outsideReady = true;
        }
    }
    Timer {
        interval: 300
        running: root.visible && !root.outsideReady
        onTriggered: root.outsideReady = true
    }

    OutsideClick {
        active: root.visible && root.catchOutside && root.outsideReady
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
