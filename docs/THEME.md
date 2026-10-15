# Charte graphique

Extraite le 2026-10-15 de la config en place. `config/Theme.qml` en est la traduction fidèle et rien d'autre.
Unités : **px logiques** (Wayland). Sur les écrans en scale 1.5, multiplier par 1.5 pour les pixels physiques.
`1rem` = **20 px** : police GTK par défaut `Inter Light 12` (16 px) × `text-scaling-factor` **1.25** (gsettings) ; Waybar ne fixe pas de taille racine.
Vérifié sur capture : arrondi des pilules = 20 px. Les tailles de police écrites en `px` (26 px, 34 px…) ne sont **pas** agrandies (chiffres de l'horloge ≈ 19 px de haut = Inter 26 px).
Quickshell (Qt) ne lit pas ce facteur : `Theme.qml` porte directement les valeurs en px ci-dessous.

## 1. Palette

Source unique de fait : **Catppuccin Mocha**, recopiée à l'identique dans
`~/.config/waybar/mocha.css`, `~/.config/nwg-panel/mocha.css`, `~/.config/hypr/lua/palette.lua`, `~/.config/hypr/mocha.conf`.
Aucun outil de génération (pywal, wallust, matugen…) n'est utilisé : la palette est statique.
Décision : `Theme.qml` porte la palette en dur (voir `ARCHITECTURE.md`).

| Nom | Valeur | Utilisation actuelle |
|---|---|---|
| `base` | `#1e1e2e` | fond notifications Dunst (`#1E1E2E`), fond nwg-menu (listes), swaylock |
| `mantle` | `#181825` | fond de tous les modules Waybar, bouton menu, fond nwg-menu, logo Arch « inversé » |
| `crust` | `#11111b` | rail (trough) du curseur de volume |
| `text` | `#cdd6f4` | texte par défaut Waybar, icône volume, remplissage du curseur de volume, texte Dunst (`#CDD6F4`) |
| `subtext0` | `#a6adc8` | — |
| `subtext1` | `#bac2de` | — |
| `surface0` | `#313244` | — |
| `surface1` | `#45475a` | espace de travail vide (Waybar), bordure fenêtre inactive (Sway) |
| `surface2` | `#585b70` | bouton (knob) du curseur de volume |
| `overlay0` | `#6c7086` | **bordure de tous les modules** Waybar, bordure Rofi (`BDR`), bordure fenêtre active (Sway), nwg-menu |
| `overlay1` | `#7f849c` | bordure fenêtre active (Hyprland), survol barre de défilement nwg-menu |
| `overlay2` | `#9399b2` | cadre des notifications Dunst (`#9399b2`), soulignement recherche nwg-menu |
| `blue` | `#89b4fa` | 3e espace de travail de chaque barre |
| `lavender` | `#b4befe` | — |
| `sapphire` | `#74c7ec` | 2e espace de travail, `custom/updates` |
| `sky` | `#89dceb` | `custom/nvidia`, `network` |
| `teal` | `#94e2d5` | 1er espace de travail, `cpu` |
| `green` | `#a6e3a1` | `memory`, cava, logo Arch, bouton menu actif/survolé, sélection Rofi (`BGA`), survol nwg-menu, bordure urgente (Sway) |
| `yellow` | `#f9e2af` | `clock` |
| `peach` | `#fab387` | cadre des notifications critiques (`#FAB387`) |
| `maroon` | `#eba0ac` | — |
| `red` | `#f38ba8` | `custom/powermenu` |
| `mauve` | `#cba6f7` | — |
| `pink` | `#f5c2e7` | couleur de sélection `slurp` (captures) |
| `flamingo` | `#f2cdcd` | — |
| `rosewater` | `#f5e0dc` | — |

Couleurs hors Mocha encore utilisées par Rofi (`~/.config/rofi/config/colors.rasi`, anciennes valeurs Catppuccin v0.1) :

| Nom Rofi | Valeur | Utilisation |
|---|---|---|
| `BG` | `#1E1D2F` | fond du lanceur et du power menu |
| `FG` | `#D9E0EE` | texte du lanceur et du power menu |
| `SEL` | `#1E1E2E` | texte de l'élément sélectionné, fond du bouton loupe, fond des éléments du power menu |
| `IMG` | `#FAE3B0` | couleur du prompt (le petit `●` jaune avant « Search… ») |
| `UGT` | `#F28FAD` | éléments urgents (inutilisé en pratique) |
| `BGA` | `#a6e3a1` | = `green` |
| `BDR` | `#6c7086` | = `overlay0` |

Autres couleurs littérales :

| Valeur | Utilisation |
|---|---|
| `rgba(255,255,255,0.1)` | fond de l'élément sélectionné du power menu, survol des boutons nwg-menu |
| `transparent` | fond de la barre Waybar (seules les pilules sont opaques) |
| `#ffffff20` | fond de `slurp` (région) |
| `rgba(1a1a1aee)` | ombre des fenêtres Hyprland |

## 2. Polices

| Rôle | Police | Taille | Paquet |
|---|---|---|---|
| Défaut Waybar (icônes, espaces, volume) | `Symbols Nerd Font Mono` | selon module | `ttf-nerd-fonts-symbols-mono` |
| Texte des modules Waybar (updates, nvidia, cpu, memory, clock, mpris, network) | `Inter` (Regular) | 26 px | `inter-font` |
| cava | `Inter` demandé, mais les caractères `▁…█` viennent de **`DejaVu Sans`** (repli) | 20 px | `ttf-dejavu` |
| Glyphes d'espaces de travail | `Symbols Nerd Font Mono` | 34 px | |
| Icône volume (`pulseaudio`) | `Symbols Nerd Font Mono` | 26 px | |
| Bouton power (`custom/powermenu`) | `Symbols Nerd Font Mono` | 28 px | |
| Notifications Dunst | `Monospace` → résolu en **Noto Sans Mono** | 16 (pt Pango) ; titre en gras | `noto-fonts` |
| Lanceur Rofi | `Inter Regular` | 20 | |
| Bouton loupe du lanceur | `Symbols Nerd Font Mono` | 20 | |
| Libellés du power menu | `Symbols Nerd Font Mono bold` (le texte latin retombe sur la police de repli → aspect monospace gras) | 12 | |
| nwg-menu | `Symbols Nerd Font Mono` (texte en repli monospace) | 20 px ; recherche 24 px | |
| GTK (applications, tooltips Waybar) | `Inter Light` | 12 pt | |

Les tooltips de Waybar suivent le thème GTK (`catppuccin-mocha-green-standard+default`) et la police GTK.

### Police de chaque glyphe

Vérifié caractère par caractère avec `fc-list ":charset=<code>"` : **toutes** les icônes de la barre, du power menu et du lanceur
(planche `docs/reference/glyphs.png`) sont dans `Symbols Nerd Font Mono` (`/usr/share/fonts/TTF/SymbolsNerdFontMono-Regular.ttf`,
paquet `ttf-nerd-fonts-symbols-mono`, licence MIT). Aucune ne dépend d'un repli.

Exceptions :
- barres cava `U+2581…U+2588` → `DejaVu Sans` (`ttf-dejavu`) ;
- icônes batterie `U+F578…U+F583` (module inutilisé) → absentes de Nerd Fonts v3, à remplacer.

Règle pour `Theme.qml` : chaque texte nomme sa police explicitement (icônes → `Symbols Nerd Font Mono`, texte → `Inter`,
barres cava → `DejaVu Sans`, notifications → `Noto Sans Mono`). Qt et GTK ne choisissent pas forcément la même police de repli :
on ne s'appuie sur aucun repli implicite.

## 3. Barre (Waybar)

### Géométrie (mesurée sur captures, DP-2 scale 1)

| Élément | Valeur |
|---|---|
| Fond de la barre | transparent |
| Zone exclusive | 65 px (= 10 marge haute + 55 pilule) |
| Pilule (groupe de modules) | hauteur **55 px** bordure comprise, bordure 1 px `overlay0`, fond `mantle`, rayon `1rem` = **20 px** (mesuré) |
| Marge haute des pilules | 10 px |
| Marge entre pilules | 10 px |
| Marge gauche / droite de la barre | 10 px |
| Padding interne des modules | `0.5rem` = 10 px (haut/bas et gauche/droite) |
| Espaces de travail | glyphes 34 px, padding horizontal `0.4rem` = 8 px |
| Bouton menu Arch | min 40x40, padding horizontal 10 px, image SVG 38 px centrée |
| Tray | icônes 32 px, espacement 5 px, padding horizontal `0.3rem` = 6 px |
| Network | padding horizontal 10 px, largeur min 80 px |
| Volume (icône) | largeur min 35 px |
| Curseur de volume | largeur min 50 px, padding horizontal `1rem` = 20 px ; rail : hauteur 15, largeur min 50, rayon 15, `crust` ; remplissage : rayon 15, `text` ; bouton : 20x20, `surface2` (CSS `opacity: 0` mais **visible** sur capture) |
| cava | padding gauche 10 px, padding haut 12 px |

### Groupes de pilules (une seule bordure arrondie autour du groupe)

| Barre | Groupe | Modules |
|---|---|---|
| DP-2 | menu | `custom/menu` seul |
| toutes | espaces | `workspaces` seul |
| DP-2 | média | `mpris` + `cava` + `pulseaudio` + `slider` (quand mpris est masqué, la pilule commence à `pulseaudio`) |
| DP-1, DP-3 | audio | `pulseaudio` + `slider` |
| DP-2 | updates | `custom/updates` seul (masqué si 0) |
| DP-2, DP-1 | système | `custom/nvidia` + `cpu` + `memory` |
| toutes | horloge | `clock` seul |
| DP-3 | réseau | `network` seul |
| DP-2 | tray | `tray` + `custom/powermenu` |

### Couleurs des modules

| Module | Couleur du texte |
|---|---|
| espaces : 1re / 2e / 3e position | `teal` / `sapphire` / `blue` |
| espace vide | `surface1` |
| espace focalisé | sa couleur + halo `text-shadow 0 0 6px currentColor` |
| espace survolé | fond `alpha(couleur, 0.1)`, rayon 20 px |
| `custom/updates` | `sapphire` |
| `custom/nvidia` | `sky` |
| `cpu` | `teal` |
| `memory` | `green` |
| `clock` | `yellow` |
| `network` | `sky` |
| `pulseaudio` | `text` |
| `mpris` | `text` (défaut) |
| `cava` | `green` |
| `custom/powermenu` | `red` |
| `battery` (laptop) | `green` ; `warning` hors charge : `red` |
| `backlight` (laptop) | `yellow` |
| bouton Arch | logo `green` sur `mantle` ; actif/survol : logo `mantle` sur fond `green` |

Transitions : aucune (`transition: none` sur le bouton menu et les espaces vides).

## 4. Notifications (Dunst)

| Élément | Valeur |
|---|---|
| Position | coin bas-droit, décalage 4 px / 4 px, écran principal |
| Largeur | 600 px ; hauteur max 600 px |
| Espacement entre notifications | 20 px |
| Fond / texte | `#1E1E2E` (`base`) / `#CDD6F4` (`text`) pour toutes les urgences |
| Cadre | 1 px `#9399b2` (`overlay2`) ; critique : `#FAB387` (`peach`) |
| Rayon | 15 px |
| Padding | vertical 16 px, horizontal 8 px ; icône → texte : 32 px |
| Icône | à gauche, 100x100 px, thème `Papirus-Dark` |
| Texte | `<b>titre</b>` puis corps, aligné à gauche, centré verticalement, police Noto Sans Mono 16 |
| Barre de progression | hauteur 20, cadre 4, largeur 150–300 |
| Opacité | 100 % |

## 5. Lanceur (Rofi)

| Élément | Valeur |
|---|---|
| Fenêtre | 500 x 1000 px, centrée dans la zone utile de l'écran focalisé (mesuré sur DP-2 : x 1470, y 252), fond `#1E1D2F`, bordure 1 px `overlay0`, rayon 20 px |
| Boîte principale | padding 15 px, espacement 15 px |
| Barre de saisie | bouton loupe (`U+F002`) + prompt + champ |
| Bouton loupe | rond (rayon 100 %), fond `#1E1E2E`, padding 8/12 px, police Symbols Nerd Font Mono 20 |
| Prompt | texte `#FAE3B0`, padding 8 px |
| Champ | placeholder « Search... » couleur `#D9E0EE`, soulignement 2 px `overlay0`, rayon 10 px, padding 8 px |
| Liste | 1 colonne, espacement 4 px, pas de cycle |
| Élément | padding 6 px, rayon 4 px, icône 24 px, texte marge 2 px |
| Élément sélectionné | fond `green` (`#a6e3a1`), texte `#1E1E2E`, rayon 10 px |
| Police | Inter Regular 20 |

## 6. Power menu (Rofi)

| Élément | Valeur |
|---|---|
| Fenêtre | 126 x 352 px, ancrée en haut à droite de l'écran focalisé, décalage -5 px / +5 px (sous la barre), fond `#1E1D2F`, bordure 1 px `#6c7086`, rayon 20 px |
| Boîte | padding 15 px |
| Liste | 4 éléments verticaux, espacement 0 |
| Élément | orientation verticale (icône au-dessus du texte), padding 7.5 px, rayon 7.5 px, fond `#1E1E2E` |
| Élément sélectionné (survol) | fond `rgba(255,255,255,0.1)` |
| Icône | SVG 48 px : `lock.svg`, `logout.svg`, `restart.svg`, `shutdown.svg` (dégradés Catppuccin, dans `~/.config/sway/assets/`) |
| Texte | « Lock », « Logout », « Reboot », « Shutdown », `#D9E0EE`, gras 12 |

## 7. Menu d'applications (nwg-menu, bouton Arch)

Fond `mantle`, bordure 1 px `overlay0`, rayon 20 px ; listes internes fond `base`, bordure `overlay0`, rayon 20 px ;
éléments : padding 5, marge 2, rayon 20, texte `text` ; survol/sélection : fond `green`, texte `mantle` ;
recherche : soulignement 1 px `overlay2`, rayon 10 px, 24 px ; barre de défilement 25 px, curseur `overlay0` (survol `overlay1`) ;
boutons lock/logout/reboot/power : survol `rgba(255,255,255,0.1)` + bordure `overlay0`. Icônes : catégories 48 px, éléments 24 px.

## 8. Fenêtres (compositeur, pour mémoire)

| | Sway | Hyprland |
|---|---|---|
| Bordure | 1 px | 1 px |
| Active | `#6c7086` (overlay0) | `overlay1` |
| Inactive | `#45475a` (surface1) | `surface1` |
| Urgente | `#a6e3a1` (green) | — |
| Gaps | inner 10, outer 0 | in 5, out 10 |
| Arrondi | — | 17 |
| Ombre / flou | — | ombre 4 px `rgba(1a1a1aee)` ; flou 3 px, 1 passe |
| Animations | — | courbes `easeOutQuint`, `almostLinear`, etc. (`lua/looknfeel.lua`) |

## 9. Thèmes système

| Élément | Valeur | Paquet |
|---|---|---|
| Thème GTK | `catppuccin-mocha-green-standard+default`, préférence sombre | `catppuccin-gtk-theme-mocha` (AUR) |
| Icônes | **`Papirus-Dark`** (GTK et Dunst) ; Qt (`qt6ct`) : `breeze`, style `kvantum` | `papirus-icon-theme` |
| Curseur | `catppuccin-mocha-green-cursors`, taille 48 | `catppuccin-cursors-mocha` (AUR) |
| Écran de verrouillage | `swaylock -C ~/.config/sway/swaylock.conf` (couleurs Mocha, police Symbols Nerd Font Mono 32) | `swaylock` |

Quickshell (Qt) ne lit pas le thème d'icônes GTK : le thème `Papirus-Dark` devra être imposé explicitement (voir `ARCHITECTURE.md`).

## 10. Animations

Aucune animation côté barre, notifications ou menus (Waybar `transition: none`, Dunst sans animation, Rofi sans animation).
Les animations Hyprland concernent les fenêtres et les *layers* (fondu à l'ouverture/fermeture des surfaces layer-shell, donc aussi la future barre) : elles restent gérées par Hyprland.

## 11. Écran de verrouillage (swaylock)

Source : `~/.config/sway/swaylock.conf` (pas de capture : verrouiller la session pendant l'audit n'était pas souhaitable).

| Élément | Valeur |
|---|---|
| Fond | `#1e1e2e` (`base`), opaque |
| Anneau | rayon 100, épaisseur 20 ; repos `#b4befe` (`lavender`), effacement `#f5e0dc` (`rosewater`), verr. maj `#fab387` (`peach`), vérification `#89b4fa` (`blue`), erreur `#eba0ac` (`maroon`) |
| Segment de frappe | `#a6e3a1` (`green`) ; retour arrière `#f5e0dc` (`rosewater`) |
| Intérieur, lignes, séparateur | transparents |
| Texte | `#cdd6f4` (`text`) ; mêmes variantes de couleur que l'anneau selon l'état |
| Horloge | affichée : `%H:%M:%S` puis `%A, %d %B %Y` |
| Police | `Symbols Nerd Font Mono` 32 (le texte retombe sur une police de repli) |
| Divers | indicateur toujours visible, nombre d'échecs affiché, disposition clavier masquée |

## 12. Images et icônes (hors glyphes de police)

Recensement de toutes les références à des fichiers image dans les configs actives (Sway, Hyprland, Waybar, Rofi, Dunst, scripts).

### Fichiers à embarquer dans le dépôt (`assets/`)

| Fichier actuel | Taille | Usage | Remarque |
|---|---|---|---|
| `~/.config/sway/assets/arch_linux_icon_green.svg` | 2 Ko | bouton Arch, état normal (logo vert) | SVG simple, sans filtre ni dégradé |
| `~/.config/sway/assets/arch_linux_icon_mantle.svg` | 2 Ko | bouton Arch, survol / menu ouvert (logo `mantle` sur fond vert) | idem |
| `~/.config/sway/assets/lock.svg` | 4,5 Ko | power menu : Lock | dégradés + **un filtre `feGaussianBlur`** |
| `~/.config/sway/assets/logout.svg` | 5 Ko | power menu : Logout | dégradés |
| `~/.config/sway/assets/restart.svg` | 20 Ko | power menu : Reboot | dégradés + **un filtre `feGaussianBlur`** |
| `~/.config/sway/assets/shutdown.svg` | 12 Ko | power menu : Shutdown | dégradés + **un filtre `feGaussianBlur`** |

Aucun de ces SVG ne référence de fichier externe. Les 4 icônes du power menu existent à l'identique dans `~/.config/hypr/assets/`.
Point à vérifier au moment de leur intégration (phase 8) : rendu du flou par Qt SVG (`qt6-svg`) comparé au rendu Rofi (librsvg), sur la capture de référence.

Non repris : `~/.config/hypr/assets/layout/layout-{max,columns}.svg` (module mort `custom/maximized`), variantes `*_blur.svg`,
`arch_linux_icon_{blue_pink,yellow,132588}.svg`, icônes de `bar_icons/` (non référencées).

### Icônes venant d'un thème (pas de fichier à embarquer)

| Usage | Thème | Paquet |
|---|---|---|
| Icônes d'applications : lanceur, futur menu d'applications, notifications, tray | `Papirus-Dark` (+ repli `hicolor`) | `papirus-icon-theme` ; `hicolor-icon-theme` (installé avec `quickshell`) |
| Icônes propres aux applications installées (jeux Steam, web apps…) | `~/.local/share/icons/hicolor` | fournies par les applications elles-mêmes |
| Curseur | `catppuccin-mocha-green-cursors`, taille 48 | `catppuccin-cursors-mocha` (AUR) |

### Règle pour les nouveaux composants

Les composants sans équivalent actuel (réseau, Bluetooth, disques, verrouillage, polkit, capture, sélecteur de fond, calendrier, menu d'applications)
utiliseront des glyphes de `Symbols Nerd Font Mono` ou des icônes `Papirus-Dark`. Chaque icône ajoutée est inscrite ici et, si c'est un fichier,
versionnée dans `assets/` dans le même commit.
