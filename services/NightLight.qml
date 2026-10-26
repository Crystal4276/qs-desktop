pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Veilleuse (Night Light de GNOME) : `gammastep` tourne tant qu'elle est activée, avec l'horaire et la température de la
// config (`nightLight` dans hosts/*.json ; valeurs par défaut reprises de tes réglages GNOME). gammastep plutôt que wlsunset
// (ta demande du 2026-10-26) : fondu d'environ 4 s à l'activation, à la désactivation et aux heures de l'horaire, là où
// wlsunset change la température d'un coup. Activée ou non : gardé dans un fichier d'état local, donc retrouvé à la session
// suivante.
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

    // Réglages de gammastep : les heures de l'horaire ne passent que par un fichier de config, écrit avant chaque lancement.
    // dusk-time : passage à la nuit, dawn-time : retour au jour (une heure seule : bascule à cette heure, en fondu).
    FileView {
        id: configFile
        path: Quickshell.statePath("gammastep.ini")
        blockWrites: true
        printErrors: false
    }

    function start(): void {
        configFile.setText(["[general]", "adjustment-method=wayland", "fade=1", "temp-day=6500",
            `temp-night=${config.temperature}`, `dusk-time=${config.from}`, `dawn-time=${config.to}`, ""].join("\n"));
        gammastep.running = true;
    }

    // SIGTERM : gammastep revient en fondu à la température neutre, puis quitte.
    function stop(): void {
        if (gammastep.running)
            gammastep.signal(15);
    }

    onEnabledChanged: enabled ? start() : stop()
    Component.onCompleted: if (enabled) start()

    // Arrêt inattendu (au rechargement, l'ancienne instance tient encore le réglage gamma des écrans le temps de son fondu) :
    // relancé 1 s plus tard.
    Process {
        id: gammastep
        command: ["gammastep", "-c", configFile.path]
        onExited: {
            if (root.enabled)
                retry.start();
        }
    }

    Timer {
        id: retry
        interval: 1000
        onTriggered: if (root.enabled) root.start()
    }

    // `qs ipc call nightlight toggle` (raccourci éventuel, tests).
    IpcHandler {
        target: "nightlight"

        function toggle(): void {
            root.toggle();
        }

        function isEnabled(): bool {
            return root.enabled;
        }
    }
}
