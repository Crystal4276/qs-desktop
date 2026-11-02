import QtQuick
import Quickshell
import Quickshell.Wayland

// Surfaces à clavier exclusif sur un seul écran (panneau de réglages, lanceur) : tant que `active`, une surface transparente
// couvre chacun des autres écrans et signale le premier appui (`pressed`), pour que le popup se ferme. Sans elle, un clic sur
// une fenêtre d'un autre écran atteindrait la fenêtre, mais le popup resterait ouvert et garderait le clavier.
// Les barres restent cliquables (zone exclusive respectée) : elles ferment déjà les popups (BarState.closePopups).
Variants {
    id: root

    property bool active: false
    property ShellScreen screen: null   // écran du popup, non couvert
    signal pressed

    model: active ? Quickshell.screens.filter(s => s !== screen) : []

    PanelWindow {
        required property ShellScreen modelData

        screen: modelData
        WlrLayershell.namespace: "quickshell-outside-click"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: 0
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.pressed()
        }
    }
}
