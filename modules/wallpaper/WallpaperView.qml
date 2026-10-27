import QtQuick
import qs.services

// Rendu du fond d'une sortie (`shown` : Wallpapers.forOutput) : fond d'écran (Background.qml) et fond de l'écran de verrouillage.
// Image d'un seul écran : couvre l'écran, décodée à sa taille. Panorama : l'image couvre le rectangle englobant tous les écrans
// (centrée), chaque écran n'en décode et n'en montre que sa part. Changement de fond : l'ancien reste affiché pendant le décodage
// du nouveau (`retainWhileLoading`), sauf en passant d'une image à un panorama ou l'inverse.
Item {
    id: root

    required property var output
    required property var shown

    Image {
        anchors.fill: parent
        visible: root.shown?.kind === "image"
        // Pas de source avant la taille finale : sinon une première lecture à la taille du fichier (sourceSize nulle), puis une autre.
        source: visible && width > 0 && height > 0 ? root.shown.source : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
        asynchronous: true
        retainWhileLoading: true
        cache: false
    }

    Item {
        id: panorama

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
        readonly property var b: bounds
        // Panorama mesuré par le service (le précédent tant que le nouveau n'est pas mesuré) et taille de son fichier.
        readonly property string source: visible && b.height > 0 ? Wallpapers.panorama.source : ""
        readonly property size natural: Wallpapers.panorama.size
        readonly property real dpr: Screen.devicePixelRatio
        readonly property real ratio: natural.height > 0 ? natural.width / natural.height : 0
        readonly property bool wide: ratio > 0 && b.width / b.height > ratio
        // Image entière telle qu'affichée (logique) : elle couvre l'ensemble des écrans, centrée ; position relative à cet écran.
        readonly property real fullWidth: wide ? b.width : b.height * ratio
        readonly property real fullHeight: wide ? b.width / ratio : b.height
        readonly property real fx: (b.width - fullWidth) / 2 - ((root.output?.x ?? 0) - b.x)
        readonly property real fy: (b.height - fullHeight) / 2 - ((root.output?.y ?? 0) - b.y)
        // Part de l'image visible sur cet écran (logique, relative à l'image).
        readonly property real lx: Math.max(0, -fx)
        readonly property real ly: Math.max(0, -fy)
        readonly property real lw: Math.min(fullWidth, width - fx) - lx
        readonly property real lh: Math.min(fullHeight, height - fy) - ly
        // Hauteur décodée : celle de l'image affichée en pixels réels, sans dépasser le fichier (Qt réduit, n'agrandit pas) ;
        // `k` : pixels décodés par pixel logique.
        readonly property int decodedHeight: Math.min(natural.height, Math.round(fullHeight * dpr))
        readonly property real k: fullHeight > 0 ? decodedHeight / fullHeight : 0

        // Seule la part de cet écran est décodée (sourceClipRect, en pixels de l'image réduite à sourceSize).
        Image {
            readonly property real cx: Math.floor(panorama.lx * panorama.k)
            readonly property real cy: Math.floor(panorama.ly * panorama.k)

            source: panorama.ratio > 0 && panorama.lw > 0 && panorama.lh > 0 ? panorama.source : ""
            fillMode: Image.Stretch
            sourceSize: panorama.decodedHeight < panorama.natural.height ? Qt.size(0, panorama.decodedHeight) : Qt.size(0, 0)
            sourceClipRect: Qt.rect(cx, cy, Math.min(Math.ceil(panorama.lw * panorama.k), Math.floor(panorama.decodedHeight * panorama.ratio) - cx),
                Math.min(Math.ceil(panorama.lh * panorama.k), panorama.decodedHeight - cy))
            asynchronous: true
            retainWhileLoading: true
            cache: false
            x: panorama.fx + panorama.lx
            y: panorama.fy + panorama.ly
            width: panorama.lw
            height: panorama.lh
        }
    }
}
