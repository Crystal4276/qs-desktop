import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs.config
import qs.services

// Graphe du trafic des 2 dernières minutes (Network.history, interface de la route par défaut ; onglet « Speed » de KDE) :
// descendant en aire `sky` (couleur du module réseau de la barre), montant en ligne `peach`, échelle commune au plus haut
// relevé ; légende : débits actuels et échelle. Cartes filaire et Wi-Fi.
ColumnLayout {
    id: root

    // Calculé seulement panneau affiché (une carte par barre, panneaux fermés le plus souvent).
    readonly property bool shown: visible && (QsWindow.window?.visible ?? false)
    readonly property var samples: shown ? Network.history : []
    readonly property real peak: Math.max(1000, ...samples.map(s => Math.max(s.down, s.up)))

    Layout.fillWidth: true
    spacing: 0

    function line(key: string, w: real, h: real): string {
        if (samples.length < 2)
            return "";
        const step = w / (Network.historyLength - 1);
        const x0 = w - (samples.length - 1) * step;
        return samples.map((s, i) => `${i === 0 ? "M" : "L"} ${x0 + i * step} ${h - s[key] / peak * (h - Theme.network.graphLine)}`).join(" ");
    }

    function area(w: real, h: real): string {
        const l = line("down", w, h);
        if (l === "")
            return "";
        const x0 = w - (samples.length - 1) * w / (Network.historyLength - 1);
        return `${l} L ${w} ${h} L ${x0} ${h} Z`;
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Theme.network.graphHeight
        radius: Theme.panel.rowRadius
        color: Theme.slider.trough
        clip: true

        Shape {
            id: shape
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: Qt.alpha(Theme.network.down, Theme.network.graphFill)
                PathSvg {
                    path: root.area(shape.width, shape.height)
                }
            }

            ShapePath {
                strokeWidth: Theme.network.graphLine
                strokeColor: Theme.network.down
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: root.line("down", shape.width, shape.height)
                }
            }

            ShapePath {
                strokeWidth: Theme.network.graphLine
                strokeColor: Theme.network.up
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: root.line("up", shape.width, shape.height)
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.panel.spacing

        // Flèches d'Inter : les glyphes du module de la barre sont peu lisibles à 16 px.
        component Legend: Text {
            property color tint
            property string glyph
            property real value

            font.family: Theme.font.text
            font.pixelSize: Theme.panel.smallFontSize
            font.features: { "tnum": 1 }
            color: tint
            text: `${glyph} ${Network.format(value).trim()}`
        }

        Legend {
            tint: Theme.network.down
            glyph: "↓"
            value: Network.downBytesPerSecond
        }

        Legend {
            tint: Theme.network.up
            glyph: "↑"
            value: Network.upBytesPerSecond
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: `max ${Network.format(root.peak).trim()} · 2 min`
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.smallFontSize
            color: Theme.panel.secondaryText
        }
    }
}
