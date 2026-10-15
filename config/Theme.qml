pragma Singleton

import QtQuick
import Quickshell

// Traduction fidèle de docs/THEME.md, et rien d'autre.
// Toute valeur ajoutée ici doit d'abord figurer dans THEME.md.
// Unités : px logiques. 1rem de la CSS Waybar = 20 px (THEME.md, en-tête).
Singleton {
    id: root

    // § 1 — Palette Catppuccin Mocha (statique, aucun générateur)
    readonly property QtObject color: QtObject {
        readonly property color base: "#1e1e2e"
        readonly property color mantle: "#181825"
        readonly property color crust: "#11111b"
        readonly property color text: "#cdd6f4"
        readonly property color subtext0: "#a6adc8"
        readonly property color subtext1: "#bac2de"
        readonly property color surface0: "#313244"
        readonly property color surface1: "#45475a"
        readonly property color surface2: "#585b70"
        readonly property color overlay0: "#6c7086"
        readonly property color overlay1: "#7f849c"
        readonly property color overlay2: "#9399b2"
        readonly property color blue: "#89b4fa"
        readonly property color lavender: "#b4befe"
        readonly property color sapphire: "#74c7ec"
        readonly property color sky: "#89dceb"
        readonly property color teal: "#94e2d5"
        readonly property color green: "#a6e3a1"
        readonly property color yellow: "#f9e2af"
        readonly property color peach: "#fab387"
        readonly property color maroon: "#eba0ac"
        readonly property color red: "#f38ba8"
        readonly property color mauve: "#cba6f7"
        readonly property color pink: "#f5c2e7"
        readonly property color flamingo: "#f2cdcd"
        readonly property color rosewater: "#f5e0dc"
    }

    // § 1 — Couleurs propres à Rofi (anciennes valeurs Catppuccin), sous leurs noms Rofi
    readonly property QtObject rofi: QtObject {
        readonly property color bg: "#1E1D2F"
        readonly property color fg: "#D9E0EE"
        readonly property color sel: "#1E1E2E"
        readonly property color img: "#FAE3B0"
        readonly property color ugt: "#F28FAD"
        readonly property color bga: "#a6e3a1"
        readonly property color bdr: "#6c7086"
    }

    // § 1 — Autres couleurs littérales
    readonly property color hoverWhite: Qt.rgba(1, 1, 1, 0.1)   // power menu, nwg-menu
    readonly property color slurpBackground: "#ffffff20"

    // § 2 — Polices : chaque texte nomme la sienne, aucun repli implicite
    readonly property QtObject font: QtObject {
        // Icônes : la police est celle que Waybar utilisait réellement (THEME.md § 2, « Police de chaque glyphe »)
        readonly property string icons: "Symbols Nerd Font Mono"      // modules dont le texte est l'icône
        readonly property string inlineIcons: "Hack Nerd Font"        // icônes collées à du texte Inter
        readonly property string awesome: "Font Awesome 7 Free"        // Regular (400)
        readonly property string awesomeBrands: "Font Awesome 7 Brands"
        readonly property string awesome4: "FontAwesome"               // Font Awesome 4.7
        readonly property string text: "Inter"
        readonly property string bars: "DejaVu Sans"          // ▁…█ de cava
        readonly property string notification: "Noto Sans Mono"

        readonly property int barText: 26          // texte des modules
        readonly property int workspaceGlyph: 34
        readonly property int volumeIcon: 26
        readonly property int powerIcon: 28
        readonly property int cava: 20
        readonly property int notificationPt: 16   // points (Pango), titre en gras
        readonly property int launcher: 20
        readonly property int launcherSearchIcon: 20
        readonly property int powerMenuLabel: 12   // gras
        readonly property int appMenu: 20
        readonly property int appMenuSearch: 24
    }

    // § 3 — Barre
    readonly property QtObject bar: QtObject {
        readonly property color background: "transparent"
        readonly property int exclusiveZone: 65
        readonly property int pillHeight: 55           // bordure comprise
        readonly property int pillBorder: 1
        readonly property color pillBorderColor: root.color.overlay0
        readonly property color pillColor: root.color.mantle
        readonly property int pillRadius: 20
        readonly property int marginTop: 10
        readonly property int spacing: 10              // entre pilules
        readonly property int marginSide: 10
        readonly property int modulePadding: 10        // haut/bas et gauche/droite
        readonly property int workspacePadding: 8      // horizontal
        readonly property int menuButtonMin: 40
        readonly property int menuButtonPadding: 10
        readonly property int menuIconSize: 38
        readonly property int trayIconSize: 32
        readonly property int traySpacing: 5
        readonly property int trayPadding: 6
        readonly property int networkPadding: 10
        readonly property int networkMinWidth: 80
        readonly property int volumeIconMinWidth: 35
        readonly property int cavaPaddingLeft: 10
        readonly property int cavaPaddingTop: 12
        readonly property int workspaceHoverRadius: 20
        readonly property real workspaceHoverAlpha: 0.1
        // halo du focalisé, `text-shadow 0 0 6px currentColor` : copie du glyphe floutée par MultiEffect,
        // rayon max mesuré contre la référence (THEME.md § 3)
        readonly property int workspaceGlowBlur: 28
    }

    // § 3 — Curseur de volume
    readonly property QtObject slider: QtObject {
        readonly property int minWidth: 50
        readonly property int padding: 20
        readonly property int troughHeight: 15
        readonly property int troughRadius: 15
        readonly property color trough: root.color.crust
        readonly property color fill: root.color.text
        readonly property int knobSize: 20
        readonly property color knob: root.color.surface2
    }

    // § 3 — Couleurs des modules
    readonly property QtObject module: QtObject {
        readonly property list<color> workspaces: [root.color.teal, root.color.sapphire, root.color.blue]  // par position
        readonly property color workspaceOther: root.color.text   // 4e position ou plus
        readonly property color workspaceEmpty: root.color.surface1
        readonly property color updates: root.color.sapphire
        readonly property color gpu: root.color.sky
        readonly property color cpu: root.color.teal
        readonly property color memory: root.color.green
        readonly property color clock: root.color.yellow
        readonly property color network: root.color.sky
        readonly property color volume: root.color.text
        readonly property color media: root.color.text
        readonly property color cava: root.color.green
        readonly property color power: root.color.red
        readonly property color battery: root.color.green
        readonly property color batteryWarning: root.color.red
        readonly property color backlight: root.color.yellow
        readonly property color menuLogo: root.color.green
        readonly property color menuBackground: root.color.mantle
        readonly property color menuActiveBackground: root.color.green
    }

    // Glyphes (INVENTORY.md § 1, planche docs/reference/glyphs.png), avec leur police
    readonly property QtObject icon: QtObject {
        // font.icons (Symbols Nerd Font Mono)
        readonly property list<string> workspaces: ["\ue79a", "\ue78c", "\uf32e", "\u{f043e}", "\uf1ff", "\uf1bc", "\uf043", "\uf0e0", "\uf1b6"]  // par numéro, 1 à 9
        readonly property list<string> volume: ["\uf026", "\uf027", "\uf028"]  // 0–33, 34–66, 67–100 %
        readonly property string muted: "\uf466"
        readonly property string power: "\uf011"
        readonly property string search: "\uf002"
        readonly property list<string> backlight: ["\ue38d", "\ue3d3", "\ue3d1", "\ue3cf", "\ue3ce", "\ue3cd", "\ue3ca", "\ue3c8", "\ue39b"]
        // batterie : anciennes icônes retirées de Nerd Fonts v3, à choisir en phase 4

        // font.inlineIcons (Hack Nerd Font)
        readonly property string updates: "\u{f01a7}"
        readonly property string gpu: "\u{f0379}"
        readonly property string cpu: "\uec19"
        readonly property string memory: "\u{f035b}"
        readonly property string clock: "\ue385"
        readonly property string download: "\u{f1625}"
        readonly property string upload: "\u{f1628}"

        // font.awesome / awesomeBrands / awesome4
        readonly property string calendar: "\uf274"   // font.awesome
        readonly property string spotify: "\uf1bc"    // font.awesomeBrands
        readonly property string paused: "\uf04c"     // font.awesome4

        // font.bars (DejaVu Sans)
        readonly property list<string> cavaBars: ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    }

    // § 12 — Images embarquées
    readonly property QtObject image: QtObject {
        readonly property url archGreen: Quickshell.shellPath("assets/arch_linux_icon_green.svg")
        readonly property url archMantle: Quickshell.shellPath("assets/arch_linux_icon_mantle.svg")
        readonly property url lock: Quickshell.shellPath("assets/lock.svg")
        readonly property url logout: Quickshell.shellPath("assets/logout.svg")
        readonly property url restart: Quickshell.shellPath("assets/restart.svg")
        readonly property url shutdown: Quickshell.shellPath("assets/shutdown.svg")
    }

    // § 4 — Notifications
    readonly property QtObject notification: QtObject {
        readonly property int offset: 4               // coin bas-droit, x et y
        readonly property int width: 600
        readonly property int maxHeight: 600
        readonly property int gap: 20
        readonly property color background: root.color.base
        readonly property color foreground: root.color.text
        readonly property int border: 1
        readonly property color frame: root.color.overlay2
        readonly property color frameCritical: root.color.peach
        readonly property int radius: 15
        readonly property int paddingV: 16
        readonly property int paddingH: 8
        readonly property int textPadding: 32         // icône → texte
        readonly property int iconSize: 100
        readonly property int progressHeight: 20
        readonly property int progressFrame: 4
        readonly property int progressMinWidth: 150
        readonly property int progressMaxWidth: 300
    }

    // § 5 — Lanceur
    readonly property QtObject launcher: QtObject {
        readonly property int width: 500
        readonly property int height: 1000
        readonly property color background: root.rofi.bg
        readonly property int border: 1
        readonly property color borderColor: root.color.overlay0
        readonly property int radius: 20
        readonly property int padding: 15
        readonly property int spacing: 15
        readonly property color searchButton: root.rofi.sel
        readonly property int searchButtonPaddingV: 8
        readonly property int searchButtonPaddingH: 12
        readonly property color prompt: root.rofi.img
        readonly property int promptPadding: 8
        readonly property string placeholder: "Search..."
        readonly property color placeholderColor: root.rofi.fg
        readonly property int entryUnderline: 2
        readonly property color entryUnderlineColor: root.color.overlay0
        readonly property int entryRadius: 10
        readonly property int entryPadding: 8
        readonly property int listSpacing: 4
        readonly property int itemPadding: 6
        readonly property int itemRadius: 4
        readonly property int itemIconSize: 24
        readonly property int itemTextMargin: 2
        readonly property color text: root.rofi.fg
        readonly property color selected: root.color.green
        readonly property color selectedText: root.rofi.sel
        readonly property int selectedRadius: 10
    }

    // § 6 — Power menu
    readonly property QtObject powerMenu: QtObject {
        readonly property int width: 126
        readonly property int height: 352
        readonly property int offsetX: -5
        readonly property int offsetY: 5
        readonly property color background: root.rofi.bg
        readonly property int border: 1
        readonly property color borderColor: root.rofi.bdr
        readonly property int radius: 20
        readonly property int padding: 15
        readonly property real itemPadding: 7.5
        readonly property real itemRadius: 7.5
        readonly property color item: root.rofi.sel
        readonly property color itemHover: root.hoverWhite
        readonly property int iconSize: 48
        readonly property color text: root.rofi.fg
    }

    // § 7 — Menu d'applications (style actuel de nwg-menu)
    readonly property QtObject appMenu: QtObject {
        readonly property color background: root.color.mantle
        readonly property color listBackground: root.color.base
        readonly property int border: 1
        readonly property color borderColor: root.color.overlay0
        readonly property int radius: 20
        readonly property int itemPadding: 5
        readonly property int itemMargin: 2
        readonly property int itemRadius: 20
        readonly property color text: root.color.text
        readonly property color selected: root.color.green
        readonly property color selectedText: root.color.mantle
        readonly property int searchUnderline: 1
        readonly property color searchUnderlineColor: root.color.overlay2
        readonly property int searchRadius: 10
        readonly property int scrollbarWidth: 25
        readonly property color scrollbar: root.color.overlay0
        readonly property color scrollbarHover: root.color.overlay1
        readonly property color buttonHover: root.hoverWhite
        readonly property int categoryIconSize: 48
        readonly property int itemIconSize: 24
    }

    // § 9 — Thèmes système
    readonly property string iconTheme: "Papirus-Dark"   // imposé par `//@ pragma IconTheme` dans shell.qml

}
