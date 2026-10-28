pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// Applications du tray qui ne sont qu'un menu (clic gauche → menu), règle de Waybar (sni/item.cpp) : propriété ItemIsMenu,
// vraie si l'application ne la fournit pas. libayatana-appindicator (Steam, Spotify) n'a ni ItemIsMenu ni Activate ;
// Quickshell la croit fausse dans ce cas, d'où la lecture directe sur D-Bus (busctl introspect) à chaque arrivée ou départ
// d'application.
Singleton {
    id: root

    // Identifiant StatusNotifier → la propriété manque (true) ou sa valeur.
    property var menuOnlyById: ({})

    function menuOnly(item: SystemTrayItem): bool {
        return menuOnlyById[item.id] ?? item.onlyMenu;
    }

    // Fenêtre de l'application affichée après une entrée de sa carte (ta demande du 2026-10-28) : Steam (Store, Library,
    // Friends… s'ouvrent sur son espace de travail, invisibles depuis un autre), sauf ses jeux récents (premier groupe, avant
    // le premier séparateur) et « Exit Steam ».
    function showWindowAfter(item: SystemTrayItem, entry: QsMenuEntry, group: int): bool {
        return item.id === "steam" && group > 0 && !/^exit\b/i.test(entry.text);
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

    // Une ligne par application : Id en JSON (busctl), tabulation, « true », « false », « absent » ou « error » (application
    // qui ne répond pas dans les 2 s : valeur précédente gardée).
    Process {
        id: query
        command: ["sh", "-c", `
            items=$(busctl --user --timeout=2 get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \\
                org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null | cut -d' ' -f3- | tr -d '"')
            for e in $items; do
                case $e in */*) svc=\${e%%/*}; path=/\${e#*/} ;; *) svc=$e; path=/StatusNotifierItem ;; esac
                id=$(busctl --user --timeout=2 --json=short get-property "$svc" "$path" org.kde.StatusNotifierItem Id 2>/dev/null) || continue
                # Propriétés listées avec leur valeur (indépendant de la langue des messages d'erreur).
                if props=$(busctl --user --timeout=2 introspect "$svc" "$path" org.kde.StatusNotifierItem 2>/dev/null); then
                    menu=$(echo "$props" | awk '$1 == ".ItemIsMenu" { print $4 }')
                    menu=\${menu:-absent}
                else
                    menu=error
                fi
                printf '%s\\t%s\\n' "$id" "$menu"
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n").filter(l => l.includes("\t"))) {
                    const [json, menu] = line.split("\t");
                    let id;
                    try {
                        id = JSON.parse(json).data;
                    } catch (e) {
                        continue;
                    }
                    if (menu === "error") {
                        if (id in root.menuOnlyById)
                            map[id] = root.menuOnlyById[id];
                    } else {
                        map[id] = menu !== "false";
                    }
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
