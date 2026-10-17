import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Fond d'écran natif (remplace swaybg, ARCHITECTURE § 10.1 R1) : une surface par écran sur la couche Background, sous les barres,
// sans zone d'entrée (comme swaybg : un clic sur le fond va au compositeur, qui focalise l'espace de travail). Panorama : une seule
// image étalée sur l'ensemble des écrans, découpée selon leur position réelle.
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

        // Image d'un seul écran : couvre l'écran, décodée à sa taille (pas à celle du fichier, jusqu'à 8688 px de large).
        Image {
            anchors.fill: parent
            visible: window.shown?.kind === "image"
            source: visible ? window.shown.source : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
            asynchronous: true
            cache: false
        }

        // Panorama : l'image couvre le rectangle englobant tous les écrans (centrée), chaque écran en montre sa part.
        Item {
            anchors.fill: parent
            visible: window.shown?.kind === "panorama"
            clip: true

            readonly property var bounds: {
                const all = Compositor.outputs;
                const left = Math.min(...all.map(o => o.x)), top = Math.min(...all.map(o => o.y));
                return {
                    x: left,
                    y: top,
                    width: Math.max(...all.map(o => o.x + o.width)) - left,
                    height: Math.max(...all.map(o => o.y + o.height)) - top
                };
            }

            Image {
                id: panorama

                readonly property real ratio: implicitHeight > 0 ? implicitWidth / implicitHeight : 1
                readonly property var b: parent.bounds
                readonly property bool wide: b.width / b.height > ratio

                source: parent.visible ? window.shown.source : ""
                fillMode: Image.Stretch
                // Décodée à la hauteur de l'ensemble (pixels réels de cet écran), pas à celle du fichier.
                sourceSize.height: Math.ceil(b.height * Screen.devicePixelRatio)
                asynchronous: true
                cache: false
                width: wide ? b.width : b.height * ratio
                height: wide ? b.width / ratio : b.height
                x: (b.width - width) / 2 - ((window.output?.x ?? 0) - b.x)
                y: (b.height - height) / 2 - ((window.output?.y ?? 0) - b.y)
            }
        }
    }
}
