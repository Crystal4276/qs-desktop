import QtQuick
import qs.config

// Bouton d'un module natif du tray (réseau, Wi-Fi, disques, Bluetooth, NordVPN) : même taille que les icônes d'applications ;
// icône du thème (`icon`) ou glyphe dessiné en contenu (Wi-Fi). Survol : aperçu du panneau après un court arrêt sur l'icône
// (pas en passant : l'ouverture lance des recherches Bluetooth, Wi-Fi…) ; un appui (gauche ou droit) l'épingle, l'ouvre ou le
// ferme (Panel.qml, qui gère aussi « pas d'aperçu après une fermeture tant que le pointeur reste sur l'icône »).
Item {
    id: root

    property string icon: ""
    property Panel panel
    default property alias content: glyph.data
    readonly property alias hovered: hover.hovered
    readonly property int buttons: Qt.LeftButton | Qt.RightButton

    implicitWidth: Theme.bar.trayIconSize
    implicitHeight: Theme.bar.trayIconSize

    TrayIcon {
        anchors.fill: parent
        visible: root.icon !== ""
        source: root.icon
    }

    Item {
        id: glyph
        anchors.fill: parent
    }

    HoverHandler {
        id: hover
        onHoveredChanged: BarState.setTrayHover(root, hovered)
    }

    // Relancé aussi quand un popup épinglé qui bloquait l'aperçu se ferme, pointeur resté sur l'icône.
    Timer {
        interval: Theme.panel.previewDelay
        running: root.visible && hover.hovered && !root.panel.previewSuppressed && !root.panel.visible && !BarState.popupPinned
        onTriggered: root.panel.preview(root, root.buttons)
    }

    // Icône masquée sous le pointeur (câble débranché, Bluetooth retiré…) : ni survol restant, ni aperçu accroché à elle.
    onVisibleChanged: {
        if (visible)
            return;
        BarState.setTrayHover(root, false);
        if (panel.previewing && panel.button === root)
            panel.close();
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: root.buttons
        onPressed: root.panel.toggle(root, root.buttons)
    }

    Component.onDestruction: BarState.setTrayHover(root, false)
}
