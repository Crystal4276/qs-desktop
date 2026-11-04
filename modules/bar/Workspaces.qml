import QtQuick
import Quickshell
import qs.config
import qs.services

// Espaces de travail de l'écran de la barre (INVENTORY.md § 1, THEME.md § 3).
// Boutons : exactement les numéros du bloc de cet écran (services/Outputs.qml), qu'ils existent ou non, pas la position
// instantanée des espaces (un espace créé ailleurs puis déplacé faisait sauter les pilules). Écart à Waybar : BACKLOG.md.
Item {
    id: root

    required property string output

    readonly property var shown: {
        const workspaces = Compositor.workspaces;
        return Outputs.blockFor(output).map(n => {
            const w = workspaces.find(w => w.number === n);
            if (!w)
                return {
                    number: n,
                    name: `${n}`,
                    output: output,
                    focused: false,
                    visible: false,
                    urgent: false,
                    empty: true,
                    persistent: true
                };
            // Affiché ou focalisé ailleurs, le temps qu'Outputs le ramène : pas de lueur ici. Écran pas encore connu (Hyprland :
            // créé à l'instant, `$mod+N`) : son état est montré tout de suite.
            const here = w.output === output || w.output === "";
            return Object.assign({}, w, {
                output: output,
                focused: w.focused && here,
                visible: w.visible && here,
                persistent: false
            });
        });
    }

    // Couleur au point t (0 → 1) du dégradé linéaire passant par les couleurs de Theme.module.workspaces.
    function gradient(t: real): color {
        const stops = Theme.module.workspaces;
        const x = Math.max(0, Math.min(1, t)) * (stops.length - 1);   // index -1 : bouton en cours de retrait (ScriptModel)
        const i = Math.min(Math.floor(x), stops.length - 2);
        const a = stops[i], b = stops[i + 1], f = x - i;
        return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1);
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    clip: true   // halo de l'espace focalisé

    Row {
        id: row
        height: parent.height

        Repeater {
            // ScriptModel : boutons conservés d'un changement à l'autre (survol gardé), données mises à jour sur place.
            model: ScriptModel {
                values: root.shown
                objectProp: "number"
            }

            Item {
                id: button

                required property var modelData
                required property int index

                // Couleur par position dans la barre, en dégradé sur les couleurs du thème (THEME.md § 3) :
                // avec 3 espaces, exactement teal / sapphire / blue comme Waybar.
                readonly property color positionColor: root.gradient(root.shown.length > 1 ? index / (root.shown.length - 1) : 0)
                readonly property color glyphColor: modelData.visible || hover.hovered || !modelData.empty ? positionColor : Theme.module.workspaceEmpty

                width: glyph.implicitWidth + 2 * Theme.bar.workspacePadding
                height: row.height

                Rectangle {
                    anchors.fill: parent
                    visible: hover.hovered
                    radius: Theme.bar.workspaceHoverRadius
                    color: Qt.alpha(button.positionColor, Theme.bar.workspaceHoverAlpha)
                }

                // Espace affiché sur cet écran (Waybar : seulement le focalisé ; ton choix du 2026-10-16 : un par écran) :
                // halo `text-shadow 0 0 6px currentColor` de Waybar, reproduit par l'ombre floue (shadowBlur) du glyphe
                // dessiné dans un Canvas (le flou de MultiEffect, approché par paliers, faisait un carré visible autour).
                // Coupé aux limites du module (clip de root), pour ne pas déborder de la pilule sur le fond d'écran.
                Canvas {
                    id: glow

                    readonly property int margin: Theme.bar.workspaceGlowMargin

                    visible: button.modelData.visible
                    x: glyph.x - margin
                    y: glyph.y - margin
                    width: glyph.width + 2 * margin
                    height: glyph.height + 2 * margin

                    onVisibleChanged: requestPaint()
                    onAvailableChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    Connections {
                        target: button
                        function onGlyphColorChanged() {
                            glow.requestPaint();
                        }
                    }

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.font = `${glyph.font.pixelSize}px "${glyph.font.family}"`;
                        ctx.fillStyle = button.glyphColor;
                        ctx.shadowColor = button.glyphColor;
                        ctx.shadowBlur = Theme.bar.workspaceGlowBlur;
                        ctx.fillText(glyph.text, margin, margin + glyph.baselineOffset);
                    }
                }

                Text {
                    id: glyph
                    anchors.centerIn: parent
                    text: button.modelData.number >= 1 && button.modelData.number <= Theme.icon.workspaces.length
                        ? Theme.icon.workspaces[button.modelData.number - 1] : button.modelData.name
                    font.family: Theme.font.icons
                    font.pixelSize: Theme.font.workspaceGlyph
                    color: button.glyphColor
                }

                HoverHandler {
                    id: hover
                }

                // Espace persistant (n'existe nulle part) : créé directement sur l'écran de cette barre, pas sur l'écran focalisé
                // d'où il faudrait ensuite le déplacer.
                TapHandler {
                    onTapped: Compositor.focusWorkspace(button.modelData.number, button.modelData.persistent ? root.output : "")
                }
            }
        }
    }

    // Molette : espace précédent (haut) / suivant (bas) parmi ceux de cette barre, avec bouclage ;
    // sans effet si l'espace focalisé n'est pas sur cet écran (comportement de Waybar).
    WheelSteps {
        onStep: direction => {
            const list = root.shown;
            const i = list.findIndex(w => w.focused);
            if (i >= 0)
                Compositor.focusWorkspace(list[(i - direction + list.length) % list.length].number, "");
        }
    }
}
