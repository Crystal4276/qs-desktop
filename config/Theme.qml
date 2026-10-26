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
        // halo de l'espace affiché, `text-shadow 0 0 6px currentColor` : ombre floue d'un Canvas (Workspaces.qml), shadowBlur mesuré
        // contre la référence (écart moyen 1,3/255) ; marge du Canvas autour du glyphe, assez large pour toute l'ombre
        readonly property real workspaceGlowBlur: 10
        readonly property int workspaceGlowMargin: 17
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
        readonly property int autoCloseDelay: 2000       // ms : épinglé, pointeur hors du calendrier et de l'horloge → fermeture (ton choix du 2026-10-21, 5 s avant)
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
        readonly property int previewDelay: 150             // ms : arrêt sur une icône du tray avant l'aperçu de sa carte (pas en passant ; ton choix du 2026-10-21)
        readonly property int autoCloseDelay: root.calendar.autoCloseDelay   // épinglé, pointeur hors de la carte et de l'icône → fermeture (ta demande du 2026-10-21)
        readonly property int previewGrace: 300             // ms : aperçu au survol (tray), pointeur hors de l'icône et de la carte → fermeture (passage de l'une à l'autre)
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
        readonly property color fieldError: root.color.red   // mot de passe refusé, comme l'écran de verrouillage
        // Élément choisi au clavier (Tab, flèches) : liseré de la largeur de la bordure des panneaux, en `text` pour rester
        // visible sur une bascule activée (fond `green`). Nouveau, à valider.
        readonly property color focusRing: root.color.text
        readonly property real disabledOpacity: 0.5   // bouton indisponible, niveau coupé (THEME.md § 3 et § 4)
        readonly property int maxListHeight: 400            // au-delà, la liste défile
        // Cartes (Wi-Fi, filaire, Tailscale, ZeroTier ; PanelCard.qml) : fond comme le champ de saisie, icône 48 px.
        readonly property color card: root.color.base
        readonly property int cardIconSize: 48              // nouveau, à valider
    }

    // § 3 — Module Wi-Fi (nouveau composant, ta demande du 2026-10-19 ; THEME.md § 3 « Module Wi-Fi »)
    readonly property QtObject wifi: QtObject {
        // Glyphe du tray : couleurs des icônes Papirus voisines (classes ColorScheme-Text / NeutralText, opacité du fond).
        readonly property color glyph: "#dfdfdf"
        readonly property real glyphDim: 0.35
        readonly property color glyphWarning: "#ff9800"   // accès limité, comme `network-wireless-*-limited`
        readonly property int connectingDuration: 1200    // balayage du glyphe pendant la connexion (nouveau, à valider)
        readonly property int levelDuration: 250          // passage d'un niveau de signal à l'autre (nouveau, à valider)
        // Qualité du signal, de « aucun » à « excellent » (seuils de GNOME, Network.qml).
        readonly property list<color> quality: [root.color.red, root.color.peach, root.color.yellow, root.color.green, root.color.green]
    }

    // § 3 — Panneau réseau (refonte du 2026-10-19 ; THEME.md § 3 « Panneau réseau »)
    readonly property QtObject network: QtObject {
        readonly property int graphHeight: 64                 // nouveau, à valider
        readonly property int graphLine: 2                    // nouveau, à valider
        readonly property real graphFill: 0.25                // aire sous la courbe descendante (nouveau, à valider)
        readonly property color down: root.color.sky          // couleur du module réseau de la barre
        readonly property color up: root.color.peach          // nouveau, à valider
        readonly property color online: root.color.green      // appareil en ligne (point), comme l'état connecté
        readonly property color offline: root.color.surface2  // comme les jours hors du mois du calendrier
        readonly property int dotSize: 10                     // nouveau, à valider
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

    // § 3 — Niveau capté par une entrée audio (panneau audio ; ta demande du 2026-10-26) : trait de la position de la carte
    // média, creux du curseur, remplissage `green` ; échelle et lissage nouveaux, à valider.
    readonly property QtObject levelMeter: QtObject {
        readonly property int height: root.mediaCard.progressHeight     // 4 px
        readonly property int gap: root.panel.buttonPaddingV            // 6 px sous le rail ou le nom
        readonly property color trough: root.slider.trough
        // Dégradé du vide au plein (ta demande du 2026-10-26) : bleu, vert, jaune, pêche, rouge.
        readonly property list<color> gradient: [root.color.blue, root.color.green, root.color.yellow, root.color.peach, root.color.red]
        readonly property real range: 40                                // dB : -40 dBFS → vide (bruit de la pièce relevé : -37 à -40), 0 dBFS → plein
        readonly property int smoothing: 100                            // ms
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
        readonly property color highlightText: root.color.mantle   // survol en contrastes inversés (bouton Arch, mises à jour, horloge)
        readonly property color statsHighlight: root.module.memory // survol de la pilule GPU / CPU / mémoire, en bloc (ta demande du 2026-10-21)
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
        readonly property string wallpaper: "\u{f0e09}"        // nf-md-wallpaper : utilitaire de changement de fond (2026-10-17)
        // Outil de capture (nouveau, 2026-10-17) : modes zone / écran / fenêtre, fermer
        readonly property string captureArea: "\u{f0a6d}"      // nf-md-selection_drag
        readonly property string captureScreen: "\u{f0379}"    // nf-md-monitor
        readonly property string captureWindow: "\u{f0614}"    // nf-md-application_outline
        readonly property string close: "\u{f0156}"            // nf-md-close
        readonly property string sortDown: "\u{f035d}"         // nf-md-menu_down (tri décroissant, panneau de statistiques)
        readonly property string sortUp: "\u{f0360}"           // nf-md-menu_up
        readonly property string powerSaver: "\u{f032a}"       // nf-md-leaf
        readonly property string balanced: "\u{f05d1}"         // nf-md-scale_balance
        readonly property string performance: "\u{f04c5}"     // nf-md-speedometer
        readonly property string doNotDisturb: "\u{f009b}"     // nf-md-bell_off
        readonly property string keepAwake: "\u{f0176}"        // nf-md-coffee
        readonly property string nightLight: "\u{f0594}"       // nf-md-weather_night
        readonly property string hdr: "\u{f0d7d}"              // nf-md-hdr
        readonly property string vrr: "\u{f1104}"              // nf-md-monitor_shimmer
        readonly property string airplane: "\u{f001d}"         // nf-md-airplane
        readonly property string history: "\u{f02da}"          // nf-md-history : menu, aucun fichier récent (2026-10-21)

        // font.inlineIcons (Hack Nerd Font)
        readonly property string updates: "\u{f01a7}"
        readonly property string gpu: "\u{f0379}"
        readonly property string cpu: "\uec19"
        readonly property string memory: "\uefc5"        // nf-fa-memory
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
        // Logo officiel (dépôt tailscale/tailscale, client/systray/tailscale.svg) : carte de l'onglet Tailscale.
        readonly property url tailscale: Quickshell.shellPath("assets/tailscale.svg")
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

    // § 4 — Carte média du centre de notifications (refaite le 2026-10-20, ta demande : compacte, une bande de trois lignes) :
    // tailles et couleurs de la charte, combinaison nouvelle, à valider.
    readonly property QtObject mediaCard: QtObject {
        readonly property int padding: root.panel.spacing                // 10 px
        readonly property int artSize: 76                                // ta demande : 3 lignes de texte (61 px) + 25 %
        readonly property int artRadius: root.panel.rowRadius / 2        // 5 px : dans une carte à coins 10 px, padding 10 px
        readonly property int buttonSize: root.bar.trayIconSize          // boutons ronds 32 px (taille du tray)
        readonly property int glyphSize: root.panel.smallFontSize        // 16 px
        // Lecture : fond `text` (remplissage des curseurs), glyphe `mantle` ; `green` jugé trop fort (ta remarque du 2026-10-20).
        readonly property color play: root.slider.fill
        readonly property color playGlyph: root.color.mantle
        readonly property color buttonHover: root.panel.rowHover         // précédent / suivant : sans fond, `surface0` au survol
        // Position : trait fin (épaisseur du cadre de la barre de progression des notifications), bouton au survol seulement.
        readonly property int progressHeight: root.notification.progressFrame   // 4 px
        readonly property int knobSize: 3 * progressHeight                       // 12 px
        readonly property color trough: root.slider.trough
        readonly property color fill: root.slider.fill
    }

    // § 4 — Centre de notifications : lignes de l'historique (refaites le 2026-10-20, ta demande ; disposition de KDE / GNOME)
    readonly property QtObject notificationCentre: QtObject {
        readonly property int iconSize: root.bar.trayIconSize   // icône ou image : 32 px (taille du tray)
        readonly property string genericIcon: "preferences-desktop-notification"   // sans icône, ou icône illisible
        readonly property int bodyLines: 2                      // corps replié ; déplié : 6 lignes (DEFAULT_EXPAND_LINES de GNOME)
        readonly property int expandedLines: 6
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
        // Sélection : survol des cartes des panneaux (`surface0`), texte inchangé (ton choix du 2026-10-21 ; Rofi : fond `green`, texte `SEL`).
        readonly property color selected: root.panel.rowHover
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
        // Survol / sélection : survol des cartes des panneaux (`surface0`), texte inchangé (ton choix du 2026-10-21 ; nwg-menu : `green`).
        readonly property color selected: root.panel.rowHover
        readonly property int searchUnderline: 1
        readonly property color searchUnderlineColor: root.color.overlay2
        readonly property color searchNoResults: root.color.red   // recherche sans résultat (ton choix du 2026-10-21)
        readonly property int searchRadius: 10
        readonly property int scrollbarWidth: 25
        readonly property color scrollbar: root.color.overlay0
        readonly property color scrollbarHover: root.color.overlay1
        // Tailles d'icônes de nwg-menu (-isl 48, -iss 24), réparties sur la disposition de Cinnamon (ton choix du 2026-10-17) :
        // 48 px pour les applications (nom + description sur deux lignes), 24 px pour les catégories, dossiers et favoris.
        readonly property int largeIconSize: 48
        readonly property int smallIconSize: 24
        readonly property int descriptionFontSize: root.panel.smallFontSize
        readonly property color description: root.panel.secondaryText
        readonly property int padding: root.panel.padding
        readonly property int spacing: root.panel.spacing
        readonly property int appsWidth: root.launcher.width                  // colonne des applications : largeur du lanceur
        // Colonne de gauche au plus : 180 px de Cinnamon pour un texte de 10 pt (13,3 px), ramenés au texte de 20 px (ton choix
        // du 2026-10-17) ; au-delà, les noms de favoris sont abrégés.
        readonly property int sidebarMaxWidth: 270
        // Pointeur hors du menu → fermeture (ta demande du 2026-10-21 : 2 s), comme le calendrier épinglé.
        readonly property int autoCloseDelay: root.calendar.autoCloseDelay
        // Curseur de défilement du thème GTK (catppuccin) : bordure transparente de 4 px, au moins 24 px de haut, arrondi complet.
        readonly property int scrollbarInset: 4
        readonly property int scrollbarMinLength: 24
        // Icônes du thème (Papirus-Dark) : catégories (clés de Apps.categoryList), dossiers (clés de Places.folders), fichiers.
        readonly property string allIcon: "applications-all"
        readonly property string recentIcon: "document-open-recent"
        readonly property var categoryIcons: ({
            System: "applications-system",
            Settings: "preferences-desktop",
            Development: "applications-development",
            Game: "applications-games",
            Graphics: "applications-graphics",
            AudioVideo: "applications-multimedia",
            Network: "applications-internet",
            Office: "applications-office",
            Education: "applications-education",
            Science: "applications-science",
            Utility: "applications-accessories",
            Other: "applications-other"
        })
        readonly property var placeIcons: ({
            HOME: "user-home",
            DOCUMENTS: "folder-documents",
            DOWNLOAD: "folder-download",
            MUSIC: "folder-music",
            PICTURES: "folder-pictures",
            VIDEOS: "folder-videos"
        })
        readonly property string fileIcon: "text-x-generic"
    }

    // Utilitaire de changement de fond (nouveau composant) : style des panneaux ; fond actuel entouré de `green` (comme une bascule
    // activée). Taille des vignettes : ton choix du 2026-10-17.
    readonly property QtObject wallpaperPicker: QtObject {
        readonly property int thumbWidth: 240
        readonly property int thumbHeight: 135      // 16:9
        readonly property int columns: 4
        readonly property int rows: 3               // visibles ; au-delà, la grille défile
        readonly property int selectionPadding: root.appMenu.itemPadding
        readonly property color selection: root.color.green      // fond actuel : un état, comme une bascule activée
        readonly property color hover: root.panel.rowHover
        readonly property int radius: root.panel.rowRadius
    }

    // Outil de capture (nouveau, phase 8b) : voile et cadre de ta sélection actuelle (slurp), barre d'outils au style des panneaux.
    readonly property QtObject screenshot: QtObject {
        readonly property color veil: root.slurpBackground          // hors de la sélection
        readonly property color selection: root.slurpSelection
        readonly property int border: root.slurpBorder
        readonly property color hover: Qt.alpha(root.slurpSelection, 0.25)   // écran ou fenêtre sous le pointeur
        readonly property int gap: root.panel.gap                   // barre d'outils : distance au bas de l'écran
    }

    // Panneau de statistiques système (nouveau, phase 8b ; remplace btop et nvtop) : style des panneaux ; jauges aux couleurs des modules
    // de la barre (processeur `teal`, mémoire `green`, GPU `sky`), piste `surface0`. Largeur, hauteur des jauges et nombre
    // de lignes de processus : validés pour une première version (2026-10-19).
    readonly property QtObject monitor: QtObject {
        readonly property int width: 1100
        readonly property int barHeight: 8
        readonly property color track: root.panel.button
        readonly property color cpu: root.module.cpu
        readonly property color memory: root.module.memory
        readonly property color gpu: root.module.gpu
        readonly property color disk: root.panel.accent
        readonly property int coreColumns: 4
        readonly property int processRows: 14
        readonly property color selected: root.panel.rowHover
    }

    // Écran de verrouillage (nouveau design, ARCHITECTURE § 10.1 R2) : fond d'écran de chaque écran flouté et assombri, horloge, date ;
    // sur l'écran principal, initiale et nom de l'utilisateur, champ du mot de passe. Maquette validée le 2026-10-17.
    readonly property QtObject lock: QtObject {
        readonly property int blur: 64                            // rayon max du flou (MultiEffect)
        readonly property color dim: Qt.alpha(root.color.crust, 0.45)
        readonly property int clockSize: 120                      // Inter Light
        readonly property color clock: root.color.text
        readonly property int dateSize: 26
        readonly property color date: root.color.subtext1
        readonly property int avatarSize: 72
        readonly property color avatar: root.color.green
        readonly property color avatarText: root.color.mantle
        readonly property int userSize: 20
        readonly property color user: root.color.text
        readonly property int fieldWidth: 360
        readonly property int fieldHeight: 56
        readonly property color field: Qt.alpha(root.color.mantle, 0.85)
        readonly property color fieldBorder: root.color.overlay0
        readonly property color fieldFocus: root.color.green
        readonly property color fieldError: root.color.red
        readonly property int fieldFontSize: 20
        readonly property color dot: root.color.text
        readonly property int dotSize: 10
        readonly property int messageSize: 16
        readonly property color message: root.color.subtext0
        readonly property color error: root.color.red
        readonly property color warning: root.color.yellow   // verrouillage majuscules
        readonly property int spacing: 24
        readonly property int gap: 64                          // entre la date et l'utilisateur
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
