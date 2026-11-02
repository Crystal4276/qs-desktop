pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Applications du lanceur (remplace `rofi -show drun`, INVENTORY § 3) et du menu d'applications (catégories, favoris) : comportement de Rofi 2.0.0, code lu (modes/drun.c, history.c).
// - Liste : DesktopEntries, plus les filtres de Rofi que Quickshell n'applique pas (OnlyShowIn / NotShowIn selon
//   XDG_CURRENT_DESKTOP, TryExec introuvable, Exec absent).
// - Ordre : historique d'abord (du plus lancé au moins lancé), puis le reste par nom.
// - Recherche : mots séparés par des espaces, tous requis, sans casse, dans le nom, le nom générique, Exec, les catégories,
//   les mots-clés et le commentaire (`-drun-match-fields all`) ; un mot précédé de « - » exclut.
// - Historique (fichier d'état local, hors du dépôt) : lancements par application et textes saisis. Au premier démarrage,
//   il reprend celui de Rofi (~/.cache/rofi3.druncache, rofi-entry-history.txt).
Singleton {
    id: root

    readonly property int historySize: 25      // `max-history-size` de Rofi
    readonly property int inputHistorySize: 20 // `max-history` de la saisie Rofi

    property var hidden: ({})   // identifiants masqués par les filtres de Rofi
    readonly property var history: state.history   // [{ id, count }], du plus lancé au moins lancé
    readonly property list<string> inputs: state.inputs
    property bool importRofi: false

    // Applications affichables, sans ordre : base des listes du lanceur (par historique) et du menu (par nom, par catégorie), pour
    // que le tri par nom et les catégories ne soient pas recalculés à chaque lancement (l'historique change).
    readonly property var available: desktopApps.filter(e => !hidden[e.id] && e.execString !== "")

    // Applications de DesktopEntries relues en une fois : au chargement, la liste arrive application par application (230
    // changements d'affilée) ; liées directement, les tris, les catégories et le menu étaient recalculés à chaque fois (~1 s de
    // blocage à la première ouverture, mesuré le 2026-10-21).
    property var desktopApps: []
    Component.onCompleted: readApps()
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            Qt.callLater(root.readApps);
        }
    }

    function readApps(): void {
        desktopApps = DesktopEntries.applications.values;
    }

    readonly property var entries: {
        const rank = {};
        history.forEach((h, i) => rank[h.id] = i);
        return [...available].sort((a, b) => {
            const ra = rank[a.id] ?? -1, rb = rank[b.id] ?? -1;
            if (ra < 0 && rb < 0)
                return a.name.localeCompare(b.name);
            return (ra < 0 ? Infinity : ra) - (rb < 0 ? Infinity : rb);
        });
    }

    // Catégories du menu d'applications (modules/menus/AppMenu.qml), d'après les catégories principales de la norme freedesktop
    // (Desktop Menu Specification) : une application va dans la première catégorie de cette liste qu'elle déclare (« System »
    // avant « Settings » : un outil d'administration n'est pas une préférence) ; aucune → « Other ». Catégories vides masquées.
    readonly property var categoryList: [
        { key: "System", name: "Administration", match: ["System"] },
        { key: "Settings", name: "Preferences", match: ["Settings"] },
        { key: "Development", name: "Programming", match: ["Development"] },
        { key: "Game", name: "Games", match: ["Game"] },
        { key: "Graphics", name: "Graphics", match: ["Graphics"] },
        { key: "AudioVideo", name: "Sound & Video", match: ["AudioVideo", "Audio", "Video"] },
        { key: "Network", name: "Internet", match: ["Network"] },
        { key: "Office", name: "Office", match: ["Office"] },
        { key: "Education", name: "Education", match: ["Education"] },
        { key: "Science", name: "Science", match: ["Science"] },
        { key: "Utility", name: "Accessories", match: ["Utility"] }
    ]

    // Toutes les applications par nom (« All Applications »), puis par catégorie : { clé: [DesktopEntry] }, « Other » pour le reste.
    readonly property var byName: [...available].sort((a, b) => a.name.localeCompare(b.name))
    readonly property var byCategory: {
        const map = {};
        for (const e of byName) {
            const categories = e.categories;   // liste Qt convertie une fois par application
            const key = categoryList.find(c => c.match.some(m => categories.includes(m)))?.key ?? "Other";
            (map[key] = map[key] ?? []).push(e);
        }
        return map;
    }

    // Favoris du menu d'applications (identifiants, dans l'ordre d'ajout), fichier d'état local. Au premier démarrage, reprise
    // des applications épinglées de nwg-menu (~/.cache/nwg-pin-cache : « <identifiant>.desktop » par ligne).
    readonly property list<string> favoriteIds: favorites.ids
    readonly property var favoriteEntries: favoriteIds.map(id => available.find(e => e.id === id)).filter(e => e)
    property bool importPins: false

    function isFavorite(entry: DesktopEntry): bool {
        return favoriteIds.includes(entry.id);
    }

    function toggleFavorite(entry: DesktopEntry): void {
        favorites.ids = isFavorite(entry) ? favoriteIds.filter(id => id !== entry.id) : [...favoriteIds, entry.id];
    }

    FileView {
        path: Quickshell.statePath("app-menu.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: root.importPins = true

        JsonAdapter {
            id: favorites
            property list<string> ids: []
        }
    }

    FileView {
        path: root.importPins ? `${root.cacheDir}/nwg-pin-cache` : ""
        printErrors: false
        onLoaded: favorites.ids = text().split("\n").filter(l => l.endsWith(".desktop")).map(l => l.slice(0, -".desktop".length))
    }

    function inHistory(entry: DesktopEntry): bool {
        return history.some(h => h.id === entry.id);
    }

    // Champs de recherche de chaque application, en minuscules : calculés une fois quand la liste change, pas à chaque frappe.
    readonly property var searchFields: {
        const map = {};
        for (const e of available)   // pas `entries` (trié par historique) : pas refait à chaque lancement
            map[e.id] = [e.name, e.genericName, e.execString, ...e.categories, ...e.keywords, e.comment]
                .filter(f => f).map(f => f.toLowerCase());
        return map;
    }

    function filter(query: string): var {
        const tokens = query.toLowerCase().split(" ").filter(t => t !== "");
        if (tokens.length === 0)
            return entries;
        return entries.filter(e => {
            const fields = searchFields[e.id] ?? [];
            return tokens.every(t => {
                const invert = t.startsWith("-");
                const word = invert ? t.slice(1) : t;
                return fields.some(f => f.includes(word)) !== invert;
            });
        });
    }

    function launch(entry: DesktopEntry): void {
        const context = { command: entry.runInTerminal ? [...Settings.terminal, ...entry.command] : entry.command, environment: Launch.environment };
        if (entry.workingDirectory !== "")
            context.workingDirectory = entry.workingDirectory;
        Quickshell.execDetached(context);
        remember(entry.id);
    }

    // Texte saisi lancé comme commande (Entrée sans résultat, Ctrl+Entrée ; dans un terminal : Ctrl+Maj+Entrée).
    function run(command: string, terminal: bool): void {
        exec([...(terminal ? Settings.terminal : []), "sh", "-c", command]);
    }

    // Comme Rofi : +1 au compteur, tri stable par nombre de lancements, compteurs ramenés au plus petit, 25 entrées au plus.
    function remember(id: string): void {
        const list = history.map(h => ({ id: h.id, count: h.count }));
        const found = list.find(h => h.id === id);
        if (found)
            found.count++;
        else
            list.push({ id: id, count: 1 });
        list.sort((a, b) => b.count - a.count);
        const min = list[list.length - 1].count;
        state.history = list.map(h => ({ id: h.id, count: h.count - min })).slice(0, historySize);
    }

    // Maj+Suppr : retire l'application de l'historique.
    function forget(entry: DesktopEntry): void {
        state.history = history.filter(h => h.id !== entry.id);
    }

    // Textes saisis, du plus ancien au plus récent (Ctrl+Haut / Ctrl+Bas dans le lanceur).
    function saveInputs(list: var): void {
        state.inputs = list.filter(s => s !== "").slice(-inputHistorySize);
    }

    FileView {
        path: Quickshell.statePath("launcher.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: root.importRofi = true   // pas encore d'historique : reprise de celui de Rofi

        JsonAdapter {
            id: state
            property var history: []
            property list<string> inputs: []
        }
    }

    readonly property string cacheDir: Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")}/.cache`

    FileView {
        path: root.importRofi ? `${root.cacheDir}/rofi3.druncache` : ""
        printErrors: false
        // « <nombre> <identifiant>.desktop » par ligne, déjà trié
        onLoaded: state.history = text().split("\n").map(l => l.match(/^(\d+) (.+)\.desktop$/)).filter(m => m)
            .map(m => ({ id: m[2], count: Number(m[1]) }))
    }

    FileView {
        path: root.importRofi ? `${root.cacheDir}/rofi-entry-history.txt` : ""
        printErrors: false
        onLoaded: root.saveInputs(text().split("\n"))
    }

    // Identifiants que Rofi n'afficherait pas : la première entrée trouvée pour un identifiant compte (priorité XDG),
    // seules les clés du groupe [Desktop Entry] sont lues. Relancé quand les applications changent.
    // Sécurité : les valeurs lues dans les fichiers ne passent jamais dans une chaîne exécutée par un shell (`system()` d'awk
    // l'aurait fait pour TryExec : revue de code).
    Process {
        id: filters
        running: true
        command: ["sh", "-c", `for d in "$@"; do [ -d "$d/applications" ] && find -L "$d/applications" -type f -name '*.desktop'; done | awk '
            BEGIN { n = split(ENVIRON["XDG_CURRENT_DESKTOP"], desk, ":") }
            {
                path = $0; id = path; sub(/.*\\/applications\\//, "", id); gsub("/", "-", id); sub(/\\.desktop$/, "", id)
                if (id in seen) next
                seen[id] = 1; main = 0; only = ""; hasOnly = 0; notIn = ""; tryExec = ""
                while ((getline line < path) > 0) {
                    if (line ~ /^\\[/) { main = line == "[Desktop Entry]"; continue }
                    if (!main) continue
                    value = line; sub(/^[^=]*=[ \\t]*/, "", value)
                    if (line ~ /^OnlyShowIn[ \\t]*=/) { only = value; hasOnly = 1 }
                    else if (line ~ /^NotShowIn[ \\t]*=/) notIn = value
                    else if (line ~ /^TryExec[ \\t]*=/) tryExec = value
                }
                close(path)
                hide = 0
                if (n > 0 && hasOnly) {
                    hide = 1; m = split(only, l, ";")
                    for (i = 1; i <= m; i++) for (j = 1; j <= n; j++) if (l[i] != "" && l[i] == desk[j]) hide = 0
                }
                if (n > 0 && !hide && notIn != "") {
                    m = split(notIn, l, ";")
                    for (i = 1; i <= m; i++) for (j = 1; j <= n; j++) if (l[i] == desk[j]) hide = 1
                }
                # TryExec : vérifié plus bas par le shell, en argument (jamais réinterprété : il vient de fichiers tiers).
                if (hide) print "H\t" id
                else if (tryExec != "") print "T\t" id "\t" tryExec
            }' | while IFS="$(printf '\t')" read -r kind id try; do
                if [ "$kind" = H ]; then echo "$id"
                else case "$try" in
                    /*) [ -x "$try" ] || echo "$id" ;;
                    *) command -v -- "$try" >/dev/null 2>&1 || echo "$id" ;;
                esac; fi
            done`, "sh", Quickshell.env("XDG_DATA_HOME") || `${Quickshell.env("HOME")}/.local/share`,
            ...(Quickshell.env("XDG_DATA_DIRS") || "/usr/local/share:/usr/share").split(":")]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                text.split("\n").filter(l => l !== "").forEach(id => map[id] = true);
                if (JSON.stringify(map) !== JSON.stringify(root.hidden))   // inchangé : listes et menu non recalculés
                    root.hidden = map;
            }
        }
        onExited: {
            if (root.filtersAgain) {
                root.filtersAgain = false;
                Qt.callLater(() => filters.running = true);
            }
        }
    }

    // Applications changées pendant le calcul des filtres : recalculés à la fin (sinon le changement serait perdu).
    property bool filtersAgain: false

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            if (filters.running)
                root.filtersAgain = true;
            else
                filters.running = true;
        }
    }
}
