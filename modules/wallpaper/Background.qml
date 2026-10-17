import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Fond d'écran natif (remplace swaybg, ARCHITECTURE § 10.1 R1) : une surface par écran sur la couche Background, sous les barres,
// sans zone d'entrée (comme swaybg : un clic sur le fond va au compositeur, qui focalise l'espace de travail). Rendu : WallpaperView.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: window

        required property ShellScreen modelData
        readonly property var output: Compositor.output(modelData.name)
        readonly property var shown: Wallpapers.forOutput(output, Compositor.outputs)

        screen: modelData
        visible: shown !== null && shown.source !== ""
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell-wallpaper"
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        mask: Region {}

        WallpaperView {
            anchors.fill: parent
            output: window.output
            shown: window.shown
        }
    }
}
