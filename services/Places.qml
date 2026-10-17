pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Dossiers et fichiers récents du menu d'applications (modules/menus/AppMenu.qml), ouverts par `xdg-open` (application par défaut,
// ex. le gestionnaire de fichiers pour un dossier).
// - Dossiers : le dossier personnel, puis les dossiers XDG Documents, Téléchargements, Musique, Images, Vidéos (`xdg-user-dir`)
//   qui existent comme dossiers à part (non définis : `xdg-user-dir` renvoie le dossier personnel, ils sont alors omis).
// - Fichiers récents : ceux de GTK (`recently-used.xbel`), fichiers locaux encore présents, du plus récent au plus ancien. Le fichier
//   (des centaines de Ko, réécrit par GTK à chaque fichier ouvert) n'est lu qu'à l'ouverture du menu (`refreshRecent`), pas surveillé.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // [{ key, path, name }] ; `key` choisit l'icône (Theme.appMenu.placeIcons)
    readonly property var homeFolder: ({ key: "HOME", path: home, name: "Home" })
    property var folders: [homeFolder]
    // [{ path, name, mime, time }]
    property var recent: []
    property bool recentWanted: false
    property var parsed: []   // entrées lues, avant le filtre des fichiers absents

    function open(path: string): void {
        Quickshell.execDetached(["xdg-open", path]);
    }

    function refreshRecent(): void {
        if (recentWanted)
            recentFile.reload();
        else
            recentWanted = true;
    }

    // Relus quand user-dirs.dirs change (dossiers XDG redéfinis).
    FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || `${root.home}/.config`}/user-dirs.dirs`
        printErrors: false
        watchChanges: true
        onFileChanged: folderList.running = true
    }

    Process {
        id: folderList
        running: true
        command: ["sh", "-c", `for d in DOCUMENTS DOWNLOAD MUSIC PICTURES VIDEOS; do p="$(xdg-user-dir "$d")"; [ -d "$p" ] && printf '%s\\t%s\\n' "$d" "$p"; done; exit 0`]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [root.homeFolder];
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
        path: root.recentWanted ? `${Quickshell.env("XDG_DATA_HOME") || `${root.home}/.local/share`}/recently-used.xbel` : ""
        printErrors: false
        onLoadFailed: {   // fichier supprimé (historique effacé) : plus de fichiers récents
            root.parsed = [];
            root.recent = [];
        }
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
                    // Entités XML, `&amp;` en dernier (sinon « &amp;lt; » serait décodé deux fois), puis l'encodage de l'URI.
                    path = decodeURIComponent(href.slice("file://".length).replace(/&apos;/g, "'").replace(/&quot;/g, "\"")
                        .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&"));
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
            root.parsed = list.sort((a, b) => b.time - a.time);
            root.checkExists();
        }
    }

    // Fichiers encore présents (supprimés, déplacés, disque démonté : omis). La sortie commence par le numéro de la vérification :
    // seule la dernière lancée est appliquée, à sa liste (`checking`). Liste relue entre-temps : nouvelle vérification ensuite.
    // Au plus 5 s (montage réseau ou gvfs qui ne répond plus) : sans la marque de fin, la liste est montrée sans filtre.
    property int checkNumber: 0
    property var checking: []
    property bool existsAgain: false

    function checkExists(): void {
        if (exists.running) {
            existsAgain = true;
            return;
        }
        checkNumber++;
        checking = parsed;
        exists.command = ["timeout", "-s", "KILL", "5", "sh", "-c",
            `printf '%s\\n' "$0"; for f; do [ -e "$f" ] && printf '%s\\n' "$f"; done; printf '\\n%s\\n' "$0"; exit 0`,
            String(checkNumber), ...parsed.map(f => f.path)];
        exists.running = true;
    }

    Process {
        id: exists
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const number = String(root.checkNumber);
                if (lines[0] !== number)
                    return;
                const finished = lines.length >= 3 && lines[lines.length - 2] === number;   // marque de fin : ligne vide puis le numéro
                const present = new Set(lines.slice(1));
                root.recent = finished ? root.checking.filter(f => present.has(f.path)) : root.checking;
            }
        }
        onExited: {
            if (root.existsAgain) {
                root.existsAgain = false;
                Qt.callLater(root.checkExists);
            }
        }
    }
}
