# Scripts du bureau

Recensement fait en suivant chaque `exec`, `bindsym … exec`, `hl.exec_cmd`, `hl.bind(… exec_cmd)`, `on-click`/`exec` de module Waybar,
script Rofi, règle Dunst (aucune), profil Kanshi (aucun `exec`), et en parcourant `~/.local/bin`, `~/.config/*/scripts`,
`~/.config/systemd/user`, `~/.config/autostart`. `~/bin` et `~/scripts` n'existent pas.

Décisions possibles : **QML natif** (remplacé par un service/composant Quickshell), **gardé** (rapatrié dans `scripts/`, nettoyé),
**abandonné** (mort ou redondant — **à confirmer par toi** avant suppression de toute référence).

Rien n'est supprimé ni modifié dans `~/.config` : les décisions s'appliquent au nouveau dépôt.

## Scripts actifs

### `~/.config/sway/rofi/bin/launcher`

| Champ | Contenu |
|---|---|
| Appelé par | `$mod+w` (Sway, `$menu`), `SUPER+W` (Hyprland, `programs.lua`) |
| Rôle | `rofi -show drun` avec le thème `~/.config/rofi/config/launcher.rasi` (modi `run,drun,ssh`, recherche sur tous les champs, terminal `gnome-terminal`) |
| Dépendances | `rofi` |
| Décision | **QML natif** — `modules/launcher/` (phase 7), ouvert via `qs ipc call launcher toggle`. Les modes `run` et `ssh` ne sont pas accessibles (aucun `-kb-mode-next` personnalisé, et la touche par défaut `Shift+Left/Right` n'est probablement pas utilisée) → non reproduits sauf avis contraire. |

### `~/.config/rofi/bin/power-menu`

| Champ | Contenu |
|---|---|
| Appelé par | `$mod+Escape` (Sway), `on-click` de `custom/powermenu` (Waybar DP-2) |
| Rôle | `rofi -dmenu` avec 4 entrées à icône SVG : Lock (`swaylock -C ~/.config/sway/swaylock.conf`), Logout (`swaymsg exit`), Reboot (`systemctl reboot`), Shutdown (`systemctl poweroff`). Sans confirmation. |
| Dépendances | `rofi`, `swaylock`, `systemd`, `sway` ; icônes `~/.config/sway/assets/{lock,logout,restart,shutdown}.svg` |
| Décision | **QML natif** — `modules/menus/PowerMenu.qml` (phase 8), IPC `qs ipc call powermenu toggle`. Logout adapté au compositeur (`swaymsg exit` / `hl.dsp.exit()`), ce qui corrige le bug sous Hyprland. Les 4 SVG sont copiés dans le dépôt (`assets/`). |

### `~/.config/sway/scripts/audio-toggle.sh`

| Champ | Contenu |
|---|---|
| Appelé par | `$mod+s` (Sway), `SUPER+S` (Hyprland), clic milieu sur `pulseaudio` (Waybar, chemin `/home/crystal/…` en dur) |
| Rôle | Parse `wpctl status`, passe la sortie par défaut au *sink* suivant (cyclique), règle son volume à **60 %**, notifie « Audio Switch » + nom du périphérique |
| Dépendances | `wireplumber` (`wpctl`), `libnotify` (`notify-send`), `gawk`, `sed`, `grep` |
| Décision | **QML natif** — fonction `Audio.cycleSink()` dans `services/Audio.qml` (`Quickshell.Services.Pipewire` : liste des nœuds *sink*, `Pipewire.preferredDefaultAudioSink`, volume 0.60) + notification ; IPC `qs ipc call audio cycleSink`. |

### `~/.config/sway/scripts/screenshot-window.sh`

| Champ | Contenu |
|---|---|
| Appelé par | `$mod+Shift+Print` (Sway) |
| Rôle | Liste les rectangles des fenêtres (`swaymsg -t get_tree`), sélection avec `slurp -r` (couleurs Catppuccin), capture `grim` → `~/Pictures/screenshot/<date>.png` + presse-papiers |
| Dépendances | `sway`, `jq`, `slurp`, `grim`, `wl-clipboard`, `coreutils` |
| Décision | **gardé** tel quel (fonction du compositeur, pas du shell ; Hyprland utilise `hyprshot`). Rapatrié en phase 10 avec la config Sway dans `scripts/`, chemin `~/Pictures/screenshot` remplacé par `$(xdg-user-dir PICTURES)/screenshot`. |

### `~/.config/waybar/scripts/check-updates.sh`

| Champ | Contenu |
|---|---|
| Appelé par | `exec` de `custom/updates` (toutes les 8600 s, ou signal RTMIN+8) |
| Rôle | `checkupdates \| wc -l` ; sortie vide si 0 |
| Dépendances | `pacman-contrib` (`checkupdates`) |
| Décision | **QML natif** — `services/Updates.qml` lance `checkupdates` via `Process` (seule commande externe, pas de script). Masqué si `checkupdates` est absent (non-Arch). |

### `~/.config/waybar/scripts/update-wrapper.sh`

| Champ | Contenu |
|---|---|
| Appelé par | `on-click` de `custom/updates` |
| Rôle | Ouvre `gnome-terminal --wait` avec `paru -Syu`, attend Entrée, puis signale Waybar pour recompter |
| Dépendances | `gnome-terminal`, `paru` |
| Décision | **QML natif** — `Updates.upgrade()` lance le terminal et rafraîchit à la fin du processus. Terminal et commande de mise à jour lus dans la config machine (repli : `paru` → `yay` → `sudo pacman -Syu`). |

### `~/.config/waybar/scripts/nwg-menu-wrapper.sh` + `menu-state-check.sh`

| Champ | Contenu |
|---|---|
| Appelé par | `on-click` / `exec` de `custom/menu` |
| Rôle | Pose `/tmp/nwg_menu_state`, signale Waybar (bouton vert), lance `nwg-menu` (options : cf. INVENTORY § 4) sur DP-2, puis retire l'état. `menu-state-check.sh` lit ce fichier pour la classe CSS. |
| Dépendances | `nwg-menu`, `procps` (`pkill`) |
| Décision | **QML natif** pour l'état du bouton (le bouton connaît l'état du `Process` qu'il lance : plus de fichier `/tmp` ni de signal). Pour le menu lui-même : **décision à prendre** (cf. ARCHITECTURE § 8, question Q3). |

### `nvidia-smi` (commande inline de `custom/nvidia`)

| Champ | Contenu |
|---|---|
| Appelé par | `exec` de `custom/nvidia` (5 s) ; clic → `gnome-terminal -- sh -c 'nvtop'` |
| Rôle | Température GPU |
| Dépendances | `nvidia-utils` ; `nvtop` |
| Décision | **QML natif** (service `services/Gpu.qml`, `Process` sur `nvidia-smi`), module masqué si `nvidia-smi` est absent. |

### Commandes inline des autres modules

`pamixer --toggle-mute` → **QML natif** (`Pipewire` : `audio.muted`). `pavucontrol` → **gardé** comme commande externe (application).
`playerctld shift/unshift` → **QML natif** (sélection du joueur dans `services/Media.qml` via `Quickshell.Services.Mpris`).
`gnome-terminal -e btop` → commande externe, terminal configurable.

## Scripts morts (référencés nulle part, ou seulement en commentaire)

| Chemin | Rôle | Pourquoi mort | Décision proposée |
|---|---|---|---|
| `~/.config/sway/maintain-workspaces.sh` | recrée les espaces 2 et 3 quand ils se vident | aucun appel | **abandonné** (les espaces persistants sont gérés par la barre et le service Outputs) |
| `~/.config/sway/workspace-placeholder.sh` | garde des terminaux fantômes sur 2 et 3 | aucun appel | **abandonné** |
| `~/.config/sway/scripts/chromium-focus-workspace.sh` | suit Chromium quand un lien s'ouvre | `exec` commenté | **abandonné** |
| `~/.config/sway/scripts/sway_layout_manager.py` | auto-tiling (i3ipc) | `exec_always` commenté | **abandonné** (gestion de fenêtres, hors shell) |
| `~/.config/sway/scripts/sway_three_layout.py` | disposition à 3 fenêtres (i3ipc) | `exec_always` commenté | **abandonné** (idem) |
| `~/.config/sway/scripts/sway_to_scratchpad.py` | « maximiser » en envoyant les autres fenêtres au scratchpad | `bindsym` commenté | **abandonné** (idem) |
| `~/.config/waybar/scripts/window-state.sh` (+ `_backup`) | état plein écran Hyprland pour `custom/maximized` | module défini mais placé dans aucune barre | **abandonné** |
| `~/.config/sway/rofi/bin/powermenu` | ancien power menu qtile/bspwm | non appelé (références `~/.config/qtile`) | **abandonné** |
| `~/.config/sway/rofi/bin/screenshot` | captures X11 (`maim`, `xclip`) | non appelé | **abandonné** |
| `~/.config/sway/rofi/bin/runner`, `launcher_icon` | `rofi -show run` / lanceur à icônes qtile | non appelés | **abandonné** |
| `~/.config/rofi/bin/launcher` | doublon du lanceur (`-kb-cancel Alt-F1`) | non appelé (`$menu` pointe vers `sway/rofi/bin/launcher`) | **abandonné** |

## Hors périmètre (sans lien avec le bureau)

| Chemin | Rôle |
|---|---|
| `~/.local/bin/ai-session-warmup` + `~/.config/systemd/user/ai-session-warmup.{service,timer}` | tâche quotidienne liée aux outils IA |
| `~/.local/bin/{agent,codex,grok,vibe,vibe-acp,cmark,pygmentize,pdf*,pypdfium2,dumppdf.py,vba_extract.py}` | outils CLI |
| `~/.config/autostart/*.desktop` | non exécutés par Sway/Hyprland ; contiennent un jeton NordVPN et une adresse SSH |
| `~/.config/celluloid/scripts`, `~/.config/wireplumber.bak-*/scripts` | configs d'applications |

Commandes d'autostart (nordvpn, steam, openrgb, gio mount…) : elles restent dans les configs compositeur, rapatriées en phase 10
(**sans les jetons**).
