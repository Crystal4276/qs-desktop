import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.modules.bar

// Utilitaire de changement de fond (ARCHITECTURE § 7.11) : vignettes du dossier des fonds, par onglet — images simples,
// panoramas (plusieurs écrans), triptyques (trois écrans). Un clic, Entrée ou une flèche applique le fond tout de suite ; la
// fenêtre reste ouverte pour comparer, « Reset » revient aux fonds de son ouverture. Image simple : pour tous les écrans ou un
// seul (rangée du haut). Échap ou un clic à côté ferme.
OverlayPopup {
    id: root

    readonly property int cellWidth: Theme.wallpaperPicker.thumbWidth + 2 * Theme.wallpaperPicker.selectionPadding
    readonly property int columns: width >= Theme.wallpaperPicker.wideScreenWidth ? Theme.wallpaperPicker.wideColumns
        : Theme.wallpaperPicker.columns

    property string tab: "simple"
    property string target: ""   // description de l'écran visé ("" : tous)

    readonly property var outputs: [...Compositor.outputs].sort((a, b) => a.x - b.x)
    readonly property real pixelRatio: Compositor.output(screen?.name ?? "")?.scale ?? 1   // réelle (WallpaperView.qml)
    readonly property var tabs: [
        { key: "simple", name: "Images" },
        ...(Wallpapers.corelabEnabled ? [{ key: "corelab", name: "Core Lab" }] : []),
        ...(outputs.length > 1 ? [{ key: "panorama", name: "Panoramas" }] : []),
        ...(outputs.length === 3 ? [{ key: "triptych", name: "Triptychs" }] : [])
    ]
    // `images` : chemins des images de la vignette (trois pour un triptyque).
    function entries(kind: string): var {
        const lib = Wallpapers.library;
        if (kind === "corelab") {
            const output = outputs.find(o => target !== "" ? o.description === target : o.name === screen?.name) ?? outputs[0];
            return lib.corelab.map(d => ({ path: d.path, images: [Wallpapers.corelabPath(d.path, output)] })).filter(d => d.images[0] !== "");
        }
        if (kind === "triptych")
            return lib.triptych.map(t => ({ path: t.path, images: ["left", "center", "right"].map(p => t.parts[p]) }));
        return (kind === "panorama" ? lib.panorama : lib.simple).map(p => ({ path: p, images: [p] }));
    }
    readonly property var items: entries(tab)
    property var visited: ({})
    property var tabLoaders: ({})
    readonly property var grid: tabLoaders[tab]?.item ?? null

    function visit(): void {
        visited = Object.assign({}, visited, { [tab]: true });
        Qt.callLater(() => { if (visible) grid?.forceActiveFocus(); });
    }

    // Vignette de départ (ouverture, flèches) dans les vignettes `entries` de l'onglet `kind` : le fond choisi ; écran visé sans
    // image propre : celle de tous les écrans, qu'il montre.
    function currentIn(kind: string, entries: var): int {
        const i = entries.findIndex(e => isCurrent(kind, e.path));
        const s = Wallpapers.selection;
        return i >= 0 || target === "" || Wallpapers.overrides[target] || s?.kind !== kind ? i
            : entries.findIndex(e => e.path === s.path);
    }

    function showCurrent(): void {
        grid?.showCurrent();
    }

    // Onglet et vignette du fond actuel, clavier sur les vignettes (ouverture, « Reset » : le bouton, grisé, perd le focus).
    function goToCurrent(): void {
        if (tabs.some(t => t.key === currentTab))
            tab = currentTab;
        else if (!tabs.some(t => t.key === tab))
            tab = "simple";
        Qt.callLater(() => {
            showCurrent();
            if (visible)
                grid?.forceActiveFocus();
        });
    }

    // Onglet du fond actuel : celui de l'écran visé s'il en a un, sinon celui de tous les écrans.
    readonly property string currentTab: {
        const own = target !== "" ? Wallpapers.overrides[target] ?? "" : "";
        return own !== "" ? own.split("/")[0] : Wallpapers.selection?.kind ?? "";
    }

    // Choix à l'ouverture, rétablis par « Reset ».
    property var opened: null
    readonly property bool changed: opened !== null && JSON.stringify(Wallpapers.snapshot()) !== JSON.stringify(opened)

    // Après une lecture du dossier seulement : pas de message pendant la première.
    readonly property bool empty: Wallpapers.libraryRead && items.length === 0

    // Sur l'écran `from` (bouton du panneau de réglages), sinon l'écran focalisé (raccourci).
    function open(from: var): void {
        screen = from ?? Outputs.focusedScreen();
        Wallpapers.refresh();
        if (!visible)
            opened = Wallpapers.snapshot();
        goToCurrent();
        prepareOpen(null);
        visible = true;
        visit();
    }

    function toggle(): void {
        visible ? close() : open(null);
    }

    // Choix « tous les écrans » : seulement si aucun écran présent n'a sa propre image (celles d'écrans débranchés ne comptent pas).
    function isCurrent(kind: string, path: string): bool {
        if ((kind === "simple" || kind === "corelab") && target !== "")
            return Wallpapers.overrides[target] === path;
        const s = Wallpapers.selection;
        return s !== null && s.kind === kind && s.path === path && !outputs.some(o => Wallpapers.overrides[o.description]);
    }

    function apply(index: int): void {
        const item = items[index];
        if (!item)
            return;
        if ((tab === "simple" || tab === "corelab") && target !== "")
            Wallpapers.setOutput(target, item.path);
        else
            Wallpapers.setAll(tab, item.path);
    }

    Connections {
        target: Wallpapers
        function onDirChanged() { root.visited = {}; if (root.visible) root.visit(); }
    }

    WlrLayershell.namespace: "quickshell-wallpaper-picker"
    frameItem: frame

    onTabChanged: visit()
    onGridChanged: if (visible) Qt.callLater(() => grid?.forceActiveFocus())
    // Écrans changés, fenêtre ouverte : onglet disparu → images simples ; écran visé disparu → tous les écrans.
    onTabsChanged: {
        if (!tabs.some(t => t.key === tab))
            tab = "simple";
    }
    onTargetChanged: Qt.callLater(showCurrent)
    // Hauteur de l'écran (ouvert sur un autre, même nombre de colonnes) : centrage refait à la vraie taille. Celle de la grille
    // change aussi avec les onglets (rangée des écrans) : pas elle.
    onHeightChanged: Qt.callLater(showCurrent)
    onOutputsChanged: {
        if (target !== "" && !outputs.some(o => o.description === target))
            target = "";
    }

    PanelFrame {
        id: frame

        x: parent.width - width - Theme.bar.marginSide
        y: Theme.panel.gap
        width: Math.min(root.columns * root.cellWidth + 2 * Theme.panel.padding,
            parent.width - 2 * Theme.bar.marginSide)
        height: Math.max(0, parent.height - 2 * Theme.panel.gap)
        onCloseRequested: root.close()

        // Commandes fixes ; chaque groupe passe à la ligne si nécessaire.
        ColumnLayout {
            id: controls
            Layout.fillWidth: true
            spacing: Theme.panel.spacing

            Flow {
                Layout.fillWidth: true
                spacing: Theme.panel.spacing

                Repeater {
                    model: root.tabs

                    PanelButton {
                        required property var modelData
                        text: modelData.name
                        checked: root.tab === modelData.key
                        onClicked: root.tab = modelData.key
                    }
                }

                PanelButton {
                    text: "Reset"
                    enabled: root.changed
                    onClicked: {
                        Wallpapers.restore(root.opened);
                        root.goToCurrent();
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                visible: (root.tab === "simple" || root.tab === "corelab") && root.outputs.length > 1
                spacing: Theme.panel.spacing

                Repeater {
                    model: [{ description: "", name: "All screens" }, ...root.outputs]

                    PanelButton {
                        required property var modelData
                        text: modelData.name
                        checked: root.target === modelData.description
                        onClicked: root.target = modelData.description
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(0, frame.height - 2 * Theme.panel.padding
                - controls.implicitHeight - Theme.panel.spacing)

            // Le cadre reste haut même si la bibliothèque est vide.
            PanelSection {
                anchors.top: parent.top
                width: parent.width
                visible: root.empty
                readonly property string dir: Wallpapers.dir.startsWith(`${Places.home}/`) ? `~${Wallpapers.dir.slice(Places.home.length)}` : Wallpapers.dir
                text: `No wallpapers in ${dir}/${root.tab}`
            }

            Repeater {
                id: grids
                model: ["simple", "corelab", "panorama", "triptych"]
                onItemAdded: (index, item) => root.tabLoaders = Object.assign({}, root.tabLoaders, { [item.modelData]: item })
                Loader {
                    id: tabLoader
                    required property string modelData
                    anchors.fill: parent
                    active: !!root.visited[modelData] && root.tabs.some(t => t.key === modelData)
                    visible: !root.empty && root.tab === modelData
                    sourceComponent: Component {
                        GridView {
                            id: view

                            readonly property string kind: tabLoader.modelData
                            property var modelEntries: []
                            readonly property string signature: JSON.stringify(root.entries(kind))
                            onSignatureChanged: {
                                const next = JSON.parse(signature);
                                if (JSON.stringify(modelEntries) !== signature) modelEntries = next;
                            }
                            // Vignette du fond actuel choisie au clavier et montrée (ouverture, écran visé changé, « Reset ») ; modèle
                            // remplacé (dossier relu, écran visé dans Core Lab, onglet caché compris) : la grille était repartie de 0.
                            function showCurrent(): void {
                                const i = root.currentIn(kind, modelEntries);
                                if (i < 0)
                                    return;
                                currentIndex = i;
                                showIndex();
                            }
                            onModelEntriesChanged: Qt.callLater(showCurrent)
                            anchors.fill: parent
                            cellWidth: kind === "panorama" || kind === "triptych" ? width : Math.min(root.cellWidth, width)
                            cellHeight: Theme.wallpaperPicker.thumbHeight + 2 * Theme.wallpaperPicker.selectionPadding
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            keyNavigationEnabled: true
                            model: modelEntries

                            // Largeur changée (ouvert sur un écran d'un autre nombre de colonnes) : la vignette du clavier reste en vue.
                            // Pas la hauteur (rangée des écrans montrée selon l'onglet) : les grilles cachées ne bougent pas.
                            onWidthChanged: Qt.callLater(showIndex)
                            // Après la mise en page (reportée) : en changeant de nombre de colonnes, la grille déplace son origine.
                            function showIndex(): void {
                                if (currentIndex >= 0)
                                    positionViewAtIndex(currentIndex, GridView.Center);
                            }

                            Keys.onReturnPressed: root.apply(currentIndex)
                            Keys.onEnterPressed: root.apply(currentIndex)
                            Keys.onEscapePressed: root.close()
                            // Flèches : restent sur les vignettes (pas de passage aux boutons) ; depuis le fond actuel, la voisine
                            // est appliquée tout de suite ; onglet sans fond actuel : la première.
                            Keys.onUpPressed: step(() => moveCurrentIndexUp())
                            Keys.onDownPressed: step(() => moveCurrentIndexDown())
                            Keys.onLeftPressed: step(() => moveCurrentIndexLeft())
                            Keys.onRightPressed: step(() => moveCurrentIndexRight())
                            function step(move: var): void {
                                const here = root.currentIn(kind, modelEntries);
                                if (here < 0) {
                                    currentIndex = 0;
                                } else {
                                    currentIndex = here;
                                    move();
                                }
                                // Bloqué au bord : rien (un écran visé sans image propre en recevrait une, la même).
                                if (currentIndex !== here) {
                                    root.apply(currentIndex);
                                    positionViewAtIndex(currentIndex, GridView.Contain);   // curseur déjà sur 0 : la vue ne suit pas
                                }
                            }

                            delegate: Item {
                                id: cell

                                required property var modelData
                                required property int index
                                readonly property bool current: root.isCurrent(view.kind, modelData.path)

                                width: view.cellWidth
                                height: view.cellHeight

                                // Fond choisi : cadre `green` ; vignette sous le pointeur ou au clavier : cadre `surface0`.
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.wallpaperPicker.radius + Theme.wallpaperPicker.selectionPadding
                                    color: cell.current ? Theme.wallpaperPicker.selection
                                        : hover.hovered || (view.activeFocus && view.currentIndex === cell.index) ? Theme.wallpaperPicker.hover : "transparent"
                                }

                                ClippingRectangle {
                                    anchors.fill: parent
                                    anchors.margins: Theme.wallpaperPicker.selectionPadding
                                    radius: Theme.wallpaperPicker.radius
                                    color: Theme.panel.fieldBackground

                                    Row {
                                        anchors.fill: parent

                                        Repeater {
                                            model: cell.modelData.images

                                            Thumbnail {
                                                required property string modelData
                                                path: modelData
                                                pixelRatio: root.pixelRatio
                                                active: root.visible && tabLoader.visible
                                                width: parent.width / cell.modelData.images.length
                                                height: parent.height
                                            }
                                        }
                                    }
                                }

                                HoverHandler {
                                    id: hover
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        view.currentIndex = cell.index;
                                        root.apply(cell.index);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Molette : une rangée par cran (Flickable relance à chaque cran un défilement d'une demi-rangée, sans cumul : lent
            // avec une molette rapide). La molette arrive aussi avec `pixelDelta` (15 px par cran, mesuré) : seules les phases,
            // propres au pavé tactile, les distinguent ; le pavé tactile garde le défilement natif, avec son élan. Clics laissés
            // aux vignettes.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    const g = root.grid;
                    if (!g || wheel.phase !== Qt.NoScrollPhase) {
                        wheel.accepted = false;
                        return;
                    }
                    g.contentY = Math.max(g.originY, Math.min(g.originY + g.contentHeight - g.height,
                        g.contentY - wheel.angleDelta.y / 120 * g.cellHeight));
                }
            }
        }
    }
}
