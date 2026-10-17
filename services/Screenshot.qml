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
    property string pictures: ""

    function open(startMode: string): void {
        if (active)
            return;
        mode = startMode;
        startScreen = Compositor.focusedOutput;
        const o = Compositor.output(startScreen);
        selection = mode === "screen" && o ? { x: o.x, y: o.y, width: o.width, height: o.height } : null;
        windows = [];
        windowList.command = Compositor.isHyprland ? ["hyprctl", "clients", "-j"] : ["swaymsg", "-t", "get_tree"];
        windowList.running = true;
        active = true;
    }

    function close(): void {
        active = false;
        selection = null;
    }

    // Capture de la sélection : la fenêtre de l'écran qui la contient s'en charge (modules/screenshot/ScreenshotTool.qml).
    signal captureRequested(var rect)

    function capture(): void {
        if (selection && selection.width > 0 && selection.height > 0)
            captureRequested(selection);
    }

    // Fichier de la capture : dossier Images XDG (comme le script de la touche Impr.).
    function nextPath(): string {
        const now = new Date();
        const pad = n => String(n).padStart(2, "0");
        const name = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}.png`;
        return `${pictures !== "" ? pictures : `${Quickshell.env("HOME")}/Pictures`}/screenshot/${name}`;
    }

    // Image enregistrée : copiée dans le presse-papiers (PNG).
    function copyToClipboard(path: string): void {
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$0"', path]);
    }

    function ensureDirectory(): void {
        Quickshell.execDetached(["mkdir", "-p", `${pictures !== "" ? pictures : `${Quickshell.env("HOME")}/Pictures`}/screenshot`]);
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

    Process {
        running: true
        command: ["xdg-user-dir", "PICTURES"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.pictures = text.trim();
                root.ensureDirectory();
            }
        }
    }

    // Fenêtres des espaces affichés (Sway : feuilles de l'arbre des espaces visibles, flottantes comprises ; Hyprland : clients
    // des espaces affichés).
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
                    for (const c of data)
                        if (shown.includes(c.workspace?.id) && !c.hidden)
                            list.push({ x: c.at[0], y: c.at[1], width: c.size[0], height: c.size[1], title: c.title });
                } else {
                    const visit = (node, visible) => {
                        if (node.type === "workspace")
                            visible = Compositor.workspaces.some(w => w.name === node.name && w.visible);
                        const children = [...(node.nodes ?? []), ...(node.floating_nodes ?? [])];
                        if (visible && children.length === 0 && (node.type === "con" || node.type === "floating_con") && node.pid)
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
