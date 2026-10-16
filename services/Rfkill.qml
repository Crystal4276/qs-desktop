pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Mode avion (bascule du panneau de réglages, laptop) : `rfkill block all` / `unblock all` (droits donnés par logind à la
// session active). Activé quand toutes les radios sont bloquées. État relu à chaque événement de `rfkill event`.
Singleton {
    id: root

    property var devices: []   // [{ type, soft, hard }]
    readonly property bool available: devices.length > 0
    readonly property bool airplane: available && devices.every(d => d.soft === "blocked" || d.hard === "blocked")

    function toggle(): void {
        Quickshell.execDetached(["rfkill", airplane ? "unblock" : "block", "all"]);
    }

    Process {
        id: list
        running: true
        command: ["rfkill", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // { "rfkilldevices": [...] } (util-linux 2.40 ; "" dans les versions plus anciennes)
                    root.devices = Object.values(JSON.parse(text))[0] ?? [];
                } catch (e) {
                    root.devices = [];
                }
            }
        }
    }

    Process {
        running: true
        command: ["rfkill", "event"]
        stdout: SplitParser {
            onRead: list.running = true
        }
    }
}
