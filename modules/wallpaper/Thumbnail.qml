import QtQuick
import qs.services

// Les cellules gardent leurs pixels ; le cache disque est réservé aux versions connues.
Image {
    id: image
    required property string path
    required property real pixelRatio
    required property bool active
    property var job: null

    sourceSize: Qt.size(Math.ceil(width * pixelRatio), Math.ceil(height * pixelRatio))
    source: sourceSize.width > 0 && sourceSize.height > 0 ? Wallpapers.thumbSource(path, sourceSize) : ""
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: false

    function cancel(): void {
        Wallpapers.cancelThumb(job);
        job = null;
    }

    function save(): void {
        if (!active || status !== Image.Ready || job !== null)
            return;
        const request = Wallpapers.beginThumb(path, sourceSize);
        if (!request)
            return;
        job = request;
        if (!grabToImage(result => {
            if (Wallpapers.currentThumb(request))
                Wallpapers.finishThumb(request, result.saveToFile(request.file));
            else
                Wallpapers.cancelThumb(request);
            if (job === request) job = null;
        }, Qt.size(width, height))) {
            Wallpapers.finishThumb(request, false);
            job = null;
        }
    }

    onActiveChanged: {
        if (!active) cancel();
        else Qt.callLater(save);
    }
    onSourceChanged: cancel()
    onStatusChanged: {
        if (status === Image.Ready) Qt.callLater(save);
        else {
            cancel();
            if (status === Image.Error && source.toString().startsWith("file:") && source.toString().includes("wallpaper-thumbs/")) {
                const failedPath = path, failedSize = sourceSize, failedSource = source.toString();
                Qt.callLater(() => {
                    if (source.toString() === failedSource && failedSource.endsWith("/" + Wallpapers.thumbName(failedPath, failedSize)))
                        Wallpapers.thumbFailed(failedPath, failedSize);
                });
            }
        }
    }
    Component.onDestruction: cancel()
}
