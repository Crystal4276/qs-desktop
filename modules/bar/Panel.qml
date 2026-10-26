import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Panneau d'un module natif du tray (THEME.md § 3 « Panneaux ») : cadre du calendrier, titre, interrupteur facultatif,
// contenu libre. `toggle(item, boutons)` l'ouvre sous l'icône ou le ferme.
// Surface Overlay à clavier exclusif, comme le panneau de réglages (OverlayPopup.qml) : sous Sway, un popup `grabFocus`
// ouvert depuis une barre ne reçoit jamais le clavier (ni saisie ni Échap ; vu le 2026-10-20, Sway 1.12). Fermé par un
// appui à côté du cadre, sur une barre ou sur un autre écran, ou par Échap.
// Aperçu (ta demande du 2026-10-21, comme l'horloge) : `preview(item, boutons)` l'ouvre au survol de l'icône, sans clavier (la
// fenêtre où l'on tape le garde) ni pointeur hors du cadre (clics et survols atteignent les fenêtres) ; fermé quand le pointeur
// quitte le cadre et les icônes des modules natifs du tray. Un clic sur l'icône ou dans le cadre l'épingle : il prend alors le clavier et se
// comporte comme ouvert au clic. Pas d'aperçu par-dessus un autre popup épinglé, ni après une fermeture (Échap, clic sur
// l'icône…) tant que le pointeur reste sur l'icône.
// Épinglé : fermé aussi quand le pointeur est resté `autoCloseDelay` hors du cadre et de l'icône (ta demande du 2026-10-21, comme
// le calendrier et le menu), une fois entré dans l'un d'eux ; jamais pendant une saisie (champ non vide qui a le focus) ni bouton
// appuyé dans le cadre.
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
        // Aperçu sous cet élément : épinglé. Sous un autre (raccourci des réglages, autre écran) : fermé, puis ouvert ici.
        if (visible && previewing) {
            if (item === button) {
                previewing = false;
                return;
            }
            close();
        }
        if (!beginOpen(item))
            return;
        ownerButtons = buttons;
        wasPinned = true;
        pointerEntered = item.hovered === true;
        openUnder(item);
    }

    property bool previewing: false
    // Ouvert et épinglé (pas un aperçu) : recherche Bluetooth et Wi-Fi seulement alors (radio, batterie du laptop).
    readonly property bool pinned: visible && !previewing
    // Fermé pointeur sur l'icône : pas d'aperçu avant que le pointeur l'ait quittée.
    property bool previewSuppressed: false
    // Épinglé pendant cette ouverture (centre de notifications : marquées vues seulement alors, pas après un simple aperçu, même
    // traversé par le pointeur).
    property bool wasPinned: false
    // Pointeur entré dans le cadre ou sur l'icône depuis l'ouverture : la fermeture automatique peut compter.
    property bool pointerEntered: false
    // Champ focalisé en cours de saisie : `pending` de PanelField.qml (heure modifiée pour TimeField.qml), sinon texte non vide.
    readonly property bool typing: frame.focusedItem?.cursorPosition !== undefined
        && (frame.focusedItem.parent instanceof PanelField ? frame.focusedItem.parent.pending : (frame.focusedItem.text ?? "") !== "")

    // Survol de `item` (bouton à PreviewArea.qml, qui le déclare en `hovered`) ; `buttons` : comme pour toggle().
    function preview(item: Item, buttons: int): void {
        if (visible || BarState.popupPinned)
            return;
        prepareOpen(item);
        ownerButtons = buttons;
        wasPinned = false;
        pointerEntered = true;
        previewing = true;
        openUnder(item);
    }

    onVisibleChanged: {
        if (visible)
            return;
        previewing = false;
        previewSuppressed = button?.hovered ?? false;
    }
    // Épinglé depuis l'aperçu : clavier exclusif, focus redemandé pour l'élément d'entrée.
    onPreviewingChanged: {
        if (previewing || !visible)
            return;
        wasPinned = true;
        initialFocus?.forceActiveFocus();
    }

    Connections {
        target: root.button
        ignoreUnknownSignals: true   // panneau audio : bouton sans `hovered`
        function onHoveredChanged() {
            if (root.button.hovered)
                root.pointerEntered = true;
            else
                root.previewSuppressed = false;
        }
    }

    WlrLayershell.namespace: "quickshell-panel"
    WlrLayershell.keyboardFocus: previewing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
    mask: previewing ? previewInput : null
    catchOutside: !previewing
    frameItem: frame

    Region {
        id: previewInput
        item: frame
    }

    // Aperçu : fermé une fois le pointeur hors de l'icône et du cadre (délai bref : passage de l'une à l'autre).
    Timer {
        interval: Theme.panel.previewGrace
        running: root.visible && root.previewing && !frameHover.hovered && BarState.hoveredTrayButton === null
        onTriggered: root.close()
    }

    Timer {
        interval: Theme.panel.autoCloseDelay
        running: root.pinned && root.pointerEntered && !root.typing && !framePress.active && !frameHover.hovered
            && !(root.button?.hovered ?? false)
        onTriggered: root.close()
    }

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

    // Au-dessus du cadre : survol vu avant ses enfants (un enfant qui accepte le survol, `hoverEnabled`, le cacherait à un
    // HoverHandler du cadre).
    Item {
        x: frame.x
        y: frame.y
        width: frame.width
        height: frame.height

        HoverHandler {
            id: frameHover
            onHoveredChanged: if (hovered) root.pointerEntered = true
        }

        // Bouton appuyé dans le cadre (curseur de volume tiré hors du cadre…) : pas de fermeture automatique avant le relâchement.
        PointHandler {
            id: framePress
            acceptedButtons: Qt.AllButtons
        }
    }

    // Aperçu : un appui dans le cadre l'épingle, puis atteint l'élément visé, sauf si `pinClickPasses` est faux (réglages :
    // boutons d'alimentation sans confirmation, qu'un clic destiné à une fenêtre sous l'aperçu ne doit pas atteindre).
    property bool pinClickPasses: true

    MouseArea {
        x: frame.x
        y: frame.y
        width: frame.width
        height: frame.height
        enabled: root.previewing
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            root.previewing = false;
            mouse.accepted = !root.pinClickPasses;
        }
    }
}
