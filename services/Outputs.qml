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
        const configured = outs.find(o => o.description === Settings.primaryOutput);
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
        if (imposed) {
            for (const o of outs)
                result[o.name] = imposed[o.description];
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
            const map = {};
            for (const w of Compositor.workspaces)
                if (w.visible)
                    map[w.output] = w.number;
            root.remember(map, Compositor.workspaces.find(w => w.focused)?.number ?? 0);
        }
    }

    Connections {
        target: Compositor
        function onWorkspacesChanged() {
            if (!settle.running)
                snapshot.restart();
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
    // Focalisé (`$mod+N`) : simplement déplacé, il reste focalisé. Créé en arrière-plan (fenêtre envoyée vers
    // un espace inexistant) : déplacé, puis le focus revient où il était. Aucune correction ne crée d'espace.
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
            for (const n of numbers) {
                const w = workspaces.find(w => w.number === n);
                if (!w || w.output === root.homes[n])
                    continue;
                if (w.focused)
                    Compositor.moveFocusedWorkspace(root.homes[n]);
                else
                    Compositor.placeWorkspaces([{ number: n, output: root.homes[n] }], [], focused ? focused.number : 0);
            }
        }
    }

    // Place tous les espaces 1–9 sur l'écran de leur bloc, sans perdre l'espace visible de chaque écran ni le focus.
    function apply(): void {
        const outs = Compositor.outputs;
        if (outs.length === 0)
            return;
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
        const focused = workspaces.find(w => w.number === previous?.focus) ?? workspaces.find(w => w.focused);
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
            const existing = block.filter(n => workspaces.some(w => w.number === n)).sort((a, b) => a - b);
            let wanted;
            if (remembered !== undefined)
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
        if (focused)
            intended[finalOutput(focused)] = focused.number;
        // Mémorisé tout de suite : un nouveau changement d'écrans peut arriver avant la prochaine lecture.
        remember(intended, focused ? focused.number : 0);
        lastPlaced = intended;

        if (moves.length === 0 && show.length === 0)
            return;
        Compositor.placeWorkspaces(moves, show, focused ? focused.number : 0);
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
    }

    function blockFor(name: string): var {
        return blocks[name] ?? [];
    }

    function isPrimary(name: string): bool {
        return primary?.name === name;
    }
}
