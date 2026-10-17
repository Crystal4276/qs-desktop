pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Icônes du tray choisies comme GTK (Waybar) : pour 32 px, GTK prend dans Papirus-Dark la variante `16x16@2x/panel` (16 px à
// l'échelle 2, vérifié avec Gtk.IconTheme.lookup_icon), que Qt ignore à l'échelle 1 (il prendrait `24x24`, au dessin plus petit).
// Ces fichiers sont listés une fois au démarrage, dans les dossiers de données XDG.
Singleton {
    id: root

    property var panelIcons: ({})   // nom → chemin du fichier SVG

    // Icône du thème pour un type de fichier (« text/plain » → text-plain, sinon text-x-generic, sinon l'icône de fichier
    // générique), cherchée une fois par type.
    property var mimeIcons: ({})

    function mimeIcon(mime: string): string {
        if (mime in mimeIcons)
            return mimeIcons[mime];
        let found = "";
        for (const name of [mime.replace("/", "-"), `${mime.split("/")[0]}-x-generic`, Theme.appMenu.fileIcon]) {
            found = name === "" || name.startsWith("-") ? "" : Quickshell.iconPath(name, true);
            if (found !== "")
                break;
        }
        mimeIcons[mime] = found;
        return found;
    }

    // Icône d'application ou de notification : chemin absolu ou nom d'icône du thème.
    function iconSource(icon: string): string {
        if (icon === "")
            return "";
        return icon.startsWith("/") ? fileUrl(icon) : Quickshell.iconPath(icon, true);
    }

    // URL d'un fichier local, chemin encodé (« # », « % », espaces…).
    function fileUrl(path: string): string {
        return `file://${path.split("/").map(encodeURIComponent).join("/")}`;
    }

    // Source à afficher pour un nom d'icône ou une URL d'application (image://icon/<nom>?path=…, image://qspixmap/…).
    function trayIcon(source: string): string {
        const name = source.startsWith("image://icon/") ? source.slice(13).split("?")[0] : source.includes(":") ? "" : source;
        if (name !== "" && panelIcons[name])
            return fileUrl(panelIcons[name]);
        return source.includes(":") ? source : `image://icon/${source}`;
    }

    Process {
        running: true
        command: ["sh", "-c", 'for d in "$@"; do p="$d/icons/$0/16x16@2x/panel"; [ -d "$p" ] && ls -1 "$p" | sed "s|^|$p/|"; done',
            Theme.iconTheme, Quickshell.env("XDG_DATA_HOME") || `${Quickshell.env("HOME")}/.local/share`,
            ...(Quickshell.env("XDG_DATA_DIRS") || "/usr/local/share:/usr/share").split(":")]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const path of text.split("\n").filter(l => l.endsWith(".svg"))) {
                    const name = path.split("/").pop().slice(0, -4);
                    if (!map[name])
                        map[name] = path;   // premier dossier trouvé : priorité XDG
                }
                root.panelIcons = map;
            }
        }
    }
}
