pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Fonds d'écran (ARCHITECTURE § 7.11). Dossier : `wallpapersDir` de la config machine, sinon « Wallpapers »
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
    // `path` : chemin dans le dossier, clé de la copie à la taille de l'écran (screenName).
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
            const t = triptych(s.path);
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
    property var writtenSinceScan: ({})   // copies écrites depuis le début de la lecture en cours : pas encore vues par elle, gardées

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
        writtenSinceScan = {};
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

    // Copie de chaque fond affiché, à la taille de son écran, en BMP (sans perte, décodée 4 à 6 fois plus vite que tes PNG ;
    // docs/ARCHITECTURE.md § 7.11). Écrite par WallpaperView après 3 s sur le même fond, connue par l'état local (`screenCache`) avec la date
    // de l'original ; vérifiée à la lecture du dossier (checkCopies). Objets simples : pas de WeakMap (plantage de Qt).
    readonly property string screenDir: Quickshell.cachePath("wallpaper-screens")
    readonly property var screenSaving: ({})   // copies en cours d'écriture (nom de fichier)

    function screenName(path: string, size: size): string {
        return `${Qt.md5(`${dir}/${path}`)}-${size.width}x${size.height}.bmp`;
    }

    function hasCopy(name: string): bool {
        return !!state.screenCache?.[name];
    }

    function copyUrl(name: string): string {
        return Icons.fileUrl(`${screenDir}/${name}`);
    }

    // Fichier où écrire la copie `name` ("" : déjà en cache ou en cours d'écriture).
    function screenFile(name: string): string {
        if (state.screenCache?.[name] || screenSaving[name])
            return "";
        screenSaving[name] = true;
        return `${screenDir}/${name}`;
    }

    function triptych(path: string): var {
        return library.triptych.find(t => t.path === path) ?? null;
    }

    // Fonds choisis (par écran, et pour tous : `selection`, celui de la config machine si rien n'est choisi) et fonds affichés (repli
    // quand le choix a disparu du dossier ; panorama sur un seul écran) : leurs copies restent, écran éteint ou capot fermé compris.
    function chosenPaths(): var {
        const paths = [...Object.values(overrides), ...Compositor.outputs.map(o => forOutput(o, Compositor.outputs)?.path).filter(p => p)];
        if (selection?.kind === "triptych")
            paths.push(...Object.values(triptych(selection.path)?.parts ?? {}));
        else if (selection?.kind === "simple")
            paths.push(selection.path);
        return paths;
    }

    // Copies des fonds qui ne sont plus choisis : retirées de `entries`, fichiers effacés. Pas avant la lecture du dossier (parties
    // des triptyques inconnues) ni avant que tous les écrans soient décrits (fonds affichés inconnus) : fait plus tard.
    function dropUnchosen(entries: var): var {
        if (!libraryRead || Quickshell.screens.length === 0 || !Quickshell.screens.every(s => Compositor.output(s.name) !== null))
            return [];
        const keep = chosenPaths();
        const unused = Object.keys(entries).filter(n => !keep.includes(entries[n].path));
        unused.forEach(n => delete entries[n]);
        return unused;
    }

    // Liste des copies remplacée : celles des fonds plus choisis retirées, écrite dans l'état seulement si elle a changé.
    function setCopies(entries: var, orphans: var): void {
        removeFiles([...dropUnchosen(entries), ...(orphans ?? [])].map(n => `${screenDir}/${n}`));
        if (JSON.stringify(entries) !== JSON.stringify(state.screenCache ?? {}))
            state.screenCache = entries;
    }

    // Choix changé (fond déjà copié, panorama : aucune copie écrite ensuite) : copies des anciens fonds retirées aussitôt.
    function pruneCopies(): void {
        if (stateRead)
            setCopies(Object.assign({}, state.screenCache ?? {}));
    }
    onSelectionChanged: Qt.callLater(pruneCopies)   // « pour tous les écrans » change les deux : un seul passage
    onOverridesChanged: Qt.callLater(pruneCopies)

    // Copie écrite (`ok`) ou échouée. Les copies des fonds qui ne sont plus choisis sont effacées.
    function screenWritten(name: string, path: string, ok: bool): void {
        delete screenSaving[name];
        if (!ok) {
            Quickshell.execDetached(["mkdir", "-p", screenDir]);   // dossier effacé : la copie suivante pourra s'écrire
            return;
        }
        // Date de l'original : inconnue si le dossier n'est pas encore lu, relevée alors à sa lecture.
        writtenSinceScan[name] = true;
        setCopies(Object.assign({}, state.screenCache ?? {}, { [name]: { path: path, stamp: stamps[path] ?? null } }));
    }

    // Copie illisible (effacée à la main, disque) : oubliée, l'original est relu (et une nouvelle copie écrite).
    function screenFailed(name: string): void {
        if (!state.screenCache?.[name])
            return;
        const entries = Object.assign({}, state.screenCache);
        delete entries[name];
        setCopies(entries);
        Quickshell.execDetached(["mkdir", "-p", screenDir]);   // dossier des copies effacé : sinon aucune ne s'écrirait plus
    }

    // Copies vérifiées une fois le dossier ET l'état lus (sinon toutes passeraient pour inconnues) : gardées si le fichier existe, que
    // son nom suit la clé actuelle (dossier des fonds changé : écartée) et que l'original n'a pas changé (même date ; inconnue à
    // l'écriture : plus ancien que la copie), ou si elles viennent d'être écrites ; les autres oubliées. Fichier sans entrée (écriture
    // ratée, état perdu) : effacé au bout d'un jour, pas avant (une autre instance au même cache, avec un autre état, peut l'avoir écrit).
    property var screenFiles: null   // copies trouvées à la dernière lecture du dossier : { fichier: date }

    function checkCopies(): void {
        const files = screenFiles;
        if (!stateRead || files === null)
            return;
        screenFiles = null;
        const entries = {};
        for (const [name, entry] of Object.entries(state.screenCache ?? {})) {
            const stamp = stamps[entry.path];
            const size = name.match(/-(\d+)x(\d+)\.bmp$/);
            const current = size !== null && name === screenName(entry.path, Qt.size(Number(size[1]), Number(size[2])));
            const fresh = current && files[name] !== undefined && stamp !== undefined
                && (entry.stamp ? entry.stamp === stamp : Number(stamp) <= files[name]);
            if (fresh || writtenSinceScan[name])
                entries[name] = Object.assign({}, entry, { stamp: entry.stamp || stamp || null });
        }
        const dayAgo = Date.now() / 1000 - 86400;
        setCopies(entries, Object.keys(files).filter(n => !entries[n] && !screenSaving[n] && files[n] < dayAgo));
    }
    onStateReadChanged: checkCopies()

    function removeFiles(files: var): void {
        if (files.length === 0)
            return;
        Quickshell.execDetached(["rm", "-f", "--", ...files]);
    }

    // Choix enregistré et dossier lus : forOutput donne le fond définitif.
    // Fond de chaque écran pour l'écran de connexion (modules/greeter, utilisateur `greeter`, qui ne lit pas ton dossier personnel) :
    // dossier système créé par scripts/greeter-setup.sh (absent : l'écriture échoue sans bruit), une image par écran nommée
    // d'après sa description, récrite quand le fond affiché change (Background.qml). Banc (QS_TEST) : seulement sous QS_GREETER_DIR.
    readonly property string greeterDir: {
        const user = Quickshell.env("USER") ?? "";
        const base = Quickshell.env("QS_GREETER_DIR") ?? (Quickshell.env("QS_TEST") ? "" : "/var/lib/qs-desktop");
        return base === "" || user === "" ? "" : `${base}/${user}`;
    }
    readonly property var greeterSaved: ({})   // description → fond écrit (« nature:source:taille »)

    // Fichier où écrire le fond `key` de l'écran `description` ("" : déjà écrit, ou pas de dossier). Même nom côté greeter
    // (services/Greeter.qml). Retenu seulement une fois écrit (greeterWritten) : un échec est retenté au prochain affichage.
    function greeterFile(description: string, key: string): string {
        if (greeterDir === "" || description === "" || greeterSaved[description] === key)
            return "";
        return `${greeterDir}/${Qt.md5(description)}.jpg`;
    }

    function greeterWritten(description: string, key: string, ok: bool): void {
        if (ok)
            greeterSaved[description] = key;
    }

    readonly property bool ready: stateRead && libraryRead

    // Démarrage : les barres attendent que chaque écran affiche son fond (Bar.qml), pour apparaître en même temps ; au plus 3 s
    // (fond illisible, compositeur lent). Une fois pour toutes : gardé au rechargement à chaud.
    property alias startupShown: persist.startupShown
    property var shownScreens: ({})   // « nature:source » affichée par écran, "" : aucune image (Background.qml)

    function markShown(name: string, source: string): void {
        if (!startupShown && shownScreens[name] !== source)
            shownScreens = Object.assign({}, shownScreens, { [name]: source });
    }

    // Tous les écrans, pas seulement ceux déjà décrits par le compositeur, chacun avec son fond définitif (choix lus) : une image
    // provisoire (partie de triptyque avant l'arrivée des autres écrans, choix disparu du dossier) ne compte pas. Ne dépend pas de
    // `startupShown`, qu'il fait passer à vrai (boucle de liaison) ; après le démarrage, recalculé seulement aux changements d'écrans
    // ou de choix, et sans effet.
    readonly property bool allShown: ready && Quickshell.screens.length > 0 && Quickshell.screens.every(s => {
        const o = Compositor.output(s.name);
        const shown = forOutput(o, Compositor.outputs);
        return o !== null && shownScreens[s.name] === (shown?.source ? `${shown.kind}:${shown.source}` : "");
    })
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
            property var screenCache: ({})   // copies à la taille des écrans : { fichier: { path, stamp } }
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
                // Dates et vignettes avant la bibliothèque : les vignettes recréées partent directement du cache.
                root.stamps = stamps;
                root.screenFiles = used.size > 0 ? screens : null;   // dossier illisible : copies pas vérifiées
                root.thumbs = thumbs;
                root.saved.clear();
                root.library = lib;
                root.libraryRead = true;
                root.checkCopies();   // après la bibliothèque : parties des triptyques connues (dropUnchosen)
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
