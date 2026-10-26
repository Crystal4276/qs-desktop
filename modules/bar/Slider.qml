import QtQuick
import Quickshell
import qs.config
import qs.services

// Curseur de volume de la barre (INVENTORY.md § 1, `pulseaudio/slider`), sortie par défaut ; clic droit : panneau audio
// (pavucontrol dans Waybar ; ton choix du 2026-10-16).
VolumeSlider {
    id: root

    readonly property bool shown: Audio.ready
    // Survol : le panneau audio épinglé ne se ferme pas tout seul tant que le pointeur reste ici (Panel.qml).
    readonly property bool hovered: hover.hovered

    implicitWidth: 2 * Theme.slider.padding + Theme.slider.minWidth
    value: Audio.volume
    onMoved: v => Audio.setVolume(v)

    HoverHandler {
        id: hover
    }

    // Au-dessus du curseur : ne prend que le clic droit, le gauche passe au curseur.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: panel.toggle(root)
    }

    AudioPanelLoader {
        id: panel
    }
}
