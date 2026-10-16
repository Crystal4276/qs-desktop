pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Dossiers et fichiers récents du menu d'applications (modules/menus/AppMenu.qml), ouverts par `xdg-open` (application par défaut,
// ex. le gestionnaire de fichiers pour un dossier).
// - Dossiers : le dossier personnel, puis les dossiers XDG Documents, Téléchargements, Musique, Images, Vidéos (`xdg-user-dir`)
//   qui existent comme dossiers à part (non définis : `xdg-user-dir` renvoie le dossier personnel, ils sont alors omis).
// - Fichiers récents : ceux de GTK (`recently-used.xbel`), fichiers locaux seulement, du plus récent au plus ancien.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // [{ key, path, name }] ; `key` choisit l'icône (Theme.appMenu.placeIcons)
    property var folders: [{ key: "HOME", path: home, name: "Home" }]
    // [{ path, name, mime, time }]
    property var recent: []

    function open(path: string): void {
        Quickshell.execDetached(["xdg-open", path]);
    }

    Process {
        running: true
        command: ["sh", "-c", `for d in DOCUMENTS DOWNLOAD MUSIC PICTURES VIDEOS; do printf '%s\\t%s\\n' "$d" "$(xdg-user-dir "$d")"; done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [{ key: "HOME", path: root.home, name: "Home" }];
                for (const line of text.split("\n")) {
                    const [key, path] = line.split("\t");
                    if (path && path !== root.home && path !== `${root.home}/`)
                        list.push({ key: key, path: path, name: path.replace(/\/$/, "").split("/").pop() });
                }
                root.folders = list;
            }
        }
    }

    FileView {
        id: recentFile
        path: `${Quickshell.env("XDG_DATA_HOME") || `${root.home}/.local/share`}/recently-used.xbel`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const list = [];
            const bookmark = /<bookmark\b([^>]*)>([\s\S]*?)<\/bookmark>/g;   // pas de String.matchAll dans le moteur de Qt
            const content = recentFile.text();
            for (let m = bookmark.exec(content); m !== null; m = bookmark.exec(content)) {
                const href = m[1].match(/\bhref="([^"]*)"/)?.[1] ?? "";
                if (!href.startsWith("file://"))
                    continue;
                let path;
                try {
                    path = decodeURIComponent(href.slice("file://".length).replace(/&amp;/g, "&").replace(/&apos;/g, "'")
                        .replace(/&quot;/g, "\"").replace(/&lt;/g, "<").replace(/&gt;/g, ">"));
                } catch (e) {
                    continue;
                }
                list.push({
                    path: path,
                    name: path.split("/").pop(),
                    mime: m[2].match(/<mime:mime-type\s+type="([^"]*)"/)?.[1] ?? "",
                    time: Date.parse(m[1].match(/\b(?:modified|visited)="([^"]*)"/)?.[1] ?? "") || 0
                });
            }
            root.recent = list.sort((a, b) => b.time - a.time);
        }
    }
}
