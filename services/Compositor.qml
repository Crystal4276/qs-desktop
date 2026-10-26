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

    // Sorties actives : { name, description, x, y, width, height, scale, focused, hdrCapable, hdr, vrrCapable, vrr }
    // x, y, width, height en px logiques. description = « marque modèle numéro de série ».
    // HDR et VRR (bascules du panneau de réglages) : Sway seulement pour l'instant, Hyprland en phase 9.
    readonly property var outputs: {
        if (isSway)
            return I3.monitors.values.filter(m => m.lastIpcObject.active !== false).map(m => ({
                name: m.name,
                description: [m.lastIpcObject.make, m.lastIpcObject.model, m.lastIpcObject.serial].filter(s => s).join(" "),
                x: m.x, y: m.y, width: m.width, height: m.height,
                scale: m.scale,
                focused: m.focused,
                hdrCapable: m.lastIpcObject.features?.hdr === true,
                hdr: m.lastIpcObject.hdr === true,
                vrrCapable: m.lastIpcObject.features?.adaptive_sync === true,
                vrr: m.lastIpcObject.adaptive_sync_status === "enabled"
            }));
        if (isHyprland)
            return Hyprland.monitors.values.filter(m => !m.lastIpcObject.disabled).map(m => {
                const o = m.lastIpcObject;
                // Taille du mode en px physiques → logiques ; transformations impaires (90°, 270°…) : largeur et hauteur échangées.
                const w = Math.round(m.width / m.scale), h = Math.round(m.height / m.scale);
                const rotated = (o.transform ?? 0) % 2 === 1;
                return {
                    name: m.name,
                    // Même composition que sous Sway (make, model, serial de `hyprctl monitors`) : mêmes clés dans hosts/*.json.
                    description: [o.make, o.model, o.serial].filter(s => s).join(" "),
                    x: m.x, y: m.y,
                    width: rotated ? h : w, height: rotated ? w : h,
                    scale: m.scale,
                    focused: m.focused,
                    hdrCapable: false,
                    hdr: false,
                    vrrCapable: false,
                    vrr: false
                };
            });
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
            // Espace qui a des fenêtres : déplacé par un critère sur elles, sans s'y rendre d'abord. `workspace number N` puis
            // `move workspace` détruirait l'espace focalisé s'il est vide (fenêtre qu'on vient d'envoyer ailleurs), et le retour
            // du focus le recréerait sur le mauvais écran (vérifié dans un Sway isolé). Espace vide : il faut s'y rendre.
            for (const m of moves) {
                if (workspaces.find(w => w.number === m.number)?.empty === false)
                    commands.push(`[workspace="^${m.number}(:|$)"] move workspace to output "${m.output}"`);
                else
                    commands.push(`workspace number ${m.number}`, `move workspace to output "${m.output}"`);
            }
            for (const s of show)
                commands.push(`focus output "${s.output}"`, `workspace number ${s.number}`);
            if (focus > 0)
                commands.push(`workspace number ${focus}`);
            if (commands.length > 0) {
                console.info("Compositor: placement des espaces :", commands.join("; "));
                I3.dispatch(commands.join("; "));
            }
        } else if (isHyprland) {
            const calls = [];
            for (const m of moves)
                calls.push(`hl.dsp.workspace.move({ workspace = ${m.number}, monitor = "${m.output}" })`);
            for (const s of show)
                calls.push(`hl.dsp.focus({ monitor = "${s.output}" })`, `hl.dsp.focus({ workspace = ${s.number} })`);
            if (focus > 0)
                calls.push(`hl.dsp.focus({ workspace = ${focus} })`);
            hyprlandBatch(calls);
        }
    }

    // Hyprland en config Lua (la seule prise en charge pour le placement) : `hyprctl dispatch X` exécute `hl.dispatch(X)`,
    // qui accepte une fonction ; une seule requête enchaîne donc toutes les actions dans l'ordre (code d'Hyprland 0.56 lu).
    function hyprlandBatch(calls: var): void {
        if (calls.length === 0)
            return;
        if (!Hyprland.usingLua) {
            console.warn("Compositor: placement des espaces écrit pour une config Hyprland en Lua seulement");
            return;
        }
        console.info("Compositor: actions Hyprland :", calls.join("; "));
        Hyprland.dispatch(`function() ${calls.map(c => `hl.dispatch(${c})`).join(" ")} end`);
    }

    // Déplace l'espace focalisé sur une autre sortie ; il y reste focalisé.
    function moveFocusedWorkspace(output: string): void {
        if (isSway) {
            console.info("Compositor: placement des espaces :", `move workspace to output "${output}"`);
            I3.dispatch(`move workspace to output "${output}"`);
        } else if (isHyprland) {
            hyprlandBatch([`hl.dsp.workspace.move({ monitor = "${output}" })`]);
        }
    }

    // HDR / VRR sur une liste de sorties (Sway : `output X hdr on|off`, `adaptive_sync on|off`, comme ton `$mod+d`).
    function setHdr(names: var, on: bool): void {
        if (isSway && names.length > 0)
            I3.dispatch(names.map(n => `output "${n}" hdr ${on ? "on" : "off"}`).join("; "));
    }

    function setVrr(names: var, on: bool): void {
        if (isSway && names.length > 0)
            I3.dispatch(names.map(n => `output "${n}" adaptive_sync ${on ? "on" : "off"}`).join("; "));
    }

    // Alimentation des écrans (veille, services/Idle.qml) : `names` vide = tous. Sway : `output X power on|off` ;
    // Hyprland : `hl.dsp.dpms` (config Lua) ou `dpms` (config classique), comme hypridle.
    function setPower(names: var, on: bool): void {
        if (isSway) {
            I3.dispatch((names.length > 0 ? names : ["*"]).map(n => `output ${n === "*" ? "*" : `"${n}"`} power ${on ? "on" : "off"}`).join("; "));
        } else if (isHyprland) {
            const mode = on ? "on" : "off";
            if (Hyprland.usingLua)
                hyprlandBatch(names.length > 0 ? names.map(n => `hl.dsp.dpms({ mode = "${mode}", monitor = "${n}" })`)
                    : [`hl.dsp.dpms({ mode = "${mode}" })`]);
            else
                (names.length > 0 ? names : [""]).forEach(n => Hyprland.dispatch(`dpms ${mode}${n ? ` ${n}` : ""}`));
        }
    }

    // Quitte la session (Logout) : `swaymsg exit`, `hl.dsp.exit()` (le power menu Rofi appelait swaymsg même sous Hyprland).
    function exit(): void {
        if (isSway)
            I3.dispatch("exit");
        else if (isHyprland)
            Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.exit()" : "exit");
    }

    // Ouverture d'une notification (Notifs.open) : l'application demande ensuite l'activation de sa fenêtre (Chromium après
    // avoir choisi l'onglet de la notification, vu sur banc) ; Sway (focus_on_window_activation par défaut : urgent) et
    // Hyprland la marquent seulement urgente. La première fenêtre devenue urgente dans les 3 s est affichée, son espace de
    // travail avec ; les autres fenêtres urgentes ne sont pas touchées.
    property real activationDeadline: 0

    function focusNextActivation(): void {
        activationDeadline = Date.now() + 3000;
    }

    function takeActivation(): bool {
        if (Date.now() > activationDeadline)
            return false;
        activationDeadline = 0;
        return true;
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
        id: i3Listener

        // Abonnements posés après le chargement : I3IpcListener se connecte dès qu'ils sont posés, puis recrée sa connexion après le
        // chargement (« I3 event socket disconnected »). Vide à ce moment-là, il ne se connecte qu'une fois (Quickshell 0.3.2).
        property bool loaded: false
        subscriptions: root.isSway && loaded ? ["window", "mode", "workspace"] : []
        Component.onCompleted: Qt.callLater(() => i3Listener.loaded = true)

        onIpcEvent: event => {
            const data = JSON.parse(event.data);
            // Fenêtre déjà urgente avant le clic : Sway n'envoie pas de nouvel « urgent » ; Chromium change alors d'onglet, donc
            // de titre (revue de code, passe 8).
            if (event.type === "window" && ["urgent", "title"].includes(data.change) && data.container?.urgent
                    && !data.container.focused && root.takeActivation())
                I3.dispatch(`[con_id=${data.container.id}] focus`);
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
            else if (event.name === "createworkspacev2") {
                // « ID,NOM » ; l'écran n'est connu qu'après relecture : "" laisse Outputs vérifier 100 ms plus tard.
                const id = parseInt(event.data);
                if (id > 0)
                    root.workspaceCreated(id, Hyprland.workspaces.values.find(w => w.id === id)?.monitor?.name ?? "");
            }
            else if (event.name === "activewindowv2" && event.data !== "")
                root.windowFocused();
            else if (event.name === "urgent" && root.takeActivation())   // « ADRESSE » (hexadécimal, sans 0x) ; à vérifier en phase 9
                Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ window = "address:0x${event.data}" })` : `focuswindow address:0x${event.data}`);
        }
    }
}
