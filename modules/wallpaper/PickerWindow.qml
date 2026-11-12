import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.modules.bar

// Utilitaire de changement de fond (ARCHITECTURE § 7.11) : vignettes du dossier des fonds, par onglet — images simples,
// panoramas (plusieurs écrans), triptyques (trois écrans). Un clic ou Entrée applique le fond tout de suite ; la fenêtre reste
// ouverte pour comparer. Image simple : pour tous les écrans ou un seul (rangée du haut). Échap ou un clic à côté ferme.
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

    // Après une lecture du dossier seulement : pas de message pendant la première.
    readonly property bool empty: Wallpapers.libraryRead && items.length === 0

    // Sur l'écran `from` (bouton du panneau de réglages), sinon l'écran focalisé (raccourci).
    function open(from: var): void {
        screen = from ?? Outputs.focusedScreen();
        Wallpapers.refresh();
        if (!tabs.some(t => t.key === tab))
            tab = "simple";
        prepareOpen(null);
        visible = true;
        visit();
    }

    function toggle(): void {
        visible ? close() : open(null);
    }

    // Choix « tous les écrans » : seulement si aucun écran présent n'a sa propre image (celles d'écrans débranchés ne comptent pas).
    function isCurrent(path: string): bool {
        if ((tab === "simple" || tab === "corelab") && target !== "")
            return Wallpapers.overrides[target] === path;
        const s = Wallpapers.selection;
        return s !== null && s.kind === tab && s.path === path && !outputs.some(o => Wallpapers.overrides[o.description]);
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
                            anchors.fill: parent
                            cellWidth: kind === "panorama" || kind === "triptych" ? width : Math.min(root.cellWidth, width)
                            cellHeight: Theme.wallpaperPicker.thumbHeight + 2 * Theme.wallpaperPicker.selectionPadding
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            keyNavigationEnabled: true
                            model: modelEntries

                            Keys.onReturnPressed: root.apply(currentIndex)
                            Keys.onEnterPressed: root.apply(currentIndex)
                            Keys.onEscapePressed: root.close()

                            delegate: Item {
                                id: cell

                                required property var modelData
                                required property int index
                                readonly property bool current: root.isCurrent(modelData.path)

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
        }
    }
}
