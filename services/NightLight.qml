pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Veilleuse (Night Light de GNOME) : `wlsunset` tourne tant qu'elle est activée, avec l'horaire et la température de la
// config (`nightLight` dans hosts/*.json ; valeurs par défaut reprises de tes réglages GNOME). Activée ou non : gardé dans un
// fichier d'état local, donc retrouvé à la session suivante.
Singleton {
    id: root

    readonly property var config: Settings.nightLight
    readonly property bool enabled: state.enabled
    readonly property string schedule: `${config.from} – ${config.to}`

    function toggle(): void {
        state.enabled = !state.enabled;
    }

    FileView {
        path: Quickshell.statePath("night-light.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: state
            property bool enabled: false
        }
    }

    onEnabledChanged: wlsunset.running = enabled
    Component.onCompleted: wlsunset.running = enabled

    // -s : début de la soirée (coucher), -S : fin de la nuit (lever), -t : température de nuit.
    // Arrêt inattendu (au rechargement, l'ancienne instance tient encore le réglage gamma des écrans) : relancé 1 s plus tard.
    Process {
        id: wlsunset
        command: ["wlsunset", "-s", root.config.from, "-S", root.config.to, "-t", String(root.config.temperature)]
        onExited: {
            if (root.enabled)
                retry.start();
        }
    }

    Timer {
        id: retry
        interval: 1000
        onTriggered: wlsunset.running = root.enabled
    }
}
