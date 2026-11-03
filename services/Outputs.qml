pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Écrans actifs, écran principal, ordre des écrans et répartition des espaces de travail (docs/ARCHITECTURE.md § 3.2, § 3.3).
// Seul mécanisme de répartition : aucune ligne `workspace N output …` dans les configs compositeur.
//  - changement d'écrans : 500 ms après le dernier événement, chaque espace mal placé rejoint l'écran de son bloc ;
//  - création d'un espace sur un autre écran que celui de son bloc (ex. `$mod+3` depuis l'écran de gauche) : il y est déplacé.
// Un espace déplacé à la main reste où il est jusqu'au prochain changement d'écrans.
Singleton {
    id: root

    // Principal : celui de la config machine s'il est actif, sinon le plus grand en surface logique (égalité : le plus à gauche).
    readonly property var primary: {
        const outs = Compositor.outputs;
        // Pas de principal configuré ("" par défaut) : ne surtout pas élire un écran qui ne donne ni marque ni modèle.
        const configured = Settings.primaryOutput !== "" ? outs.find(o => o.description === Settings.primaryOutput) : null;
        if (configured)
            return configured;
        return outs.reduce((best, o) => {
            if (!best)
                return o;
            const area = o.width * o.height, bestArea = best.width * best.height;
            return area > bestArea || (area === bestArea && o.x < best.x) ? o : best;
        }, null);
    }

    // Principal d'abord, puis les autres de gauche à droite (x, puis y).
    readonly property var ordered: {
        const p = primary;
        const others = Compositor.outputs.filter(o => o.name !== p?.name).sort((a, b) => a.x - b.x || a.y - b.y);
        return p ? [p, ...others] : others;
    }

    readonly property int workspaceCount: 9

    // Bloc d'espaces de chaque écran : { "<nom de sortie>": [1, 2, 3], … }.
    // Répartition imposée par la config machine si elle couvre exactement les écrans actifs (par description),
    // sinon règle générale : blocs de floor(9 / n), le reste (+1) aux premiers écrans de `ordered`.
    readonly property var blocks: {
        const outs = ordered;
        const result = {};
        const descriptions = outs.map(o => o.description).sort().join("\n");
        const imposed = Settings.workspaceLayouts.find(l => Object.keys(l).sort().join("\n") === descriptions);
        // Imposée : les numéros 1–9, chacun sur un seul écran ; sinon ignorée (règle générale).
        const numbers = imposed ? Object.values(imposed).flat() : [];
        const valid = imposed && Object.values(imposed).every(Array.isArray) && numbers.length === workspaceCount
            && numbers.every(n => Number.isInteger(n) && n >= 1 && n <= workspaceCount) && new Set(numbers).size === numbers.length;
        if (imposed && !valid)
            console.warn("Outputs: répartition imposée invalide (chaque numéro 1–9 une fois), règle générale :", JSON.stringify(imposed));
        if (valid) {
            for (const o of outs)
                result[o.name] = [...imposed[o.description]].sort((a, b) => a - b);
            return result;
        }
        const n = outs.length;
        let next = 1;
        outs.forEach((o, i) => {
            const size = Math.floor(workspaceCount / n) + (i < workspaceCount % n ? 1 : 0);
            result[o.name] = Array.from({ length: size }, (_, k) => next + k);
            next += size;
        });
        return result;
    }

    // Écran de chaque espace 1–9 : { 1: "DP-2", … }
    readonly property var homes: {
        const result = {};
        for (const name in blocks)
            for (const n of blocks[name])
                result[n] = name;
        return result;
    }

    // Change quand l'ensemble des écrans actifs ou leur disposition change (pas au simple réveil d'un écran).
    readonly property string layoutKey: Compositor.outputs.map(o => `${o.name}|${o.description}|${o.x},${o.y}|${o.width}x${o.height}`).sort().join(";")

    // Réappliquée aussi quand la répartition change sans changement d'écrans (config machine modifiée).
    readonly property string blocksKey: JSON.stringify(blocks)

    onLayoutKeyChanged: {
        console.info("Outputs: écrans actifs :", Compositor.outputs.map(o => o.name).join(", ") || "aucun");
        snapshot.stop();
        settle.restart();
    }
    onBlocksKeyChanged: {
        snapshot.stop();
        settle.restart();
    }

    // Vue de chaque configuration d'écrans : { "<layoutKey>": { visible: { "DP-1": 4, … }, focus: 2 } }.
    // Revenir à une configuration déjà vue (écran rallumé, rebranché) restaure la vue qu'elle avait.
    // Lu avant un changement d'écrans, car le compositeur redistribue lui-même les espaces d'un écran retiré
    // avant que la répartition ne s'applique. Mis à jour 300 ms après le dernier changement d'espaces, hors placement.
    property var visibleByLayout: ({})
    property string currentLayout: ""   // configuration à laquelle la vue mémorisée correspond
    property var lastPlaced: ({})       // vue posée par le dernier placement : ce qui en diffère a été choisi par l'utilisateur
    function remember(visible: var, focus: int): void {
        const all = Object.assign({}, visibleByLayout);
        all[currentLayout] = { visible: visible, focus: focus };
        visibleByLayout = all;
    }

    Timer {
        id: snapshot
        interval: 300
        onTriggered: {
            // Aucun écran actif (capot fermé sans écran externe) : apply() n'a rien fait, la vue mémorisée est celle d'avant.
            if (Compositor.outputs.length === 0)
                return;
            const map = {};
            for (const w of Compositor.workspaces)
                if (w.visible)
                    map[w.output] = w.number;
            root.remember(map, Compositor.workspaces.find(w => w.focused)?.number ?? 0);
            // Espace changé par l'utilisateur pendant la fenêtre de la vue de départ ($mod+5 juste après la connexion) : elle ne
            // s'impose plus. Le focus seul ne compte pas : le compositeur le déplace de lui-même (écran sous le pointeur).
            if (root.homeRequested && Object.keys(map).some(o => root.lastPlaced[o] !== undefined && map[o] !== root.lastPlaced[o]))
                root.homeRequested = false;
        }
    }

    Connections {
        target: Compositor
        function onWorkspacesChanged() {
            if (!settle.running)
                snapshot.restart();
        }
        function onOutputsChanging() {
            snapshot.stop();
            settle.restart();
        }
    }

    // Anti-rebond : un branchement produit plusieurs événements, le compositeur applique ses règles d'écran entre-temps.
    Timer {
        id: settle
        interval: 500
        running: true   // première répartition au démarrage
        onTriggered: root.apply()
    }

    // Espace créé hors de son écran : traité 100 ms plus tard, quand le focus est à jour.
    // Focalisé (`$mod+N`) : déplacé, il reste focalisé ; son écran de départ reprend l'espace qu'il affichait. Créé en
    // arrière-plan (fenêtre envoyée vers un espace inexistant) : déplacé, son écran d'arrivée garde l'espace qu'il affichait,
    // et le focus revient où il était.
    // Bouche-trou (vide, affiché, non focalisé : Sway en crée un, au premier numéro libre, sur un écran qu'on vient de vider) :
    // pas déplacé, Sway en recréerait un sans fin ; l'écran affiche à la place un espace de son bloc, qui y est chez lui.
    property var pendingCreated: []

    Connections {
        target: Compositor
        function onWorkspaceCreated(number, output) {
            if (root.homes[number] === undefined || root.homes[number] === output)
                return;
            root.pendingCreated = [...root.pendingCreated, number];
            created.restart();
        }
    }

    Timer {
        id: created
        interval: 100
        onTriggered: {
            const numbers = root.pendingCreated;
            root.pendingCreated = [];
            if (settle.running)
                return;   // la répartition complète va passer
            const workspaces = Compositor.workspaces;
            const focused = workspaces.find(w => w.focused);
            for (const n of new Set(numbers)) {
                const w = workspaces.find(w => w.number === n);
                if (!w || w.output === root.homes[n])
                    continue;
                if (w.focused) {
                    // L'écran de départ reprend l'espace qu'il affichait (Sway l'a détruit s'il était vide), s'il n'est pas ailleurs.
                    const before = root.visibleByLayout[root.currentLayout]?.visible?.[w.output];
                    if (before !== undefined && before !== n && root.homes[before] === w.output
                            && !workspaces.some(x => x.number === before && x.output !== w.output))
                        Compositor.placeWorkspaces([{ number: n, output: root.homes[n] }], [{ number: before, output: w.output }], n);
                    else
                        Compositor.moveFocusedWorkspace(root.homes[n]);
                    continue;
                }
                // Seul espace de son écran (`visible` n'est pas encore à jour pour un espace qui vient de naître) : l'écran affiche
                // ensuite le premier espace de son bloc qui n'est pas ailleurs (sans bloc : rien n'est fait). Vide, c'est un
                // bouche-trou : il n'est pas déplacé et disparaît dès qu'il est masqué.
                const alone = !workspaces.some(x => x.number !== n && x.output === w.output);
                const own = alone ? root.blockFor(w.output).find(k => !workspaces.some(x => x.number === k && x.output !== w.output)) : undefined;
                const moves = alone && w.empty ? [] : [{ number: n, output: root.homes[n] }];
                const show = own !== undefined ? [{ number: own, output: w.output }] : [];
                // Sway affiche l'espace qu'il vient de déplacer : l'écran d'arrivée reprend celui qu'il montrait.
                const shown = workspaces.find(x => x.visible && x.output === root.homes[n]);
                if (moves.length > 0 && shown)
                    show.push({ number: shown.number, output: root.homes[n] });
                if (moves.length > 0 || show.length > 0)
                    Compositor.placeWorkspaces(moves, show, focused ? focused.number : 0);
            }
        }
    }

    // Début de session (scripts/desktop.sh, une seule fois par session) : chaque écran affiche le premier espace de son bloc
    // (1 / 4 / 7 ici), focus sur l'écran principal. Demandé avant la première répartition : fait par elle. Vaut pour toutes
    // les répartitions des 10 s suivantes : au démarrage, les écrans peuvent arriver l'un après l'autre (Hyprland, NVIDIA), à
    // plus de 500 ms d'écart ; sinon un écran arrivé après la première répartition afficherait un espace déjà ouvert de son
    // bloc (5, Discord) plutôt que le premier. Finie plus tôt si l'utilisateur change d'espace entre-temps (snapshot).
    property bool homeRequested: false

    function home(): void {
        homeRequested = true;
        homeWindow.restart();
        if (!settle.running)
            apply();
    }

    Timer {
        id: homeWindow
        interval: 10000
        onTriggered: root.homeRequested = false
    }

    // Place tous les espaces 1–9 sur l'écran de leur bloc, sans perdre l'espace visible de chaque écran ni le focus.
    function apply(): void {
        const outs = Compositor.outputs;
        if (outs.length === 0)
            return;
        const home = homeRequested;
        const workspaces = Compositor.workspaces;
        // Vue à retrouver, écran par écran : l'espace que l'utilisateur y a choisi depuis le dernier placement ;
        // sinon la vue de cette configuration si elle a déjà existé (écran rallumé) ; sinon celle d'avant le changement.
        // Le focus est celui d'avant le changement : le compositeur l'a peut-être déjà déplacé (écran focalisé retiré).
        const previous = visibleByLayout[currentLayout];
        const seen = visibleByLayout[layoutKey]?.visible ?? {};
        const candidates = name => {
            const before = previous?.visible?.[name];
            const chosen = before !== undefined && before !== lastPlaced[name];
            return (chosen ? [before, seen[name]] : [seen[name], before]).filter(n => n !== undefined);
        };
        currentLayout = layoutKey;
        const focused = home ? null : workspaces.find(w => w.number === previous?.focus) ?? workspaces.find(w => w.focused);
        const isOurs = n => homes[n] !== undefined;

        const moves = workspaces.filter(w => isOurs(w.number) && w.output !== homes[w.number])
            .map(w => ({ number: w.number, output: homes[w.number] }));
        const finalOutput = w => isOurs(w.number) ? homes[w.number] : w.output;

        // Espace à afficher sur chaque écran : le premier candidat ci-dessus qui y est chez lui (recréé s'il était vide
        // et a été détruit) ; sans aucun souvenir de l'écran, celui qu'il affiche s'il y est chez lui ;
        // sinon le premier espace existant de son bloc, sinon le premier de son bloc (créé).
        const show = [];
        const intended = {};   // espace affiché sur chaque écran une fois le placement fait
        for (const o of outs) {
            const block = blockFor(o.name);
            const shownNow = workspaces.find(w => w.visible && w.output === o.name);
            const remembered = candidates(o.name).find(n => homes[n] === o.name
                || (!isOurs(n) && workspaces.some(w => w.number === n && w.output === o.name)));
            const existing = block.filter(n => workspaces.some(w => w.number === n));
            let wanted;
            // Écran d'arrivée de l'espace focalisé : il l'affiche. Un autre espace masquerait celui-ci, que Sway détruirait
            // s'il est vide, et le focus final le recréerait sur un autre écran.
            if (home && block.length > 0)
                wanted = block[0];
            else if (focused && finalOutput(focused) === o.name)
                wanted = focused.number;
            else if (remembered !== undefined)
                wanted = remembered;
            else if (candidates(o.name).length === 0 && shownNow && homes[shownNow.number] === o.name)
                wanted = shownNow.number;   // aucun souvenir de cet écran (démarrage, nouvel écran) : rien à changer
            else if (block.length > 0)
                wanted = existing[0] ?? block[0];
            else if (shownNow)
                wanted = shownNow.number;   // plus d'écrans que d'espaces : cet écran n'a pas de bloc
            // Un espace qui arrive sur cet écran ou qui en part (Sway le focalise d'abord ici pour le déplacer)
            // change l'espace affiché : il faut alors le rétablir.
            const disturbed = moves.some(m => m.output === o.name || workspaces.find(w => w.number === m.number)?.output === o.name);
            if (wanted !== undefined && (disturbed || shownNow?.number !== wanted))
                show.push({ number: wanted, output: o.name });
            if (wanted !== undefined)
                intended[o.name] = wanted;
        }
        const focus = home ? (blockFor(primary?.name ?? "")[0] ?? 0) : focused ? focused.number : 0;
        // Mémorisé tout de suite : un nouveau changement d'écrans peut arriver avant la prochaine lecture.
        remember(intended, focus);
        lastPlaced = intended;

        if (moves.length === 0 && show.length === 0 && !home)
            return;
        Compositor.placeWorkspaces(moves, show, focus);
    }

    // `$mod+N` et `$mod+Ctrl+N` (configs compositeur, dotfiles/) : un espace qui n'existe pas encore est créé directement sur
    // l'écran de son bloc, sans détour visible par l'écran focalisé. Existant, déplacé à la main compris : rejoint là où il est.
    function focus(n: int): void {
        const exists = Compositor.workspaces.some(w => w.number === n);
        if (exists)
            Compositor.focusWorkspace(n, "");
        else
            Compositor.createWorkspace(n, homes[n] ?? "");
    }

    function moveWindow(n: int): void {
        const exists = Compositor.workspaces.some(w => w.number === n);
        Compositor.moveWindowToWorkspace(n, exists ? "" : homes[n] ?? "");
    }

    IpcHandler {
        target: "outputs"

        // Répartition calculée, en JSON : { "<sortie>": [espaces] } (utilisé par scripts/test-outputs.sh)
        function blocks(): string {
            return JSON.stringify(root.blocks);
        }

        // Réapplique la répartition tout de suite.
        function apply(): void {
            root.apply();
        }

        // Début de session : premier espace du bloc de chaque écran (scripts/desktop.sh).
        function home(): void {
            root.home();
        }

        // Espace N affiché, créé sur son écran s'il n'existe pas ($mod+N).
        function focus(n: int): void {
            root.focus(n);
        }

        // Fenêtre focalisée envoyée sur l'espace N, qui est affiché ($mod+Ctrl+N).
        function moveWindow(n: int): void {
            root.moveWindow(n);
        }
    }

    function blockFor(name: string): var {
        return blocks[name] ?? [];
    }

    function isPrimary(name: string): bool {
        return primary?.name === name;
    }

    // Écran où ouvrir une fenêtre (lanceur, sélecteur de fonds, polkit, moniteur) : l'écran focalisé, sinon l'écran principal
    // (focalisé inconnu : démarrage, écran retiré), sinon le premier.
    function focusedScreen(): ShellScreen {
        return Quickshell.screens.find(s => s.name === Compositor.focusedOutput)
            ?? Quickshell.screens.find(s => s.name === primary?.name) ?? Quickshell.screens[0] ?? null;
    }
}
