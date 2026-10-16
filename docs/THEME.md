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
| Défaut Waybar (icônes, espaces, volume) | `Symbols Nerd Font Mono` | selon module | fournie par le dépôt (`assets/fonts/`) |
| Icônes des modules texte | Hack Nerd Font, Font Awesome 7 Free / Brands, FontAwesome 4.7 (voir ci-dessous) | 26 px | fournies par le dépôt (`assets/fonts/`) |
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

Les tooltips de Waybar suivent le thème GTK (`catppuccin-mocha-green-standard+default`) et la police GTK. Ils ne sont pas repris (décision du 2026-10-16, `INVENTORY.md` § 1, « Tooltips »).

### Police de chaque glyphe

*Corrigé en phase 2.* L'audit de phase 0 avait vérifié qu'un glyphe **existe** dans Symbols Nerd Font Mono, pas quelle police Waybar
**utilise réellement**. Or dans les modules dont la CSS impose `font-family: Inter` (horloge, CPU, mémoire, GPU, réseau, mises à jour, mpris),
Inter ne contient pas les icônes : Pango les prend dans la première police de repli de fontconfig qui les couvre.
Relevé avec l'ordre de repli de `fc-match -s Inter`, puis confirmé en dessinant chaque candidat à côté des captures de référence :

| Glyphes | Module | Police réellement utilisée | Fichier embarqué |
|---|---|---|---|
| `U+E79A` … `U+F1B6` (espaces), `U+F026–F028`, `U+F466` (volume), `U+F011` (power), `U+E38D…` (rétroéclairage) | modules sans `font-family` → `*` | **Symbols Nerd Font Mono** | `assets/fonts/SymbolsNerdFontMono-Regular.ttf` |
| `U+E385` horloge, `U+EC19` CPU, `U+F035B` mémoire, `U+F0379` GPU, `U+F01A7` mises à jour, `U+F1625` / `U+F1628` réseau | Inter → repli | **Hack Nerd Font** (Regular) | `assets/fonts/HackNerdFont-Regular.ttf` |
| `U+F274` calendrier | Inter → repli | **Font Awesome 7 Free** (Regular 400, contour fin) | `assets/fonts/FontAwesome7Free-Regular-400.otf` |
| `U+F1BC` Spotify | Inter → repli | **Font Awesome 7 Brands** | `assets/fonts/FontAwesome7Brands-Regular-400.otf` |
| `U+F04C` pause | Inter → repli | **FontAwesome** (Font Awesome 4.7) | `assets/fonts/FontAwesome4-Regular.ttf` |
| `U+2581…U+2588` barres cava | Inter → repli | **DejaVu Sans** | paquet `ttf-dejavu` |

Pourquoi ces polices exactes (parité exacte, choisie le 2026-10-15) :
- Symbols Nerd Font Mono dessine les icônes de Hack environ 25 % plus grandes ;
- Symbols Nerd Font (non Mono) a le **même dessin** que Hack Nerd Font, mais une avance plus large (19,5 px contre 15,65 px à 26 px) :
  dans Hack, l'icône déborde sur l'espace qui suit, ce qui fixe la position du texte ;
- le calendrier de Symbols a un bandeau plein (la référence a un contour fin), son Spotify et sa pause sont plus petits.

Icônes batterie `U+F578…U+F583` (module du laptop) : codes Material Design v2 absents de Nerd Fonts v3. *Phase 4* : transposés à l'identique
dans la plage v3 (code v2 − `U+F500` + `U+F0001`, même dessin vérifié par rendu) : `U+F0083` (alerte), `U+F007A`…`U+F0082` (10 à 90 %),
`U+F0079` (pleine), `U+F0084` (en charge). La config Waybar répète `U+F57D` (50 %) deux fois dans ses 12 paliers : repris tel quel.

Règles pour Qt :
- chaque texte nomme sa police explicitement (`Theme.font.*`) ; on ne s'appuie sur aucun repli implicite ;
- une icône collée à du texte est mise en page **dans la même ligne de texte** (texte riche, une police par segment), comme le label Pango :
  un `Text` séparé compterait le débordement du glyphe dans sa largeur (19,6 px au lieu de 15,65 px) et décalerait la suite ;
- rendu du texte par FreeType (`//@ pragma NativeTextRendering`), comme Pango : graisse et crénage plus proches de la référence ;
- *phase 4* — espaces : Pango (relevé avec `pango-view --serialize-to`) dessine une espace **située entre deux icônes** dans la police de la
  première icône (ex. Spotify `U+F1BC` + espace + pause : espace en Font Awesome 7 Brands, 13 px au lieu de 7) ; une espace suivie de texte reste en Inter ;
- *phase 4* — les polices de `assets/fonts/` sont chargées depuis le dépôt (`FontLoader` dans `Theme.qml`) : une copie système du même nom peut différer
  (ici `fa-brands-400.woff2` n'a pas l'espace de 13 px, l'écart faisait 6 px) ;
- modules sans taille dans `style.css` (batterie, rétroéclairage) : taille du texte GTK, 12 pt × 1,25 (`text-scaling-factor`) = **20 px**.

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
| espaces | dégradé linéaire `teal` → `sapphire` → `blue`, selon la **position** dans la barre (1er espace `teal`, dernier `blue`, interpolation RGB entre les deux). Avec 3 espaces par barre, identique à Waybar (couleur par position, `nth-child`). Décision du 2026-10-16 : quand des blocs se regroupent (2 écrans, 1 écran), les couleurs se répartissent en dégradé au lieu de se répéter. Les espaces nommés suivent la même règle |
| espace vide (aucune fenêtre, flottantes comprises), non visible | `surface1` (la règle `.visible:nth-child` l'emporte : un espace vide **visible** garde sa couleur de position) |
| espace focalisé | sa couleur + halo `text-shadow 0 0 6px currentColor`. Traduction Qt : copie du glyphe floutée (MultiEffect, `blurMax` 28) sous le glyphe net, calibrée contre la capture de référence (écart moyen 5/255 sur le bouton ; une ombre MultiEffect seule est deux fois trop faible) |
| espace survolé | fond `alpha(couleur, 0.1)`, rayon 20 px, texte dans sa couleur de position même vide ; bouton = glyphe + 2 × 8 px, hauteur de la pilule moins la bordure |
| `custom/updates` | `sapphire` ; survol (ta demande du 2026-10-16) : contrastes inversés comme le bouton Arch — fond `sapphire` (arrondi intérieur de la pilule), texte `mantle`, sans transition |
| `custom/nvidia` | `sky` |
| `cpu` | `teal` |
| `memory` | `green` |
| `clock` | `yellow` |
| `network` | `sky` |
| `pulseaudio` | `text` |
| `mpris` | `text` (défaut) |
| `cava` | `green` |
| `custom/powermenu` | `red` |
| `battery` (laptop) | `green` ; `warning` hors charge : `red`. Waybar ne passe à `critical` (≤ 15 %) qu'en quittant `warning`, sans style : la batterie redevenait verte sous 15 %. Ici, rouge dès 30 % et en dessous (écart assumé, phase 4) |
| `backlight` (laptop) | `yellow` |
| bouton Arch | logo `green` sur `mantle` ; actif/survol : logo `mantle` sur fond `green` |

Transitions : aucune (`transition: none` sur le bouton menu et les espaces vides).

### Menus du tray (phase 5)

Copie des menus GTK de Waybar (thème `catppuccin-mocha-green-standard+default`, `gtk-3.0/gtk-dark.css`), mesurée sur capture (DP-2, échelle 1) :

| Élément | Valeur |
|---|---|
| Position | au pointeur (coin haut-gauche), basculé à gauche ou en haut s'il déborde de l'écran ; ouvert à l'appui du bouton |
| Cadre | fond `surface0` (`#313244`), coins 12 px, bordure intérieure 1 px `#eff1f5` à 10 %, liseré extérieur 1 px `crust` à 80 % (mesuré), padding 6 px |
| Élément | padding 4 / 8 px, coins 6 px, survol `#eff1f5` à 8 % ; désactivé : opacité 50 % |
| Texte | `#eff1f5` ; **Inter 20 px** (ta demande du 2026-10-16 : police homogène ; Waybar donnait Noto Sans Mono par repli) |
| Marge gauche | 16 px réservés (case, radio ou icône de l'application) + 2 px avant le texte |
| Case / radio | 16 px, rond, fond `#eff1f5` à 12 % ; cochée : fond `green`, marque `crust` à 87 % (tracés `small-checkbox-checked-symbolic.svg` / `small-radio-checked-symbolic.svg` du thème) |
| Sous-menu | flèche 16 px (`pan-end-symbolic`) 8 px après le texte ; ouvert au survol, à droite de l'élément |
| Séparateur | 1 px `#eff1f5` à 12 %, marges 4 px |
| Fermeture | clic sur une autre application (géré par wlroots), clic sur une barre, Échap, choix d'un élément |

### Panneaux des modules natifs (nouveau composant, phase 5)

Réseau, Bluetooth, disques, NordVPN (choix du 2026-10-16 : « panneaux modernes », pensés pour rejoindre plus tard un panneau de réglages
rapides façon GNOME). Style du calendrier ; valeurs reprises de la charte sauf mention.

| Élément | Valeur | Origine |
|---|---|---|
| Position | sous l'icône, 10 px sous la pilule, glissé pour rester dans l'écran ; ouvert au clic (gauche ou droit) | calendrier |
| Cadre | fond `mantle`, bordure 1 px `overlay0`, coins 20 px, padding 15 px, espacement 10 px, largeur 500 px | calendrier ; largeur du lanceur |
| Titre | Inter 20 px gras, `yellow` ; interrupteur à droite (Wi-Fi, Bluetooth) | couleur du titre du calendrier |
| Texte | Inter 20 px `text` ; secondaire et titres de section **Inter 16 px** `subtext0` | 20 : lanceur ; **16 : nouvelle taille** |
| Ligne | padding 8 px, coins 10 px, survol `surface0`, icône 24 px ; état actif (connecté, monté) en `green` | lanceur |
| Bouton | fond `surface0`, survol `surface1`, coins 10 px, padding 6 / 12 px, Inter 16 px | — |
| Interrupteur | 44 × 24 px, rond ; activé : fond `green`, bouton `mantle` ; désactivé : fond `surface1`, bouton `overlay2` | — |
| Champ de saisie | fond `base`, bordure 1 px `overlay0` (`green` quand il a le focus), coins 10 px, Inter 20 px | soulignement du lanceur |
| Liste longue | au-delà de 400 px, elle défile | — |
| Fermeture | clic sur une autre application ou sur une barre, Échap ; un clic à côté n'est pas transmis (popup « grab », nécessaire pour la saisie au clavier) | — |

### Calendrier de l'horloge (nouveau composant, phase 4 — ARCHITECTURE § 8.3)

Remplace le tooltip calendrier. Aucune valeur nouvelle : tout est repris de la barre, du lanceur et de la palette.

| Élément | Valeur | Origine |
|---|---|---|
| Position | centré sous l'horloge, 10 px sous la pilule (à la hauteur du haut des fenêtres) | marge haute de la barre / `gaps inner 10` |
| Cadre | fond `mantle`, bordure 1 px `overlay0`, rayon 20 px, padding 15 px, espacement 10 px | pilules ; padding du lanceur |
| Titre | `2026 October` (format du tooltip Waybar), Inter 26 px, `yellow` | texte de la barre, couleur de l'horloge |
| Jours de la semaine | 2 lettres selon la locale (`Su Mo …`), Inter 20 px, `subtext0` | taille du lanceur |
| Jours | Inter 20 px, `text` ; mois voisins `surface2` ; cases de 40 px | taille min. du bouton Arch |
| Aujourd'hui | fond `green`, texte `mantle` en gras, rayon 10 px | sélection du lanceur et de nwg-menu |
| Flèches (épinglé) | `U+F053` / `U+F054`, Symbols Nerd Font Mono 20 px, `text`, `yellow` au survol | — |
| Fermeture automatique (épinglé) | pointeur hors du calendrier et de l'horloge pendant **5 s** | ta demande du 2026-10-16 (durée choisie par moi, à ajuster) |

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
| Texte | `<b>titre</b>` puis corps, aligné à gauche, centré verticalement, police Noto Sans Mono 16 → **Inter 16 pt** dans Quickshell (police homogène, ta demande) |
| Barre de progression | hauteur 20, cadre 4 (couleur du cadre de la notification), largeur 150–300, centrée ; remplissage non fixé dans dunstrc (défauts Dunst `#1745d1` / `#7f7fff` / `#ff6666`, hors palette) → **`blue`** (ton choix du 2026-10-16) |
| Opacité | 100 % |
| Largeur réelle | 603 px cadre compris (Dunst ajoute 3 × le cadre à `width`, `draw.c`) |
| Boutons d'action (ajout, ton choix du 2026-10-16) | sous le texte, aligné sur lui, un par action nommée (l'action `default` reste au clic milieu) ; style des boutons de panneau (§ 3) |

### OSD (nouveau composant, ton choix du 2026-10-16)

Volume, micro ou luminosité changés au clavier. Cadre des panneaux (§ 3), icône du module de la barre (Symbols Nerd Font Mono 26 px,
`text` ; luminosité `yellow`), niveau dessiné comme le curseur de volume (rail `crust`, partie remplie `text`, bouton `surface2`) sur
300 px (largeur de la barre de progression des notifications), pourcentage en Inter 16 px `subtext0` ; muet : niveau à 50 % d'opacité
(comme un bouton désactivé). **Proposé, à valider** : centré en bas de l'écran focalisé, à 65 px du bord (même écart que la zone de la
barre en haut), affiché 1,5 s (durée de l'OSD de GNOME).

### Panneau audio (nouveau composant, ton choix du 2026-10-16)

Clic droit sur le volume ou le curseur (pavucontrol dans Waybar). Style des panneaux (§ 3) ; interrupteur du titre : son (muet) ;
sections Output / Input / Applications ; périphérique par défaut en `green` ; sous chacun, curseur de volume (style du curseur de la
barre), pourcentage, bouton Mute ; bouton « Advanced… » (pavucontrol).

### Centre de notifications (nouveau composant, ta demande du 2026-10-16)

Cloche dans le tray, après les modules natifs ; panneau au style des panneaux (§ 3). Interrupteur du titre : notifications affichées /
« ne pas déranger ». Lignes : icône de la notification (sinon `preferences-desktop-notification`), titre, puis « heure · application · corps »
en texte secondaire ; non vues (expirées sans toi, ou reçues pendant « ne pas déranger ») en `green` ; bouton « Clear » par ligne, « Clear all ».

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

| Icône | Composant | Police |
|---|---|---|
| `U+F053` / `U+F054` (chevrons) | calendrier épinglé : mois précédent / suivant | Symbols Nerd Font Mono |
| `nm-device-wired`, `nm-signal-{00,25,50,75,100}[-secure]`, `nm-no-connection` | module réseau (tray, lignes) — noms de nm-applet | Papirus-Dark |
| `blueman-tray`, `blueman-tray-active`, `blueman-tray-disabled` | module Bluetooth (tray) — noms de blueman | Papirus-Dark |
| icône fournie par BlueZ (`audio-headset`, `input-gaming`…), sinon `bluetooth` | lignes des appareils Bluetooth | Papirus-Dark |
| `drive-removable-media-usb-panel` | module disques (tray) — icône d'udiskie | Papirus-Dark |
| `drive-removable-media`, `changes-prevent` / `changes-allow` | lignes des volumes (chiffré verrouillé / déverrouillé) | Papirus-Dark |
| `nordvpn-tray-blue` / `nordvpn-tray-gray` | module NordVPN (connecté / non) — icônes du paquet nordvpn | hicolor (`nordvpn-bin`) |
| `notification-inactive` / `notification-active` / `notification-disabled` | cloche du centre de notifications (rien de nouveau / non vues / ne pas déranger) | Papirus-Dark (`16x16@2x/panel`) |
| `preferences-desktop-notification` | ligne du centre pour une notification sans icône | Papirus-Dark |
| `U+F130` / `U+F131` (micro / micro coupé) | OSD du micro | Symbols Nerd Font Mono |
| `network-wired-no-route`, `network-wireless-{0,20,40,60,80,100}-limited` | module réseau : connecté sans accès à Internet | Papirus-Dark (`16x16@2x/panel`) |
| `audio-speakers`, `audio-input-microphone`, icône de l'application (sinon `audio-x-generic`) | lignes du panneau audio | Papirus-Dark |
| `battery-low` / `battery-caution` | notification de batterie faible / critique (laptop) | Papirus-Dark |
| icônes de lecteurs `U+F04B` (défaut), `U+F1FF` Discord, `U+F269` Firefox, `U+F268` Chromium, `U+F03D` io | module média, lecteur choisi à la molette (`player-icons` de Waybar, enfin atteignables) | FontAwesome 4.7 (défaut, io), Hack Nerd Font (Discord), Font Awesome 7 Brands (Firefox, Chromium) — relevé avec Pango |
