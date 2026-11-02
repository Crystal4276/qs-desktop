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
    // Dossier Images XDG, aussi pour les fonds d'écran (Wallpapers) et les captures (Screenshot) : "" avant la première lecture ;
    // non défini ou absent : ~/Pictures.
    property string pictures: ""
    // [{ path, name, mime, time }]
    property var recent: []
    property bool recentReady: false   // liste relue et vérifiée au moins une fois (message « No recent files » seulement ensuite)
    property bool recentWanted: false
    property var parsed: []   // entrées lues, avant le filtre des fichiers absents

    function open(path: string): void {
        Launch.exec(["xdg-open", path]);
    }

    function refreshRecent(): void {
        if (recentWanted)
            recentFile.reload();
        else
            recentWanted = true;
    }

    // Relus à chaque ouverture du menu (dossier créé, supprimé ou redéfini dans user-dirs.dirs) ; demande pendant une lecture :
    // relue juste après.
    property bool foldersAgain: false

    function refreshFolders(): void {
        if (folderList.running)
            foldersAgain = true;
        else
            folderList.running = true;
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
                if (JSON.stringify(list) !== JSON.stringify(root.folders))   // inchangés : lignes du menu gardées
                    root.folders = list;
                root.pictures = list.find(f => f.key === "PICTURES")?.path.replace(/\/$/, "") ?? `${root.home}/Pictures`;
            }
        }
        onExited: {
            if (root.foldersAgain) {
                root.foldersAgain = false;
                Qt.callLater(() => folderList.running = true);
            }
        }
    }

    FileView {
        id: recentFile
        path: root.recentWanted ? `${Quickshell.env("XDG_DATA_HOME") || `${root.home}/.local/share`}/recently-used.xbel` : ""
        printErrors: false
        onLoadFailed: {   // fichier supprimé (historique effacé) : plus de fichiers récents, vérification en cours ignorée
            root.checkNumber++;
            root.existsAgain = false;
            root.parsed = [];
            root.recent = [];
            root.recentReady = true;
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
                    // Entités XML (nommées et numériques, `&#39;` selon l'application), en une passe (sinon « &amp;lt; » serait
                    // décodé deux fois), puis l'encodage de l'URI.
                    path = decodeURIComponent(href.slice("file://".length).replace(/&(amp|lt|gt|quot|apos|#x[0-9a-f]+|#[0-9]+);/gi,
                        (e, n) => n[0] === "#" ? (Number(`0${n.slice(1)}`) <= 0x10ffff ? String.fromCodePoint(Number(`0${n.slice(1)}`)) : e)
                            : ({ amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'" })[n.toLowerCase()]));
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
            // Un fichier par chemin, le plus récent (deux signets du même fichier, encodés autrement par deux applications) :
            // les identifiants de la liste du menu doivent être uniques.
            const seen = new Set();
            root.parsed = list.sort((a, b) => b.time - a.time).filter(f => !seen.has(f.path) && seen.add(f.path));
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
                root.recentReady = true;
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
