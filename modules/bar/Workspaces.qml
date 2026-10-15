import QtQuick
import QtQuick.Effects
import qs.config
import qs.services

// Espaces de travail de l'écran de la barre (INVENTORY.md § 1, THEME.md § 3).
// Affichés : les espaces existants sur cet écran, plus ceux de son bloc qui n'existent nulle part (espaces persistants de Waybar).
Item {
    id: root

    required property string output

    readonly property var shown: {
        const all = Compositor.workspaces;
        const here = all.filter(w => w.output === output);
        const persistent = Outputs.blockFor(output).filter(n => !all.some(w => w.number === n)).map(n => ({
            number: n,
            name: `${n}`,
            output: output,
            focused: false,
            visible: false,
            urgent: false,
            empty: true
        }));
        return [...here, ...persistent].sort((a, b) => a.number - b.number);
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        height: parent.height

        Repeater {
            model: root.shown

            Item {
                id: button

                required property var modelData
                required property int index

                readonly property color positionColor: index < Theme.module.workspaces.length ? Theme.module.workspaces[index] : Theme.module.workspaceOther
                readonly property color glyphColor: modelData.visible || hover.hovered || !modelData.empty ? positionColor : Theme.module.workspaceEmpty

                width: glyph.implicitWidth + 2 * Theme.bar.workspacePadding
                height: row.height

                Rectangle {
                    anchors.fill: parent
                    visible: hover.hovered
                    radius: Theme.bar.workspaceHoverRadius
                    color: Qt.alpha(button.positionColor, Theme.bar.workspaceHoverAlpha)
                }

                // Focalisé : halo `text-shadow 0 0 6px currentColor`, reproduit par une copie floutée
                // du glyphe sous le glyphe net (une ombre MultiEffect seule est deux fois trop faible).
                Text {
                    visible: button.modelData.focused
                    anchors.centerIn: parent
                    text: glyph.text
                    font: glyph.font
                    color: button.glyphColor
                    layer.enabled: visible
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1
                        blurMax: Theme.bar.workspaceGlowBlur
                        autoPaddingEnabled: true
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

                TapHandler {
                    onTapped: Compositor.focusWorkspace(button.modelData.number)
                }
            }
        }
    }

    // Molette : espace précédent (haut) / suivant (bas) parmi ceux de cette barre, avec bouclage ;
    // sans effet si l'espace focalisé n'est pas sur cet écran (comportement de Waybar).
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const list = root.shown;
            const i = list.findIndex(w => w.focused);
            if (i < 0 || event.angleDelta.y === 0)
                return;
            const step = event.angleDelta.y > 0 ? -1 : 1;
            Compositor.focusWorkspace(list[(i + step + list.length) % list.length].number);
        }
    }
}
