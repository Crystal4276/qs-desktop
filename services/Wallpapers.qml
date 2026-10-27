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

    readonly property string dir: Settings.wallpapersDir !== "" ? Settings.wallpapersDir
        : Places.pictures !== "" ? `${Places.pictures}/Wallpapers` : ""

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
        if (!output || dir === "" || !stateRead)
            return null;
        const own = overrides[output.description];
        if (own && (!libraryRead || library.simple.includes(own)))
            return { kind: "image", source: url(own) };
        // Choix enregistré disparu du dossier (fichier supprimé ou renommé) : fond de la config machine.
        return pick(selection, output, outputs)
            ?? (libraryRead && selection !== Settings.wallpaper ? pick(Settings.wallpaper, output, outputs) : null);
    }

    // Panorama affiché (le même sur tous les écrans qui en montrent un) et sa taille, lue une seule fois pour tous les écrans et
    // l'écran de verrouillage (la sonde décode l'image entière). `panorama` garde le précédent jusqu'à la mesure du suivant : les
    // écrans le montrent pendant ce temps au lieu d'un fond vide. Vidé quand plus aucun écran n'affiche de panorama.
    readonly property string panoramaSource: Compositor.outputs.map(o => forOutput(o, Compositor.outputs))
        .find(s => s?.kind === "panorama")?.source ?? ""
    property var panorama: ({ source: "", size: Qt.size(0, 0) })

    onPanoramaSourceChanged: {
        if (panoramaSource === "")
            panorama = { source: "", size: Qt.size(0, 0) };
    }

    Image {
        // Chaîne demandée (pas `source`, une URL qui pourrait être réécrite) : comparée à `panorama.source`.
        readonly property string wanted: root.panoramaSource !== root.panorama.source ? root.panoramaSource : ""

        source: wanted
        asynchronous: true
        cache: false
        // Fichier illisible : taille nulle, rien d'affiché (plutôt que le panorama précédent).
        onStatusChanged: {
            if (wanted !== "" && (status === Image.Ready || status === Image.Error))
                root.panorama = { source: wanted, size: Qt.size(implicitWidth, implicitHeight) };
        }
    }

    function pick(s: var, output: var, outputs: var): var {
        if (!s)
            return null;
        if (libraryRead && s.kind !== "triptych" && !(library[s.kind] ?? []).includes(s.path))
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

    // Ouverture de l'utilitaire depuis l'interface (bouton du panneau de réglages), sur l'écran `screen` (celui du bouton) :
    // modules/wallpaper/WallpaperPicker.qml écoute.
    signal pickerRequested(var screen)

    // Bibliothèque relue (ouverture de l'utilitaire, dossier changé) ; demande pendant une lecture : relue juste après (le dossier
    // a pu changer). `libraryRead` : une lecture complète faite, les choix absents du dossier peuvent être écartés.
    property bool scanAgain: false
    property bool libraryRead: false

    function refresh(): void {
        if (dir === "")
            return;
        if (scan.running) {
            scanAgain = true;
            return;
        }
        // Commande fixée ici : liée par une liaison, elle pourrait ne pas encore suivre un dossier qui vient de changer.
        // Lignes `w<tab>date<tab>chemin` (images, triées par chemin) puis `t<tab>fichier` (vignettes en cache).
        scan.command = ["sh", "-c", `mkdir -p "$1"; (cd "$0" 2>/dev/null && find -L simple panorama triptych -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) -printf 'w\\t%T@\\t%p\\n' 2>/dev/null | sort -t "$(printf '\\t')" -k3); find "$1" -maxdepth 1 -name '*.png' -printf 't\\t%f\\n' 2>/dev/null; exit 0`, dir, thumbDir];
        scan.running = true;
    }

    // Vignettes de l'utilitaire en cache (PNG à la taille affichée, en pixels réels) : décoder les originaux (jusqu'à 13 Mo) prenait
    // 2 à 3 s à la première ouverture. Nom : empreinte du chemin et de la date de l'image (une image remplacée n'a plus de vignette),
    // puis la taille. Celles d'images disparues ou modifiées sont effacées à la lecture du dossier.
    readonly property string thumbDir: Quickshell.cachePath("wallpaper-thumbs")
    property var stamps: ({})   // chemin → date de modification
    property var thumbs: ({})   // fichiers de vignette présents

    function thumbName(path: string, size: size): string {
        return `${Qt.md5(`${path}\t${stamps[path] ?? ""}`)}-${size.width}x${size.height}.png`;
    }

    // Source d'une vignette : le cache s'il y est, sinon l'original.
    function thumbSource(path: string, size: size): string {
        const name = thumbName(path, size);
        return thumbs[name] ? Icons.fileUrl(`${thumbDir}/${name}`) : url(path);
    }

    // Fichier où enregistrer la vignette décodée depuis l'original, une seule fois ("" : déjà en cache ou enregistrée depuis la
    // dernière lecture du dossier, ou date de l'image pas encore lue). Sans `saved`, chaque changement d'onglet réenregistrait tout.
    readonly property var saved: new Set()   // modifié sur place : ne déclenche pas de liaison

    function thumbFile(path: string, size: size): string {
        const name = thumbName(path, size);
        if (thumbs[name] || saved.has(name) || stamps[path] === undefined)
            return "";
        saved.add(name);
        return `${thumbDir}/${name}`;
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

    // Choix enregistré lu (ou absent) : rien n'est affiché avant, sinon le fond de la config machine passerait d'abord à l'écran.
    property bool stateRead: false

    FileView {
        path: Quickshell.statePath("wallpaper.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: root.stateRead = true
        onLoadFailed: root.stateRead = true

        JsonAdapter {
            id: state
            property var selection: null
            property var overrides: ({})
        }
    }

    Process {
        id: scan
        stdout: StdioCollector {
            onStreamFinished: {
                const lib = { simple: [], panorama: [], triptych: [] };
                const triptychs = {};
                const stamps = {}, thumbs = {};
                for (const line of text.split("\n")) {
                    const fields = line.split("\t");
                    if (fields[0] === "t" && fields.length === 2)
                        thumbs[fields[1]] = true;
                    if (fields[0] !== "w" || fields.length !== 3)
                        continue;
                    const path = fields[2];
                    stamps[path] = fields[1];
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
                // Vignettes d'images disparues ou modifiées : effacées (pas si le dossier n'a pas pu être lu : rien n'est perdu).
                const used = new Set(Object.keys(stamps).map(p => Qt.md5(`${p}\t${stamps[p]}`)));
                const stale = Object.keys(thumbs).filter(f => !used.has(f.split("-")[0]));
                if (used.size > 0 && stale.length > 0) {
                    prune.command = ["rm", "-f", "--", ...stale.map(f => `${root.thumbDir}/${f}`)];
                    prune.running = true;
                    stale.forEach(f => delete thumbs[f]);
                }
                // Dates et vignettes avant la bibliothèque : les vignettes recréées partent directement du cache.
                root.stamps = stamps;
                root.thumbs = thumbs;
                root.saved.clear();
                root.library = lib;
                root.libraryRead = true;
            }
        }
        onExited: {
            if (root.scanAgain) {
                root.scanAgain = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    Process {
        id: prune
    }
}
