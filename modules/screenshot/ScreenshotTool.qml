import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.modules.bar

// Outil de capture (modèle de l'outil de GNOME, service : Screenshot.qml) : à l'ouverture, une image figée de chaque écran ; voile et
// cadre de ta sélection actuelle (slurp). Capture dès que le choix est fait (demande du 2026-10-19) : zone (tracer, capture au
// relâchement), écran (clic sur un écran), fenêtre (clic sur une fenêtre). Barre d'outils en bas de l'écran de départ : modes,
// fermer. Entrée ou Espace capturent l'écran présélectionné (mode écran), Échap ferme. La capture vient de l'image figée, à la
// résolution réelle de l'écran.
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
            // Clavier pris seulement une fois l'outil visible (image figée reçue). Pointeur pris dès l'ouverture : curseur vide
            // (cursorHider) ; invisible, l'outil le bloque donc jusqu'aux images figées (3 s au plus).
            WlrLayershell.keyboardFocus: home && view.hasContent ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
            // Capture commencée une fois le curseur masqué (Screenshot.pointerEntered).
            MouseArea {
                anchors.fill: parent
                visible: !view.hasContent
                hoverEnabled: true
                cursorShape: Qt.BlankCursor
                onContainsMouseChanged: if (containsMouse) Screenshot.pointerEntered()
            }

            // Pas d'image figée de l'écran de départ au bout de 3 s (capture refusée, écran éteint) : outil fermé.
            Timer {
                interval: 3000
                running: win.home && !view.hasContent
                onTriggered: Screenshot.close()
            }

            ScreencopyView {
                id: view
                anchors.fill: parent
                captureSource: Screenshot.cursorHidden ? win.modelData : null
                live: !hasContent
                paintCursor: false
            }

            // Capture de la sélection si cet écran en est chargé (Screenshot.capture) : découpe de l'image figée à sa résolution
            // réelle, enregistrée, copiée dans le presse-papiers ; image figée pas encore reçue : outil fermé sans capture.
            ShaderEffectSource {
                id: crop
                z: -1
                sourceItem: view
                hideSource: false
            }

            Connections {
                target: Screenshot
                function onCaptureRequested(rect, screen) {
                    if (screen !== win.modelData?.name)
                        return;
                    const r = win.local;
                    if (!r || !view.hasContent || view.width <= 0) {
                        Screenshot.close();
                        return;
                    }
                    const scale = view.sourceSize.width / view.width;
                    crop.sourceRect = Qt.rect(r.x, r.y, r.width, r.height);
                    crop.width = r.width;
                    crop.height = r.height;
                    crop.textureSize = Qt.size(Math.round(r.width * scale), Math.round(r.height * scale));
                    const path = Screenshot.nextPath();
                    const started = crop.grabToImage(result => {
                        if (result.saveToFile(path))
                            Screenshot.copyToClipboard(path);
                        Screenshot.close();
                    }, crop.textureSize);
                    if (!started)
                        Screenshot.close();
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

                // Cadre de la sélection, à l'extérieur de la zone (comme slurp).
                Rectangle {
                    visible: win.local !== null
                    x: (win.local?.x ?? 0) - Theme.screenshot.border
                    y: (win.local?.y ?? 0) - Theme.screenshot.border
                    width: (win.local?.width ?? 0) + 2 * Theme.screenshot.border
                    height: (win.local?.height ?? 0) + 2 * Theme.screenshot.border
                    color: "transparent"
                    border.width: Theme.screenshot.border
                    border.color: Theme.screenshot.selection
                }

                // Capture dès que le choix est fait : zone tracée (au relâchement), écran ou fenêtre cliqués.
                MouseArea {
                    id: mouse

                    property point start          // global

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
                        } else if (pressed) {
                            Screenshot.selection = {
                                x: Math.min(start.x, p.x), y: Math.min(start.y, p.y),
                                width: Math.abs(p.x - start.x), height: Math.abs(p.y - start.y)
                            };
                        }
                    }

                    onExited: win.hovered = null

                    onPressed: m => {
                        const p = clampToScreen(globalPoint(m));
                        if (Screenshot.mode === "screen") {
                            Screenshot.selection = { x: win.ox, y: win.oy, width: win.width, height: win.height };
                        } else if (Screenshot.mode === "window") {
                            const w = windowAt(p);
                            Screenshot.selection = w ? { x: w.x, y: w.y, width: w.width, height: w.height } : null;
                        } else {
                            start = p;
                            Screenshot.selection = { x: p.x, y: p.y, width: 0, height: 0 };
                        }
                    }

                    // Un simple clic en mode zone (aucune surface) ne capture rien : Screenshot.capture() l'ignore.
                    onReleased: Screenshot.capture()
                }

                // Barre d'outils (écran de départ) : ce qu'il faut faire dans le mode choisi, puis les modes (glyphe et nom, le choisi
                // en contrastes inversés) et fermer.
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

                    ColumnLayout {
                        id: tools
                        anchors.centerIn: parent
                        spacing: Theme.panel.spacing

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: ({
                                area: "Drag to capture an area",
                                screen: "Click a screen to capture it",
                                window: "Click a window to capture it"
                            })[Screenshot.mode] + "  ·  Esc to cancel"
                            font.family: Theme.font.text
                            font.pixelSize: Theme.panel.smallFontSize
                            color: Theme.panel.secondaryText
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Theme.panel.spacing

                            Repeater {
                                model: [
                                    { mode: "area", glyph: Theme.icon.captureArea, name: "Area" },
                                    { mode: "screen", glyph: Theme.icon.captureScreen, name: "Screen" },
                                    { mode: "window", glyph: Theme.icon.captureWindow, name: "Window" }
                                ]

                                Rectangle {
                                    id: modeButton

                                    required property var modelData
                                    readonly property bool chosen: Screenshot.mode === modelData.mode
                                    readonly property color ink: chosen ? Theme.quickSettings.checkedText : Theme.panel.text

                                    implicitWidth: Math.max(modeGlyph.implicitWidth, modeName.implicitWidth, Theme.quickSettings.imageSize)
                                        + 2 * Theme.panel.buttonPaddingH
                                    implicitHeight: modeColumn.implicitHeight + 2 * Theme.quickSettings.buttonPadding
                                    radius: Theme.panel.rowRadius
                                    color: chosen ? Theme.quickSettings.checked : modeHover.hovered ? Theme.panel.buttonHover : Theme.panel.button

                                    Column {
                                        id: modeColumn
                                        anchors.centerIn: parent

                                        Text {
                                            id: modeGlyph
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modeButton.modelData.glyph
                                            font.family: Theme.font.icons
                                            font.pixelSize: Theme.quickSettings.glyphSize
                                            color: modeButton.ink
                                        }

                                        Text {
                                            id: modeName
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modeButton.modelData.name
                                            font.family: Theme.font.text
                                            font.pixelSize: Theme.panel.smallFontSize
                                            color: modeButton.ink
                                        }
                                    }

                                    HoverHandler {
                                        id: modeHover
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            Screenshot.mode = modeButton.modelData.mode;
                                            Screenshot.selection = modeButton.modelData.mode === "screen"
                                                ? { x: win.ox, y: win.oy, width: win.width, height: win.height } : null;
                                        }
                                    }
                                }
                            }

                            QuickButton {
                                Layout.alignment: Qt.AlignVCenter
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
}
