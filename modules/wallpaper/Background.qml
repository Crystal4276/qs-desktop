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
        readonly property var output: Compositor.output(modelData?.name ?? "")
        readonly property var shown: Wallpapers.forOutput(output, Compositor.outputs)

        screen: modelData
        visible: shown !== null && shown.source !== ""
        // Écran décrit, choix lus, mais aucune image (aucun fond, partie de triptyque introuvable) : rien à attendre au démarrage.
        readonly property bool nothingToShow: output !== null && Wallpapers.ready && !visible
        // Vérifié au tour suivant : notifié avant `shown` et `visible` (ordre de QML), il pourrait se croire vrai un instant.
        onNothingToShowChanged: nothingCheck.restart()
        Component.onCompleted: nothingCheck.restart()

        Timer {
            id: nothingCheck
            interval: 0
            onTriggered: {
                if (window.nothingToShow)
                    Wallpapers.markShown(window.modelData?.name ?? "", "");
            }
        }
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
            onDisplayed: Wallpapers.markShown(window.modelData?.name ?? "", window.shown ? `${window.shown.kind}:${window.shown.source}` : "")
        }
    }
}
