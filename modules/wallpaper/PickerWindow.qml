import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.modules.bar

// Utilitaire de changement de fond (docs/WALLPAPERS.md, proposition 4) : vignettes du dossier des fonds, par onglet — images simples,
// panoramas (plusieurs écrans), triptyques (trois écrans). Un clic ou Entrée applique le fond tout de suite ; la fenêtre reste
// ouverte pour comparer. Image simple : pour tous les écrans ou un seul (rangée du haut). Échap ou un clic à côté ferme.
OverlayPopup {
    id: root

    property string tab: "simple"
    property string target: ""   // description de l'écran visé ("" : tous)

    readonly property var outputs: [...Compositor.outputs].sort((a, b) => a.x - b.x)
    readonly property var tabs: [
        { key: "simple", name: "Images" },
        ...(outputs.length > 1 ? [{ key: "panorama", name: "Panoramas" }] : []),
        ...(outputs.length === 3 ? [{ key: "triptych", name: "Triptychs" }] : [])
    ]
    readonly property bool wide: tab !== "simple"   // panoramas et triptyques : vignettes de deux colonnes
    readonly property var items: {
        const lib = Wallpapers.library;
        if (tab === "triptych")
            return lib.triptych.map(t => ({ path: t.path, sources: ["left", "center", "right"].map(p => Wallpapers.url(t.parts[p])) }));
        return (tab === "panorama" ? lib.panorama : lib.simple).map(p => ({ path: p, sources: [Wallpapers.url(p)] }));
    }

    // Sur l'écran `from` (bouton du panneau de réglages), sinon l'écran focalisé (raccourci).
    function open(from: var): void {
        screen = from ?? Outputs.focusedScreen();
        Wallpapers.refresh();
        if (!tabs.some(t => t.key === tab))
            tab = "simple";
        prepareOpen(null);
        visible = true;
        grid.forceActiveFocus();
    }

    function toggle(): void {
        visible ? close() : open(null);
    }

    // Choix « tous les écrans » : seulement si aucun écran présent n'a sa propre image (celles d'écrans débranchés ne comptent pas).
    function isCurrent(path: string): bool {
        if (tab === "simple" && target !== "")
            return Wallpapers.overrides[target] === path;
        const s = Wallpapers.selection;
        return s !== null && s.kind === tab && s.path === path && !outputs.some(o => Wallpapers.overrides[o.description]);
    }

    function apply(index: int): void {
        const item = items[index];
        if (!item)
            return;
        if (tab === "simple" && target !== "")
            Wallpapers.setOutput(target, item.path);
        else
            Wallpapers.setAll(tab, item.path);
    }

    WlrLayershell.namespace: "quickshell-wallpaper-picker"
    frameItem: frame

    onTabChanged: grid.currentIndex = 0
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

        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        // Quatre vignettes simples de large (deux panoramas ou triptyques).
        width: Theme.wallpaperPicker.columns * (Theme.wallpaperPicker.thumbWidth + 2 * Theme.wallpaperPicker.selectionPadding)
            + 2 * Theme.panel.padding
        onCloseRequested: root.close()

        // Onglets ; pour les images simples, l'écran visé.
        RowLayout {
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

            Item {
                Layout.fillWidth: true
            }

            Repeater {
                model: root.tab === "simple" && root.outputs.length > 1 ? [{ description: "", name: "All screens" }, ...root.outputs] : []

                PanelButton {
                    required property var modelData
                    text: modelData.name
                    checked: root.target === modelData.description
                    onClicked: root.target = modelData.description
                }
            }
        }

        GridView {
            id: grid

            Layout.fillWidth: true
            Layout.preferredHeight: Theme.wallpaperPicker.rows * cellHeight
            cellWidth: (Theme.wallpaperPicker.thumbWidth + 2 * Theme.wallpaperPicker.selectionPadding) * (root.wide ? 2 : 1)
            cellHeight: Theme.wallpaperPicker.thumbHeight + 2 * Theme.wallpaperPicker.selectionPadding
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true
            model: root.items

            Keys.onReturnPressed: root.apply(currentIndex)
            Keys.onEnterPressed: root.apply(currentIndex)
            Keys.onEscapePressed: root.close()

            delegate: Item {
                id: cell

                required property var modelData
                required property int index
                readonly property bool current: root.isCurrent(modelData.path)

                width: grid.cellWidth
                height: grid.cellHeight

                // Fond choisi : cadre `green` ; vignette sous le pointeur ou au clavier : cadre `surface0`.
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.wallpaperPicker.radius + Theme.wallpaperPicker.selectionPadding
                    color: cell.current ? Theme.wallpaperPicker.selection
                        : hover.hovered || (grid.activeFocus && grid.currentIndex === cell.index) ? Theme.wallpaperPicker.hover : "transparent"
                }

                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.wallpaperPicker.selectionPadding
                    radius: Theme.wallpaperPicker.radius
                    color: Theme.panel.fieldBackground

                    Row {
                        anchors.fill: parent

                        Repeater {
                            model: cell.modelData.sources

                            Image {
                                required property string modelData
                                width: parent.width / cell.modelData.sources.length
                                height: parent.height
                                source: modelData
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
                                asynchronous: true
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
                        grid.currentIndex = cell.index;
                        root.apply(cell.index);
                    }
                }
            }
        }
    }
}
