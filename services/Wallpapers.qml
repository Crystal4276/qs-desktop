pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Fonds d'écran (docs/WALLPAPERS.md, ARCHITECTURE § 10.1 R1). Dossier : `wallpapersDir` de la config machine, sinon « Wallpapers »
// dans le dossier Images XDG, rangé en `simple/`, `panorama/` (image à étaler sur plusieurs écrans) et `triptych/<nom>/{left,center,
// right}.<ext>`. Choix mémorisé dans l'état local (pas dans le dépôt) : un fond pour tous les écrans, plus une image simple par écran
// si on en a choisi une pour lui. Rien de choisi : celui de la config machine (`wallpaper`), sinon aucune image.
Singleton {
    id: root

    property string pictures: ""
    readonly property string dir: Settings.wallpapersDir !== "" ? Settings.wallpapersDir : pictures !== "" ? `${pictures}/Wallpapers` : ""

    // Chemins relatifs au dossier : { simple: [chemin], panorama: [chemin], triptych: [{ path, name, parts: { left, center, right } }] }
    property var library: ({ simple: [], panorama: [], triptych: [] })

    // { kind: "simple" | "panorama" | "triptych", path } pour tous les écrans ; images simples par écran : { description: chemin }.
    readonly property var selection: state.selection ?? Settings.wallpaper
    readonly property var overrides: state.overrides ?? ({})

    function url(path: string): string {
        return path === "" || dir === "" ? "" : Icons.fileUrl(`${dir}/${path}`);
    }

    // Ce qu'affiche une sortie (Compositor.outputs) : { kind: "image", source } ou { kind: "panorama", source }, ou null.
    function forOutput(output: var, outputs: var): var {
        if (!output || dir === "")
            return null;
        const own = overrides[output.description];
        if (own)
            return { kind: "image", source: url(own) };
        const s = selection;
        if (!s)
            return null;
        if (s.kind === "panorama")
            return outputs.length > 1 ? { kind: "panorama", source: url(s.path) } : { kind: "image", source: url(s.path) };
        if (s.kind === "triptych") {
            const t = library.triptych.find(t => t.path === s.path);
            if (!t)
                return null;
            // Trois écrans : gauche, centre, droite selon leur position ; sinon le centre partout.
            const sorted = [...outputs].sort((a, b) => a.x - b.x);
            const part = outputs.length === 3 ? ["left", "center", "right"][sorted.findIndex(o => o.name === output.name)] : "center";
            return { kind: "image", source: url(t.parts[part] ?? t.parts.center ?? "") };
        }
        return { kind: "image", source: url(s.path) };
    }

    // Choix pour tous les écrans (efface les choix par écran) ; image simple pour un seul écran.
    function setAll(kind: string, path: string): void {
        state.overrides = {};
        state.selection = { kind: kind, path: path };
    }

    function setOutput(description: string, path: string): void {
        state.overrides = Object.assign({}, overrides, { [description]: path });
    }

    // Bibliothèque relue (ouverture de l'utilitaire, dossier changé).
    function refresh(): void {
        if (dir === "" || scan.running)
            return;
        // Commande fixée ici : liée par une liaison, elle pourrait ne pas encore suivre un dossier qui vient de changer.
        scan.command = ["sh", "-c", `cd "$0" 2>/dev/null && find -L simple panorama triptych -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort; exit 0`, dir];
        scan.running = true;
    }

    onDirChanged: refresh()
    Component.onCompleted: refresh()

    // `qs ipc call wallpaper set <kind> <chemin>` (tous les écrans) ; `state` : dossier, choix et bibliothèque en JSON (tests).
    IpcHandler {
        target: "wallpaper"

        function set(kind: string, path: string): void {
            root.setAll(kind, path);
        }

        function state(): string {
            return JSON.stringify({ dir: root.dir, selection: root.selection, overrides: root.overrides,
                simple: root.library.simple.length, panorama: root.library.panorama.length, triptych: root.library.triptych.map(t => t.name) });
        }
    }

    FileView {
        path: Quickshell.statePath("wallpaper.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: state
            property var selection: null
            property var overrides: ({})
        }
    }

    Process {
        running: Settings.wallpapersDir === ""
        command: ["xdg-user-dir", "PICTURES"]
        stdout: StdioCollector {
            onStreamFinished: root.pictures = text.trim()
        }
    }

    Process {
        id: scan
        stdout: StdioCollector {
            onStreamFinished: {
                const lib = { simple: [], panorama: [], triptych: [] };
                const triptychs = {};
                for (const path of text.split("\n").filter(l => l !== "")) {
                    const parts = path.split("/");
                    if (parts[0] === "triptych" && parts.length === 3) {
                        const key = `triptych/${parts[1]}`;
                        const t = triptychs[key] ?? (triptychs[key] = { path: key, name: parts[1], parts: {} });
                        t.parts[parts[2].replace(/\.[^.]*$/, "")] = path;
                    } else if (parts[0] === "simple" || parts[0] === "panorama") {
                        lib[parts[0]].push(path);
                    }
                }
                lib.triptych = Object.values(triptychs).filter(t => t.parts.left && t.parts.center && t.parts.right);
                root.library = lib;
            }
        }
    }
}
