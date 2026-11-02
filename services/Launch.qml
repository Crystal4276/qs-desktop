pragma Singleton

import QtQuick
import Quickshell

// Lancement d'une application depuis le bureau, sans les réglages propres au processus Quickshell (scripts/qs-env.sh, à garder
// identique) : forcer un pilote EGL gênerait par exemple les conteneurs de Steam. Séparé d'Apps.qml : un `xdg-open` ne doit pas créer
// tout le lanceur.
Singleton {
    readonly property var environment: ({
        MALLOC_CONF: null,
        QSG_ATLAS_WIDTH: null,
        QSG_ATLAS_HEIGHT: null,
        __EGL_VENDOR_LIBRARY_FILENAMES: null
    })

    function exec(command: var): void {
        Quickshell.execDetached({ command, environment });
    }
}
