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

Les modules `custom/maximized`, `backlight`, `battery` sont définis mais placés dans aucune barre
(`backlight`/`battery` serviront pour le laptop ; `custom/maximized` est mort).

### Détail des modules

| Module | Barres | Contenu / format | Intervalle | Tooltip | Clic / scroll |
|---|---|---|---|---|---|
| `custom/menu` | DP-2 | bouton image logo Arch (SVG vert ; SVG `mantle` sur fond vert quand survolé ou menu ouvert) | `once`, rafraîchi par signal RTMIN+1 | non | gauche : `nwg-menu-wrapper.sh` (ouvre **nwg-menu**) |
| `sway/workspaces` | toutes | icône par espace (`format: {icon}`), espaces persistants : DP-2 → 1,2,3 ; DP-1 → 4,5,6 ; DP-3 → 7,8,9 | événements | non | clic : aller à l'espace ; scroll : espace suivant/précédent (`disable-scroll: false`) |
| `hyprland/workspaces` | toutes | mêmes icônes, `sort-by-number`, pas de persistants côté Waybar (persistance dans la config Hyprland) | événements | non | clic (inopérant sous parseur Lua, bug Waybar #5008) ; scroll désactivé |
| `mpris` | DP-2 | `{player_icon} {status_icon} {dynamic}` ; joueur **spotify** uniquement ; dynamic = artiste - titre, `dynamic-len 40`, `title-len 20`, ellipse `...` | événements | défaut Waybar | scroll haut/bas : `playerctld shift` / `unshift` |
| `cava` | DP-2 | 12 barres `▁ ▂ ▃ ▄ ▅ ▆ ▇ █` (chaque glyphe suivi d'une espace), 100 fps, stéréo, `monstercat`, `waves`, `noise_reduction 0.77`, 50–10000 Hz, source pulse auto, **masqué en silence** | 100 fps | non | — |
| `pulseaudio` | toutes | icône seule : volume bas/moyen/haut `U+F026 / U+F027 / U+F028`, muet `U+F466` | événements | défaut Waybar | gauche : `pamixer --toggle-mute` ; milieu : `audio-toggle.sh` ; droite : `pavucontrol` ; scroll : ±5 % |
| `pulseaudio/slider` | toutes | curseur horizontal 0–100 | événements | — | droite : `pavucontrol` ; scroll ±5 % ; glisser |
| `custom/updates` | DP-2, DP-3 | `U+F01A7` + nombre de mises à jour (`checkupdates \| wc -l`) ; **masqué quand 0** (sortie vide) | 8600 s, + signal RTMIN+8 | texte brut | gauche : `update-wrapper.sh` (terminal `paru -Syu`, puis rafraîchit) |
| `custom/nvidia` | DP-2, DP-1 | `U+F0379` + `{}°C` (`nvidia-smi --query-gpu=temperature.gpu`) ; `critical-threshold 80` → `U+F0379 {}°C!` (*note : `critical-threshold`/`format-critical` ne sont pas des options de `custom/*` → probablement sans effet*) | 5 s | texte brut | gauche : `gnome-terminal -- sh -c 'nvtop'` |
| `cpu` | DP-2, DP-1 | `U+EC19` + `{usage:2}%` | 5 s | non | gauche : `gnome-terminal -e btop` |
| `memory` | DP-2, DP-1 | `U+F035B` + `{used:2.0f}G` | 5 s | `Memory: {used:0.1f}G / {total:0.1f}G\nSwap: {swapUsed:0.1f}G / {swapTotal:0.1f}G` | gauche : `gnome-terminal -e btop` |
| `clock` | toutes | DP-2 : `U+E385 {:%H:%M}` + 3 espaces + `U+F274 {:%a-%d}` (ex. `17:46 Thu-15`) ; DP-1/DP-3 : `U+E385 {:%H:%M}` ; fuseau `Asia/Riyadh` (= fuseau système) | 60 s (défaut) | calendrier du mois : `<big>{:%Y %B}</big>` + `<tt><small>{calendar}</small></tt>` | — |
| `network` | DP-3 | `U+F1625 {bandwidthDownBytes:>3}  U+F1628 {bandwidthUpBytes:>3}` (interface `eno2` en dur) | 5 s | défaut Waybar | — |
| `tray` | DP-2 | `icon-size 32`, `spacing 5` | — | par élément | comportement par défaut Waybar (gauche : activer, droite : menu) |
| `custom/powermenu` | DP-2 | `U+F011` (rouge) | — | non | gauche : `~/.config/rofi/bin/power-menu` |

Icônes d'espaces (format-icons, Symbols Nerd Font) :

| Espace | Glyphe | Sens |
|---|---|---|
| 1 | `U+E79A` | (non commenté) |
| 2 | `U+E78C` | (non commenté) |
| 3 | `U+F32E` | (non commenté) |
| 4 | `U+F043E` | (non commenté) |
| 5 | `U+F1FF` | Discord |
| 6 | `U+F1BC` | Spotify |
| 7 | `U+F043` | Deluge |
| 8 | `U+F0E0` | Thunderbird |
| 9 | `U+F1B6` | Steam |

Icônes de joueurs MPRIS : défaut `U+F04B`, spotify `U+F1BC`, discord `U+F1FF`, firefox `U+F269`,
chromium `U+F268`, io `U+F03D` ; statut en pause `U+F04C` (aucune icône définie pour « playing »).

Modules définis mais inutilisés (gardés pour le laptop) : `backlight` (`intel_backlight`, 9 icônes
`U+E38D…U+E39B`), `battery` (états warning 30 / critical 15, en charge/branché `U+F583`, 12 icônes `U+F582…U+F578`).

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
