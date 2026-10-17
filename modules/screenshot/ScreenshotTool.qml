import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.modules.bar

// Outil de capture (modèle de l'outil de GNOME, service : Screenshot.qml) : à l'ouverture, une image figée de chaque écran ; voile et
// cadre de ta sélection actuelle (slurp). Modes : zone (tracer ; déplacer en tirant dedans ; redimensionner par les coins), écran
// (clic sur un écran), fenêtre (clic sur une fenêtre). Barre d'outils en bas de l'écran de départ : modes, capture, fermer.
// Entrée ou Espace capturent, Échap ferme. La capture vient de l'image figée, à la résolution réelle de l'écran.
LazyLoader {
    active: Screenshot.active

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData
            readonly property var output: Compositor.output(modelData?.name ?? "")
            readonly property bool home: (modelData?.name ?? "") === Screenshot.startScreen
            readonly property real ox: output?.x ?? 0
            readonly property real oy: output?.y ?? 0
            // Sélection dans les coordonnées de cet écran (null : aucune, ou sur un autre écran).
            readonly property var local: {
                const s = Screenshot.selection;
                if (!s || !output)
                    return null;
                const x1 = Math.max(s.x, ox), y1 = Math.max(s.y, oy);
                const x2 = Math.min(s.x + s.width, ox + output.width), y2 = Math.min(s.y + s.height, oy + output.height);
                return x2 > x1 && y2 > y1 ? { x: x1 - ox, y: y1 - oy, width: x2 - x1, height: y2 - y1 } : null;
            }
            property var hovered: null      // écran ou fenêtre sous le pointeur (coordonnées de cet écran)

            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-screenshot"
            WlrLayershell.keyboardFocus: home ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"

            // Image figée, sans curseur : la vue capture en continu jusqu'à sa première image, puis s'arrête (une capture demandée
            // à la création échoue : le contexte d'enregistrement n'est pas encore prêt). L'outil reste invisible jusque-là, il
            // n'apparaît donc pas sur l'image.
            ScreencopyView {
                id: view
                anchors.fill: parent
                captureSource: win.modelData
                live: !hasContent
                paintCursor: false
            }

            // Capture de la sélection si elle est sur cet écran : découpe de l'image figée à sa résolution réelle, enregistrée,
            // copiée dans le presse-papiers.
            ShaderEffectSource {
                id: crop
                z: -1
                sourceItem: view
                hideSource: false
            }

            Connections {
                target: Screenshot
                function onCaptureRequested(rect) {
                    const r = win.local;
                    if (!r || !view.hasContent || view.width <= 0)
                        return;
                    const scale = view.sourceSize.width / view.width;
                    crop.sourceRect = Qt.rect(r.x, r.y, r.width, r.height);
                    crop.width = r.width;
                    crop.height = r.height;
                    crop.textureSize = Qt.size(Math.round(r.width * scale), Math.round(r.height * scale));
                    const path = Screenshot.nextPath();
                    crop.grabToImage(result => {
                        if (result.saveToFile(path))
                            Screenshot.copyToClipboard(path);
                        Screenshot.close();
                    }, crop.textureSize);
                }
            }

            Item {
                id: ui

                anchors.fill: parent
                visible: view.hasContent
                focus: win.home

                Keys.onEscapePressed: Screenshot.close()
                Keys.onReturnPressed: Screenshot.capture()
                Keys.onEnterPressed: Screenshot.capture()
                Keys.onSpacePressed: Screenshot.capture()

                // Voile hors de la sélection (tout l'écran sans sélection ici).
                Rectangle {
                    x: 0
                    y: 0
                    width: parent.width
                    height: win.local ? win.local.y : parent.height
                    color: Theme.screenshot.veil
                }
                Rectangle {
                    visible: win.local !== null
                    x: 0
                    y: win.local?.y ?? 0
                    width: win.local?.x ?? 0
                    height: win.local?.height ?? 0
                    color: Theme.screenshot.veil
                }
                Rectangle {
                    visible: win.local !== null
                    x: (win.local?.x ?? 0) + (win.local?.width ?? 0)
                    y: win.local?.y ?? 0
                    width: parent.width - x
                    height: win.local?.height ?? 0
                    color: Theme.screenshot.veil
                }
                Rectangle {
                    visible: win.local !== null
                    x: 0
                    y: (win.local?.y ?? 0) + (win.local?.height ?? 0)
                    width: parent.width
                    height: parent.height - y
                    color: Theme.screenshot.veil
                }

                // Écran ou fenêtre sous le pointeur (modes écran et fenêtre).
                Rectangle {
                    visible: win.hovered !== null && Screenshot.mode !== "area"
                    x: win.hovered?.x ?? 0
                    y: win.hovered?.y ?? 0
                    width: win.hovered?.width ?? 0
                    height: win.hovered?.height ?? 0
                    color: Theme.screenshot.hover
                }

                // Cadre de la sélection, à l'extérieur de la zone (comme slurp) ; poignées aux coins en mode zone.
                Rectangle {
                    visible: win.local !== null
                    x: (win.local?.x ?? 0) - Theme.screenshot.border
                    y: (win.local?.y ?? 0) - Theme.screenshot.border
                    width: (win.local?.width ?? 0) + 2 * Theme.screenshot.border
                    height: (win.local?.height ?? 0) + 2 * Theme.screenshot.border
                    color: "transparent"
                    border.width: Theme.screenshot.border
                    border.color: Theme.screenshot.selection

                    Repeater {
                        model: Screenshot.mode === "area" ? [[0, 0], [1, 0], [0, 1], [1, 1]] : []

                        Rectangle {
                            required property var modelData
                            width: Theme.screenshot.handle
                            height: width
                            radius: width / 2
                            color: Theme.screenshot.selection
                            x: modelData[0] * parent.width - width / 2
                            y: modelData[1] * parent.height - height / 2
                        }
                    }
                }

                MouseArea {
                    id: mouse

                    property string action: ""   // "new", "move", "resize"
                    property point start          // global
                    property var original: null   // sélection au début du geste
                    property var corner: [0, 0]   // coin tiré (0 : gauche / haut, 1 : droite / bas)

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Screenshot.mode === "area" ? Qt.CrossCursor : Qt.PointingHandCursor

                    function globalPoint(m): point {
                        return Qt.point(m.x + win.ox, m.y + win.oy);
                    }

                    // Point gardé sur l'écran du geste.
                    function clampToScreen(p: point): point {
                        return Qt.point(Math.max(win.ox, Math.min(p.x, win.ox + win.width)), Math.max(win.oy, Math.min(p.y, win.oy + win.height)));
                    }

                    function windowAt(p: point): var {
                        const list = Screenshot.windows.filter(w => p.x >= w.x && p.x < w.x + w.width && p.y >= w.y && p.y < w.y + w.height);
                        return list.length > 0 ? list[list.length - 1] : null;   // la dernière : flottante, au-dessus
                    }

                    onPositionChanged: m => {
                        const p = clampToScreen(globalPoint(m));
                        if (Screenshot.mode === "screen") {
                            win.hovered = { x: 0, y: 0, width: win.width, height: win.height };
                        } else if (Screenshot.mode === "window") {
                            const w = windowAt(p);
                            win.hovered = w ? { x: w.x - win.ox, y: w.y - win.oy, width: w.width, height: w.height } : null;
                        }
                        if (!pressed || Screenshot.mode !== "area")
                            return;
                        if (action === "new") {
                            Screenshot.selection = {
                                x: Math.min(start.x, p.x), y: Math.min(start.y, p.y),
                                width: Math.abs(p.x - start.x), height: Math.abs(p.y - start.y)
                            };
                        } else if (action === "move") {
                            const o = original;
                            const nx = Math.max(win.ox, Math.min(o.x + p.x - start.x, win.ox + win.width - o.width));
                            const ny = Math.max(win.oy, Math.min(o.y + p.y - start.y, win.oy + win.height - o.height));
                            Screenshot.selection = { x: nx, y: ny, width: o.width, height: o.height };
                        } else if (action === "resize") {
                            const o = original;
                            // Coin opposé fixe.
                            const fx = corner[0] === 0 ? o.x + o.width : o.x, fy = corner[1] === 0 ? o.y + o.height : o.y;
                            Screenshot.selection = {
                                x: Math.min(fx, p.x), y: Math.min(fy, p.y), width: Math.abs(p.x - fx), height: Math.abs(p.y - fy)
                            };
                        }
                    }

                    onExited: win.hovered = null

                    onPressed: m => {
                        const p = clampToScreen(globalPoint(m));
                        if (Screenshot.mode === "screen") {
                            Screenshot.selection = { x: win.ox, y: win.oy, width: win.width, height: win.height };
                            return;
                        }
                        if (Screenshot.mode === "window") {
                            const w = windowAt(p);
                            if (w)
                                Screenshot.selection = { x: w.x, y: w.y, width: w.width, height: w.height };
                            return;
                        }
                        start = p;
                        const s = Screenshot.selection;
                        original = s;
                        const near = (a, b) => Math.abs(a - b) <= Theme.screenshot.handle;
                        if (s && [0, 1].some(cx => near(p.x, s.x + cx * s.width)) && [0, 1].some(cy => near(p.y, s.y + cy * s.height))) {
                            action = "resize";
                            corner = [near(p.x, s.x) ? 0 : 1, near(p.y, s.y) ? 0 : 1];
                        } else if (s && p.x >= s.x && p.x <= s.x + s.width && p.y >= s.y && p.y <= s.y + s.height) {
                            action = "move";
                        } else {
                            action = "new";
                            Screenshot.selection = { x: p.x, y: p.y, width: 0, height: 0 };
                        }
                    }
                }

                // Barre d'outils (écran de départ) : modes, capture, fermer.
                Rectangle {
                    visible: win.home
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.screenshot.gap
                    width: tools.implicitWidth + 2 * Theme.panel.padding
                    height: tools.implicitHeight + 2 * Theme.panel.padding
                    radius: Theme.panel.radius
                    color: Theme.panel.background
                    border.width: Theme.panel.border
                    border.color: Theme.panel.borderColor

                    // Les clics sur la barre ne touchent pas la sélection.
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                    }

                    RowLayout {
                        id: tools
                        anchors.centerIn: parent
                        spacing: Theme.panel.spacing

                        Repeater {
                            model: [
                                { mode: "area", glyph: Theme.icon.captureArea },
                                { mode: "screen", glyph: Theme.icon.captureScreen },
                                { mode: "window", glyph: Theme.icon.captureWindow }
                            ]

                            QuickButton {
                                required property var modelData
                                readonly property bool chosen: Screenshot.mode === modelData.mode
                                glyph: modelData.glyph
                                activeFocusOnTab: false
                                background: chosen ? Theme.quickSettings.checked : Theme.panel.button
                                hoverBackground: chosen ? Theme.quickSettings.checked : Theme.panel.buttonHover
                                glyphColor: chosen ? Theme.quickSettings.checkedText : Theme.panel.text
                                onClicked: {
                                    Screenshot.mode = modelData.mode;
                                    Screenshot.selection = modelData.mode === "screen"
                                        ? { x: win.ox, y: win.oy, width: win.width, height: win.height } : null;
                                }
                            }
                        }

                        // Capture : anneau et disque `text`.
                        Rectangle {
                            implicitWidth: Theme.screenshot.captureSize
                            implicitHeight: implicitWidth
                            radius: width / 2
                            color: "transparent"
                            border.width: Theme.screenshot.border
                            border.color: Theme.panel.text
                            opacity: Screenshot.selection && Screenshot.selection.width > 0 ? 1 : Theme.panel.disabledOpacity

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 4 * Theme.screenshot.border
                                height: width
                                radius: width / 2
                                color: Theme.panel.text
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: Screenshot.capture()
                            }
                        }

                        QuickButton {
                            glyph: Theme.icon.close
                            activeFocusOnTab: false
                            onClicked: Screenshot.close()
                        }
                    }
                }
            }
        }
    }
}
