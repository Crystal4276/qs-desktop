pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Interface unique sur le compositeur (docs/ARCHITECTURE.md § 2).
// Backend choisi au démarrage : Sway (SWAYSOCK) via Quickshell.I3, Hyprland (HYPRLAND_INSTANCE_SIGNATURE) via Quickshell.Hyprland.
// Seul le singleton du backend actif est touché : l'autre ne tente jamais de se connecter.
Singleton {
    id: root

    readonly property string type: Quickshell.env("SWAYSOCK") ? "sway"
        : Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "hyprland" : ""
    readonly property bool isSway: type === "sway"
    readonly property bool isHyprland: type === "hyprland"

    // Sorties actives : { name, description, x, y, width, height, scale, powered, hdrCapable, hdr, vrrCapable, vrr }
    // x, y, width, height en px logiques. description = « marque modèle numéro de série ». powered : faux si éteinte par la veille.
    readonly property var outputs: {
        if (isSway)
            return I3.monitors.values.filter(m => m.lastIpcObject.active === true).map(m => ({
                name: m.name,
                description: [m.lastIpcObject.make, m.lastIpcObject.model, m.lastIpcObject.serial].filter(s => s).join(" "),
                x: m.x, y: m.y, width: m.width, height: m.height,
                scale: m.scale,
                powered: m.lastIpcObject.power !== false,
                hdrCapable: m.lastIpcObject.features?.hdr === true,
                hdr: m.lastIpcObject.hdr === true,
                vrrCapable: m.lastIpcObject.features?.adaptive_sync === true,
                vrr: m.lastIpcObject.adaptive_sync_status === "enabled"
            }));
        // Écran en miroir d'un autre (`mirrorOf`, projecteur du laptop) : pas de bloc d'espaces à lui. FALLBACK : sortie fictive
        // d'Hyprland quand aucun écran n'est actif (= aucun écran, comme sous Sway). Moniteur pas encore relu (objet IPC vide,
        // description inconnue) : compté à la relecture, sinon répartition d'un instant sans sa config machine.
        if (isHyprland)
            return Hyprland.monitors.values.filter(m => m.lastIpcObject.id !== undefined && m.name !== "FALLBACK" && !m.lastIpcObject.disabled
                    && (m.lastIpcObject.mirrorOf ?? "none") === "none").map(m => {
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
                    powered: o.dpmsStatus !== false,
                    hdrCapable: o.hardwareDetails?.hdr === true,
                    hdr: o.colorManagementPreset === "hdr",
                    vrrCapable: o.hardwareDetails?.vrrCapable === true,
                    vrr: o.vrr === true
                };
            });
        return [];
    }

    // Espaces de travail existants : { number, name, output, focused, visible, urgent, empty }
    // empty = aucune fenêtre, flottantes comprises (classe `empty` de Waybar).
    // Sway : focus et visibilité lus dans l'objet IPC de l'espace (relu après chaque événement d'espace), pas dans `focused` et
    // `active` de Quickshell, qui ne suivent que les événements « focus » : déplacer le seul espace d'un écran en envoie un faux
    // vers l'espace que Sway y crée, et un espace déplacé d'écran ne change pas `active` (vérifié, Sway 1.12, Quickshell 0.3.2).
    readonly property var workspaces: {
        if (isSway)
            return I3.workspaces.values.map(w => ({
                number: w.number,
                name: w.name,
                output: w.monitor?.name ?? "",
                focused: w.lastIpcObject.focused === true,
                visible: w.lastIpcObject.visible === true,
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

    // Jamais `I3.focusedMonitor` : Quickshell 0.3.2 ne le remet pas à zéro quand l'écran focalisé disparaît sans événement « focus »
    // (son espace, avec fenêtres, passe sur un autre écran) ; le relire fait planter (pile : lookupSingletonProperty → wrap, reproduit
    // sur banc). `focused` d'un moniteur vivant ne suit pas ce pointeur.
    readonly property string focusedOutput: isSway ? (workspaces.find(w => w.focused)?.output ?? I3.monitors.values.find(m => m.focused)?.name ?? "")
        : isHyprland ? (Hyprland.focusedMonitor?.name ?? "") : ""

    function output(name: string): var {
        return outputs.find(o => o.name === name) ?? null;
    }

    // Création d'un espace (événement du compositeur) : numéro et sortie où il est né.
    signal workspaceCreated(int number, string output)

    // Hyprland : écran ajouté ou retiré, avant que `outputs` soit relu. Il a déjà déplacé les espaces (il ramène ceux d'un écran
    // rallumé) : ce qu'on lit jusque-là n'est plus la vue de l'utilisateur.
    signal outputsChanging

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
                    // Nom qui commence par le numéro (« 3 », « 3:web », « 3 web ») : Sway lui donne ce numéro.
                    commands.push(`[workspace="^${m.number}([^0-9]|$)"] move workspace to output "${m.output}"`);
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
            hyprlandBatch(calls, "placement des espaces");
        }
    }

    // Hyprland en config Lua (la seule prise en charge pour le placement) : `hyprctl dispatch X` exécute `hl.dispatch(X)`,
    // qui accepte une fonction ; une seule requête enchaîne donc toutes les actions dans l'ordre (code d'Hyprland 0.56 lu).
    // `label` : libellé du journal, le même que sous Sway pour le placement (compté par scripts/test-outputs.sh).
    function hyprlandBatch(calls: var, label: var): void {
        if (calls.length === 0)
            return;
        if (!Hyprland.usingLua) {
            console.warn("Compositor: actions écrites pour une config Hyprland en Lua seulement");
            return;
        }
        console.info(`Compositor: ${label ?? "actions Hyprland"} :`, calls.join("; "));
        Hyprland.dispatch(`function() ${calls.map(c => `hl.dispatch(${c})`).join(" ")} end`);
    }

    // Déplace l'espace focalisé sur une autre sortie ; il y reste focalisé.
    function moveFocusedWorkspace(output: string): void {
        if (isSway) {
            console.info("Compositor: placement des espaces :", `move workspace to output "${output}"`);
            I3.dispatch(`move workspace to output "${output}"`);
        } else if (isHyprland) {
            hyprlandBatch([`hl.dsp.workspace.move({ monitor = "${output}" })`], "placement des espaces");
        }
    }

    // HDR / VRR sur une liste de sorties. Sway : `output X hdr on|off`, `adaptive_sync on|off`, comme ton `$mod+d`. Hyprland : règles
    // à l'exécution ; une fois activés, reposés après un `hyprctl reload` (réveil, services/Idle.qml), qui les efface : Sway, lui,
    // garde ces réglages. Désactivés : rien n'est reposé, le `reload` rend les valeurs de ta config.
    // HDR : `hl.monitor` partiel (fusionné avec la règle de l'écran, mode et échelle gardés). VRR : `misc.vrr`, seul effectif
    // (le champ `vrr` de `hl.monitor` ne change rien, Hyprland 0.57 vérifié), et la bascule porte sur tous les écrans compatibles.
    function setHdr(names: var, on: bool): void {
        if (isSway && names.length > 0)
            I3.dispatch(names.map(n => `output "${n}" hdr ${on ? "on" : "off"}`).join("; "));
        else if (isHyprland && names.length > 0) {
            // Arrêt : retour au préréglage et à la profondeur d'avant (10 bits si la config de l'écran les donne, comme
            // `render_bit_depth 10` sous Sway, que `hdr off` garde) ; inconnus (HDR déjà actif au démarrage) : sRGB 8 bits.
            const sdr = Object.assign({}, sdrModes);
            if (on)
                for (const n of names) {
                    const o = Hyprland.monitors.values.find(m => m.name === n)?.lastIpcObject;
                    if (o?.colorManagementPreset && o.colorManagementPreset !== "hdr")
                        sdr[n] = { cm: o.colorManagementPreset, bitdepth: /2101010/.test(o.currentFormat ?? "") ? 10 : 8 };
                }
            sdrModes = sdr;
            // Blanc SDR à 203 nits (BT.2408), comme Sway à ma connaissance : Hyprland l'affiche par défaut à 80 nits en HDR, d'où un
            // bureau terne (ton constat du 2026-11-03).
            setRuntimeRule("hdr", names.map(n => `hl.monitor({ output = "${n}", ${on ? `cm = "hdr", bitdepth = 10, sdr_max_luminance = 203`
                : `cm = "${sdr[n]?.cm ?? "srgb"}", bitdepth = ${sdr[n]?.bitdepth ?? 8}`} })`).join(" "), on);
        }
    }

    property var sdrModes: ({})   // Hyprland : { "<écran>": { cm, bitdepth } } relevés avant le passage en HDR

    function setVrr(names: var, on: bool): void {
        if (isSway && names.length > 0)
            I3.dispatch(names.map(n => `output "${n}" adaptive_sync ${on ? "on" : "off"}`).join("; "));
        else if (isHyprland && names.length > 0)
            setRuntimeRule("vrr", `hl.config({ misc = { vrr = ${on ? 1 : 0} } })`, on);
    }

    property var runtimeRules: ({})   // règle de chaque réglage activé, reposée après un reload : { hdr: "<Lua>", vrr: "<Lua>" }

    function setRuntimeRule(name: string, lua: string, keep: bool): void {
        const rules = Object.assign({}, runtimeRules);
        if (keep)
            rules[name] = lua;
        else
            delete rules[name];
        runtimeRules = rules;
        applyRuntimeRules([lua]);
    }

    function applyRuntimeRules(rules: var): void {
        hyprlandBatch(rules.map(r => `function() ${r} end`));
        monitorReread.restart();
    }

    // Relecture des moniteurs après la dernière d'une rafale : HDR et VRR, qu'Hyprland n'annonce pas (une fois le mode appliqué) ;
    // écrans et espaces : quand plusieurs événements se suivent, le dernier écran pouvait rester invisible jusqu'à l'événement
    // d'écran suivant (3 écrans rallumés coup sur coup, sur banc ; relecture perdue si une autre est en cours, déduit, code non lu).
    Timer {
        id: monitorReread
        interval: 500
        onTriggered: Hyprland.refreshMonitors()
    }

    // Déplacement nul du pointeur : Sway envoie l'entrée du pointeur à une surface apparue sous lui (outil de capture). Hyprland : inutile.
    function nudgeCursor(): void {
        if (isSway)
            I3.dispatch("seat - cursor move 0 0");
    }

    // Alimentation des écrans (veille, services/Idle.qml) : `names` vide = tous. Sway : `output X power on|off` ;
    // Hyprland : `hl.dsp.dpms`.
    function setPower(names: var, on: bool): void {
        if (isSway) {
            I3.dispatch((names.length > 0 ? names : ["*"]).map(n => `output ${n === "*" ? "*" : `"${n}"`} power ${on ? "on" : "off"}`).join("; "));
        } else if (isHyprland) {
            const mode = on ? "on" : "off";
            // `action` : avec un autre nom d'argument (`mode`, dans ton hypridle.conf), Hyprland bascule sans le dire (0.57, vérifié).
            hyprlandBatch(names.length > 0 ? names.map(n => `hl.dsp.dpms({ action = "${mode}", monitor = "${n}" })`)
                : [`hl.dsp.dpms({ action = "${mode}" })`]);
        }
    }

    // Quitte la session (Logout) : `swaymsg exit`, `hl.dsp.exit()` (le power menu Rofi appelait swaymsg même sous Hyprland).
    function exit(): void {
        if (isSway)
            I3.dispatch("exit");
        else if (isHyprland)
            hyprlandBatch(["hl.dsp.exit()"]);
    }

    // Ouverture d'une notification (Notifs.open) : l'application demande ensuite l'activation de sa fenêtre (Chromium après
    // avoir choisi l'onglet de la notification, vu sur banc) ; Sway (focus_on_window_activation par défaut : urgent) et
    // Hyprland la marquent seulement urgente. La première fenêtre devenue urgente dans les 3 s est affichée, son espace de
    // travail avec ; les autres fenêtres urgentes ne sont pas touchées.
    property real activationDeadline: 0
    property string activationApp: ""   // vide : n'importe quelle fenêtre

    function focusNextActivation(): void {
        activationDeadline = Date.now() + 3000;
        activationApp = "";
    }

    // Lien d'une web app envoyé au navigateur (dotfiles/webapps/open-link) : il atterrit dans la dernière fenêtre active, peut-être
    // sur un autre espace de travail, qui est affiché. Seulement une fenêtre de `appId` : Discord peut devenir urgent entre-temps.
    IpcHandler {
        target: "compositor"

        function focusNextWindowOf(appId: string): void {
            root.focusNextActivation();
            root.activationApp = appId;
        }
    }

    function takeActivation(appId: string): bool {
        if (Date.now() > activationDeadline || (activationApp !== "" && appId !== activationApp))
            return false;
        activationDeadline = 0;
        return true;
    }

    // Fenêtre de l'application `appId` affichée, son espace de travail avec (carte du tray : Steam) : la plus ancienne déjà là
    // (fenêtre principale) aussitôt, puis celle qu'elle ouvre dans les 3 s (Friends, Settings…). Focus par focusWindow (Sway :
    // commande sans déplacement du pointeur ; Hyprland : Toplevel.activate).
    property string pendingApp: ""
    property var pendingKnown: []

    // Focus sur `toplevel` sans déplacer le pointeur (ta demande du 2026-10-28). Sway : mouse_warping coupé le temps du focus,
    // dans la même commande (exécutée d'un bloc ; rétabli à `output`, défaut de Sway, que ta config ne change pas — à reprendre
    // de dotfiles/sway en phase 10) ; fenêtre désignée par app_id, ou classe sous
    // XWayland, et titre. Hyprland : Toplevel.activate (ta config a no_warps).
    function focusWindow(toplevel: Toplevel): void {
        if (!isSway) {
            toplevel.activate();
            return;
        }
        const quote = text => `"^${text.replace(/[\\^$.*+?()[\]{}|]/g, "\\$&").replace(/"/g, '\\"')}$"`;
        const match = `${quote(toplevel.appId)} title=${quote(toplevel.title)}`;
        I3.dispatch(`mouse_warping none; [app_id=${match}] focus; [class=${match}] focus; mouse_warping output`);
    }

    function appWindows(appId: string): var {
        return ToplevelManager.toplevels.values.filter(t => t.appId.toLowerCase() === appId);
    }

    function showAppWindow(appId: string): void {
        pendingApp = appId.toLowerCase();
        pendingKnown = appWindows(pendingApp);
        if (pendingKnown.length > 0)
            focusWindow(pendingKnown[0]);
        appWindowTimer.restart();
    }

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() {
            if (root.pendingApp === "")
                return;
            const opened = root.appWindows(root.pendingApp).find(t => !root.pendingKnown.includes(t));
            if (opened) {
                root.pendingApp = "";
                appWindowTimer.stop();
                root.focusWindow(opened);
            }
        }
    }

    Timer {
        id: appWindowTimer
        interval: 3000
        onTriggered: root.pendingApp = ""
    }

    // `output` : sortie focalisée d'abord, où l'espace est créé s'il n'existe pas (clic sur un espace persistant d'une barre).
    function focusWorkspace(n: int, output: string): void {
        if (isSway) {
            I3.dispatch(`${output ? `focus output "${output}"; ` : ""}workspace number ${n}`);
        } else if (isHyprland) {
            hyprlandBatch([...(output ? [`hl.dsp.focus({ monitor = "${output}" })`] : []), `hl.dsp.focus({ workspace = ${n} })`]);
        }
    }

    // --- Backend Sway : événements que Quickshell.I3 ne suit pas lui-même ---

    function refreshWorkspaces(): void {
        I3.refreshWorkspaces();
    }

    I3IpcListener {
        id: i3Listener

        // Abonnements posés après le chargement : I3IpcListener se connecte dès qu'ils sont posés, puis recrée sa connexion après le
        // chargement (« I3 event socket disconnected »). Vide à ce moment-là, il ne se connecte qu'une fois (Quickshell 0.3.2).
        property bool loaded: false
        subscriptions: root.isSway && loaded ? ["window", "workspace"] : []
        Component.onCompleted: Qt.callLater(() => i3Listener.loaded = true)

        onIpcEvent: event => {
            // Changement de titre (fréquent : navigateur) : utile seulement si une activation est attendue, pas analysé sinon ; de focus
            // (à chaque fenêtre survolée) : aucun usage.
            if (event.type === "window" && Date.now() > root.activationDeadline && /^\s*\{\s*"change"\s*:\s*"(title|focus)"/.test(event.data))
                return;
            const data = JSON.parse(event.data);
            // Fenêtre déjà urgente avant le clic : Sway n'envoie pas de nouvel « urgent » ; Chromium change alors d'onglet, donc
            // de titre (revue de code, passe 8).
            if (event.type === "window" && ["urgent", "title"].includes(data.change) && data.container?.urgent
                    && !data.container.focused && root.takeActivation(data.container.app_id ?? ""))
                I3.dispatch(`[con_id=${data.container.id}] focus`);
            if (event.type === "workspace") {
                if (data.change === "init" && data.current)
                    root.workspaceCreated(data.current.num, data.current.output ?? "");
                // Focus et visibilité relus après chaque événement d'espace : ceux que portent les événements sont souvent faux
                // (Sway 1.12, vérifié). Une relecture pour tous les événements d'une même rafale.
                Qt.callLater(root.refreshWorkspaces);
                return;
            }
            // Ouverture, fermeture, déplacement : l'état vide des espaces change, I3 ne le relit pas de lui-même.
            if (["new", "close", "move", "floating"].includes(data.change))
                Qt.callLater(root.refreshWorkspaces);
        }
    }

    // --- Backend Hyprland ---

    Connections {
        target: root.isHyprland ? Hyprland : null
        function onRawEvent(event) {
            if (event.name === "createworkspacev2") {
                // « ID,NOM » ; l'écran n'est connu qu'après relecture : "" laisse Outputs vérifier 100 ms plus tard.
                const id = parseInt(event.data);
                if (id > 0)
                    root.workspaceCreated(id, Hyprland.workspaces.values.find(w => w.id === id)?.monitor?.name ?? "");
            }
            // Comme sous Sway : un espace déplacé ne met pas à jour l'espace affiché par chaque écran (Quickshell 0.3.2, code lu).
            else if (event.name === "moveworkspacev2") {
                Hyprland.refreshMonitors();
                monitorReread.restart();
            } else if (["monitoradded", "monitorremoved"].includes(event.name)) {
                root.outputsChanging();
                monitorReread.restart();
            }
            else if (event.name === "configreloaded")
                root.applyRuntimeRules(Object.values(root.runtimeRules));
            else if (event.name === "urgent" && root.takeActivation(Hyprland.toplevels.values.find(t => t.address === event.data)?.wayland?.appId ?? ""))   // « ADRESSE » (hexadécimal, sans 0x, vérifié)
                hyprlandBatch([`hl.dsp.focus({ window = "address:0x${event.data}" })`]);
        }
    }
}
