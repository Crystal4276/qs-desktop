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

    Process {
        id: externalOpens
        command: ["python3", Quickshell.shellPath("scripts/open-origin.py")]
        running: (root.isSway || root.isHyprland) && Quickshell.env("QS_TEST") !== "1"
        onRunningChanged: if (!running) externalOpensRetry.restart()
    }
    Timer {
        id: externalOpensRetry
        interval: 5000
        onTriggered: if ((root.isSway || root.isHyprland) && Quickshell.env("QS_TEST") !== "1") externalOpens.running = true
    }

    // Description d'un écran (`make`, `model`, `serial` de l'IPC), identique sous Sway et Hyprland : clé de hosts/*.json, des
    // fonds par écran et des fonds exportés pour l'écran de connexion (qui tourne sous Sway, même pour une session Hyprland).
    // Sans le « Unknown » que Sway met pour un champ absent de l'EDID ni les virgules, qu'Hyprland retire de ses descriptions
    // (`desc:` de dotfiles/hypr/hosts/) : dalle de laptop « China Star Optoelectronics Technology Co. Ltd 0x1471 » sous les deux.
    function describe(o: var): string {
        return [o.make, o.model, o.serial].filter(s => s && s !== "Unknown").join(" ").replace(/,/g, "");
    }

    // Sorties actives : { name, description, x, y, width, height, scale, powered, hdrCapable, hdr, vrrCapable, vrr }
    // x, y, width, height en px logiques. description = « marque modèle numéro de série ». powered : faux si éteinte par la veille.
    readonly property var outputs: {
        if (isSway)
            return I3.monitors.values.filter(m => m.lastIpcObject.active === true).map(m => ({
                name: m.name,
                description: root.describe(m.lastIpcObject),
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
                    description: root.describe(o),
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

    // Connected physical displays, including disabled panels and mirrors (independent of DPMS).
    property var connectedOutputs: []
    property bool connectedDirty: false
    signal connectedOutputsReady(bool success)
    signal configurationReloaded

    function requestConnectedOutputs(): void {
        if (connectedQuery.running) { connectedDirty = true; return; }
        connectedQuery.running = true;
    }
    Process {
        id: connectedQuery
        command: root.isSway ? ["timeout", "2", "swaymsg", "-r", "-t", "get_outputs"]
            : ["timeout", "2", "hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector { id: connectedReply }
        onExited: code => {
            if (root.connectedDirty) {
                root.connectedDirty = false;
                connectedQuery.running = true;
                return;
            }
            try {
                const rows = JSON.parse(connectedReply.text);
                if (code !== 0 || !Array.isArray(rows) || !rows.every(o => typeof o.name === "string"))
                    throw new Error("invalid connected display snapshot");
                root.connectedOutputs = rows.filter(o => !/^(HEADLESS|WAYLAND|X11|FALLBACK)/i.test(o.name))
                    .filter(o => !o.non_desktop && (!root.isHyprland || !o.hardwareDetails?.backend || o.hardwareDetails.backend === "drm"))
                    .map(o => ({name: o.name, internal: /^(eDP|LVDS|DSI)[-0-9]/i.test(o.name),
                        enabled: root.isSway ? o.active === true : o.disabled !== true}));
                root.connectedOutputsReady(true);
            } catch (error) {
                console.warn("Compositor: connected displays unavailable", error);
                root.connectedOutputsReady(false);
            }
        }
    }

    // A shell crash loses the saved rule; reload the configured layout rather than guess the panel's scale.
    function restoreInternalOutputs(names: var): void {
        if (isHyprland) Quickshell.execDetached(["hyprctl", "reload"]);
        else for (const name of names) setOutputEnabled(name, true, "");
    }
    function lidRestoreRule(name: string): string {
        return isHyprland ? ruleKey(name) : "";
    }
    function setOutputEnabled(name: string, enabled: bool, restoreRule: string): void {
        if (isSway)
            I3.dispatch(`output ${luaString(name)} ${enabled ? "enable" : "disable"}`);
        else if (isHyprland)
            hyprlandBatch([`function() hl.monitor({ ${restoreRule}, disabled = ${!enabled} }) end`], "activation des sorties");
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
        if (isHyprland) {
            const native = Hyprland.workspaces.values.filter(w => w.id > 0).map(w => ({
                number: w.id,
                name: w.name,
                output: w.monitor?.name ?? "",
                focused: w.focused,
                visible: w.active,
                urgent: w.urgent,
                empty: w.toplevels.values.length === 0
            }));
            // QS 0.3.2 can discard a workspace created during its initial query.
            // Ordinary refreshWorkspaces() cannot recreate it. Supplement only missing/incomplete records.
            const missing = workspaceSnapshot.filter(w => !native.some(n => n.number === w.id && n.output !== ""));
            return native.filter(n => !missing.some(w => w.id === n.number)).concat(missing.map(w => ({
                number: w.id, name: w.name, output: w.monitor,
                focused: Hyprland.focusedWorkspace?.id === w.id,
                visible: Hyprland.monitors.values.some(m => m.activeWorkspace?.id === w.id),
                urgent: false, empty: w.windows === 0
            })));
        }
        return [];
    }

    // Bounded, event-driven verification before placement, never polling at idle.
    property var workspaceSnapshot: []
    property bool snapshotDirty: false
    property int snapshotAttempts: 0
    signal workspaceSnapshotReady(bool success)

    function requestWorkspaceSnapshot(): void {
        if (workspaceQuery.running) {
            snapshotDirty = true;
            return;
        }
        snapshotRetry.stop();
        snapshotAttempts = 0;
        workspaceQuery.running = true;
    }

    Process {
        id: workspaceQuery
        command: ["timeout", "2", "hyprctl", "-j", "workspaces"]
        stdout: StdioCollector { id: workspaceReply }
        onExited: (code, status) => {
            if (root.snapshotDirty) {
                root.snapshotDirty = false;
                workspaceQuery.running = true;
                return;
            }
            let rows;
            try {
                rows = JSON.parse(workspaceReply.text);
                if (code !== 0 || !Array.isArray(rows) || !rows.every(w => Number.isInteger(w.id)
                        && typeof w.name === "string" && typeof w.monitor === "string" && Number.isInteger(w.windows)))
                    throw new Error("invalid workspace snapshot");
            } catch (e) {
                if (++root.snapshotAttempts < 3) {
                    snapshotRetry.restart();
                    return;
                }
                console.warn("Compositor: workspace verification failed after three attempts");
                root.workspaceSnapshotReady(false);
                return;
            }
            root.workspaceSnapshot = rows.filter(w => w.id > 0);
            root.workspaceSnapshotReady(true);
        }
    }
    Timer {
        id: snapshotRetry
        interval: 500
        onTriggered: workspaceQuery.running = true
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
    // HDR : `hl.monitor` complet (ruleKey : mode, position, échelle, rotation relus ; les autres champs de la règle de la config,
    // miroir ou zone réservée, ne sont pas repris : BACKLOG.md). VRR : `misc.vrr`, seul effectif
    // (le champ `vrr` de `hl.monitor` ne change rien, Hyprland 0.57 vérifié), et la bascule porte sur tous les écrans compatibles.
    function setHdr(names: var, on: bool): void {
        if (isSway && names.length > 0)
            I3.dispatch(names.map(n => `output "${n}" hdr ${on ? "on" : "off"}`).join("; "));
        else if (isHyprland && names.length > 0) {
            if (on) {
                // Mode SDR relevé avant le HDR, rendu à l'arrêt (10 bits si la config de l'écran les donne, comme
                // `render_bit_depth 10` sous Sway, que `hdr off` garde).
                const sdr = Object.assign({}, sdrModes);
                for (const n of names) {
                    const o = Hyprland.monitors.values.find(m => m.name === n)?.lastIpcObject;
                    if (o?.colorManagementPreset && o.colorManagementPreset !== "hdr")
                        sdr[n] = { cm: o.colorManagementPreset, bitdepth: /2101010/.test(o.currentFormat ?? "") ? 10 : 8,
                            luminance: o.sdrMaxLuminance ?? 80 };
                }
                sdrModes = sdr;
            }
            // Arrêt : aussi pour un écran passé en HDR puis absent (éteint), à qui sa règle HDR serait rendue à son retour.
            const targets = on ? names : union(names, hdrOnOutputs);
            hdrOnOutputs = on ? union(names, hdrOnOutputs) : [];
            applyRuntimeRules([hdrRule(targets, on)]);
        }
    }

    function setVrr(names: var, on: bool): void {
        if (isSway && names.length > 0)
            I3.dispatch(names.map(n => `output "${n}" adaptive_sync ${on ? "on" : "off"}`).join("; "));
        else if (isHyprland && names.length > 0) {
            vrrOn = on;
            applyRuntimeRules([vrrRule(on)]);
        }
    }

    // Hyprland, état posé par les bascules, reposé après un `reload` : écrans passés en HDR, VRR actif ; mode SDR de chaque écran
    // relevé avant le HDR (inconnu, HDR déjà actif au démarrage : sRGB 8 bits, blanc à 80 nits, défaut d'Hyprland).
    property var hdrOnOutputs: []
    property bool vrrOn: false
    property var sdrModes: ({})   // { "<écran>": { cm, bitdepth, luminance } }

    // Blanc SDR à 203 nits (BT.2408), comme Sway à ma connaissance : Hyprland l'affiche par défaut à 80 nits en HDR, d'où un
    // bureau terne (ton constat du 2026-11-03).
    // Règle visée par la description de l'écran, comme dans dotfiles/hypr/hosts/ (même clé que la config : une règle par
    // connecteur ne s'y fondrait pas) ; écran sans description : son connecteur. Retenue tant que l'écran est actif (un écran
    // éteint depuis garde la sienne). Règle complète (mode, position, échelle, rotation relus sur l'écran) : rien ne dépend de la
    // règle de la config, qui peut n'être que le repli `output = ""` d'une machine sans hosts/ (une règle partielle plus précise
    // le remplacerait : mode et échelle par défaut).
    property var ruleKeys: ({})

    // `desc:` désigne tout écran dont la description COMMENCE par elle : deux écrans identiques sans numéro de série recevraient
    // la même règle (position comprise). Dans ce cas, le connecteur. Échelle publiée à 2 décimales (1.67) : ramenée au 1/120 le
    // plus proche, la grille d'Hyprland, sinon il la corrige lui-même en affichant une erreur.
    function ruleKey(name: string): string {
        const m = Hyprland.monitors.values.find(m => m.name === name)?.lastIpcObject;
        const description = output(name)?.description ?? "";
        const byDescription = description !== "" && !outputs.some(o => o.name !== name && o.description.startsWith(description));
        if (m?.width)
            ruleKeys[name] = `output = ${luaString(byDescription ? `desc:${description}` : name)}, `
                + `mode = "${m.width}x${m.height}@${m.refreshRate}", position = "${m.x}x${m.y}", `
                + `scale = ${Math.round(m.scale * 120) / 120}, transform = ${m.transform ?? 0}`;
        return ruleKeys[name] ?? `output = ${luaString(name)}`;
    }

    // Chaîne Lua : la description vient de l'EDID de l'écran, guillemets et barres obliques inverses possibles.
    function luaString(text: string): string {
        return `"${text.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n")}"`;
    }

    function hdrRule(names: var, on: bool): string {
        return names.map(n => {
            const sdr = sdrModes[n];
            return `hl.monitor({ ${ruleKey(n)}, ${on ? `cm = "hdr", bitdepth = 10, sdr_max_luminance = 203`
                : `cm = "${sdr?.cm ?? "srgb"}", bitdepth = ${sdr?.bitdepth ?? 8}, sdr_max_luminance = ${sdr?.luminance ?? 80}`} })`;
        }).join(" ");
    }

    function vrrRule(on: bool): string {
        return `hl.config({ misc = { vrr = ${on ? 1 : 0} } })`;
    }

    function union(a: var, b: var): var {
        return [...new Set([...a, ...b])];
    }

    // Après un `reload` : HDR et VRR reposés. Aussi ceux que montrent les écrans, encore lus d'avant le `reload` : état d'un shell
    // relancé HDR actif (rechargement à chaud, $mod+Ctrl+w), qui ne les a pas posés lui-même. Règles posées une fois les écrans
    // relus : la règle HDR est complète (ruleKey), elle reprend donc le mode, la position et l'échelle de la config rechargée,
    // pas ceux d'avant le `reload`.
    function replayRuntimeRules(): void {
        hdrOnOutputs = union(hdrOnOutputs, outputs.filter(o => o.hdr).map(o => o.name));
        const vrrOutputs = outputs.filter(o => o.vrrCapable);
        vrrOn = vrrOn || (vrrOutputs.length > 0 && vrrOutputs.every(o => o.vrr));   // comme la bascule (Displays.vrr)
        if (hdrOnOutputs.length > 0 || vrrOn) {
            Hyprland.refreshMonitors();
            replayAfterReread.restart();
        }
    }

    Timer {
        id: replayAfterReread
        interval: 500   // comme monitorReread : réponse de refreshMonitors reçue
        // Écrans présents seulement : la règle d'un écran absent (éteint, désactivé) le rallumerait avec sa géométrie d'avant.
        onTriggered: {
            const present = root.hdrOnOutputs.filter(n => root.outputs.some(o => o.name === n));
            root.applyRuntimeRules([...(present.length > 0 ? [root.hdrRule(present, true)] : []), ...(root.vrrOn ? [root.vrrRule(true)] : [])]);
        }
    }

    function applyRuntimeRules(rules: var): void {
        if (rules.length === 0)
            return;
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

    // Espace N, qui n'existe pas encore, créé et affiché sur `output` (`$mod+N`), sans détour visible par l'écran focalisé.
    // Hyprland : un espace vide créé sur un autre écran que celui du pointeur perd aussitôt le focus au profit de la fenêtre sous le
    // pointeur (`follow_mouse`, `no_warps` : vu sur banc). Créé ici puis déplacé, comme la correction de services/Outputs.qml, mais
    // dans la même requête : l'écran de départ reprend l'espace qu'il affichait.
    function createWorkspace(n: int, output: string): void {
        if (isHyprland && output && output !== focusedOutput)
            hyprlandBatch([`hl.dsp.focus({ workspace = ${n} })`, ...moveBackCalls(n, output)]);
        else
            focusWorkspace(n, output);
    }

    // Hyprland : espace N (focalisé, sur l'écran de départ) envoyé sur `output` ; l'écran de départ réaffiche son espace, puis N
    // est refocalisé. Lu avant la requête.
    function moveBackCalls(n: int, output: string): var {
        const from = focusedOutput;
        const shown = workspaces.find(w => w.visible && w.output === from)?.number;
        // N désigné par son numéro : si l'action précédente n'a pas eu lieu, l'espace de départ ne part pas à sa place.
        return [`hl.dsp.workspace.move({ workspace = ${n}, monitor = "${output}" })`,
            // Écran de départ inconnu (écran focalisé tout juste retiré) : pas de retour, `focus monitor ""` arrêterait la suite.
            ...(from !== "" && shown !== undefined && shown !== n ? [`hl.dsp.focus({ monitor = "${from}" })`, `hl.dsp.focus({ workspace = ${shown} })`,
                `hl.dsp.focus({ workspace = ${n} })`] : [])];
    }

    // Fenêtre focalisée envoyée sur l'espace N, qui est ensuite affiché (`$mod+Ctrl+N`). `output` : sortie où créer N, qui n'existe
    // pas encore. Aucune fenêtre focalisée : l'espace est seulement affiché.
    function moveWindowToWorkspace(n: int, output: string): void {
        const current = workspaces.find(w => w.focused);
        if (!current || current.empty) {
            output ? createWorkspace(n, output) : focusWorkspace(n, "");
            return;
        }
        if (isSway) {
            // Fenêtre marquée, espace créé sur sa sortie, fenêtre envoyée et focalisée : en une commande, sans détour visible.
            I3.dispatch(output ? `mark --add _qs_move; focus output "${output}"; workspace number ${n}; `
                + `[con_mark="^_qs_move$"] move container to workspace number ${n}; [con_mark="^_qs_move$"] focus; unmark _qs_move`
                : `move container to workspace number ${n}; workspace number ${n}`);
        } else if (isHyprland) {
            // Fenêtre active désignée par son adresse ; aucune sur l'espace focalisé (liste pas à jour, fenêtre qui vient de se
            // fermer) : l'espace est seulement affiché, sinon `moveBackCalls` déplacerait l'espace de départ à sa place.
            // `window.move` suit la fenêtre (comme ton `$mod+Ctrl+N`) : N naît ici avec elle, puis rejoint `output`.
            const window = Hyprland.activeToplevel;
            if (!window || window.workspace?.id !== current.number) {
                output ? createWorkspace(n, output) : focusWorkspace(n, "");
                return;
            }
            // Adresse pas encore reçue (fenêtre qui vient de s'ouvrir) : sans `window`, Hyprland prend la fenêtre active.
            const target = window.address ? `window = "address:0x${window.address}", ` : "";
            hyprlandBatch([`hl.dsp.window.move({ ${target}workspace = ${n} })`,
                ...(output && output !== focusedOutput ? moveBackCalls(n, output) : [])]);
        }
    }

    // Only this process's monitor window is placed; ordinary windows are never targeted.
    readonly property string monitorWindowTitle: "System Monitor — Quickshell"
    property string monitorOutput: ""
    property int monitorSwayId: -1
    property string monitorHyprAddress: ""
    property real monitorPlacementDeadline: 0

    function prepareMonitorWindow(output: string): void {
        monitorSwayId = -1;
        monitorHyprAddress = "";
        monitorOutput = output;
        monitorPlacementDeadline = Date.now() + 2000;
    }

    function cancelMonitorPlacement(): void { monitorPlacementDeadline = 0; }

    function forgetMonitorWindow(): void {
        cancelMonitorPlacement();
        monitorSwayId = -1;
        monitorHyprAddress = "";
        monitorRecenter.stop();
    }

    function resizeMonitorWindow(): void { monitorRecenter.restart(); }
    Timer {
        id: monitorRecenter
        interval: 50
        onTriggered: {
            if (root.isSway && root.monitorSwayId >= 0)
                I3.dispatch(`[con_id=${root.monitorSwayId}] move position center`);
            else if (root.isHyprland && root.monitorHyprAddress !== "")
                root.hyprlandBatch([`hl.dsp.window.center({ window = "address:0x${root.monitorHyprAddress}" })`]);
        }
    }

    function placeSwayMonitor(container: var): void {
        if (Date.now() > monitorPlacementDeadline || container?.pid !== Quickshell.processId
            || container?.name !== monitorWindowTitle)
            return;
        const target = `[con_id=${container.id}]`;
        const output = outputs.some(o => o.name === monitorOutput) ? monitorOutput : "";
        monitorPlacementDeadline = 0;
        monitorSwayId = container.id;
        I3.dispatch(`${target} floating enable; `
            + (output ? `${target} move container to output ${luaString(output)}; ` : "")
            + `${target} move position center; ${target} focus`);
    }

    Timer {
        interval: 50
        repeat: true
        running: root.isHyprland && root.monitorPlacementDeadline > 0
        onTriggered: {
            if (Date.now() > root.monitorPlacementDeadline) {
                root.cancelMonitorPlacement();
                return;
            }
            const window = Hyprland.toplevels.values.find(t => t.title === root.monitorWindowTitle
                && t.lastIpcObject.pid === Quickshell.processId && t.address !== "");
            if (!window) {
                Hyprland.refreshToplevels();
                return;
            }
            const target = `window = "address:0x${window.address}"`;
            const output = root.outputs.some(o => o.name === root.monitorOutput) ? root.monitorOutput : "";
            root.monitorHyprAddress = window.address;
            root.cancelMonitorPlacement();
            root.hyprlandBatch([`hl.dsp.window.float({ action = "set", ${target} })`,
                ...(output ? [`hl.dsp.window.move({ monitor = ${root.luaString(output)}, ${target} })`] : []),
                `hl.dsp.window.center({ ${target} })`, `hl.dsp.focus({ ${target} })`]);
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
        subscriptions: root.isSway && loaded ? ["window", "workspace", "output"] : []
        Component.onCompleted: Qt.callLater(() => i3Listener.loaded = true)

        onIpcEvent: event => {
            // Changement de titre (fréquent : navigateur) : utile seulement si une activation est attendue, pas analysé sinon ; de focus
            // (à chaque fenêtre survolée) : aucun usage.
            if (event.type === "window" && Date.now() > root.monitorPlacementDeadline && Date.now() > root.activationDeadline && /^\s*\{\s*"change"\s*:\s*"(title|focus)"/.test(event.data))
                return;
            const data = JSON.parse(event.data);
            if (event.type === "output") { root.outputsChanging(); return; }
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
            if (["new", "title"].includes(data.change))
                root.placeSwayMonitor(data.container);
            // Ouverture, fermeture, déplacement : l'état vide des espaces change, I3 ne le relit pas de lui-même.
            if (["new", "close", "move", "floating"].includes(data.change))
                Qt.callLater(root.refreshWorkspaces);
        }
    }

    // --- Backend Hyprland ---

    Connections {
        target: root.isHyprland ? Hyprland : null
        function onRawEvent(event) {
            // A response issued before a structural event must not be published afterwards.
            if (["createworkspacev2", "destroyworkspacev2", "moveworkspacev2", "monitoradded", "monitorremoved", "configreloaded"].includes(event.name)) {
                if (workspaceQuery.running || snapshotRetry.running)
                    root.snapshotDirty = true;
                if (event.name === "destroyworkspacev2") {
                    const id = parseInt(event.data);
                    root.workspaceSnapshot = root.workspaceSnapshot.filter(w => w.id !== id);
                }
            }
            // Keep fallback occupancy fresh if an otherwise correctly placed workspace is still absent natively.
            if (["openwindow", "closewindow", "movewindowv2"].includes(event.name)
                    && root.workspaceSnapshot.some(w => !Hyprland.workspaces.values.some(n => n.id === w.id && n.monitor)))
                root.requestWorkspaceSnapshot();
            if (event.name === "createworkspacev2") {
                // « ID,NOM » ; l'écran n'est connu qu'après relecture : "" laisse Outputs vérifier 100 ms plus tard.
                const id = parseInt(event.data);
                if (id > 0)
                    root.workspaceCreated(id, Hyprland.workspaces.values.find(w => w.id === id)?.monitor?.name ?? "");
            }
            // Comme sous Sway : un espace déplacé ne met pas à jour l'espace affiché par chaque écran (Quickshell 0.3.2, code lu).
            else if (event.name === "moveworkspacev2") {
                if (root.workspaceSnapshot.some(w => w.id === parseInt(event.data)))
                    Hyprland.refreshToplevels();
                Hyprland.refreshMonitors();
                monitorReread.restart();
            } else if (["monitoradded", "monitorremoved"].includes(event.name)) {
                root.outputsChanging();
                monitorReread.restart();
            }
            else if (event.name === "configreloaded") {
                root.replayRuntimeRules();
                root.configurationReloaded();
            }
            else if (event.name === "urgent" && root.takeActivation(Hyprland.toplevels.values.find(t => t.address === event.data)?.wayland?.appId ?? ""))   // « ADRESSE » (hexadécimal, sans 0x, vérifié)
                hyprlandBatch([`hl.dsp.focus({ window = "address:0x${event.data}" })`]);
        }
    }
}
