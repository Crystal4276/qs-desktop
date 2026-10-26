pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Outil de capture natif (ARCHITECTURE § 10.1 R8, modèle de l'outil de GNOME ; fenêtres : modules/screenshot/) : image figée de chaque
// écran (ScreencopyView), puis zone, écran ou fenêtre ; enregistrée comme ta touche Impr. (`Images/screenshot/AAAA-MM-JJ-HHMMSS.png`)
// et copiée dans le presse-papiers. Fenêtres : rectangles donnés par le compositeur (Toplevel ne fournit pas leur position).
Singleton {
    id: root

    property bool active: false
    property string mode: "area"        // "area" | "screen" | "window"
    // Rectangle choisi, en coordonnées logiques globales : { x, y, width, height } ou null.
    property var selection: null
    property string startScreen: ""     // écran focalisé à l'ouverture : barre d'outils
    // Fenêtres visibles : [{ x, y, width, height, title }], coordonnées logiques globales.
    property var windows: []
    // Curseur masqué : les images figées peuvent être prises (voir hideCursor).
    property bool cursorHidden: false
    property list<string> frozenScreens: []   // écrans dont l'image figée est reçue
    readonly property string pictures: Places.pictures !== "" ? Places.pictures : `${Quickshell.env("HOME")}/Pictures`

    function open(startMode: string): void {
        if (active)
            return;
        mode = startMode;
        // Écran focalisé, sinon le premier : barre d'outils et clavier (Échap) ont toujours un écran.
        const names = Quickshell.screens.map(s => s.name);
        startScreen = names.includes(Compositor.focusedOutput) ? Compositor.focusedOutput : (names[0] ?? "");
        const o = Compositor.output(startScreen);
        selection = mode === "screen" && o ? { x: o.x, y: o.y, width: o.width, height: o.height } : null;
        windows = [];
        ensureDirectory();   // le temps de choisir la zone suffit à le créer
        windowList.command = Compositor.isHyprland ? ["hyprctl", "clients", "-j"] : ["swaymsg", "-t", "get_tree"];
        windowList.running = true;
        frozenScreens = [];
        hideCursor();
        active = true;
    }

    function close(): void {
        active = false;
        selection = null;
        restoreCursor();
    }

    // Curseur hors des images figées (ta demande du 2026-10-26). `paintCursor: false` (ScreenshotTool.qml) ne suffit pas quand le
    // compositeur dessine le curseur dans l'image de l'écran : curseur logiciel, Sway sur Nvidia (vu le 2026-10-26 : même `grim`
    // sans `-c` le capture). Une surface qui apparaît sous un pointeur immobile n'en reçoit pas l'entrée sous Sway : un curseur
    // vide demandé par l'outil ne s'appliquerait qu'au premier mouvement. Sway : `hide_cursor 1` le cache sans attendre de
    // mouvement, rétabli (valeur de ta config, 0 sinon) dès les images figées reçues. Hyprland : curseur matériel, déjà exclu.
    property bool hidingCursor: false
    property int hideCursorConfig: 0

    function hideCursor(): void {
        if (Compositor.isHyprland) {
            cursorHidden = true;
            return;
        }
        cursorHidden = false;
        hidingCursor = true;
        swayConfig.running = true;
        Quickshell.execDetached(["swaymsg", "seat", "*", "hide_cursor", "1"]);
        hideDelay.restart();
    }

    function restoreCursor(): void {
        hideDelay.stop();
        if (!hidingCursor)
            return;
        hidingCursor = false;
        Quickshell.execDetached(["swaymsg", "seat", "*", "hide_cursor", String(hideCursorConfig)]);
    }

    // Image figée reçue (ScreenshotTool.qml) : curseur rétabli une fois celles de tous les écrans reçues.
    function frozen(screen: string): void {
        if (!frozenScreens.includes(screen))
            frozenScreens = [...frozenScreens, screen];
        if (Quickshell.screens.every(s => frozenScreens.includes(s.name)))
            restoreCursor();
    }

    Component.onDestruction: restoreCursor()   // rechargement de la config pendant une capture

    // Écran redessiné sans curseur (une image à 60 Hz suffit ; marge pour la commande swaymsg).
    Timer {
        id: hideDelay
        interval: 150
        onTriggered: root.cursorHidden = true
    }

    // Délai de `hide_cursor` de ta config Sway (`seat … hide_cursor N`), rétabli après la capture.
    Process {
        id: swayConfig
        command: ["swaymsg", "-t", "get_config"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const match = JSON.parse(text).config.match(/^\s*seat\s+\S+\s+hide_cursor\s+(\d+)/m);
                    root.hideCursorConfig = match ? Number(match[1]) : 0;
                } catch (e) {
                    root.hideCursorConfig = 0;
                }
            }
        }
    }

    // Capture de la sélection par la fenêtre de l'écran qui en recouvre la plus grande part (un seul fichier, même pour une fenêtre
    // à cheval sur deux écrans : on garde la partie de cet écran) ; modules/screenshot/ScreenshotTool.qml. Sur aucun écran :
    // outil fermé.
    signal captureRequested(var rect, string screen)

    function capture(): void {
        const s = selection;
        if (!s || s.width <= 0 || s.height <= 0)
            return;
        const names = Quickshell.screens.map(q => q.name);
        let best = "", bestArea = 0;
        for (const o of Compositor.outputs.filter(o => names.includes(o.name))) {
            const w = Math.min(s.x + s.width, o.x + o.width) - Math.max(s.x, o.x);
            const h = Math.min(s.y + s.height, o.y + o.height) - Math.max(s.y, o.y);
            if (w > 0 && h > 0 && w * h > bestArea) {
                best = o.name;
                bestArea = w * h;
            }
        }
        if (best === "")
            close();
        else
            captureRequested(s, best);
    }

    // Fichier de la capture : dossier Images XDG (comme le script de la touche Impr.).
    function nextPath(): string {
        const now = new Date();
        const pad = n => String(n).padStart(2, "0");
        const name = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}.png`;
        return `${pictures}/screenshot/${name}`;
    }

    // Image enregistrée : copiée dans le presse-papiers (PNG).
    function copyToClipboard(path: string): void {
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$0"', path]);
    }

    function ensureDirectory(): void {
        Quickshell.execDetached(["mkdir", "-p", `${pictures}/screenshot`]);
    }

    // `qs ipc call screenshot area|screen|window` (touche Impr., phase 10).
    IpcHandler {
        target: "screenshot"

        function area(): void {
            root.open("area");
        }

        function screen(): void {
            root.open("screen");
        }

        function window(): void {
            root.open("window");
        }

        function close(): void {
            root.close();
        }

        // Tests et raccourcis : zone choisie (coordonnées logiques globales), puis capture.
        function select(x: real, y: real, width: real, height: real): void {
            root.selection = { x: x, y: y, width: width, height: height };
        }

        function capture(): void {
            root.capture();
        }

        function isActive(): bool {
            return root.active;
        }
    }


    // Fenêtres des espaces affichés, de la plus basse à la plus haute (windowAt prend la dernière) : Sway, feuilles visibles
    // (`visible` : une fenêtre cachée par un plein écran ou un onglet garde son rectangle), flottantes après ; Hyprland, clients des
    // espaces affichés (l'ordre de `hyprctl clients` n'est pas l'empilement) : en mosaïque, flottants, puis plein écran.
    Process {
        id: windowList
        stdout: StdioCollector {
            onStreamFinished: {
                let data;
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const list = [];
                if (Compositor.isHyprland) {
                    const shown = Compositor.workspaces.filter(w => w.visible).map(w => w.number);
                    const layer = c => c.fullscreen ? 2 : c.floating ? 1 : 0;
                    for (const c of data.filter(c => shown.includes(c.workspace?.id) && !c.hidden && c.mapped !== false)
                            .sort((a, b) => layer(a) - layer(b)))
                        list.push({ x: c.at[0], y: c.at[1], width: c.size[0], height: c.size[1], title: c.title });
                } else {
                    const visit = (node, visible) => {
                        if (node.type === "workspace")
                            visible = Compositor.workspaces.some(w => w.name === node.name && w.visible);
                        const children = [...(node.nodes ?? []), ...(node.floating_nodes ?? [])];
                        if (visible && children.length === 0 && (node.type === "con" || node.type === "floating_con") && node.pid
                                && node.visible)
                            list.push({ x: node.rect.x, y: node.rect.y, width: node.rect.width, height: node.rect.height, title: node.name });
                        for (const child of children)
                            visit(child, visible);
                    };
                    visit(data, false);
                }
                root.windows = list;
            }
        }
    }
}
