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
    // Sélection de zone des captures (`slurp -b ffffff20 -c f5c2e7 -w 4`, touche Impr.) ; slurp lit #RRGGBBAA, QML #AARRGGBB.
    readonly property color slurpBackground: Qt.rgba(1, 1, 1, 0x20 / 255)
    readonly property color slurpSelection: root.color.pink
    readonly property int slurpBorder: 4

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
        readonly property string notification: "Inter"   // Dunst : Noto Sans Mono ; Inter à ta demande (police homogène)

        readonly property int barText: 26          // texte des modules
        readonly property int workspaceGlyph: 34
        readonly property int volumeIcon: 26
        readonly property int powerIcon: 28
        readonly property int defaultIcon: 20     // modules sans taille dans style.css (batterie, rétroéclairage) : texte GTK, 12 pt × 1,25
        readonly property int cava: 20
        readonly property int notificationPt: 16   // points (Pango), titre en gras
        readonly property int launcherPt: 20             // points (Pango) = 26,67 px : pas de ligne de 53 px, majuscules de 20 px (mesuré)
        readonly property int launcherSearchIconPt: 20   // points
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

    // § 3 — Calendrier de l'horloge (nouveau composant, ARCHITECTURE § 8.3) : valeurs reprises de la barre et du lanceur
    readonly property QtObject calendar: QtObject {
        readonly property int gap: 10                    // sous la pilule, à la hauteur du haut des fenêtres (gaps 10)
        readonly property color background: root.color.mantle
        readonly property int border: 1
        readonly property color borderColor: root.color.overlay0
        readonly property int radius: 20
        readonly property int padding: 15
        readonly property int spacing: 10
        readonly property int titleSize: 26
        readonly property int fontSize: 20
        readonly property int cell: 40
        readonly property int todayRadius: 10
        readonly property color title: root.color.yellow   // couleur de l'horloge
        readonly property color text: root.color.text
        readonly property color weekday: root.color.subtext0
        readonly property color otherMonth: root.color.surface2
        readonly property color today: root.color.green
        readonly property color todayText: root.color.mantle
        readonly property int autoCloseDelay: 5000       // ms : épinglé, pointeur hors du calendrier et de l'horloge → fermeture
    }

    // § 3 — Menus du tray : copie des menus GTK du thème catppuccin-mocha-green (gtk-3.0/gtk-dark.css), mesurée sur capture ;
    // texte en Inter (ta demande : police homogène) au lieu du repli monospace de Waybar.
    readonly property QtObject trayMenu: QtObject {
        readonly property color gtkForeground: "#eff1f5"           // couleur de texte du thème GTK
        readonly property color background: root.color.surface0     // #313244
        readonly property color frame: Qt.rgba(0.937, 0.945, 0.961, 0.1)    // bordure intérieure 1 px, #eff1f5 à 10 %
        readonly property color outline: Qt.rgba(0.067, 0.067, 0.106, 0.8)  // liseré extérieur 1 px (crust), mesuré
        readonly property int radius: 12
        readonly property int padding: 6
        readonly property int itemPaddingV: 4
        readonly property int itemPaddingH: 8
        readonly property int itemRadius: 6
        readonly property color itemHover: Qt.rgba(0.937, 0.945, 0.961, 0.08)
        readonly property real disabledOpacity: 0.5
        readonly property color separator: Qt.rgba(0.937, 0.945, 0.961, 0.12)
        readonly property int outlineWidth: 1         // liseré extérieur
        readonly property int frameWidth: 1           // bordure intérieure
        readonly property int separatorHeight: 1
        readonly property int separatorMargin: 4
        readonly property int toggleSize: 16          // place réservée avant le texte (case, radio ou icône)
        readonly property int toggleSpacing: 2        // texte à 18 px du bord intérieur de l'élément (mesuré)
        readonly property color toggleBackground: Qt.rgba(0.937, 0.945, 0.961, 0.12)
        readonly property color toggleChecked: root.color.green
        readonly property color toggleMark: Qt.rgba(0.067, 0.067, 0.106, 0.87)
        readonly property int arrowMargin: 8          // flèche de sous-menu : 16 px, 8 px après le texte
        readonly property int fontSize: 20            // texte GTK : 12 pt × 1,25
    }

    // § 3 — Panneaux des modules natifs (réseau, Bluetooth, disques, NordVPN) : nouveau composant, style du calendrier,
    // valeurs reprises de la barre, du calendrier et du lanceur (THEME.md § 3 « Panneaux »).
    readonly property QtObject panel: QtObject {
        readonly property int gap: 10                       // sous la pilule, comme le calendrier
        readonly property int width: 500                    // largeur du lanceur
        readonly property color background: root.color.mantle
        readonly property int border: 1
        readonly property color borderColor: root.color.overlay0
        readonly property int radius: 20
        readonly property int padding: 15
        readonly property int spacing: 10
        readonly property int fontSize: 20                  // texte principal (lanceur)
        readonly property int smallFontSize: 16             // texte secondaire, titres de section
        readonly property int iconSize: 24                  // icônes des lignes (lanceur)
        readonly property color text: root.color.text
        readonly property color secondaryText: root.color.subtext0
        readonly property color title: root.color.yellow   // comme le titre du calendrier
        readonly property color accent: root.color.green   // connecté, actif
        readonly property color warning: root.color.red
        readonly property int rowPadding: 8
        readonly property int rowRadius: 10                 // sélection du lanceur
        readonly property color rowHover: root.color.surface0
        readonly property color button: root.color.surface0
        readonly property color buttonHover: root.color.surface1
        readonly property int buttonPaddingV: 6
        readonly property int buttonPaddingH: 12
        readonly property int switchWidth: 44
        readonly property int switchHeight: 24
        readonly property color switchOn: root.color.green
        readonly property color switchOff: root.color.surface1
        readonly property color switchKnobOn: root.color.mantle
        readonly property color switchKnobOff: root.color.overlay2
        readonly property color fieldBackground: root.color.base
        readonly property color fieldBorder: root.color.overlay0
        readonly property color fieldFocus: root.color.green
        // Élément choisi au clavier (Tab, flèches) : liseré de la largeur de la bordure des panneaux, en `text` pour rester
        // visible sur une bascule activée (fond `green`). Nouveau, à valider.
        readonly property color focusRing: root.color.text
        readonly property real disabledOpacity: 0.5   // bouton indisponible, niveau coupé (THEME.md § 3 et § 4)
        readonly property int maxListHeight: 400            // au-delà, la liste défile
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
        readonly property list<color> workspaces: [root.color.teal, root.color.sapphire, root.color.blue]  // dégradé par position dans la barre
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
        readonly property color settings: root.color.text    // engrenage (ton choix du 2026-10-16 ; power : `red`)
        readonly property color battery: root.color.green
        readonly property color batteryWarning: root.color.red
        readonly property color backlight: root.color.yellow
        readonly property color menuLogo: root.color.green
        readonly property color menuBackground: root.color.mantle
        readonly property color menuActiveBackground: root.color.green
        readonly property color highlightText: root.color.mantle   // survol en contrastes inversés (bouton Arch, mises à jour)
    }

    // Glyphes (INVENTORY.md § 1, planche docs/reference/glyphs.png), avec leur police
    readonly property QtObject icon: QtObject {
        // font.icons (Symbols Nerd Font Mono)
        readonly property list<string> workspaces: ["\ue79a", "\ue78c", "\uf32e", "\u{f043e}", "\uf1ff", "\uf1bc", "\uf043", "\uf0e0", "\uf1b6"]  // par numéro, 1 à 9
        readonly property list<string> volume: ["\uf026", "\uf027", "\uf028"]  // 0–33, 34–66, 67–100 %
        readonly property string muted: "\uf466"
        readonly property string microphone: "\uf130"        // OSD (nouveau, 2026-10-16) : nf-fa-microphone
        readonly property string microphoneMuted: "\uf131"   // nf-fa-microphone_slash
        readonly property string power: "\uf011"
        readonly property string search: "\uf002"
        readonly property list<string> backlight: ["\ue38d", "\ue3d3", "\ue3d1", "\ue3cf", "\ue3ce", "\ue3cd", "\ue3ca", "\ue3c8", "\ue39b"]
        // batterie : codes v2 de la config Waybar (U+F578…U+F583) transposés en Nerd Fonts v3 (+0xEFA89), même dessin
        readonly property list<string> battery: ["\u{f0083}", "\u{f007a}", "\u{f007b}", "\u{f007c}", "\u{f007d}", "\u{f007e}", "\u{f007e}", "\u{f007f}", "\u{f0080}", "\u{f0081}", "\u{f0082}", "\u{f0079}"]
        readonly property string batteryCharging: "\u{f0084}"
        readonly property string previous: "\uf053"   // calendrier épinglé : mois précédent
        readonly property string next: "\uf054"       // mois suivant ; panneau de réglages : liste repliée
        // Panneau de réglages façon GNOME (nouveau, 2026-10-16)
        readonly property string settings: "\uf013"            // nf-fa-gear : bouton de la barre (remplace power)
        readonly property string expanded: "\uf078"            // nf-fa-chevron_down : liste dépliée
        readonly property string screenshot: "\u{f0100}"       // nf-md-camera
        readonly property string powerSaver: "\u{f032a}"       // nf-md-leaf
        readonly property string balanced: "\u{f05d1}"         // nf-md-scale_balance
        readonly property string performance: "\u{f04c5}"     // nf-md-speedometer
        readonly property string doNotDisturb: "\u{f009b}"     // nf-md-bell_off
        readonly property string keepAwake: "\u{f0176}"        // nf-md-coffee
        readonly property string nightLight: "\u{f0594}"       // nf-md-weather_night
        readonly property string hdr: "\u{f0d7d}"              // nf-md-hdr
        readonly property string vrr: "\u{f1104}"              // nf-md-monitor_shimmer
        readonly property string airplane: "\u{f001d}"         // nf-md-airplane

        // font.inlineIcons (Hack Nerd Font)
        readonly property string updates: "\u{f01a7}"
        readonly property string gpu: "\u{f0379}"
        readonly property string cpu: "\uec19"
        readonly property string memory: "\u{f035b}"
        readonly property string clock: "\ue385"
        readonly property string download: "\u{f1625}"
        readonly property string upload: "\u{f1628}"
        readonly property string launcherPrompt: "\uf444"   // prompt du lanceur (`display-drun`), Inter → Hack Nerd Font par repli

        // font.awesome / awesomeBrands / awesome4
        readonly property string calendar: "\uf274"   // font.awesome
        readonly property string spotify: "\uf1bc"    // font.awesomeBrands
        // Icône par lecteur (`player-icons` de Waybar), avec la police où Pango la trouvait (pango-view, 2026-10-16) ;
        // clé : nom MPRIS du lecteur (sans instance), `default` sinon.
        readonly property var players: ({
            default: { font: root.font.awesome4, glyph: "\uf04b" },
            spotify: { font: root.font.awesomeBrands, glyph: spotify },
            discord: { font: root.font.inlineIcons, glyph: "\uf1ff" },
            firefox: { font: root.font.awesomeBrands, glyph: "\uf269" },
            chromium: { font: root.font.awesomeBrands, glyph: "\uf268" },
            io: { font: root.font.awesome4, glyph: "\uf03d" }
        })
        readonly property string paused: "\uf04c"     // font.awesome4
        // Carte média du centre de notifications (nouveau, 2026-10-16), font.icons
        readonly property string mediaPrevious: "\uf048"
        readonly property string mediaPlay: "\uf04b"
        readonly property string mediaPause: "\uf04c"
        readonly property string mediaNext: "\uf051"

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

    // § 3 — Panneau de réglages façon GNOME (style des panneaux)
    readonly property QtObject quickSettings: QtObject {
        readonly property int imageSize: root.bar.trayIconSize        // icônes SVG du power menu : 32 px (48 dans Rofi)
        readonly property int glyphSize: root.panel.iconSize          // glyphes des boutons et des bascules : 24 px
        readonly property int buttonPadding: root.panel.buttonPaddingV
        readonly property int columns: 2                              // bascules en 2 colonnes, comme GNOME
        readonly property color checked: root.panel.accent            // bascule activée : fond `green`…
        readonly property color checkedText: root.module.highlightText   // …texte `mantle` (contraste inversé, comme le lanceur)
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
        readonly property color progressFill: root.color.blue   // non fixé dans dunstrc (défauts Dunst hors palette) : `blue`, ton choix du 2026-10-16
    }

    // § 4 — OSD (nouveau composant, 2026-10-16 ; cadre des panneaux) — position et durée proposées, à valider
    readonly property QtObject osd: QtObject {
        readonly property int marginBottom: root.bar.exclusiveZone             // au bas de l'écran, même écart que la zone de la barre en haut
        readonly property int levelWidth: root.notification.progressMaxWidth   // comme la barre de progression des notifications
        readonly property int duration: 1500                                   // ms, comme l'OSD de GNOME (osdWindow.js)
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
        readonly property int itemSpacing: 2      // icône → texte, et entre bouton loupe, prompt et champ : espacement par défaut des boîtes Rofi
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

    // Polices embarquées (assets/fonts, ARCHITECTURE § 8.2) chargées depuis le dépôt : prioritaires sur une copie système
    // du même nom, qui peut différer (ex. `fa-brands-400.woff2` du paquet woff2-font-awesome).
    readonly property list<FontLoader> embeddedFonts: [
        FontLoader { source: Quickshell.shellPath("assets/fonts/SymbolsNerdFontMono-Regular.ttf") },
        FontLoader { source: Quickshell.shellPath("assets/fonts/HackNerdFont-Regular.ttf") },
        FontLoader { source: Quickshell.shellPath("assets/fonts/FontAwesome7Free-Regular-400.otf") },
        FontLoader { source: Quickshell.shellPath("assets/fonts/FontAwesome7Brands-Regular-400.otf") },
        FontLoader { source: Quickshell.shellPath("assets/fonts/FontAwesome4-Regular.ttf") }
    ]

    // Glyphe d'un niveau (0–100 %) dans une liste de paliers, comme `getIcon` de Waybar : palier = floor(p / floor(100 / n)).
    function level(icons: var, percent: int): string {
        return icons[Math.min(Math.floor(percent / Math.floor(100 / icons.length)), icons.length - 1)];
    }

    // § 9 — Thèmes système
    readonly property string iconTheme: "Papirus-Dark"   // imposé par `//@ pragma IconTheme` dans shell.qml

}
