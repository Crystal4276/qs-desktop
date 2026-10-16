pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Hyprland
import Quickshell.Io

// Interface unique sur le compositeur (docs/ARCHITECTURE.md § 2).
// Backend choisi au démarrage : Sway (SWAYSOCK) via Quickshell.I3, Hyprland (HYPRLAND_INSTANCE_SIGNATURE) via Quickshell.Hyprland.
// Seul le singleton du backend actif est touché : l'autre ne tente jamais de se connecter.
Singleton {
    id: root

    readonly property string type: Quickshell.env("SWAYSOCK") ? "sway"
        : Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "hyprland" : ""
    readonly property bool isSway: type === "sway"
    readonly property bool isHyprland: type === "hyprland"

    // Sorties actives : { name, description, x, y, width, height, scale, focused }
    // x, y, width, height en px logiques. description = « marque modèle numéro de série ».
    readonly property var outputs: {
        if (isSway)
            return I3.monitors.values.filter(m => m.lastIpcObject.active !== false).map(m => ({
                name: m.name,
                description: [m.lastIpcObject.make, m.lastIpcObject.model, m.lastIpcObject.serial].filter(s => s).join(" "),
                x: m.x, y: m.y, width: m.width, height: m.height,
                scale: m.scale,
                focused: m.focused
            }));
        if (isHyprland)
            return Hyprland.monitors.values.filter(m => !m.lastIpcObject.disabled).map(m => ({
                name: m.name,
                description: m.description,
                x: m.x, y: m.y,
                // taille du mode en px physiques → logiques [rotation : à vérifier en phase 9]
                width: Math.round(m.width / m.scale), height: Math.round(m.height / m.scale),
                scale: m.scale,
                focused: m.focused
            }));
        return [];
    }

    // Espaces de travail existants : { number, name, output, focused, visible, urgent, empty }
    // empty = aucune fenêtre, flottantes comprises (classe `empty` de Waybar).
    readonly property var workspaces: {
        if (isSway)
            return I3.workspaces.values.map(w => ({
                number: w.number,
                name: w.name,
                output: w.monitor?.name ?? "",
                focused: w.focused,
                visible: w.active,
                urgent: w.urgent,
                empty: (w.lastIpcObject.focus ?? []).length === 0
            }));
        if (isHyprland)
            return Hyprland.workspaces.values.filter(w => w.id > 0).map(w => ({
                number: w.id,
                name: w.name,
                output: w.monitor?.name ?? "",
                focused: w.focused,
                visible: w.active,
                urgent: w.urgent,
                empty: w.toplevels.values.length === 0
            }));
        return [];
    }

    readonly property string focusedOutput: isSway ? (I3.focusedMonitor?.name ?? "")
        : isHyprland ? (Hyprland.focusedMonitor?.name ?? "") : ""

    // Titre de la fenêtre focalisée ("" sans fenêtre) et mode / submap actif ("" pour le mode par défaut).
    // Exposés sans widget (parité, ARCHITECTURE § 8 Q4).
    readonly property string activeWindowTitle: isHyprland ? (Hyprland.activeToplevel?.title ?? "") : sway.title
    readonly property string mode: isHyprland ? hyprland.submap : sway.mode

    function output(name: string): var {
        return outputs.find(o => o.name === name) ?? null;
    }

    // Création d'un espace (événement du compositeur) : numéro et sortie où il est né.
    signal workspaceCreated(int number, string output)
    // Une fenêtre reçoit le focus (clic, raccourci…).
    signal windowFocused

    // Placement des espaces (docs/ARCHITECTURE.md § 3.2), en une seule commande :
    //   moves : [{ number, output }]  espaces existants à déplacer ;
    //   show  : [{ number, output }]  espace à afficher sur chaque sortie (créé s'il n'existe pas) ;
    //   focus : numéro de l'espace à focaliser à la fin (0 : aucun).
    function placeWorkspaces(moves: var, show: var, focus: int): void {
        if (isSway) {
            const commands = [];
            for (const m of moves)
                commands.push(`workspace number ${m.number}`, `move workspace to output "${m.output}"`);
            for (const s of show)
                commands.push(`focus output "${s.output}"`, `workspace number ${s.number}`);
            if (focus > 0)
                commands.push(`workspace number ${focus}`);
            if (commands.length > 0) {
                console.info("Compositor: placement des espaces :", commands.join("; "));
                I3.dispatch(commands.join("; "));
            }
        } else if (isHyprland) {
            // [phase 9] règles d'espaces et déplacement sous Hyprland (ARCHITECTURE § 2)
            console.warn("Compositor: placement des espaces pas encore écrit pour Hyprland (phase 9)");
        }
    }

    // Déplace l'espace focalisé sur une autre sortie ; il y reste focalisé.
    function moveFocusedWorkspace(output: string): void {
        if (isSway) {
            console.info("Compositor: placement des espaces :", `move workspace to output "${output}"`);
            I3.dispatch(`move workspace to output "${output}"`);
        } else if (isHyprland) {
            console.warn("Compositor: placement des espaces pas encore écrit pour Hyprland (phase 9)");
        }
    }

    function focusWorkspace(n: int): void {
        if (isSway)
            I3.dispatch(`workspace number ${n}`);
        else if (isHyprland)
            Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ workspace = ${n} })` : `workspace ${n}`);
    }

    // --- Backend Sway : titre et mode ne sont pas exposés par Quickshell.I3 ---

    QtObject {
        id: sway

        property string title: ""
        property string mode: ""
    }

    I3IpcListener {
        subscriptions: root.isSway ? ["window", "mode", "workspace"] : []

        onIpcEvent: event => {
            const data = JSON.parse(event.data);
            if (event.type === "workspace") {
                if (data.change === "init" && data.current)
                    root.workspaceCreated(data.current.num, data.current.output ?? "");
                return;
            }
            if (event.type === "mode") {
                sway.mode = data.change === "default" ? "" : data.change;
                return;
            }
            // Ouverture, fermeture, déplacement : l'état vide des espaces change, I3 ne le relit pas de lui-même.
            if (["new", "close", "move", "floating"].includes(data.change))
                I3.refreshWorkspaces();
            // Sway envoie aussi « focus » pour une fenêtre qui ne le reçoit pas (clic sur un popup de barre) : on vérifie.
            if (data.change === "focus" && data.container?.focused)
                root.windowFocused();
            if ((data.change === "focus" || data.change === "title") && data.container?.focused)
                sway.title = data.container.name ?? "";
            else
                treeQuery.restart();
        }
    }

    // Relecture complète (démarrage, fermeture, changement d'espace) : get_tree pour le titre, get_binding_state pour le mode.
    Timer {
        id: treeQuery
        interval: 50
        running: root.isSway
        onTriggered: {
            swayTree.running = true;
            swayMode.running = true;
        }
    }

    Connections {
        target: root.isSway ? I3 : null
        function onFocusedWorkspaceChanged() {
            treeQuery.restart();
        }
    }

    Process {
        id: swayTree
        command: ["swaymsg", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                const find = node => {
                    if (node.focused)
                        return node;
                    for (const child of [...(node.nodes ?? []), ...(node.floating_nodes ?? [])]) {
                        const found = find(child);
                        if (found)
                            return found;
                    }
                    return null;
                };
                const focused = find(JSON.parse(text));
                sway.title = focused && focused.type !== "workspace" ? (focused.name ?? "") : "";
            }
        }
    }

    Process {
        id: swayMode
        command: ["swaymsg", "-t", "get_binding_state"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = JSON.parse(text).name;
                sway.mode = name === "default" ? "" : name;
            }
        }
    }

    // --- Backend Hyprland : submap ---

    QtObject {
        id: hyprland

        property string submap: ""
    }

    Connections {
        target: root.isHyprland ? Hyprland : null
        function onRawEvent(event) {
            if (event.name === "submap")
                hyprland.submap = event.data;
            else if (event.name === "activewindowv2" && event.data !== "")
                root.windowFocused();
        }
    }
}
