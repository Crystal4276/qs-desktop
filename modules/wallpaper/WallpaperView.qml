import QtQuick
import qs.services

// Rendu du fond d'une sortie (`shown` : Wallpapers.forOutput) : fond d'écran (Background.qml) et fond de l'écran de verrouillage.
// Image d'un seul écran : couvre l'écran, décodée à sa taille. Panorama : l'image couvre le rectangle englobant tous les écrans
// (centrée), chaque écran en montre sa part.
Item {
    id: root

    required property var output
    required property var shown

    Image {
        anchors.fill: parent
        visible: root.shown?.kind === "image"
        source: visible ? root.shown.source : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
        asynchronous: true
        cache: false
    }

    Item {
        anchors.fill: parent
        visible: root.shown?.kind === "panorama"
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
            readonly property real ratio: implicitHeight > 0 ? implicitWidth / implicitHeight : 1
            readonly property var b: parent.bounds
            readonly property bool wide: b.width / b.height > ratio

            source: parent.visible ? root.shown.source : ""
            fillMode: Image.Stretch
            // Décodée à la hauteur de l'ensemble (pixels réels de cet écran), pas à celle du fichier.
            sourceSize.height: Math.ceil(b.height * Screen.devicePixelRatio)
            asynchronous: true
            cache: false
            width: wide ? b.width : b.height * ratio
            height: wide ? b.width / ratio : b.height
            x: (b.width - width) / 2 - ((root.output?.x ?? 0) - b.x)
            y: (b.height - height) / 2 - ((root.output?.y ?? 0) - b.y)
        }
    }
}
