pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Outil de capture natif (ARCHITECTURE § 7.15, modèle de l'outil de GNOME ; fenêtres : modules/screenshot/) : image figée de chaque
// écran (ScreencopyView), puis zone (sur un ou plusieurs écrans), écran ou fenêtre ; enregistrée comme ta touche Impr.
// (`Images/screenshot/AAAA-MM-JJ-HHMMSS.png`), copiée dans le presse-papiers et annoncée par une notification (clic : le fichier
// montré dans le gestionnaire de fichiers). Fenêtres : rectangles donnés par le compositeur (Toplevel ne fournit pas leur position).
Singleton {
    id: root

    property bool active: false
    property string mode: "area"        // "area" | "screen" | "window"
    // Rectangle choisi, en coordonnées logiques globales : { x, y, width, height } ou null.
    property var selection: null
    property string startScreen: ""     // écran focalisé à l'ouverture : barre d'outils
    // Fenêtres visibles : [{ x, y, width, height, title }], coordonnées logiques globales.
    property var windows: []
    // Curseur masqué : les images figées peuvent être prises (voir pointerEntered).
    property bool cursorHidden: false
    // Curseur à masquer par l'outil (curseur logiciel possible) : Sway. Hyprland : curseur matériel, exclu par `paintCursor: false` (logiciel : BACKLOG).
    readonly property bool hidesCursor: !Compositor.isHyprland
    readonly property string appName: "Screenshot"   // notification de capture : affichée même en « ne pas déranger » (Notifs)
    readonly property string pictures: Places.pictures !== "" ? Places.pictures : `${Quickshell.env("HOME")}/Pictures`

    // Pas pendant le verrouillage : l'outil prendrait le clavier de l'écran de verrouillage (fermé au verrouillage ; capture déjà
    // demandée : laissée finir, l'outil se ferme de lui-même une fois l'image enregistrée, au plus 500 ms).
    property bool capturing: false

    Connections {
        target: Session
        function onLockActiveChanged() {
            if (Session.lockActive && !root.capturing)
                root.close();
        }
    }
    Timer {
        running: Session.lockActive && root.capturing
        interval: 500
        onTriggered: root.close()
    }

    function open(startMode: string): void {
        if (active || Session.lockActive)
            return;
        mode = startMode;
        // Écran focalisé, sinon le premier : barre d'outils et clavier (Échap) ont toujours un écran.
        const names = Quickshell.screens.map(s => s.name);
        startScreen = names.includes(Compositor.focusedOutput) ? Compositor.focusedOutput : (names[0] ?? "");
        const o = Compositor.output(startScreen);
        selection = mode === "screen" && o ? { x: o.x, y: o.y, width: o.width, height: o.height } : null;
        windows = [];
        ensureDirectory();   // le temps de choisir la zone suffit à le créer
        // Hyprland : fenêtres, puis moniteurs (espace affiché, espace spécial ouvert), coup sur coup.
        windowList.command = Compositor.isHyprland
            ? ["sh", "-c", `printf '{"clients":'; hyprctl clients -j; printf ',"monitors":'; hyprctl monitors -j; printf '}'`]
            : ["swaymsg", "-t", "get_tree"];
        windowList.running = true;
        cursorHidden = !hidesCursor;
        active = true;
    }

    function close(): void {
        active = false;
        capturing = false;
        selection = null;
        pieces = [];
        nudge.stop();
        settle.stop();
    }

    // Curseur logiciel (Sway sur Nvidia) hors des images figées : les surfaces de l'outil demandent un curseur vide, la capture
    // commence peu après l'entrée du pointeur ; un déplacement nul la provoque sous un pointeur immobile (constaté le 2026-10-26).
    property int nudges: 0

    function surfaceCreated(): void {
        if (cursorHidden || nudge.running || settle.running)
            return;
        nudges = 0;
        nudge.start();
    }

    function pointerEntered(): void {
        nudge.stop();
        if (active && !cursorHidden && !settle.running)
            settle.start();
    }

    Timer {
        id: nudge
        interval: 50
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // Pointeur sur aucune surface de l'outil au bout d'1 s (surfaces très lentes à s'afficher, trou entre les écrans) :
            // capture quand même, plutôt que pas de capture.
            if (++root.nudges > 20) {
                stop();
                root.cursorHidden = true;
            } else {
                Compositor.nudgeCursor();
            }
        }
    }

    // Écran redessiné sans curseur : quelques images à 60 Hz.
    Timer {
        id: settle
        interval: 50
        onTriggered: root.cursorHidden = true
    }

    // Capture de la sélection : chaque écran qu'elle touche découpe sa part de son image figée, à sa résolution réelle
    // (modules/screenshot/ScreenshotTool.qml), puis addPiece ; une seule part est enregistrée telle quelle, plusieurs sont
    // assemblées en une image par l'écran de départ (stitchRequested), à l'échelle la plus haute (comme grim : la partie d'un
    // écran moins dense est agrandie). Sur aucun écran : outil fermé.
    signal captureRequested(var rect, var screens)
    signal stitchRequested(var pieces)

    property string capturePath: ""
    property int expected: 0
    // Parts reçues : { grab (ItemGrabResult), x, y, width, height (logiques globales), scale }.
    property var pieces: []

    function capture(): void {
        const s = selection;
        if (!s || s.width <= 0 || s.height <= 0 || capturing)
            return;
        const names = Quickshell.screens.map(q => q.name);
        const touched = Compositor.outputs.filter(o => names.includes(o.name)
            && Math.min(s.x + s.width, o.x + o.width) > Math.max(s.x, o.x)
            && Math.min(s.y + s.height, o.y + o.height) > Math.max(s.y, o.y)).map(o => o.name);
        if (touched.length === 0) {
            close();
            return;
        }
        capturing = true;
        capturePath = nextPath();
        expected = touched.length;
        pieces = [];
        captureRequested(s, touched);
    }

    function addPiece(piece): void {
        if (!capturing)
            return;
        pieces = [...pieces, piece];
        if (pieces.length < expected)
            return;
        if (pieces.length === 1)
            finish(piece.grab.saveToFile(capturePath));
        else
            stitchRequested(pieces);
    }

    // Image enregistrée (ok) : presse-papiers et notification ; dans tous les cas, outil fermé.
    function finish(ok: bool): void {
        if (ok) {
            copyToClipboard(capturePath);
            notifySaved(capturePath);
        }
        close();
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

    // Notification avec l'aperçu (indice image-path ; icône du thème en repli) ; un clic (action « default ») montre le fichier
    // dans le gestionnaire de fichiers (org.freedesktop.FileManager1, Nemo ici). `notify-send --wait` vit jusqu'à la fermeture
    // de la notification.
    function notifySaved(path: string): void {
        const uri = "file://" + path.split("/").map(encodeURIComponent).join("/");
        Quickshell.execDetached(["sh", "-c", `a=$(notify-send --app-name=${root.appName} --icon=accessories-screenshot --hint="string:image-path:$0" \
            --action=default=Open --wait "Screenshot saved" "$1") && [ "$a" = default ] && gdbus call --session \
            --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 \
            --method org.freedesktop.FileManager1.ShowItems "$2" "" >/dev/null`,
            path, `${path.split("/").pop()} · copied to clipboard`, `[${JSON.stringify(uri)}]`]);
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
    // espaces affichés (l'ordre de `hyprctl clients` n'est pas l'empilement) : en mosaïque et agrandies (`$mod+TAB`) en dessous ;
    // au-dessus, flottantes et plein écran (`$mod+F`), par focus le plus récent (une flottante focalisée après le plein écran est
    // dessinée sur lui, sinon cachée : vu sur Hyprland 0.57) ; par-dessus tout, l'espace spécial ouvert sur un écran (`$mod+H`).
    Process {
        id: windowList
        stdout: StdioCollector {
            onStreamFinished: {
                let data;
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    console.warn("Screenshot: liste des fenêtres illisible, mode fenêtre sans fenêtres :", e);
                    return;
                }
                const list = [];
                if (Compositor.isHyprland) {
                    const shown = (data.monitors ?? []).map(m => m.activeWorkspace?.id);
                    const special = (data.monitors ?? []).map(m => m.specialWorkspace?.name).filter(n => n);
                    // `fullscreen` : 1 agrandie, 2 plein écran.
                    const layer = c => (special.includes(c.workspace?.name) ? 2 : 0) + (c.floating || (c.fullscreen & 2) ? 1 : 0);
                    const age = c => c.focusHistoryID >= 0 ? c.focusHistoryID : Infinity;   // -1 : jamais focalisée
                    for (const c of (data.clients ?? []).filter(c => (shown.includes(c.workspace?.id) || special.includes(c.workspace?.name))
                            && !c.hidden && c.mapped !== false)
                            .sort((a, b) => layer(a) - layer(b) || (age(b) - age(a) || 0)))
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
