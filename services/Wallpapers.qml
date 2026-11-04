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

    // Ce qu'affiche une sortie (Compositor.outputs) : { kind: "image", source, path } ou { kind: "panorama", source }, ou null.
    // `path` : chemin dans le dossier, clé de la copie à la taille de l'écran (screenSource).
    function forOutput(output: var, outputs: var): var {
        if (!output || dir === "" || !stateRead)
            return null;
        const own = overrides[output.description];
        if (own && (!libraryRead || library.simple.includes(own)))
            return { kind: "image", source: url(own), path: own };
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
            return outputs.length > 1 ? { kind: "panorama", source: url(s.path) } : { kind: "image", source: url(s.path), path: s.path };
        if (s.kind === "triptych") {
            const t = library.triptych.find(t => t.path === s.path);
            if (!t)
                return null;
            // Trois écrans : gauche, centre, droite selon leur position ; sinon le centre partout.
            const sorted = [...outputs].sort((a, b) => a.x - b.x);
            const part = outputs.length === 3 ? ["left", "center", "right"][sorted.findIndex(o => o.name === output.name)] : "center";
            const path = t.parts[part] ?? t.parts.center ?? "";
            return { kind: "image", source: url(path), path: path };
        }
        return { kind: "image", source: url(s.path), path: s.path };
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
    property real scanStarted: 0   // copies d'écran écrites depuis : pas encore vues par la lecture en cours, gardées

    function refresh(): void {
        if (dir === "")
            return;
        if (scan.running) {
            scanAgain = true;
            return;
        }
        // Commande fixée ici : liée par une liaison, elle pourrait ne pas encore suivre un dossier qui vient de changer.
        // Lignes `w<tab>date<tab>chemin` (images, triées par chemin), `t<tab>fichier` (vignettes en cache), puis
        // `c<tab>date<tab>fichier` (copies à la taille des écrans).
        scan.command = ["sh", "-c", `mkdir -p "$1" "$2"; (cd "$0" 2>/dev/null && find -L simple panorama triptych -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) -printf 'w\\t%T@\\t%p\\n' 2>/dev/null | sort -t "$(printf '\\t')" -k3); find "$1" -maxdepth 1 -name '*.png' -printf 't\\t%f\\n' 2>/dev/null; find "$2" -maxdepth 1 -name '*.bmp' -printf 'c\\t%T@\\t%f\\n' 2>/dev/null; exit 0`, dir, thumbDir, screenDir];
        scanStarted = Date.now() / 1000;
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

    // Source d'une vignette : le cache s'il y est (ou vient d'y être écrite), sinon l'original.
    function thumbSource(path: string, size: size): string {
        const name = thumbName(path, size);
        return thumbs[name] || saved.get(name) ? Icons.fileUrl(`${thumbDir}/${name}`) : url(path);
    }

    // Vignettes enregistrées depuis la dernière lecture du dossier : nom → fichier écrit (false pendant l'écriture). Modifié sur
    // place, sans déclencher de liaison : les vignettes affichées gardent leur image, celles recréées ensuite (défilement,
    // onglet) partent du fichier écrit. Sans lui, chaque changement d'onglet réenregistrait tout, et le défilement redécodait.
    readonly property var saved: new Map()

    // Fichier où enregistrer la vignette décodée depuis l'original, une seule fois ("" : déjà en cache ou en cours, ou date de
    // l'image pas encore lue) ; `thumbWritten` une fois le fichier écrit.
    function thumbFile(path: string, size: size): string {
        const name = thumbName(path, size);
        if (thumbs[name] || saved.has(name) || stamps[path] === undefined)
            return "";
        saved.set(name, false);
        return `${thumbDir}/${name}`;
    }

    function thumbWritten(file: string): void {
        saved.set(file.slice(thumbDir.length + 1), true);
    }

    // Copie de chaque fond affiché, à la taille exacte de son écran, en BMP : décodée en 28 ms au lieu de 125 à 165 ms pour tes
    // PNG (8,5 et 12,9 Mo), sans perte (JPEG de `saveToFile` : qualité 75, écart visible). Écrite par WallpaperView, telle
    // qu'affichée, une fois le fond décodé depuis l'original et gardé 3 s (pas à chaque essai dans l'utilitaire), puis lue aux
    // lancements suivants (pas aussitôt : l'image affichée est la même). Connue par l'état local (`screenCache` : lisible dès le
    // démarrage, sans attendre la lecture du dossier), avec la date de l'original ; celle d'une image changée depuis (date
    // différente, plus ancienne comprise : `cp -p`) ou disparue est effacée à la lecture du dossier. Seules restent celles des fonds
    // affichés (environ 25 Mo par écran 4K). Objets simples, pas de Set ni de WeakMap (plantage de Qt avec ce dernier).
    readonly property string screenDir: Quickshell.cachePath("wallpaper-screens")
    readonly property var screenSaving: ({})   // copies en cours d'écriture (nom de fichier)
    readonly property var writtenNow: ({})     // copies écrites par ce processus : l'original reste affiché

    function screenName(path: string, size: size): string {
        return `${Qt.md5(path)}-${size.width}x${size.height}.bmp`;
    }

    // La copie est lue à la place de l'original (WallpaperView : `fromCopy`, sans comparer d'URL, encodées différemment).
    function usesCopy(path: string, size: size): bool {
        const name = screenName(path, size);
        return !!state.screenCache?.[name] && !writtenNow[name];
    }

    function screenSource(path: string, size: size): string {
        return usesCopy(path, size) ? Icons.fileUrl(`${screenDir}/${screenName(path, size)}`) : url(path);
    }

    // Fichier où écrire la copie de `path` ("" : déjà en cache ou en cours d'écriture).
    function screenFile(path: string, size: size): string {
        const name = screenName(path, size);
        if (state.screenCache?.[name] || screenSaving[name])
            return "";
        screenSaving[name] = true;
        return `${screenDir}/${name}`;
    }

    // Copie écrite (`ok`) ou échouée. Les copies de fonds qu'aucun écran actif n'affiche plus sont effacées.
    function screenWritten(file: string, path: string, ok: bool): void {
        const name = file.slice(screenDir.length + 1);
        delete screenSaving[name];
        if (!ok)
            return;
        writtenNow[name] = true;
        const shownPaths = Compositor.outputs.map(o => forOutput(o, Compositor.outputs)?.path).filter(p => p);
        // Date de l'original : inconnue si le dossier n'est pas encore lu, relevée alors à sa lecture.
        const entries = Object.assign({}, state.screenCache ?? {}, { [name]: { path: path, stamp: stamps[path] ?? null, written: Date.now() / 1000 } });
        const unused = Object.keys(entries).filter(n => !shownPaths.includes(entries[n].path));
        unused.forEach(n => delete entries[n]);
        removeFiles(unused.map(n => `${screenDir}/${n}`));
        state.screenCache = entries;
    }

    // Copie illisible (effacée à la main, disque) : oubliée, l'original est relu (et une nouvelle copie écrite).
    function screenFailed(path: string, size: size): void {
        const name = screenName(path, size);
        if (!state.screenCache?.[name])
            return;
        const entries = Object.assign({}, state.screenCache);
        delete entries[name];
        state.screenCache = entries;
    }

    function removeFiles(files: var): void {
        if (files.length === 0)
            return;
        Quickshell.execDetached(["rm", "-f", "--", ...files]);
    }

    // Choix enregistré et dossier lus : forOutput donne le fond définitif.
    readonly property bool ready: stateRead && libraryRead

    // Démarrage : les barres attendent que chaque écran affiche son fond (Bar.qml), pour apparaître en même temps ; au plus 3 s
    // (fond illisible, compositeur lent). Une fois pour toutes : gardé au rechargement à chaud.
    property alias startupShown: persist.startupShown
    property var shownScreens: []   // écrans dont le fond est affiché (Background.qml)

    function markShown(name: string): void {
        if (!shownScreens.includes(name))
            shownScreens = [...shownScreens, name];
    }

    // Écran sans image (aucun fond, ou partie de triptyque introuvable : source vide, fenêtre jamais affichée) : rien à attendre.
    // Après le démarrage : plus calculé (`startupShown` en tête).
    readonly property bool allShown: !startupShown && ready && Compositor.outputs.length > 0
        && Compositor.outputs.every(o => !forOutput(o, Compositor.outputs)?.source || shownScreens.includes(o.name))
    onAllShownChanged: {
        if (allShown)
            startupShown = true;
    }

    PersistentProperties {
        id: persist
        reloadableId: "wallpapers"
        property bool startupShown: false
    }

    Timer {
        interval: 3000
        running: !root.startupShown
        onTriggered: root.startupShown = true
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
            property var screenCache: ({})   // copies à la taille des écrans : { fichier: { path, written } }
        }
    }

    Process {
        id: scan
        stdout: StdioCollector {
            onStreamFinished: {
                const lib = { simple: [], panorama: [], triptych: [] };
                const triptychs = {};
                const stamps = {}, thumbs = {}, screens = {};
                for (const line of text.split("\n")) {
                    const fields = line.split("\t");
                    if (fields[0] === "t" && fields.length === 2)
                        thumbs[fields[1]] = true;
                    if (fields[0] === "c" && fields.length === 3)
                        screens[fields[2]] = Number(fields[1]);
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
                    root.removeFiles(stale.map(f => `${root.thumbDir}/${f}`));
                    stale.forEach(f => delete thumbs[f]);
                }
                // Copies d'écran : gardées si le fichier existe et que l'image n'a pas changé depuis, ou si elles viennent d'être écrites ;
                // les autres sont oubliées, et tout fichier sans entrée effacé (écriture ratée, état perdu), sauf une copie en cours
                // d'écriture ; pas si le dossier n'a pas pu être lu. Les instances de test ont leur propre cache (test-outputs.sh).
                if (used.size > 0) {
                    const entries = {};
                    for (const [name, entry] of Object.entries(state.screenCache ?? {})) {
                        const stamp = stamps[entry.path];
                        // Date de l'original à l'écriture : identique exigée ; inconnue alors : original plus ancien que la copie.
                        const fresh = screens[name] !== undefined && stamp !== undefined
                            && (entry.stamp ? entry.stamp === stamp : Number(stamp) <= screens[name]);
                        if (fresh || entry.written >= root.scanStarted)
                            entries[name] = Object.assign({}, entry, { stamp: entry.stamp || stamp || null });
                    }
                    root.removeFiles(Object.keys(screens).filter(n => !entries[n] && !root.screenSaving[n]).map(n => `${root.screenDir}/${n}`));
                    if (JSON.stringify(entries) !== JSON.stringify(state.screenCache ?? {}))
                        state.screenCache = entries;
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

}
