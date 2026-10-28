pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// Applications du tray qui ne sont qu'un menu (clic gauche → menu), règle de Waybar (sni/item.cpp) : propriété ItemIsMenu,
// vraie si l'application ne la fournit pas. libayatana-appindicator (Steam, Spotify) n'a ni ItemIsMenu ni Activate ;
// Quickshell la croit fausse dans ce cas, d'où la lecture directe sur D-Bus (busctl) à chaque arrivée ou départ d'application.
Singleton {
    id: root

    // Identifiant StatusNotifier → la propriété manque (true) ou sa valeur.
    property var menuOnlyById: ({})

    function menuOnly(item: SystemTrayItem): bool {
        return menuOnlyById[item.id] ?? item.onlyMenu;
    }

    readonly property string ids: SystemTray.items.values.map(i => i.id).join("\n")
    Component.onCompleted: query.running = true
    onIdsChanged: {
        if (query.running)
            queryAgain = true;
        else
            query.running = true;
    }
    property bool queryAgain: false

    // Une ligne par application : « Id<tab>true|false|absent ».
    Process {
        id: query
        command: ["sh", "-c", `
            items=$(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \\
                org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null | cut -d' ' -f3- | tr -d '"')
            for e in $items; do
                case $e in */*) svc=\${e%%/*}; path=/\${e#*/} ;; *) svc=$e; path=/StatusNotifierItem ;; esac
                id=$(busctl --user get-property "$svc" "$path" org.kde.StatusNotifierItem Id 2>/dev/null) || continue
                menu=$(busctl --user get-property "$svc" "$path" org.kde.StatusNotifierItem ItemIsMenu 2>/dev/null) || menu="b absent"
                printf '%s\\t%s\\n' "$(echo "$id" | cut -d' ' -f2- | sed 's/^"//; s/"$//')" "\${menu#b }"
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n").filter(l => l.includes("\t"))) {
                    const [id, menu] = line.split("\t");
                    map[id] = menu !== "false";
                }
                root.menuOnlyById = map;
            }
        }
        onExited: {
            if (root.queryAgain) {
                root.queryAgain = false;
                running = true;
            }
        }
    }
}
