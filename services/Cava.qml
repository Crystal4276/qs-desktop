pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Visualiseur audio (INVENTORY.md § 1, module `cava`) : `cava` en sortie brute, réglages dans config/cava.conf.
// Ne tourne que tant qu'un module l'affiche (`users`) et qu'un lecteur MPRIS est en lecture (`active`, ton choix du 2026-10-16 :
// affiché pendant toute la lecture, même à bas niveau, et non plus masqué sur silence comme Waybar).
// Pas d'équivalent natif dans Quickshell (ARCHITECTURE § 6).
Singleton {
    id: root

    // Nombre de modules affichés qui l'utilisent (incrémenté / décrémenté par les widgets).
    property int users: 0

    // Dernière image brute de cava (« 0;3;7;…; ») ; une chaîne, pour ne notifier qu'en cas de changement.
    property string frame: ""
    // Hauteur de chaque barre, 0 à 7.
    readonly property var bars: frame.split(";").filter(s => s !== "").map(Number)
    readonly property bool active: users > 0 && Media.playing.length > 0

    // Lancé et arrêté selon `active`, sans liaison sur `running` : la relance après un arrêt l'écraserait, et cava ne s'arrêterait
    // plus quand plus rien ne joue.
    onActiveChanged: cava.running = active
    Component.onCompleted: cava.running = active

    Process {
        id: cava
        command: ["cava", "-p", Quickshell.shellPath("config/cava.conf")]
        stdout: SplitParser {
            onRead: line => root.frame = line
        }
        onExited: {
            root.frame = "";
            if (root.active)
                restart.start();
        }
    }

    // cava qui s'arrête (serveur audio relancé…) : nouvel essai 2 s plus tard.
    Timer {
        id: restart
        interval: 2000
        onTriggered: cava.running = root.active
    }
}
