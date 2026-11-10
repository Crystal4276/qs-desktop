# Charte graphique

**`config/Theme.qml` porte toutes les valeurs** (couleurs, polices, tailles, marges, arrondis, délais, glyphes) et c'est le seul
endroit où elles existent. Ce document en donne les règles et les usages ; les numéros de section correspondent aux commentaires
`// § N` de `Theme.qml`. Origine de chaque valeur (Waybar, Dunst, Rofi, nwg-menu, mesures sur captures) : `docs/archive/THEME.md`.

Règles :
- aucune couleur, police, taille, marge, arrondi ou icône inventé : partir d'une valeur existante de `Theme.qml` ; si rien ne
  convient, **demander** ;
- un nouveau composant reprend le style des panneaux (§ 3) et ses valeurs viennent de groupes existants (barre, panneaux, lanceur) ;
- unités : **px logiques** (×1,5 en pixels physiques sur les écrans en scale 1.5). `1rem` de l'ancienne CSS Waybar = 20 px
  (Inter Light 12 × `text-scaling-factor` 1,25) ; Quickshell ne lit pas ce facteur, `Theme.qml` porte les px directement.

## 1. Palette

**Catppuccin Mocha**, statique (aucun générateur : pas de pywal, wallust, matugen), réunie dans `Theme.color` ; les autres groupes
n'y font que référence, avec une opacité au besoin.

| Nom | Usage principal |
|---|---|
| `mantle` | fond des pilules de la barre, des panneaux, du menu ; logo Arch « inversé » |
| `base` | fond des notifications, des listes du menu |
| `crust` | rail des curseurs |
| `text` | texte par défaut, icône du volume, remplissage des curseurs, engrenage |
| `subtext0` | texte secondaire (jours de la semaine…) |
| `surface1` | espace de travail vide ; bordure de fenêtre inactive |
| `surface2` | bouton des curseurs, jours hors du mois |
| `overlay0` | **bordure de toutes les pilules et de tous les panneaux** ; bordure de fenêtre active (Sway) |
| `overlay1` | bordure de fenêtre active (Hyprland) |
| `overlay2` | cadre des notifications |
| `teal` / `sapphire` / `blue` | 1er / 2e / 3e espace de travail de chaque barre ; `teal` : CPU ; `sapphire` : mises à jour |
| `sky` | GPU, réseau |
| `green` | mémoire, logo Arch, bouton actif ou survolé, sélection, aujourd'hui (calendrier), fond actuel (sélecteur), bordure urgente (Sway) |
| `yellow` | horloge, titres des cartes |
| `peach` | cadre des notifications critiques |
| `red` | erreurs |
| `pink` | cadre de sélection de l'outil de capture (couleur de l'ancien `slurp`) |
| `lavender`, `maroon`, `mauve`, `flamingo`, `rosewater`, `subtext1`, `surface0` | disponibles, peu ou pas utilisés |

Hors Mocha : `rofiBg` / `rofiFg` / `rofiSel` / `rofiImg` (lanceur, anciennes valeurs Catppuccin de Rofi), `gtkText` (texte des
menus du tray, thème GTK), `papirusText` / `papirusWarning` (glyphe Wi-Fi), `slurpVeil` (voile de la capture). Fond de la barre :
transparent, seules les pilules sont opaques.

## 2. Polices

| Rôle | Police | Source |
|---|---|---|
| Texte (barre, panneaux, notifications, lanceur, menu) | `Inter` | paquet `inter-font` |
| Icônes seules (espaces, volume, engrenage, rétroéclairage, boutons) | `Symbols Nerd Font Mono` | `assets/fonts/` |
| Icônes collées à du texte Inter (horloge, CPU, mémoire, GPU, mises à jour, réseau) | `Hack Nerd Font` | `assets/fonts/` |
| Calendrier `U+F274` | `Font Awesome 7 Free` (Regular 400) | `assets/fonts/` |
| Spotify `U+F1BC` | `Font Awesome 7 Brands` | `assets/fonts/` |
| Pause `U+F04C` (module média) | `FontAwesome` (4.7) | `assets/fonts/` |
| Monospace (repli, terminaux) | `Noto Sans Mono` | `noto-fonts` |
| Repli CJK / emojis | `noto-fonts-cjk`, `noto-fonts-emoji` | paquets |

Pourquoi ces polices d'icônes exactes : ce sont celles que Waybar utilisait réellement par repli fontconfig (Inter n'a pas les
icônes). Symbols Nerd Font Mono dessine les icônes de Hack ~25 % plus grandes, et l'avance plus étroite de Hack (15,65 px à 26 px)
fixe la position du texte qui suit. Icônes batterie : codes Material Design v2 transposés dans la plage v3 de Nerd Fonts.

Règles pour Qt :
- chaque texte nomme sa police **et** sa taille (`Theme.font.*`), aucun repli implicite (qt6ct impose sinon sa police : `ARCHITECTURE.md` § 8.1) ;
- une icône collée à du texte est mise en page **dans la même ligne de texte** (texte riche, une police par segment) : un `Text` séparé
  compterait le débordement du glyphe dans sa largeur ;
- une espace située entre deux icônes est dessinée dans la police de la première icône (comme Pango) ; suivie de texte, en Inter ;
- rendu FreeType (`//@ pragma NativeTextRendering`) ;
- les polices de `assets/fonts/` sont chargées depuis le dépôt (`FontLoader` dans `Theme.qml`) : une copie système du même nom peut
  différer.

## 3. Barre et panneaux

**Barre** (`Theme.bar`) : zone exclusive 65 px (10 de marge haute + pilule de 55 bordure comprise) ; pilules fond `mantle`, bordure
1 px `overlay0`, rayon 20 ; 10 px entre pilules et sur les côtés ; padding des modules 10 ; une seule bordure arrondie autour de chaque
groupe de modules (pilule de la config machine). Espaces de travail : glyphes 34 px, couleur par position dans le bloc (`teal`,
`sapphire`, `blue`), espace affiché avec un halo (ombre floue d'un `Canvas`), vide en `surface1` ; un glyphe par numéro selon le
profil de la machine (`Theme.icon.workspaces.jeux` : 7 goutte de Deluge, 9 Steam ; `.travail` : 7 `nf-md-circle_double`, 9
`nf-md-microscope` pour DigitalMicrograph). Couleurs des modules : `Theme.module` ; luminosité `peach`, batterie `teal` (rouge à 30 % ou moins hors charge).

La musique se dimensionne sur la place restante par écran, texte « artiste - titre » plafonné à 600 px
(`mediaTextMaxWidth`, ~ l'ancienne limite Waybar de 40 caractères) : artiste et titre abrégés séparément seulement s'ils ne
tiennent pas (un artiste réduit à « … » est retiré au profit du titre), puis retirés si nécessaire : il ne reste alors que
l'icône du lecteur (pas d'icône de pause), le haut-parleur et le curseur. Si la pilule laisserait moins de 50 px (`mediaSnapGap`) avant sa voisine, elle se cale sur l'écart normal de 10 px. Si les modules fixes manquent encore de place, la date disparaît (heure conservée),
puis les statistiques GPU / CPU / mémoire ; restauration automatique quand la largeur revient. Le volume et son curseur restent
affichés. Luminosité et batterie partagent la dernière pilule avec le tray et les réglages dans la configuration par défaut.

**Panneaux** (`Theme.panel`, cartes du tray, calendrier, réglages, audio, polkit) : style commun — fond `mantle`, bordure 1 px
`overlay0`, rayon 20, largeur 500 (celle du lanceur), 10 px sous la pilule ; titre jaune ; sections, lignes, boutons, interrupteurs
et onglets par les composants partagés de `modules/bar/` (`Panel*`, `CardHeader`, `QuickToggle`…). Délais : aperçu 150 ms, passage
icône ↔ carte 300 ms, fermeture automatique 2 s.

Composants propres : calendrier (`Theme.calendar`), Wi-Fi (`Theme.wifi`, glyphe dessiné sur la géométrie Papirus), Bluetooth
(`Theme.bluetooth`), panneau réseau (`Theme.network`, graphe du trafic), curseurs (`Theme.slider`), niveau des entrées audio
(`Theme.levelMeter`), panneau de réglages (`Theme.quickSettings`), croix d'effacement des champs de recherche.

## 4. Notifications

`Theme.notification` : reprend la config Dunst (fond `base`, cadre `overlay2`, critique `peach`, police Inter 16 pt, titre en gras),
carte média et lignes du centre de notifications (`Theme.mediaCard`, `Theme.notificationCentre`), OSD (`Theme.osd`, cadre des panneaux).

## 5. Lanceur

`Theme.launcher` : couleurs Rofi (`rofiBg`, `rofiFg`, `rofiSel`, prompt `rofiImg`), Inter 20 pt, sélection `green`, cadre arrondi
vers le haut et la gauche.

## 6. Panneau de réglages

Remplace le power menu Rofi ; style des panneaux (§ 3), icônes de session de `assets/` (§ 12), engrenage `U+F013` en `text`.

## 7. Menu d'applications et autres composants

- Menu d'applications (`Theme.appMenu`) : style de nwg-menu (fond `mantle` / `base`, Symbols Nerd Font Mono 20, recherche 24, survol
  translucide), disposition du menu Cinnamon.
- Sélecteur de fond (`Theme.wallpaperPicker`), outil de capture (`Theme.screenshot` : voile `slurpVeil`, cadre `pink` 4 px),
  statistiques (`Theme.monitor`), agent polkit (`Theme.polkit`) : style des panneaux.

## 8. Fenêtres (configs compositeur, `dotfiles/`)

| | Sway | Hyprland |
|---|---|---|
| Bordure | 1 px | 1 px |
| Active / inactive | `overlay0` / `surface1` | `overlay1` / `surface1` |
| Urgente | `green` | — |
| Gaps | inner 10, outer 0 | in 5, out 10 |
| Arrondi | — | 17 |
| Ombre, flou | — | ombre 4 px `rgba(1a1a1aee)` ; flou 3 px, 1 passe |

Palette côté Hyprland : `dotfiles/hypr/lua/palette.lua`.

## 9. Thèmes système

| Élément | Valeur | Paquet |
|---|---|---|
| GTK | `catppuccin-mocha-green-standard+default`, préférence sombre | `catppuccin-gtk-theme-mocha` (AUR) |
| Icônes | `Papirus-Dark` (+ repli `hicolor`) ; imposé à Quickshell par `//@ pragma IconTheme` | `papirus-icon-theme` |
| Curseur | `catppuccin-mocha-green-cursors`, taille 48 | `catppuccin-cursors-mocha` (AUR) |
| Qt (`qt6ct`) | `breeze`, style `kvantum` — sans effet sur le bureau (`ARCHITECTURE.md` § 8.1) | — |

## 10. Animations

Aucune animation propre à la barre, aux notifications ou aux menus. Le champ password du greeter et du verrouillage pulse
au survol (bordure normale ↔ verte, cycle `Theme.lock.fieldPulseDuration`, repris du Wi-Fi : 1,2 s), puis reste vert après clic
ou saisie ; clic ailleurs ou nouvel affichage : retour au repos. Les erreurs restent rouges. Sous Hyprland, les couches héritent des animations `layers*`
de la config (fondu des panneaux gardé) ; changement d'espace sans fondu ; `fadeDpms` coupé. Idées : `BACKLOG.md`.

## 11. Écran de verrouillage

Design propre (pas celui de swaylock) : `Theme.lock` — fond de l'écran flouté et assombri, horloge et date, initiale, nom et champ
sur l'écran principal, palette et polices de la charte. Sous le champ, boutons ronds éteindre / redémarrer / veille (style du champ,
bordure `green` au survol ; validés le 2026-11-04). Le même design sert d'écran de connexion (§ 9 d'`ARCHITECTURE.md`).

## 12. Images et icônes

- Fichiers (`assets/`, `Theme.image`) : logo Arch vert et `mantle` (bouton du menu), 5 icônes de session (verrouiller, se
  déconnecter, redémarrer, éteindre ; SVG avec dégradés et flou ; veille : croissant au trait `teal` → `sapphire`, dessiné le
  2026-11-04 à la suite des quatre), `tailscale.svg` (BSD-3).
- Glyphes : `Theme.icon` (code et police de chaque glyphe ; planche : `docs/reference/glyphs.png`).
- Icônes de thème : noms **Papirus-Dark** (ceux de nm-applet, blueman, udiskie pour les modules qui les remplacent ; variante
  `16x16@2x/panel` pour le tray, choisie comme GTK : `services/Icons.qml`), icônes `hicolor` des applications (NordVPN, Steam, web apps).
- **Nouveau composant** : glyphe de `Symbols Nerd Font Mono` (ajouté à `Theme.icon`) ou icône `Papirus-Dark` ; un fichier va dans
  `assets/`, dans le même commit, avec sa licence si elle n'est pas celle du dépôt.
