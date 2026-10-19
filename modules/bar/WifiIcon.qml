import QtQuick
import QtQuick.Shapes
import qs.config

// Glyphe Wi-Fi dessiné (THEME.md § 3 « Module Wi-Fi ») : géométrie des icônes Papirus `network-wireless-signal-*` (viewBox 16×16,
// éventail de sommet (8, 15)), pour animer ce qu'elles montrent en images fixes. Éventail de fond à 35 %, secteur plein selon le
// niveau (0 aucun … 4 excellent, sommets y = 15 / 9 / 6 / 4 / 1 comme Papirus), glissement d'un niveau à l'autre ; balayage en
// boucle pendant la connexion ; croix (Wi-Fi coupé) et « ! » (accès limité) repris de `network-wireless-offline` / `-limited` ;
// cadenas (réseau protégé, listes du panneau) de `network-wireless-secure-*`, réduit à 85 % dans le coin pour ne pas toucher
// l'éventail (Papirus l'entaille).
Item {
    id: root

    property int level: 0
    property bool connecting: false
    property bool off: false
    property bool limited: false
    property bool secure: false
    property color color: Theme.wifi.glyph
    property int size: Theme.bar.trayIconSize

    implicitWidth: size
    implicitHeight: size

    readonly property string wedge: "M 0,4 C 2.1,2.1 4.9,1 8,1 c 3.1,0 5.9,1.1 8,3 L 8,15 Z"
    readonly property var tops: [15, 9, 6, 4, 1]

    // Haut du secteur plein : niveau (animé) ou balayage pendant la connexion.
    property real levelTop: tops[Math.max(0, Math.min(4, level))]
    Behavior on levelTop {
        NumberAnimation {
            duration: Theme.wifi.levelDuration
            easing.type: Easing.OutCubic
        }
    }
    property real sweepTop: 15
    readonly property real fillTop: off ? 15 : connecting ? sweepTop : levelTop

    NumberAnimation on sweepTop {
        running: root.connecting && !root.off && root.visible
        from: 13
        to: 1
        duration: Theme.wifi.connectingDuration
        easing.type: Easing.InOutSine
        loops: Animation.Infinite
    }

    // Secteur plein de sommet (8, t) : arc de cercle passant par (8, t) et coupant les bords de l'éventail un peu plus bas
    // (écart mesuré sur les icônes Papirus : 0,22 × la hauteur), fermé au sommet de l'éventail. Plein au-delà d'« excellent ».
    function fill(t: real): string {
        if (t >= 14.9)
            return "";
        if (t <= 1.05)
            return wedge;
        const ye = t + 0.22 * (15 - t);
        const w = (15 - ye) * 8 / 11;
        const s = ye - t;
        const r = (w * w + s * s) / (2 * s);
        return `M ${8 - w} ${ye} A ${r} ${r} 0 0 1 ${8 + w} ${ye} L 8 15 Z`;
    }

    Shape {
        width: 16
        height: 16
        scale: root.size / 16
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Qt.alpha(root.color, Theme.wifi.glyphDim)
            PathSvg {
                path: root.wedge
            }
        }

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.color
            PathSvg {
                path: root.fill(root.fillTop)
            }
        }

        // Croix de `network-wireless-offline`, en bas à droite (hors de l'éventail).
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.off ? root.color : "transparent"
            PathSvg {
                path: "M 11,11 V 12 C 11,12.28 11.1,12.54 11.28,12.72 L 12.06,13.5 11.28,14.28 C 11.1,14.47 11,14.73 11,15 V 16 H 12 C 12.28,16 12.54,15.9 12.72,15.72 L 13.5,14.94 14.28,15.72 C 14.46,15.9 14.73,16 15,16 H 16 V 15 C 16,14.73 15.9,14.47 15.72,14.28 L 14.94,13.5 15.72,12.72 C 15.9,12.54 16,12.28 16,12 V 11 H 15 C 14.73,11 14.46,11.1 14.28,11.28 L 13.5,12.07 12.72,11.28 C 12.54,11.1 12.28,11 12,11 Z"
            }
        }

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.secure && !root.off && !root.limited ? root.color : "transparent"
            PathSvg {
                path: "M 13.45,10.05 C 12.508,10.05 11.75,10.825 11.75,11.776 L 11.75,12.6 L 10.9,12.6 L 10.9,16 L 16,16 L 16,12.6 L 15.15,12.6 L 15.15,11.776 C 15.15,10.825 14.392,10.05 13.45,10.05 z M 13.45,10.9 C 13.921,10.9 14.3,11.276 14.3,11.75 L 14.3,12.6 L 12.6,12.6 L 12.6,11.75 C 12.6,11.276 12.979,10.9 13.45,10.9 z"
            }
        }

        // « ! » de `network-wireless-*-limited`.
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.limited && !root.off ? Theme.wifi.glyphWarning : "transparent"
            PathSvg {
                path: "m 14,8 v 5 h 2 V 8 Z m 0,6 v 2 h 2 v -2 z"
            }
        }
    }
}
