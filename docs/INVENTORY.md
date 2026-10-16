# Inventaire de l'existant

Relevé le 2026-10-15 sur la machine `terrier` (Arch, Sway 1.12, Hyprland 0.56.2, Quickshell 0.3.2).
Tout ce qui suit est **observé** dans les fichiers ou en session ; les déductions sont signalées.

Fichiers sources lus :

| Fichier | Rôle | Actif ? |
|---|---|---|
| `~/.config/sway/config` | config Sway | oui |
| `~/.config/sway/config_minimal`, `tatus` (sortie de `git diff` collée) | restes | non |
| `~/.config/hypr/hyprland.lua` + `lua/*.lua` | config Hyprland (parseur Lua) | oui |
| `~/.config/hypr/hyprland.conf`, `hyprland_old_version.conf`, `mocha.conf` | ancienne config hyprlang, gardée en repli | non (repli) |
| `~/.config/hypr/hypridle.conf` | veille DPMS sous Hyprland | oui (Hyprland) |
| `~/.config/hypr/hyprpaper.conf` | fond d'écran hyprpaper | non (swaybg utilisé) |
| `~/.config/waybar/config`, `style.css`, `mocha.css` | Waybar | oui |
| `~/.config/waybar/config_backup`, `style_backup.css`, `frappe/latte/macchiato.css` | restes | non |
| `~/.config/dunst/dunstrc` | Dunst | oui |
| `~/.config/rofi/config.rasi`, `config/*.rasi`, `bin/*` | thèmes et scripts Rofi actifs | oui |
| `~/.config/sway/rofi/bin/launcher` | lanceur (`$menu`) — utilise le thème de `~/.config/rofi/config/` | oui |
| `~/.config/sway/rofi/config/*`, autres `sway/rofi/bin/*` | anciens thèmes/scripts (qtile/X11) | non |
| `~/.config/nwg-panel/menu-start.css`, `mocha.css` | style de `nwg-menu` (bouton Arch) | oui |
| `~/.config/cava/config` | cava (le module Waybar a sa propre config) | non pour Waybar |
| `~/.config/kanshi/config` | un profil `qtile` | **non** : kanshi installé mais pas lancé |

---

## 1. Waybar

Lancé par Sway : `exec_always sleep 1 && waybar`, par Hyprland : `hl.exec_cmd("waybar")`.
Relance manuelle : `$mod+Ctrl+W` → `killall waybar && waybar`.

Trois barres, une par sortie (`"output"` en dur), toutes `position: top`. Pas de `height` : la hauteur
découle du contenu. Zone exclusive mesurée : **65 px logiques** (espace de travail Sway à `y=75`
avec `gaps inner 10`).

### Barre DP-2 (centre, 3440x1440, scale 1)

- Gauche : `custom/menu`, `sway/workspaces`, `hyprland/workspaces`, `mpris`, `cava`, `pulseaudio`, `pulseaudio/slider`
- Droite : `custom/updates`, `custom/nvidia`, `cpu`, `memory`, `clock`, `tray`, `custom/powermenu`

### Barre DP-1 (gauche, 4K, scale 1.5)

- Gauche : `sway/workspaces`, `hyprland/workspaces`, `pulseaudio`, `pulseaudio/slider`
- Droite : `custom/nvidia`, `cpu`, `memory`, `clock`, `custom/logout`, `custom/reboot`, `custom/power`
  - `custom/logout`, `custom/reboot`, `custom/power` **ne sont pas définis** → Waybar ne les affiche pas (vérifié sur capture).

### Barre DP-3 (droite, 4K, scale 1.5)

- Gauche : `sway/workspaces`, `hyprland/workspaces`, `pulseaudio`, `pulseaudio/slider`
- Droite : `custom/updates`, `network`, `clock`
  - `custom/updates` est placé ici mais **pas défini dans le bloc DP-3** (chaque barre Waybar a ses propres définitions) : sans commande, il ne devrait jamais rien afficher. Confirmé par toi : **oubli de config** → le compteur ne sera **pas** affiché sur DP-3.

Les modules `custom/maximized`, `backlight`, `battery` sont définis mais placés dans aucune barre
(`backlight`/`battery` serviront pour le laptop ; `custom/maximized` est mort).

### Détail des modules

Chaque fiche distingue ce qui est **écrit dans ta config** de ce qui vient des **valeurs par défaut de Waybar 0.15**
(relevées dans `man 5 waybar-<module>`), car la parité porte sur les deux.
Toutes les icônes sont visibles sur la planche `docs/reference/glyphs.png` (police Symbols Nerd Font Mono).
Locale : `en_US.UTF-8` (jours en anglais : `Thu`).

#### `custom/menu` — bouton Arch (DP-2)

- **Affichage** : pas de texte (une espace), uniquement une image de fond CSS : logo Arch **vert** (`arch_linux_icon_green.svg`) sur fond `mantle`.
- **États** : survol **ou** menu ouvert → logo couleur `mantle` (`arch_linux_icon_mantle.svg`) sur fond **vert**. L'état « ouvert » est connu par le fichier `/tmp/nwg_menu_state` et un signal (RTMIN+1).
- **Clic gauche** : ouvre **nwg-menu** (cf. § 4). Pas d'autre clic, pas de tooltip.

#### `sway/workspaces` / `hyprland/workspaces` — espaces de travail (toutes)

- **Affichage** : un glyphe par espace, sans numéro. Espaces **persistants** : chaque barre montre toujours ses 3 espaces, même vides ou inexistants (Sway : `persistent-workspaces` de Waybar ; Hyprland : `persistent = true` côté compositeur).
- **Glyphes** : 1 `U+E79A`, 2 `U+E78C`, 3 `U+F32E`, 4 `U+F043E`, 5 `U+F1FF` (Discord), 6 `U+F1BC` (Spotify), 7 `U+F043` (Deluge), 8 `U+F0E0` (Thunderbird), 9 `U+F1B6` (Steam).
- **États** (style) :
  - occupé : couleur de sa **position** dans la barre (1re teal, 2e sapphire, 3e blue) ;
  - vide / inexistant : `surface1` (gris) ;
  - visible sur son écran sans focus : même couleur que occupé, pas de marque supplémentaire ;
  - focalisé : couleur + **halo** (`text-shadow 0 0 6px`) ;
  - urgent : aucun style défini (rien de visible) ;
  - survol : fond de la couleur à 10 % d'opacité, coins arrondis 20 px.
- **Clic gauche** : aller à l'espace (défaut Waybar). Sous Hyprland en config Lua, le clic est inopérant (bug Waybar #5008).
- **Molette** : Sway : espace précédent / suivant (défaut, avec bouclage) ; Hyprland : désactivée (`disable-scroll: true`).
- **Tooltip** : aucun.

#### `mpris` — lecture en cours (DP-2)

- **Joueur suivi** : **Spotify uniquement** (`"player": "spotify"`). Spotify fermé → module **masqué** (et la pilule média commence alors au volume).
- **Format** (identique en lecture, pause, arrêt) : `{player_icon} {status_icon} {dynamic}`.
  - `player_icon` : spotify `U+F1BC` (seul utile, puisque seul Spotify est suivi ; les icônes discord/firefox/chromium/io/défaut sont définies mais inatteignables) ;
  - `status_icon` : en pause `U+F04C` ; en lecture et à l'arrêt : **rien** (aucune icône définie) ;
  - `dynamic` : `Artiste - Titre` (seuls ces deux champs), longueur totale max 40 caractères, titre max 20, troncature par `...` ; le **titre** est tronqué en premier.
  - exemple capturé : `[spotify] [pause] Tricky - Aftermath`.
- **Tooltip** (défaut Waybar) : `{player} ({status}) {dynamic}` sans limite de longueur, ex. `spotify (paused): Tricky - Aftermath` (*relevé en phase 4* : statut en minuscules, deux-points).
- **Clics** (défauts Waybar) : gauche lecture/pause, milieu piste **précédente**, droite piste **suivante**.
- **Molette** : haut `playerctld shift`, bas `playerctld unshift` (change de joueur actif — sans effet visible puisque le module est fixé sur Spotify).

#### `cava` — visualiseur (DP-2)

- **Affichage** : 12 barres en caractères `▁▂▃▄▅▆▇█` (U+2581…U+2588, chacun suivi d'une espace), couleur `green`, 20 px. La CSS demande Inter, mais **Inter ne contient pas ces caractères** : ils sont dessinés par **DejaVu Sans** (repli fontconfig, vérifié avec `fc-match`).
- **Réglages** : 100 images/s, stéréo, sensibilité auto (`autosens 1`, `sensitivity 2`), 50–10 000 Hz, lissage `monstercat` + `waves`, `noise_reduction 0.77`, source PulseAudio automatique.
- **Silence** : module **masqué** (`hide_on_silence`).
- Pas de clic, pas de tooltip.

#### `pulseaudio` — icône de volume (toutes)

- **Affichage** : icône seule, pas de pourcentage. Volume 0–32 % `U+F026`, 33–65 % `U+F027`, 66–100 % `U+F028` (3 paliers, défaut Waybar ; *corrigé en phase 4* d'après `ALabel::getIcon` : indice = volume / (100 / 3 en entier = 33)) ; muet `U+F466` (+ une espace).
- **Clic gauche** : bascule muet (`pamixer --toggle-mute`).
- **Clic milieu** : sortie audio suivante (`audio-toggle.sh` : cycle des sorties, volume remis à 60 %, notification « Audio Switch » + nom).
- **Clic droit** : `pavucontrol`.
- **Molette** : ±5 %, plafonné à 100 % (défaut `max-volume`).
- **Tooltip** (défaut Waybar) : description du périphérique de sortie (ex. `SMSL USB AUDIO Pro`).

#### `pulseaudio/slider` — curseur de volume (toutes)

- **Affichage** : rail horizontal (`crust`), partie remplie couleur `text`, bouton rond gris (`surface2`). Pas de texte.
- **Interaction** : clic / glisser pour régler le volume (0–100), molette ±5 %, clic droit `pavucontrol`.

#### `custom/updates` — mises à jour (DP-2 ; listé sur DP-3 mais non défini, cf. ci-dessus)

- **Affichage** : `U+F01A7` + nombre de paquets à mettre à jour (`checkupdates | wc -l`). Couleur `sapphire`.
- **Aucune mise à jour** : module **masqué** (sortie vide) — c'était le cas lors des captures.
- **Rafraîchissement** : toutes les 8600 s (≈ 2 h 23), et immédiatement après une mise à jour lancée depuis le module.
- **Clic gauche** : terminal `paru -Syu`, attend Entrée, puis recompte.
- **Tooltip** : aucun texte spécifique (sortie d'une seule ligne).

#### `custom/nvidia` — température GPU (DP-2, DP-1)

- **Affichage** : `U+F0379` + température en °C (`nvidia-smi --query-gpu=temperature.gpu`), ex. `39°C`. Couleur `sky`. Toutes les 5 s.
- **Seuil critique** : la config demande `°C!` au-delà de 80 °C, mais ces options n'existent pas pour un module `custom` → **jamais affiché** aujourd'hui.
- **Clic gauche** : `nvtop` dans un terminal. Tooltip : aucun texte spécifique.

#### `cpu` — processeur (DP-2, DP-1)

- **Affichage** : `U+EC19` + utilisation totale en % sur 2 caractères, ex. `10%`. Couleur `teal`. Toutes les 5 s.
- **Clic gauche** : `btop` dans un terminal. **Tooltip désactivé**.

#### `memory` — mémoire (DP-2, DP-1)

- **Affichage** : `U+F035B` + mémoire utilisée en Gio, arrondie sans décimale, ex. `9G`. Couleur `green`. Toutes les 5 s.
- **Tooltip** : deux lignes, une décimale — `Memory: <utilisée>G / <totale>G` puis `Swap: <utilisé>G / <total>G` (machine actuelle : 31 Gio de RAM, 15 Gio de swap).
- **Clic gauche** : `btop` dans un terminal.

#### `clock` — horloge (toutes)

- **Affichage** :
  - DP-2 : format exact `U+E385␣␣%H:%M␣␣U+F274␣%a-%d` → `U+E385  17:46  U+F274 Thu-15` (heure 24 h, jour abrégé selon la locale, jour du mois) ;
  - DP-1, DP-3 : `U+E385␣␣%H:%M` seulement.
  - Tout le texte est en Inter 26 px (espaces compris) ; les deux glyphes viennent de Symbols Nerd Font Mono par repli.
  - Couleur `yellow`. Mise à jour chaque minute. Fuseau `Asia/Riyadh` écrit en dur, identique au fuseau système.
- **Tooltip** : titre `2026 October` en grand, puis le calendrier du mois en police à chasse fixe, petite taille, **aujourd'hui en gras souligné** (défaut Waybar), semaines non numérotées, semaine commençant le dimanche (locale `en_US`).
- Pas de clic ni de molette configurés (le calendrier ne défile pas).

#### `network` — débit réseau (DP-3)

- **Affichage** : `U+F1625` + débit descendant, puis `U+F1628` + débit montant, en octets/s avec unité automatique, ex. `2.5MB/s  833.6kB/s`. Couleur `sky`. Toutes les 5 s.
- **Interface** : `eno2` écrite en dur (aujourd'hui la route par défaut passe par `bridge0`).
- **Tooltip** (défaut Waybar) : reprend le texte du module.
- Pas de clic.

#### `tray` — zone de notification (DP-2)

- **Affichage** : icônes 32 px, espacées de 5 px ; éléments au statut « passif » **masqués** (défaut).
- **Clics** (défauts Waybar) : gauche active l'application, milieu action secondaire, droit menu contextuel. Tooltip : celui fourni par chaque application.
- Éléments observés : nm-applet, udiskie, blueman, WhatsDesk, NordVPN, Steam.

#### `custom/powermenu` — bouton d'extinction (DP-2)

- **Affichage** : `U+F011` en rouge (28 px), collé à droite du tray dans la même pilule.
- **Clic gauche** : power menu Rofi (cf. § 3). Pas de tooltip.

#### Modules définis mais placés dans aucune barre

- `backlight` (`intel_backlight`, 9 icônes `U+E38D`…`U+E39B`, couleur `yellow`) et `battery` (seuils warning 30 % / critical 15 %, en charge et branché `U+F583`, 12 icônes `U+F582`…`U+F578`, vert, rouge en `warning` hors charge) : restes d'un laptop, **à reprendre pour le futur laptop**.
  ⚠ Les icônes batterie `U+F578`…`U+F583` sont d'anciens codes Material Design **retirés de Nerd Fonts v3** : elles n'existent plus dans Symbols Nerd Font Mono (elles ne s'afficheraient aujourd'hui que par repli sur Font Awesome 7). Il faudra choisir leurs équivalents v3 (plage `U+F0079`…) en phase 4.
- `custom/maximized` (état plein écran Hyprland) : mort.
- Les définitions `network` de DP-2 et DP-1 (formats légèrement différents) ne sont utilisées par aucune barre.

### Tooltips (décision du 2026-10-16)

Les tooltips de Waybar **ne sont pas repris** : le calendrier devient une fenêtre au survol (ARCHITECTURE § 8.3) et les autres
n'apportaient que peu d'information. Perdus : swap (mémoire), nom de la sortie audio (volume), titre complet du morceau (mpris) ;
ils pourront revenir dans la fenêtre de statistiques (phase 8b) ou un panneau audio (`BACKLOG.md`).
Relevé fait avant la décision (captures en phase 4, pour mémoire) : fond `rgba(11, 11, 18, 0.9)`, texte `#eff1f5`, rayon 6 px, padding 4 / 8 px,
Noto Sans Mono 20 px (repli de `* { font-family: Symbols Nerd Font Mono }` pour le latin), interligne 28 px ;
centré 20 px à droite du pointeur, 44 px sous lui.

### Particularités de style à reproduire (cf. `THEME.md`)

- Couleur des espaces selon leur **position** dans la barre (1er teal, 2e sapphire, 3e blue), pas selon leur numéro.
- Espace focalisé : `text-shadow: 0 0 6px currentColor` (halo). Espace vide : `surface1`.
- Groupes « pilules » : `nvidia + cpu + memory` forment une seule pilule (bordures gauche/droite seulement aux extrémités) ;
  `mpris + cava + pulseaudio + slider` idem sur DP-2 ; `pulseaudio + slider` sur DP-1/DP-3 ; `tray + powermenu` sur DP-2.

## 2. Dunst

Lancé par **systemd user** (`dunst.service`, activé par D-Bus). Arrêt/relance : `systemctl --user stop|start dunst`.

| Réglage | Valeur |
|---|---|
| Écran | `monitor = 1` (index Wayland ; observé : **DP-2**), `follow` absent → `none` |
| Position | `origin = bottom-right`, `offset = 4x4` |
| Taille | `width = 600`, `height = (0, 600)`, `notification_limit = 0` (illimité) |
| Barre de progression | oui, hauteur 20, cadre 4, largeur 150–300 |
| `indicate_hidden` | yes |
| Transparence | 0 |
| Séparateur | hauteur 2, `separator_color = frame` ; `gap_size = 20` (donc notifications séparées, le séparateur ne s'affiche pas) |
| Padding | `padding 16`, `horizontal_padding 8`, `text_icon_padding 32` |
| Cadre | `frame_width 1`, `frame_color #9399b2` (critique : `#FAB387`) |
| Tri | `sort = yes` (urgence puis date) |
| Police | `Monospace 16` (→ Noto Sans Mono), `line_height 0` |
| Format | `markup = full`, `"<b>%s</b>\n%b"`, aligné à gauche, centré verticalement |
| Âge | `show_age_threshold = 60` |
| Texte long | `ellipsize = middle`, `ignore_newline = no` |
| Doublons | `stack_duplicates = true`, compteur affiché |
| Indicateurs | `show_indicators = yes` (U pour URL, A pour actions) |
| Icônes | thème `Papirus-Dark`, recherche récursive, à gauche, **taille fixe 100 px** (min = max = 100), `icon_path /usr/share/icons` |
| Historique | `sticky_history = yes`, `history_length = 20` |
| `dmenu` / `browser` | `/usr/bin/dmenu -p dunst:` (dmenu absent) / `xdg-open` |
| Arrondi | `corner_radius = 15` |
| Souris | gauche : `close_current` ; milieu : `do_action, close_current` ; droite : `close_all` |
| Urgences | low / normal / critical : fond `#1E1E2E`, texte `#CDD6F4` ; critical : cadre `#FAB387` |
| Timeouts | **non définis** → défauts Dunst : low 10 s, normal 10 s, critical 0 (permanent) ; `ignore_dbusclose = false` |
| Règles par application | **aucune** ; aucun `script` |
| Raccourcis `dunstctl` | **aucun** raccourci ni script n'appelle `dunstctl` (seul `dunstify` dans un vieux script mort) |

Anomalie : une ligne non commentée `systemctl --user restart dunst` traîne au milieu de `[global]` (ligne 81) — ignorée par Dunst.
Observé : l'icône `audio-volume-high` n'a pas été résolue lors du test (pas d'icône affichée), `dialog-warning` oui.

## 3. Rofi

| Usage | Commande | Thème | Mode |
|---|---|---|---|
| Lanceur | `$mod+w` → `~/.config/sway/rofi/bin/launcher` (Hyprland : `SUPER+W`, même script) | `~/.config/rofi/config/launcher.rasi` | `-show drun`, modi `run,drun,ssh`, `-drun-match-fields all`, `-drun-display-format "{name}"`, `-no-drun-show-actions`, terminal `gnome-terminal`, `-kb-cancel Escape`, historique actif, clic hors fenêtre = fermer |
| Power menu | `$mod+Escape` (Sway uniquement) et bouton `custom/powermenu` → `~/.config/rofi/bin/power-menu` | `~/.config/rofi/config/power-menu.rasi` | `-dmenu` avec icônes SVG (`~/.config/sway/assets/{lock,logout,restart,shutdown}.svg`), `-hover-select`, sélection au clic gauche |

Power menu — actions : Lock → `swaylock -C ~/.config/sway/swaylock.conf` ; Logout → `swaymsg exit` ;
Reboot → `systemctl reboot` ; Shutdown → `systemctl poweroff`. **Aucune confirmation.**
Logout utilise `swaymsg exit` même sous Hyprland (bug latent).

Le lanceur affiche 7 lignes (`lines: 7`) mais `dynamic: true` + `height: 1000px` → la liste remplit la fenêtre (17 lignes visibles sur la capture).

Le `config.rasi` global (`show-icons: true`) n'est utilisé que par défaut ; tous les appels passent `-theme`.

## 4. nwg-menu (bouton Arch)

Lancé par `custom/menu` via `nwg-menu-wrapper.sh` :
`nwg-menu -cmd-lock "swaylock -C ~/.config/sway/swaylock.conf" -d -t -fm nemo -isl 48 -iss 24 -va top -ml 10 -mt 10 -o DP-2 -term gnome-terminal`
(catégories XDG, favoris/épinglés, dossiers utilisateur, recherche, boutons lock/logout/reboot/poweroff ; `-d` ferme quand on clique ailleurs, `-t` sous la barre).
Style : `~/.config/nwg-panel/menu-start.css`. Le wrapper pose `/tmp/nwg_menu_state` pour que le bouton reste vert tant que le menu est ouvert.

## 5. Tray (StatusNotifierItem)

Hôte : Waybar (DP-2 uniquement). Éléments observés : nm-applet (`--indicator`), udiskie (`--appindicator`), blueman-applet,
WhatsDesk, NordVPN, Steam. Lancés depuis la config Sway (cf. § 7).

## 6. Raccourcis clavier liés au shell

### Sway

| Raccourci | Action |
|---|---|
| `$mod+w` | lanceur Rofi |
| `$mod+Escape` | power menu Rofi |
| `$mod+Ctrl+W` | `killall waybar && waybar` |
| `$mod+Ctrl+R` | `reload` |
| `$mod+Ctrl+q` | `swaymsg exit` |
| `$mod+s` | `~/.config/sway/scripts/audio-toggle.sh` (sortie audio suivante) |
| `XF86AudioMute` / `LowerVolume` / `RaiseVolume` / `MicMute` (`--locked`) | `pactl` mute / -5 % / +5 % / micro mute |
| `XF86MonBrightnessDown/Up` (`--locked`) | `brightnessctl set 5%-/5%+` (**brightnessctl non installé**) |
| `$mod+Shift+Print` | `screenshot-window.sh` (fenêtre choisie avec slurp → fichier + presse-papiers) |
| `$mod+Print` | `grim -g "$(slurp -or)"` → `~/Pictures/screenshot/<date>.png` + `wl-copy` |
| `Print` | région `slurp -b ffffff20 -c f5c2e7 -w 4` → fichier + `wl-copy` |
| `$mod+d` | bascule HDR de DP-1 et DP-3 |
| `$mod+1…9` | `workspace N` |
| `$mod+Ctrl+1…9` | `move container to workspace N, workspace N` |
| `$mod+Left/Right` | `move container to output left/right, focus output left/right` |

Pas de mode `resize` ni d'autre `mode` défini. Aucune touche `XF86AudioPlay/Next/Prev` sous Sway.

### Hyprland (`lua/binds.lua`)

`SUPER+W` lanceur ; `SUPER+S` audio-toggle ; `SUPER+CTRL+W` relance Waybar ; `SUPER+CTRL+Q` exit ;
`SUPER+CTRL+R` `force_renderer_reload` ; captures via `hyprshot -m window|output|region` ;
touches volume (`wpctl`, ±5 %), luminosité (`brightnessctl` ±10 %), média (`playerctl`) ;
`SUPER+1…9` / `SUPER+CTRL+1…9` ; `SUPER+H` / `SUPER+SHIFT+S` espace spécial `magic` ;
`SUPER+molette` espaces voisins. **Pas de power menu** sous Hyprland.

## 7. Autostart

### Sway (`exec` / `exec_always`)

- `swayidle -w timeout 300 'swaymsg "output * power off"' resume '... power on'`
- `exec_always sleep 1 && waybar`
- `modprobe sidewinder`, `polkit-gnome-authentication-agent-1`, `gsettings … cursor-size 48`, `systemctl --user import-environment …`
- VPN : `nordvpn login --token …` (**jeton en clair dans la config**), `nordvpn c Netherlands`
- Applications : deluge (flatpak), thunderbird, steam, montage `gio mount ssh://…`, Discord web app, whatsdesk, spotify (adblock), `openrgb -p purple.orp`
- Tray : `nm-applet --indicator`, `blueman-applet`, `udiskie --appindicator`
- Focus initial : `workspace 1; workspace 4; workspace 9`, puis `focus output DP-2`
- `include /etc/sway/config.d/*` (import d'environnement systemd/D-Bus)

### Hyprland (`lua/autostart.lua`)

`nordvpn c Netherlands`, `nm-applet`, `waybar`, `swaybg` (3 images), polkit-gnome, blueman-applet, `udiskie --appindicator`,
`openrazer-daemon`, `openrgb`, `hypridle`, curseur, spotify, deluge, steam, thunderbird, discord, whatsdesk ; focus 4 / 1 / 7.

### Hors compositeur

- `~/.config/autostart/` : `bitwarden.desktop`, `mount_vps.desktop`, `nordvpn.desktop` (**jeton en clair**) — non lus par Sway/Hyprland (aucun lanceur XDG autostart configuré) ; hors périmètre du shell.
- `~/.config/systemd/user/ai-session-warmup.{service,timer}` → `~/.local/bin/ai-session-warmup` : sans rapport avec le bureau.
- `~/.local/bin/` : outils CLI (agents IA, pdf…) sans rapport avec le bureau.

## 8. Sorties et espaces de travail

### Écrans (relevé `swaymsg -t get_outputs`)

| Connecteur | Description (make model serial) | Mode | Échelle | Position | Taille logique |
|---|---|---|---|---|---|
| DP-1 | `LG Electronics 27GN950 207NTLEFY824` | 3840x2160 @ 60 Hz, HDR off, 10 bits | 1.5 | 0,0 | 2560x1440 |
| DP-2 | `Dell Inc. Dell AW3418DW #ASPFPBQwWjbd` | 3440x1440 @ 100 Hz | 1 | 2560,0 | 3440x1440 |
| DP-3 | `LG Electronics 27GN950 207NTHMFY841` | 3840x2160 @ 60 Hz, HDR off, 10 bits | 1.5 | 6000,0 | 2560x1440 |

Sources : lignes `output` de la config Sway, `lua/layout.lua` (Hyprland, mêmes valeurs). Fonds : `output … bg` (Sway), `swaybg` (Hyprland).
Kanshi : installé, **non lancé** ; son unique profil (`qtile`, 120 Hz) est obsolète.
Veille : `swayidle` (Sway) / `hypridle` + `hyprctl reload` au réveil (Hyprland).

### Attribution des espaces de travail (identique Sway et Hyprland)

| Écran | Position | Espaces | Focus au démarrage |
|---|---|---|---|
| DP-2 (ultrawide, principal) | centre | **1, 2, 3** | 1 (Sway : focus final) |
| DP-1 | gauche | **4, 5, 6** | 4 |
| DP-3 | droite | **7, 8, 9** | 9 (Sway) / 7 (Hyprland) |

⚠ L'ordre n'est **pas** gauche → droite : le bloc 1-3 est sur l'écran **central**. Les espaces sont persistants (Waybar sous Sway, `persistent = true` sous Hyprland).

Règles liées aux espaces (à garder dans les configs compositeur, phase 10) : `assign` Discord/WhatsDesk → 5, Spotify → 6, Deluge → 7,
Thunderbird → 8, Steam → 9, jeux Steam/gamescope → 3 ; fenêtres ouvertes sur 7 et 8 (sauf Deluge/Thunderbird) renvoyées sur **DP-2** (nom en dur).

## 9. Secrets repérés (à ne jamais versionner)

- Jeton NordVPN en clair : `~/.config/sway/config`, `~/.config/hypr/hyprland.conf`, `~/.config/hypr/hyprland_old_version.conf`, `~/.config/autostart/nordvpn.desktop` (deux jetons différents).
- Adresses de montage SSH (`gio mount ssh://…`) dans la config Sway et `mount_vps.desktop`.

Ces lignes devront être retirées ou externalisées avant tout rapatriement en phase 10.

## 10. Seconde passe (2026-10-15) — toute la couche shell

Méthode : processus réellement lancés dans la session, paquets installés, **tous** les dossiers de `~/.config`, services utilisateur activés,
puis comparaison avec les types QML disponibles dans Quickshell 0.3.2 (`/usr/lib/qt6/qml/Quickshell/**/*.qmltypes`).

### 10.1 Éléments du bureau et cible proposée

« Natif » = remplacé par Quickshell sans programme externe. Les **?** ont été tranchés : voir `ARCHITECTURE.md` § 10.1 (tout passe en natif, y compris disques et Bluetooth ; `grim`/`slurp` au départ pour les captures ; écran de connexion en phase 12).

| Élément | Aujourd'hui | Ce que Quickshell 0.3.2 offre | Cible proposée |
|---|---|---|---|
| Barres | Waybar | `PanelWindow` | natif (phases 1–5) |
| Notifications | Dunst | `NotificationServer` | natif (phase 6) |
| Lanceur | Rofi `drun` | `DesktopEntries` | natif (phase 7) |
| Menu d'applications | nwg-menu | `DesktopEntries` | natif, modèle Cinnamon (phase 8) |
| Power menu | Rofi `-dmenu` | — | natif (phase 8) |
| Tray | Waybar | `SystemTray` | natif (phase 5) |
| **Fond d'écran** | `swaybg` (Sway : `output … bg`, Hyprland : `swaybg` avec **d'autres images**) | `PanelWindow` sur la couche `Background` | natif + utilitaire de changement de fond (voir `WALLPAPERS.md`) |
| **Verrouillage** | `swaylock -C swaylock.conf` (power menu, nwg-menu) | `WlSessionLock` + `PamContext` | **?** natif |
| **Veille écrans** | `swayidle` 300 s → `output * power off` (Sway) ; `hypridle` 300 s → DPMS off, réveil échelonné DP-1/DP-3 puis DP-2 après 3 s (Hyprland) | `IdleMonitor` (`timeout`, `respectInhibitors`) + commande DPMS au compositeur | **?** natif |
| **Agent polkit** (fenêtre de mot de passe administrateur) | `polkit-gnome-authentication-agent-1` | `PolkitAgent` + `AuthFlow` | **?** natif |
| **Réseau** (icône + menu) | `nm-applet --indicator` dans le tray | `Networking` (appareils, Wi-Fi, connexion/déconnexion) | **?** natif ; limites : pas de VPN ni d'édition des connexions (→ `nm-connection-editor` en repli) |
| **Bluetooth** (icône + menu) | `blueman-applet` + `blueman-tray` | `Bluetooth` (adaptateurs, appareils, connecter, appairer, oublier) | **?** natif ; limite : pas d'agent d'appairage (code PIN) visible dans l'API → à tester |
| **Disques amovibles** | `udiskie --appindicator` (montage auto + notifications + menu tray) | aucun équivalent (pas d'accès D-Bus générique en QML) | **?** garder `udiskie` |
| **Captures d'écran** | `grim` + `slurp` (+ `screenshot-window.sh`) sous Sway, `hyprshot` sous Hyprland | `ScreencopyView` (capture) ; sélection et enregistrement à écrire | **?** garder `grim`/`slurp` |
| **Touches volume / média / luminosité** | Sway : `pactl` ; Hyprland : `wpctl`, `playerctl`, `brightnessctl` | `Pipewire`, `Mpris` via `IpcHandler` | natif via `qs ipc` (phase 10) |
| Configuration des écrans | Sway / Hyprland | — | compositeur (§ 3.1 d'ARCHITECTURE) |
| Écran de connexion | SDDM (`catppuccin-sddm-theme-mocha`) | `Greetd` (exigerait greetd + config système) | **?** hors périmètre |
| Thème GTK / curseur / icônes | paquets + `gtk-3.0/settings.ini` | — | paquets (deps) |
| Portails XDG, trousseau | `xdg-desktop-portal-*`, `gnome-keyring` | — | hors périmètre (système) |

### 10.2 Oublis du premier passage

- **Tri du lanceur par fréquence d'utilisation** : Rofi garde un historique (`disable-history: false`) dans `~/.cache/rofi3.druncache`
  (nombre de lancements par application). L'ordre de la capture (`Windows 10`, `Calculator`, `virt-manager`, `deluge`…) vient de là.
  Le lanceur QML doit garder ce tri et peut importer cet historique une fois.
- **Dépendances cachées des raccourcis** : `pactl` (paquet `libpulse`, touches volume Sway), `wpctl` (`wireplumber`), `playerctl` (touches média Hyprland),
  `gsettings` (`glib2`, taille du curseur). Elles disparaissent si les touches passent par `qs ipc`.
- **Autostart XDG inactif** : `~/.config/autostart/{bitwarden,mount_vps,nordvpn}.desktop` ne sont exécutés par personne
  (Bitwarden ne tourne pas). Hors périmètre, mais à savoir.
- **Espace affiché au démarrage** : Sway montre 1 / 4 / **9** (DP-2 / DP-1 / DP-3), Hyprland 1 / 4 / **7**.
- **Fonds d'écran** : Sway utilise `~/Pictures/Wallpaper/3-screens/monitor_{left,center,right}_*.png`, Hyprland `swaybg_spread_*_DP-{1,2,3}.png` : images différentes.
- **`DP-2` écrit en dur ailleurs** (à remplacer par « écran principal » ou par description en phase 10) : renvoi des fenêtres des espaces 7 et 8
  vers DP-2 (Sway et Hyprland), `cursor.default_monitor = "DP-2"` (Hyprland), `monitor = 1` (Dunst), `-o DP-2` (nwg-menu).
- **Dossier `~/.config/menus/`** : `cinnamon-applications.menu` + `applications-merged/` (applis Chrome, Wine) — catégories XDG personnalisées,
  héritées de Cinnamon. À prendre en compte pour les catégories du futur menu d'applications.
- **Restes sans effet** (aucune action) : `fontconfig/` (fichiers vides générés par Font Manager), `waypaper/`, `wpaperd/`, `azote/` (anciens gestionnaires
  de fond d'écran, non lancés), `cinnamon/spices/*` (dossiers vides), `nwg-look` (outil qui écrit `gtk-3.0/settings.ini`), `qtile/`, `openbox/`, `xfce4/`.
- **Applications personnelles** de `~/.local/share/applications` (132 fichiers : jeux Steam, web apps Chrome, Discord web…) : le lanceur et le menu
  les lisent via `DesktopEntries`, rien à faire.

## 11. Troisième passe (2026-10-15) — autour du bureau

Champ élargi : démarrage de session, variables d'environnement, réglages dconf/GTK/Qt, portails, alimentation, trousseau, polices de repli,
et revue de **tous** les paquets installés explicitement (`pacman -Qe`).

### 11.1 Démarrage de session et environnement

- Sway est lancé par **SDDM** (thème `catppuccin-mocha-green` ; SDDM sera remplacé par un greeter Quickshell en phase 12) via une session **créée à la main** :
  `/usr/share/wayland-sessions/sway-vulkan.desktop` → `env WLR_RENDERER=vulkan sway --unsupported-gpu` (aucun paquet ne possède ce fichier).
- `/etc/environment` : `QT_QPA_PLATFORMTHEME=qt6ct`. qt6ct : style `kvantum` (thème Kvantum `KvArcDark`), icônes **`breeze`**.
  **Quickshell est une application Qt : il hérite de ces réglages** (style, police par défaut, thème d'icônes) — voir `ARCHITECTURE.md` § 11.
- Le trousseau `gnome-keyring` est déverrouillé à la connexion par la config PAM de SDDM (`pam_gnome_keyring.so`) → à reproduire avec le futur greeter (phase 12).
- `logind` : réglages par défaut (bouton power = extinction immédiate ; capot = mise en veille sur laptop).

### 11.2 Réglages dconf / GTK (à reproduire sur un nouveau PC)

| Clé `org.gnome.desktop.interface` | Valeur |
|---|---|
| `gtk-theme` | `catppuccin-mocha-green-standard+default` |
| `icon-theme` | `Papirus-Dark` |
| `font-name` / `document-font-name` / `monospace-font-name` | `Inter Light 12` / `Inter Light 13` / `Source Code Pro 12` |
| `text-scaling-factor` | **`1.25`** → agrandit le texte GTK, donc `1rem` = 20 px dans Waybar (`THEME.md` corrigé) |
| `color-scheme` | `prefer-dark` |
| `cursor-theme` / `cursor-size` | `default` / `48` (le thème réel est fixé par Sway/Hyprland : `catppuccin-mocha-green-cursors`) |
| `clock-format` | `24h` |

Incohérence relevée : `gtk-3.0/settings.ini` a `prefer-dark=1`, `gtk-4.0/settings.ini` a `prefer-dark=0`.

### 11.3 Polices de repli (texte non latin, emojis)

| Texte | Police utilisée aujourd'hui | Problème |
|---|---|---|
| Japonais, chinois | MS Gothic | `/usr/share/fonts/MS_Fonts/` : **540 polices Microsoft (363 Mo) copiées depuis Windows en 2022**, aucun paquet → absentes d'un nouveau PC ; tu veux les garder (documents Word) : voir `ARCHITECTURE.md` § 11.3 |
| Coréen | Malgun Gothic | idem |
| Emojis | DejaVu Sans (monochrome), alors que `Noto Color Emoji` est installé | rendu à vérifier dans Quickshell (notifications Discord/WhatsApp, titres Spotify) |

Proposition : `noto-fonts-cjk` et `noto-fonts-emoji` dans `deps/` ; test en phase 4 (titre MPRIS japonais) et en phase 6 (notification avec emojis).

### 11.4 Autres constats

- **Portail de partage d'écran** (Sway) : `xdg-desktop-portal-wlr` choisit l'écran avec `slurp` → `slurp` reste une dépendance même avec un outil de capture natif.
- **`gnome-screenshot`** et GNOME Shell sont installés : référence disponible pour l'outil de capture (phase 8b).
- **Onduleur** : `apcupsd` actif mais `STATUS: COMMLOST`. **Hors périmètre** (tu le règles séparément).
- **Réseaux privés et VPN** : **NordVPN** (VPN, icône dans le tray), **Tailscale** et **ZeroTier** (réseaux privés, utilisés et nécessaires ;
  services `tailscaled` et `zerotier-one` activés). Le montage `gio mount ssh://…@<serveur>` de l'autostart Sway passe vraisemblablement par ZeroTier.
  Restes inutilisés : `networkmanager-openvpn`, `networkmanager-pptp`, `wireguard-tools` (désinstallation à ta main, hors projet).
  Aucun module dans la barre n'est prévu pour eux (parité) ; ce sont des services système, hors du shell.
- **Bluetooth** : `bluez-tools` (`bt-agent`) est installé, mais il n'est pas retenu comme agent : ses modes sans interaction acceptent tout (cf. `ARCHITECTURE.md` § 10.2).
- **Autostart XDG** (`~/.config/autostart`) : rappel, Bitwarden ne démarre pas (rien n'exécute ces fichiers).
- **Hors bureau, sans action** : `lightdm`, `gdm` (installés, inactifs), `picom`, `openbox`, `qtile`, `numlockx` (X11), `hyprpicker`, `autotiling`, `obs-studio`,
  `timeshift`, `gamemode`, `openrgb`, `webapp-manager` (crée les web apps lues par le lanceur).
