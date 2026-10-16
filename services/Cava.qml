pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Visualiseur audio (INVENTORY.md § 1, module `cava`) : `cava` en sortie brute, réglages dans config/cava.conf.
// Ne tourne que tant qu'un module l'affiche (`users`). Pas d'équivalent natif dans Quickshell (ARCHITECTURE § 6).
Singleton {
    id: root

    // Nombre de modules affichés qui l'utilisent (incrémenté / décrémenté par les widgets).
    property int users: 0

    // Dernière image brute de cava (« 0;3;7;…; ») ; une chaîne, pour ne notifier qu'en cas de changement.
    property string frame: ""
    // Hauteur de chaque barre, 0 à 7.
    readonly property var bars: frame.split(";").filter(s => s !== "").map(Number)
    // Silence : toutes les barres à zéro (Waybar : échantillons d'entrée nuls ; écart accepté, PROGRESS phase 4).
    readonly property bool silent: bars.every(v => v === 0)

    // Lancé et arrêté selon `users`, sans liaison sur `running` : la relance après un arrêt l'écraserait, et cava ne s'arrêterait
    // plus quand plus aucun module ne l'affiche.
    onUsersChanged: cava.running = users > 0
    Component.onCompleted: cava.running = users > 0

    Process {
        id: cava
        command: ["cava", "-p", Quickshell.shellPath("config/cava.conf")]
        stdout: SplitParser {
            onRead: line => root.frame = line
        }
        onExited: {
            root.frame = "";
            if (root.users > 0)
                restart.start();
        }
    }

    // cava qui s'arrête (serveur audio relancé…) : nouvel essai 2 s plus tard.
    Timer {
        id: restart
        interval: 2000
        onTriggered: cava.running = root.users > 0
    }
}
