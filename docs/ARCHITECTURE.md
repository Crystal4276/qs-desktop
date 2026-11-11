# Architecture

État actuel du bureau (Quickshell 0.3.2, Sway 1.12, Hyprland 0.57 en config Lua). Le pourquoi détaillé des décisions, avec
leur historique : `docs/archive/ARCHITECTURE.md`. Méthode de travail, bancs et pièges : `docs/DEVELOPMENT.md`.

## 1. Structure

Celle de `CLAUDE.md`, plus :

- `assets/` : images (logo Arch, icônes de session) et polices embarquées (§ 8.3), référencées par chemin relatif au dépôt.
- `dotfiles/sway/`, `dotfiles/hypr/` : configs des compositeurs, liées en `~/.config/sway` et `~/.config/hypr` (retour arrière :
  `docs/ROLLBACK.md`). Partie commune (`config`, `hyprland.lua` + `lua/`) et partie machine (`hosts/<hostname>.conf` inclus par
  `include hosts/$(cat /etc/hostname).conf` ; `hosts/<hostname>.lua` chargé par `lua/host.lua`) : écrans par description, règles
  qui les visent, matériel. Fichier absent : ignoré. Données privées (adresses, identifiants, montages) : jamais dans le dépôt, dans
  `~/.config/qs-desktop.local/` (`sway.conf`, inclus par la config Sway ; absent : ignoré).
- `dotfiles/greetd/` : fichiers système de l'écran de connexion (config greetd, PAM, Sway du greeter), installés par
  `scripts/greeter-setup.sh` (§ 9). Les écrans d'une machine sont à part (`dotfiles/sway/hosts/<hostname>.outputs.conf`), inclus par la
  session et par le greeter.
- `greeter.qml` : point d'entrée de l'écran de connexion (`//@ pragma ShellId greeter`), à côté de `shell.qml` : mêmes `qs.config`,
  `qs.services`, `qs.modules.*` (§ 9).
- Applications de tous les jours, installées par `install.sh` (`README.md`) : `dotfiles/fastfetch`, `starship`, `mpv` et `chromium`
  (partie commune + `hosts/<machine>.conf` pour le décodage vidéo ; extensions `extensions.txt`, réglages de nightTab
  `nighttab.json`, styles de Stylus `stylus.json`), `dconf` (clés GSettings, + `hosts/<machine>.ini`), `mime`
  (applications par défaut), `bash` (bloc ajouté au `~/.bashrc`), `viewnior`, `samba` (fichier système, `scripts/system-setup.sh`).
- `dotfiles/wireplumber/` : règle dont dépend la coupure des sons pendant « ne pas déranger » (§ 4, `doNotDisturb.muteApps`).
- `dotfiles/webapps/` : extension Chromium `open-links/` et son hôte natif `open-link`, lanceurs des web apps (`applications/`),
  manifeste de l'hôte (`qs_desktop.open_link.json`) ; développés par `install.sh` (procédure : `deps/README.md`, « Web apps ») (§ 7.10).
- `scripts/desktop.sh` : lancé par l'autostart des deux compositeurs (§ 8.2) ; `scripts/ipc.sh` : `qs ipc call` des raccourcis vers
  l'instance de la session, désignée par son PID (`docs/DEVELOPMENT.md`).
- Le dépôt est désigné par le lien de la config Quickshell (`~/.config/quickshell/desktop`), jamais par un chemin personnel.
- `shell.qml` : `//@ pragma IconTheme Papirus-Dark` (§ 8.1), `//@ pragma ShellId desktop` (même identifiant pour `qs ipc` et les
  dossiers d'état, que la config soit lancée par `-p` ou par `-c`). Imports `qs.config`, `qs.services`, `qs.modules.*`, sans `qmldir`.

## 2. Compositeur

`services/Compositor.qml` (singleton) choisit son backend au démarrage :

| | Sway | Hyprland |
|---|---|---|
| Détection | `SWAYSOCK` | `HYPRLAND_INSTANCE_SIGNATURE` |
| Module | `Quickshell.I3` (`I3.workspaces`, `I3.monitors`, `I3.dispatch()`, `I3IpcListener`) | `Quickshell.Hyprland` (`Hyprland.workspaces`, `.monitors`, `.dispatch()`, `.usingLua`) |

Interface commune : `workspaces` (num, nom, écran, focalisé, visible, urgent, vide), `outputs` (nom, description, x, y, taille
logique, scale, focalisé), `focusedOutput`, et les actions (`focusWorkspace`, `moveWorkspace`, `createWorkspace`,
`moveWindowToWorkspace`, `setPower`, `showAppWindow`, `focusNextActivation`, `exit`…).

- **Hyprland en config Lua uniquement** : `hyprctl keyword` n'existe plus, `dispatch` attend une expression Lua
  (`hl.dsp.focus({ workspace = 4 })`). Avec une config classique (`Hyprland.usingLua` faux), aucune action n'est envoyée (journal).
- **Sway** : l'état de `Quickshell.I3` se périme (espace affiché par un écran jamais mis à jour par un déplacement d'espace, faux
  événements « focus ») : `Compositor` relit `get_workspaces` après chaque événement d'espace et lit focus et visibilité dans l'objet
  IPC de chaque espace. Sorties : seulement celles que `get_outputs` dit `active: true`.
- Ni titre de la fenêtre active ni mode (Sway) / submap (Hyprland) : aucun widget ne les lit (à rétablir avec le widget qui en aura
  besoin, `BACKLOG.md`).
- Commandes de placement écrites dans le journal (`Compositor: placement des espaces : …`).

## 3. Écrans dynamiques

Deux problèmes, deux mécanismes, **un seul** par problème.

### 3.1 Configuration des sorties → le compositeur, écrans identifiés par description

Chaque compositeur configure ses sorties nativement, par **description** d'écran (marque modèle numéro de série), jamais par
connecteur, dans la partie machine de sa config (§ 1). Le reste de la config est commun. Côté Quickshell, la description
(`Compositor.describe`) est la même sous les deux : sans le « Unknown » de Sway pour un champ absent de l'EDID ni les virgules
qu'Hyprland retire (dalle du laptop : `China Star Optoelectronics Technology Co. Ltd 0x1471`). Clé de `hosts/*.json`, des fonds
par écran et des fonds exportés pour l'écran de connexion, qui tourne sous Sway même pour une session Hyprland.

| | Sway 1.12 | Hyprland 0.57 (Lua) |
|---|---|---|
| Identification | `output "LG Electronics 27GN950 207NTLEFY824" …` | `hl.monitor({ output = "desc:…", … })` |
| Mode, position, échelle | `mode`, `pos`, `scale` | `mode`, `position`, `scale` |
| HDR, profondeur | `hdr on/off/toggle`, `render_bit_depth 10` | `cm` (`"hdr"`), `bitdepth` |
| VRR | `adaptive_sync on/off` | `misc.vrr` (le champ `vrr` de `hl.monitor` est sans effet) |
| Désactiver | `disable` | `disabled = true` |
| Écran inconnu | placé à droite, mode préféré | règle de repli `output = ""`, `preferred`, `auto`, échelle `auto` |
| Capot du laptop | `bindswitch --locked --reload lid:on output <desc> disable` / `lid:off … enable` | `hl.bind("switch:on:Lid Switch", …)` → `hl.monitor({ …, disabled = true })`, état relu au chargement |

Pas de Kanshi : il ne transporte ni HDR ni profondeur de couleur (deux sources pour un même écran), le `hyprctl reload` du réveil
écraserait sa configuration, et ses profils conditionnels ne répondent à aucun besoin actuel (réévaluation : `BACKLOG.md`).
Prix : les réglages d'écran d'une machine sont écrits une fois par compositeur, côte à côte dans `dotfiles/*/hosts/`.

Raccourcis Hyprland `$mod+←` / `$mod+→` : voisin géométrique (`hl.get_monitor("l"|"r")`), puis déplacement avec suivi
du focus. Sans voisin ou fenêtre active : aucune action. Ne pas utiliser `+1` / `-1` : ils parcourent l'ordre interne des
écrans, qui peut différer de leur position même avec des identifiants numériques croissants de gauche à droite.

HDR et VRR à l'exécution (`services/Displays.qml`, `$mod+d` = `qs ipc call display toggleHdr`, bascules du panneau de réglages) :
seulement sur les écrans compatibles (Sway `features.hdr` / `features.adaptive_sync` ; Hyprland `hardwareDetails`), sans nom en
dur. Hyprland : la règle posée vise l'écran par la même clé que la config (`desc:…`) et elle est **complète** (mode, position,
échelle, rotation relus sur l'écran), sinon l'écran perd échelle et position ; règles reposées sur `configreloaded` (le `reload`
du réveil les efface) ; arrêt du HDR = retour au mode d'avant (préréglage, 10 bits, blanc SDR à 203 nits).

### 3.2 Répartition des espaces de travail → `services/Outputs.qml`

Quickshell tourne déjà, connaît le compositeur, et la barre a besoin de la même répartition : un seul calcul pour Sway et Hyprland.
Aucune ligne `workspace N output …` dans les configs (sous Sway, la première attribution d'un espace l'emporte et ne pourrait plus
être corrigée). Si Quickshell ne tourne pas, les compositeurs déplacent d'eux-mêmes les espaces d'un écran disparu.

1. Source de vérité : sorties **actives** du compositeur. Hyprland : `FALLBACK` et un moniteur pas encore relu ne comptent pas.
2. Anti-rebond : recalcul 500 ms après le **dernier** changement d'écrans ou de config machine.
3. Répartition imposée par la config machine pour exactement cet ensemble de descriptions, sinon règle générale (§ 3.3).
4. Application en **une seule commande** au compositeur (Hyprland : une fonction Lua dans un seul `hyprctl dispatch`) : chaque
   espace mal placé rejoint l'écran de son bloc ; chaque écran affiche ensuite, parmi ses candidats (recréés s'ils sont vides) :
   l'espace qu'on y a choisi depuis le dernier placement ; sinon la vue de cette configuration d'écrans si elle a déjà existé (un
   écran éteint puis rallumé retrouve sa vue) ; sinon celle d'avant le changement ; sinon le premier espace existant de son bloc,
   sinon le premier de son bloc. Puis l'espace focalisé **avant** le changement est refocalisé.
   Mémoire de vue par configuration (`layoutKey`), relevée 300 ms après chaque changement d'espaces et à chaque placement ;
   Hyprland : suspendue dès `monitoradded` / `monitorremoved` (`Compositor.outputsChanging`), car Hyprland ramène les espaces
   d'un écran rallumé avant la relecture des moniteurs.
5. **Espace créé hors de son écran** (fenêtre envoyée vers un espace inexistant, commande native) : 100 ms plus tard, déplacé sur
   son écran ; focalisé, il le reste, et son écran de départ reprend l'espace qu'il affichait. **Bouche-trou** (écran vidé de son
   seul espace, Sway en crée un au premier numéro libre) : jamais déplacé (boucle sinon) ; l'écran affiche le premier espace de son
   bloc qui n'est pas ailleurs, le bouche-trou vide disparaît.
6. Un espace déplacé à la main reste où il est jusqu'au prochain changement d'écrans.

**Vérification Hyprland (Quickshell 0.3.2)** : une réponse initiale arrivée après une création peut supprimer ce nouvel espace
du modèle natif ; `refreshWorkspaces()` ne recrée pas les éléments manquants. Avant une répartition et après une rafale de
créations, `Compositor` lit `hyprctl -j workspaces` (délai maximal 2 s, trois tentatives espacées de 500 ms en cas d'échec).
La lecture complète seulement les espaces absents ou sans écran du modèle natif ; les autres conservent leurs données natives.
Un événement structurel pendant la lecture invalide sa réponse et impose une nouvelle lecture. Les créations restent en attente
pendant cette vérification et la stabilisation des écrans ; après déplacement, fenêtres et moniteurs natifs sont rafraîchis.
Aucune scrutation au repos, aucun délai supplémentaire dans les lancements automatiques. Test de régression :
`python3 scripts/test-workspace-startup.py` (Quickshell réel, sockets Hyprland et commande de lecture factices, bus privé).

Raccourcis : `$mod+N` et `$mod+Ctrl+N` → `scripts/ipc.sh outputs focus|moveWindow N` (~45 ms de plus ; commande native si
Quickshell ne répond pas) : un espace inexistant naît directement sur l'écran de son bloc (Sway : `focus output X; workspace number N` ;
Hyprland : créé sur l'écran focalisé puis déplacé, dans la même requête, sinon `follow_mouse` reprend le focus).

**Début de session** : `scripts/desktop.sh` passe `QS_DESKTOP_HOME=<secondes de /proc/uptime>` au premier lancement ; `Outputs` le
lit à sa création (une fois par processus, dans la minute) : chaque écran affiche le premier espace de son bloc (1 / 4 / 7), focus
sur l'écran principal, pour toutes les répartitions des 10 s suivantes, sauf si l'utilisateur change d'espace entre-temps.
`qs ipc call outputs home` reste pour les tests.

### 3.3 Règle générale

- Ordre des écrans : **écran principal d'abord**, puis les autres de gauche à droite (x, puis y).
- Écran principal : celui de la config machine (`primaryOutput`), sinon le plus grand en surface logique (égalité : le plus à gauche).
  Sans compositeur reconnu : le premier écran.
- Blocs : `floor(9 / n)` chacun, le reste (+1) aux premiers écrans dans cet ordre ; blocs contigus.

| Écrans | Résultat |
|---|---|
| 1 | 1-9 |
| 2 | principal 1-5, autre 6-9 |
| 3 | principal 1-3, gauche 4-6, droite 7-9 (ce desktop : DP-2 = 1-3, DP-1 = 4-6, DP-3 = 7-9) |
| 4 | principal 1-3, puis 4-5, 6-7, 8-9 de gauche à droite |
| 5 | 1-2, 3-4, 5-6, 7-8, 9 |

### 3.4 Tests

`scripts/test-outputs.sh [sway|hyprland]` : session isolée (Sway headless ; Hyprland imbriqué dans la session Hyprland), sa propre
instance Quickshell sur ce dépôt, trois écrans comme le desktop, fenêtres `zenity` sur les espaces 1, 2, 4–9. Scénarios : ajout
d'écrans, désactivation / réactivation, débranchement, 2 puis 1 écran, aucun écran actif, écran principal et focalisé éteint puis
rallumé, fenêtre envoyée vers un espace inexistant (avec et sans focus), `$mod+N` / `$mod+Ctrl+N` depuis un autre écran, bouche-trou,
début de session. Contrôles : répartition recalculée indépendamment (jq), espaces sur le bon écran, focus et vue conservés, aucune
fenêtre perdue, nombre de commandes de placement borné.
Limites : les écrans virtuels portent tous la description « Unknown Unknown Unknown » (la répartition imposée par description se
teste sur les vrais écrans) ; un écran virtuel créé pendant la veille hérite de `power off`.

## 4. Config par machine

`hosts/default.json` + `hosts/<hostname>.json` (hostname lu dans `/proc/sys/kernel/hostname`). `config/Settings.qml` charge
`default.json` puis superpose le fichier de la machine **au premier niveau** (une clé remplace entièrement celle de `default.json`).
Relu à chaud (`FileView.watchChanges`).

Tout ce qui se détecte n'y figure pas : batterie (`UPower`, batterie de laptop seulement — l'alimentation USB-C `ucsi-source-psy`
de ce desktop n'en est pas une), rétroéclairage (`/sys/class/backlight`), GPU (§ 7.16), interface réseau, `checkupdates`.

`hosts/terrier.json` (ce desktop ; `terminal`, `mediaPlayer`, `notificationsOutput`, `nightLight` viennent de `default.json`) :

```json
{
  "profile": "jeux",
  "updateCommand": "paru -Syu",
  "wallpaper": { "kind": "triptych", "path": "triptych/green-storm" },
  "doNotDisturb": { "muteApps": ["discord", "whatsapp"] },
  "primaryOutput": "Dell Inc. Dell AW3418DW #ASPFPBQwWjbd",
  "greeter": { "defaultSession": "wayland/sway-vulkan" },
  "bars": {
    "primary":   { "left": [["menu"], ["workspaces"], ["mpris", "volume", "slider"]],
                   "right": [["updates"], ["gpu", "cpu", "memory"], ["clockDate"], ["tray", "settings"]] },
    "secondary": { "left": [["workspaces"], ["volume", "slider"]], "right": [["gpu", "cpu", "memory"], ["clock"]] },
    "LG Electronics 27GN950 207NTHMFY841": { "left": [["workspaces"], ["volume", "slider"]], "right": [["network"], ["clock"]] }
  }
}
```

- `profile` : `jeux` ou `travail` (défaut, `default.json`). Seule clé lue hors de Quickshell : `scripts/profile.sh` la donne à Sway
  (`include profiles/<profil>.conf`), à Hyprland (`lua/profile.lua` → `profiles/<profil>.lua`) et à `install.sh`. **jeux** : règles
  et démarrage de Steam, de ses jeux (EVE, gamescope) et de Deluge (espaces 9 et 7), Discord-WhatsApp sur 5, Spotify sur 6,
  paquets `deps/games.txt`. **travail** : DigitalMicrograph sur 5 (Wine : app_id ou classe X11 `digitalmicrograph.exe`), Windows sur 6,
  Thunderbird sur 7, Discord-WhatsApp sur 8, Spotify sur 9 ; paquets `deps/work.txt`. Les espaces de Discord-WhatsApp et de Spotify viennent du
  profil (`$ws_chat` / `$ws_music` sous Sway, `workspaces.chat` / `.music` sous Hyprland), leurs règles restent communes.
  Thunderbird et la console Windows suivent aussi le profil (`$ws_mail` / `$ws_windows`, `workspaces.mail` / `.windows`). Glyphes
  des espaces : `Theme.icon.workspaces[Settings.profile]`. Changement : éditer la clé (ou `install.sh --profil …`), puis recharger le
  compositeur.
- `primaryOutput` : écran principal, par description. `workspaceLayouts` (facultatif, absent ici : la règle générale tombe juste) :
  liste de répartitions imposées, chacune `{ "<description>": [1, 2, 3], … }`, appliquée quand l'ensemble des écrans actifs est
  exactement celui-là.

- `bars` : l'écran principal reçoit `primary` ; les autres, leur entrée par description, sinon `secondary` (un écran inconnu a
  toujours une barre ; un écran qui a sa propre entrée mais devient principal garde tray et réglages). Chaque côté est une liste de
  **pilules**, chaque pilule une liste de modules. Modules : `menu`, `workspaces`, `mpris`, `volume`, `slider`, `updates`, `gpu`,
  `cpu`, `memory`, `clock`, `clockDate`, `network`, `tray`, `settings`, `battery`, `backlight`. Module sans donnée ou sans matériel :
  masqué ; pilule entièrement masquée : retirée. Sans écran décrit au bout de 10 s : disposition par défaut.
- `terminal` : préfixe qui lance une commande dans un terminal **et attend sa fin** (liste : chaque terminal a sa syntaxe).
- `mediaPlayer` : lecteur préféré (nom D-Bus après `org.mpris.MediaPlayer2.`) : suivi s'il joue, sinon un lecteur qui joue, sinon lui ;
  un lecteur arrêté n'est plus suivi.
- `updateCommand` : absente → `paru`, sinon `yay`, sinon `sudo pacman -Syu`.
- `nightLight` : `{ "from": "20:00", "to": "06:00", "temperature": 3239 }`.
- `doNotDisturb` : horaire de départ `{ "schedule": true, "from": "21:00", "to": "07:00" }`, ensuite réglé depuis le panneau (état local).
- `doNotDisturb.muteApps` : applications qui jouent elles-mêmes le son de leurs notifications, coupées pendant « ne pas déranger », par
  `application.id` du flux (web apps : `env PULSE_PROP_OVERRIDE=application.id=whatsapp chromium …` dans leur lanceur) ou par
  binaire ; ici `["discord", "whatsapp"]`. Va avec `dotfiles/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf` (WirePlumber ne
  retient ni volume ni coupure de ces flux).
- `idle` : `timeout` (300 s par défaut), `lockOnIdle` et `lockBeforeSleep` (null : machine avec batterie ; true/false : choix explicite).
- `wallpaper`, `wallpapersDir` : fond par défaut et dossier des fonds (§ 7.11).
- `greeter.defaultSession` : session proposée par l'écran de connexion tant que l'utilisateur n'en a choisi aucune,
  `wayland/<fichier .desktop sans extension>` ou `x11/…` ; `wayland/sway` par défaut, `wayland/sway-vulkan` ici (§ 9).
- Les icônes d'espaces de travail font partie de la charte → `Theme.qml`, pas de la config machine.

## 5. Thème

`config/Theme.qml` porte toutes les valeurs (palette Catppuccin Mocha statique, aucun générateur), `docs/THEME.md` les règles et
les usages. Aucune couleur, police ou taille hors de `Theme.qml`.

## 6. Services

Singletons de `services/`. Les widgets ne lisent que les services ; aucun `Process` dans l'UI.

| Service | Rôle | Source |
|---|---|---|
| `Compositor` | interface commune Sway / Hyprland (§ 2) | `Quickshell.I3` / `Quickshell.Hyprland` |
| `Outputs` | écrans actifs, principal, répartition des espaces (§ 3) | `Compositor`, `Settings` |
| `Displays` | HDR et VRR | `Compositor` |
| `Audio` | sortie et entrées, volumes, coupure « ne pas déranger » | `Quickshell.Services.Pipewire` ; `pw-dump`, `wpctl` (profils Bluetooth) |
| `Media` | lecteur suivi par le module média et les touches | `Quickshell.Services.Mpris` |
| `SystemStats` | CPU, mémoire (5 s) | `/proc` (`FileView`) |
| `Gpu` | utilisation et température (5 s) | `nvidia-smi` ou sysfs (§ 7.16) |
| `Monitor` | statistiques détaillées, panneau ouvert seulement | `/proc`, `/sys`, `nvidia-smi`, `df` |
| `Network` | débit, connexions NetworkManager | `/proc/net`, `Quickshell.Networking`, `nmcli` (détails) |
| `Tailscale`, `ZeroTier` | onglets du panneau réseau | `tailscale`, `zerotier-cli` ; `Poller`, `CliRunner` |
| `Vpn` | NordVPN | `nordvpn` (une seule file de commandes) |
| `Bluez` | Bluetooth | `Quickshell.Bluetooth` ; `bluetoothctl` (appairage) |
| `Disks` | disques amovibles | `busctl`, `gdbus monitor`, `udisksctl` |
| `Notifs` | serveur de notifications | `Quickshell.Services.Notifications` |
| `Updates` | mises à jour en attente | `checkupdates` |
| `Battery`, `Brightness` | laptop | `UPower` ; `/sys/class/backlight` + `brightnessctl` |
| `Profiles` | profils d'énergie | `PowerProfiles` (power-profiles-daemon) |
| `Rfkill` | mode avion | `rfkill` |
| `NightLight` | veilleuse | `gammastep` (jamais deux à la fois) |
| `Idle` | veille des écrans | `IdleMonitor`, `systemd-inhibit`, `gdbus monitor` (`PrepareForSleep`) |
| `Polkit` | agent polkit | `Quickshell.Services.Polkit` |
| `Session` | verrouiller, déconnexion, redémarrage, extinction | `Compositor`, `systemctl` |
| `Screenshot` | outil de capture | `ScreencopyView`, `Toplevel`, `wl-copy` |
| `Wallpapers` | fonds d'écran | `FileView`, cache |
| `Apps` | applications (lanceur, menu), historique, favoris | `DesktopEntries` + filtres `find`/`awk` |
| `Places` | dossiers XDG, fichiers récents | `xdg-user-dir`, `recently-used.xbel`, `xdg-open` |
| `Icons` | icônes du tray et des types MIME, choisies comme GTK | thème Papirus-Dark |
| `Launch` | lancement d'applications sans l'environnement propre au processus (`qs-env.sh`) | `Quickshell.execDetached` |
| `WidthTexts` | largeurs fixes des modules, mesurées une fois pour toutes les barres | — |

Restent hors Quickshell, faute d'équivalent : `nvidia-smi`, `checkupdates`, `nordvpn`, `tailscale`, `zerotier-cli`, `busctl` / `gdbus` /
`udisksctl` (pas d'accès D-Bus générique en QML), `bluetoothctl` (pas d'agent d'appairage dans Quickshell), `nmcli` (détails),
`notify-send`, `wl-copy` (le presse-papiers de Quickshell ne gère que du texte, et seulement avec un appui récent), `xdg-open`,
`brightnessctl`, `gammastep`, `rfkill`, `pavucontrol` et `nm-connection-editor` (boutons « avancé »).

## 7. Composants

### 7.1 Barre et popups

- Une barre par écran actif (`Variants { model: Quickshell.screens }`), créée et détruite à chaud, disposition de la config machine
  (§ 4). Au démarrage, le contenu attend que chaque écran affiche son fond (au plus 3 s) ; pas au rechargement à chaud.
- Aucun tooltip dans la barre ; les modules du tray et l'engrenage ont un **aperçu au survol** (carte, 150 ms), épinglé au clic.
- **Popups** : surfaces Overlay à clavier exclusif (`modules/bar/OverlayPopup.qml`, base du lanceur, du menu, du panneau de
  réglages, des cartes du tray, de polkit) — un popup Wayland « grab » ouvert depuis une barre ne reçoit jamais le clavier sous Sway.
  Fermeture : Échap, appui à côté (non transmis à ce qui est dessous), sur une barre, sur un autre écran (`OutsideClick.qml`, surfaces
  transparentes créées après l'affichage). Un seul popup à la fois (`BarState.closePopups`). Un appui sur le bouton d'un popup ouvert
  le ferme. Écran ou bouton disparu : popup fermé. Pendant le verrouillage, aucun `OverlayPopup` ne s'ouvre.
- Menu d'applications et panneau de réglages : **un seul exemplaire**, placé sous le bouton qui l'ouvre ; le raccourci le ferme s'il
  est ouvert, sinon l'ouvre sous le bouton de l'écran focalisé (`BarState.toggle`, `toggleFromShortcut`). Créés par
  `modules/menus/Panels.qml`, qui inscrit leurs `LazyLoader` dans `BarState` (pas d'import circulaire). Panneaux du tray créés d'avance.
- **Menus des applications du tray** : cartes (`AppMenuPanel.qml`) — titre = nom de l'application, entrées dbusmenu en lignes,
  sous-menus en sections ; clics gauche et droit ouvrent la carte. Steam : après une entrée autre qu'un jeu ou « Exit Steam », sa
  fenêtre et son espace sont affichés (`Compositor.showAppWindow` ; Sway : `mouse_warping none` le temps de ce focus).
  L'icône d'une application remplacée par un module natif (nm-applet, blueman, udiskie, NordVPN) est masquée si le module existe.
- **OSD** (`modules/osd/`) : volume, micro, luminosité, déclenché par `qs ipc`.

### 7.2 Notifications

- `services/Notifs.qml`, comportement de Dunst 1.13 : délais (celui de l'application, sinon 10 s ; jamais pour une critique),
  suspendus sous le pointeur ; tri urgence puis arrivée ; doublons « (N) » ; étiquettes de pile (`x-dunst-stack-tag`,
  `x-canonical-private-synchronous`) ; remplacement par identifiant ; indicateurs `(A)` `(U)` ; âge au-delà de 60 s ; markup Pango
  traduit pour Qt. Capacités annoncées : celles de Dunst.
- Écran : `notificationsOutput` (`primary` ou description), l'écran principal à défaut.
- Souris : gauche ferme ; milieu lance l'action `default` (ou l'unique action, ou ouvre l'unique lien) ; droit ferme tout ; boutons
  pour les actions nommées. Ouvrir une notification affiche l'espace et la fenêtre de l'application (`focusNextActivation` : Quickshell
  ne transmet pas de jeton d'activation, la fenêtre n'est que marquée urgente).
- Icônes en fichier temporaire (Chromium) copiées à la réception dans `<cacheDir>/notification-icons/` (vidé au démarrage).
- Centre de notifications (cloche du tray) : 20 dernières fermées, carte média ; « ne pas déranger » (clic droit sur la cloche) :
  seules les critiques s'affichent, sons des `muteApps` coupés ; horaire réglable.
- Historique et « ne pas déranger » conservés au rechargement (`PersistentProperties`), pas au redémarrage.
- IPC `notifications` : `close`, `closeAll`, `historyPop`, `count`.

### 7.3 Lanceur (`modules/launcher/`)

- Comportement de `rofi -show drun` (Rofi 2.0) : `DesktopEntries.applications` + filtres que Quickshell n'applique pas (`OnlyShowIn` /
  `NotShowIn` selon `XDG_CURRENT_DESKTOP`, `TryExec` introuvable, `Exec` absent).
- Ordre : historique (le plus lancé d'abord, 25 entrées, `launcher.json` dans l'état local), puis par nom. Recherche : tous les mots,
  sans casse, dans nom, nom générique, `Exec`, catégories, mots-clés, commentaire ; « -mot » exclut.
- Lancement dans `Settings.terminal` si `Terminal=true`. Texte sans résultat ou Ctrl+Entrée : commande `sh -c` ; Maj+Entrée sans
  résultat, Ctrl+Maj+Entrée : dans un terminal.
- Surface couvrant la zone utile de l'écran focalisé ; clavier de Rofi (Entrée, Ctrl+J/M, Haut/Bas, Ctrl+P/N, Tab, Pages, Début/Fin,
  Ctrl+Haut/Bas = textes précédents, Maj+Suppr = retirer de l'historique, édition Emacs, Échap) ; souris : clic sélectionne, double clic
  lance. Hauteur bornée à l'écran. IPC `launcher toggle|open|close`.

### 7.4 Menu d'applications (`modules/menus/AppMenu.qml`, bouton Arch)

- Disposition du menu Cinnamon, style de nwg-menu ; code propre, catégories tirées des `.desktop`.
- Colonne de gauche : dossier personnel et dossiers XDG, favoris (clic droit sur une application ; `app-menu.json`), verrouiller,
  se déconnecter, redémarrer, éteindre (sans confirmation). Colonne 270 px au plus.
- Catégories au survol : « All Applications », catégories freedesktop non vides (première déclarée dans l'ordre Administration,
  Preferences, Programming, Games, Graphics, Sound & Video, Internet, Office, Education, Science, Accessories ; sinon « Other »),
  « Recent Files » (`recently-used.xbel`, lu à l'affichage).
- Visée : un pointeur qui file vers la liste ne change pas de catégorie en traversant les autres (30 ms d'arrêt) ; le survol ne vole
  pas la sélection clavier si la souris n'a pas bougé.
- Recherche en bas (même filtre que le lanceur) ; le survol ne l'efface jamais. Clavier : Haut/Bas, Pages, Gauche = catégories,
  Droite / Entrée = retour, Échap. Hauteur bornée à l'écran (chaque colonne défile).
- Fermeture automatique : pointeur dehors 2 s (pas pendant une recherche, ni s'il n'est jamais entré). IPC `menu toggle`.

### 7.5 Panneau de réglages (engrenage, `$mod+Escape`)

- Remplace le power menu. Modèle : réglages rapides de GNOME.
- Ligne du haut : batterie (laptop), capture d'écran, verrouiller / se déconnecter / redémarrer / éteindre (pas de veille, pas de
  confirmation). Curseurs : sortie son (flèche → choix de la sortie), luminosité (laptop). Bouton du sélecteur de fond.
- Bascules : profil d'énergie (trois boutons), ne pas déranger (clic droit : horaire), garder l'écran allumé (`IdleInhibitor`), VRR et
  HDR (écrans compatibles), veilleuse (`gammastep`, fondu de ~4 s), mode avion (dès qu'il y a une radio).
- Aperçu au survol de l'engrenage. Réseau, Bluetooth, NordVPN, disques, cloche restent dans le tray (pas de doublon). IPC `settings toggle`.

### 7.6 Réseau (tray)

- Deux icônes : **réseau** (filaire et réseaux privés ; visible si un câble est branché, sans Wi-Fi, ou avec Tailscale / ZeroTier) et
  **Wi-Fi**. Connexion limitée signalée (`Networking.connectivity`).
- Wi-Fi (`WifiPanel.qml`) : `Quickshell.Networking` (interrupteur, réseaux, mot de passe, oubli), réseau courant déplié, niveaux de
  signal GNOME (20 / 40 / 50 / 80 %), glyphe animé dessiné en QML (`WifiIcon.qml`). Détails absents de l'API (bande, canal, débit,
  IPv4) : `nmcli`, toutes les 5 s panneau ouvert. Portail captif : bouton vers le navigateur par défaut ; sonde native relancée
  toutes les 10 s pendant un accès limité, même panneau fermé. Sonde et navigateur partagent une adresse HTTP ; configuration
  système reproductible et retour arrière : `docs/NETWORK.md`. Sondes désactivées : résultats périmés ignorés.
- Panneau réseau : onglets Wired (détails `nmcli`, graphe du trafic) / Tailscale (`status --json`, `debug prefs` ; actions grâce à
  `--operator=$USER`, à faire à la main) / ZeroTier (`zerotier-cli -j` avec le jeton copié dans `~/.zeroTierOneAuthToken`,
  à la main ; sinon interfaces `zt*` en lecture seule). Relus toutes les 5 s onglet affiché ; 60 s sinon, sans câble.
- Édition complète des connexions : `nm-connection-editor`. Copies : `wl-copy`.

### 7.7 Bluetooth (tray)

- `Quickshell.Bluetooth` pour lister, connecter, oublier. Quickshell n'a **pas d'agent d'appairage** (`org.bluez.Agent1`) : pendant
  un appairage seulement, `bluetoothctl` est lancé comme agent (`agent KeyboardDisplay`, sans `default-agent`) ; ses demandes
  (`[agent] Confirm passkey`, `Enter PIN code`) sont affichées dans le panneau, **jamais acceptées automatiquement**. Seules les lignes
  `[agent] …` et les résultats de `pair` en début de ligne sont lus (un nom d'appareil pourrait imiter une question).
- Lignes : état, type, batterie ; détails dépliables (adresse copiable, renommage, reconnexion automatique) ; ordre figé panneau ouvert.
- Notifications de connexion / déconnexion (« Connected 80% » quand la batterie arrive) ; batterie faible à 30 % puis 15 %, réarmée
  au-dessus de 40 %.
- Reconnexion automatique des appareils choisis (`bluetooth.json`, état local) : démarrage, allumage, apparition, toutes les 60 s.
- Profil audio d'un casque : `pw-dump` / `wpctl set-profile` (non exposé par Pipewire dans Quickshell).
- Veille suspendue tant qu'une manette est connectée. Icône animée pendant les actions.

### 7.8 Disques amovibles (tray, remplace udiskie)

- État : `busctl --system --json=short call org.freedesktop.UDisks2 … GetManagedObjects` ; branchements : `gdbus monitor --system`
  (sans droits) ; actions : `udisksctl mount | unmount | power-off | unlock` (phrase de passe passée en fichier de clé sur l'entrée
  standard).
- Montage automatique et notifications comme udiskie ; volumes système (`HintSystem`, `HintIgnore`) ignorés.
- Icône visible seulement avec un disque branché ; disque LUKS branché : le panneau s'ouvre avec le champ prêt (pas au démarrage).

### 7.9 NordVPN (tray)

- Commande `nordvpn` (pas d'API ni de flux d'événements) : `status` (lignes `Clé: valeur`) lu périodiquement et après chaque action ;
  **une seule file** pour toutes les commandes (une lecture suit chaque action et voit son effet).
- Panneau : onglets Recent (historique local `vpn.json`, pays et ville) / All countries, recherche ; l'interrupteur reconnecte à la
  dernière entrée. IPC `vpn connect [pays]` (vide : dernier pays) / `vpn disconnect` (`$mod+u` / `$mod+i`).
- Module masqué si `nordvpn` est absent ou le compte non connecté. **Jamais d'action réelle en test** (`docs/DEVELOPMENT.md`).

### 7.10 Web apps

- WhatsApp, Discord, Word, Excel, PowerPoint, Notion : `chromium --app … --user-data-dir=<profil isolé> --load-extension=…/open-links`.
- Un lien ouvert dans un nouvel onglet ou une nouvelle fenêtre part dans le profil Chromium principal (onglet ajouté, navigateur
  démarré s'il ne tourne pas), sauf s'il reste dans les domaines de l'app (liste `SITES` de l'extension : Microsoft 365, Notion) ; les
  popups (OAuth) restent dans la web app. L'hôte `open-link` appelle `qs ipc call compositor focusNextWindowOf chromium` avant Chromium, après nettoyage de l'environnement :
  la fenêtre qui reçoit le lien et son espace sont affichés.
- Règles d'espace : Discord (deux `app_id` : `…@me-Default` et `…@me_<salon>-Default`) et WhatsApp sur l'espace 5.

### 7.11 Fond d'écran (`modules/wallpaper/`, `services/Wallpapers.qml`)

- Une surface par écran sur la couche Background, sans zone d'entrée (un clic va au compositeur, comme `swaybg`). Image simple :
  couvre l'écran, décodée à sa taille. Panorama : rectangle englobant tous les écrans, chaque écran en montre sa part. Triptyque :
  gauche / centre / droite à 3 écrans, sinon le centre partout. Panorama sur un seul écran : image simple. L'ancien fond reste
  affiché pendant le décodage du nouveau.
- Choix : état local `wallpaper.json` (un fond pour tous, ou une image par écran, clé = description). Rien de choisi : `wallpaper` de
  la config machine, sinon aucune image. Dossier : `wallpapersDir`, sinon « Wallpapers » dans le dossier Images XDG.
- Profil travail : `corelab/<design>/<design>_<L>x<H>.png`, regroupés en designs dans l'onglet **Core Lab**. Choix global
  `{ kind: "corelab", path: "corelab/<design>" }` ; choix par écran : même chemin de design dans `overrides`. Résolution physique
  exacte (échelle comprise), sinon rapport le plus proche puis plus petite taille suffisante, ou plus grande disponible.
  Le même design s'adapte à chaque écran et aux changements de mode. Images / Panoramas / Triptychs restent disponibles.
  Profil jeux : Core Lab masqué, choix mémorisé conservé mais remplacé à l'affichage par le repli habituel.
- Sélecteur (`PickerWindow.qml`, `qs ipc call wallpaper-picker toggle`) : onglets Images / Panoramas / Triptychs, vignettes en cache
  (`wallpaper-thumbs/`), appliqué au clic, rangée « All screens » / un écran. Empreintes mémorisées par version de fichier ;
  un scan identique conserve les objets du modèle et les images décodées. Les écritures pendant un scan sont fusionnées
  avec son résultat. Les réservations de capture sont annulables et les callbacks obsolètes ignorés.
  Une grille est chargée à la première visite de chaque onglet puis conservée, avec sa position clavier et son défilement.
  `Thumbnail.qml` attend une taille physique valide, capture à la taille logique et régénère un cache illisible depuis
  l’original. Seules les cellules virtualisées des onglets visités sont retenues ; aucun préchargement des 252 variantes. Les noms des caches disque sont inchangés.
- **Copie à la taille de l'écran** (démarrage plus rapide) : chaque fond simple affiché est enregistré en BMP tel qu'affiché dans
  `~/.cache/quickshell/by-shell/desktop/wallpaper-screens/` (3 s après l'affichage ; 28 ms au lieu de 125–165 ms ; sans perte). Seules
  restent les copies des fonds choisis ou affichés ; une copie sans entrée n'est effacée qu'après un jour (une autre instance peut
  partager le cache) ; original modifié : copie refaite ; copie absente : original relu. Panorama sur plusieurs écrans : pas de copie.
  Les deux dossiers de cache peuvent être supprimés sans risque.
- **Copie pour l'écran de connexion** : 3 s après l'affichage, le rendu de chaque écran (image, panorama, triptyque) est enregistré en
  JPEG dans `/var/lib/qs-desktop/<utilisateur>/<md5(description)>.jpg`, lisible par l'utilisateur `greeter` (§ 9). Dossier créé par
  `scripts/greeter-setup.sh`, vérifié au démarrage de Quickshell (absent : aucun rendu). Écriture ratée : retentée au fond affiché
  suivant. Banc : seulement sous `QS_GREETER_DIR`. Aucun fond exporté pour cet écran (aucune session ouverte
  encore, écran inconnu du bureau) : `default.png|jpg`, fond de la config machine copié par `install.sh` (étape système).
- IPC de test : `wallpaper state`, `wallpaper set <kind> <chemin>` (dont `corelab corelab/<design>`). `state` inclut les noms de designs `corelab`.

### 7.12 Verrouillage (`modules/lock/`)

- `WlSessionLock` (ext-session-lock) + `PamContext` (config `login`). Fond de chaque écran flouté et assombri, horloge, date ;
  initiale, nom et champ sur l'écran principal ; saisie prise quel que soit l'écran qui a le clavier ; majuscules verrouillées
  déduites des lettres tapées ; Entrée valide, Échap efface, Ctrl+Retour arrière efface tout (`PasswordEntry.qml`, commun avec
  l'écran de connexion) ; messages de PAM (faillock). Sous le champ : éteindre, redémarrer, veille (`PowerRow.qml`, sans confirmation).
- Vue (`LockContent.qml`) partagée avec l'écran de connexion (§ 9), qui y ajoute la pastille de session et son propre fond.
- Verrouiller : panneau de réglages, menu d'applications, `qs ipc call lock lock`, veille. **Aucun déverrouillage par IPC.**
- Verrou refusé ou perdu (autre client ext-session-lock) : `locked` repasse à faux. Un « 1 » resté dans l'état n'est lu qu'une fois
  par processus.
- **Sûreté** : si Quickshell s'arrête verrouillé, le compositeur garde la session verrouillée. Reprise depuis un autre TTY :
  `WAYLAND_DISPLAY=wayland-1 qs -c desktop &` puis `qs ipc call lock lock` ; la nouvelle instance reprend le verrou.

### 7.13 Veille des écrans (`services/Idle.qml`)

- `IdleMonitor` (inhibitions du compositeur, « Keep Screen On », vidéos Wayland respectées) : après `idle.timeout`, écrans éteints
  (`Compositor.setPower` : Sway `output * power off` ; Hyprland `hl.dsp.dpms({ action = … })`), tous rallumés d'un coup à la reprise
  (un rallumage par écran refait un modeset sous Sway). Quickshell relancé écrans éteints : rallumés 2 s après le démarrage.
- Sur laptop, `idle.lockOnIdle` demande le verrouillage et attend la confirmation du compositeur avant extinction.
  Une reprise d’activité annule l’extinction différée, sans annuler le verrouillage ; un verrou refusé laisse les écrans allumés.
  Le délai reste de 300 s, sur secteur comme sur batterie ; les inhibitions ci-dessous restent respectées.
- Inhibitions D-Bus : `scripts/idle-inhibit.py` (Python/Gio) publie `org.freedesktop.ScreenSaver`, objets
  `/org/freedesktop/ScreenSaver` et `/ScreenSaver`, méthodes `Inhibit(ss) → u`, `UnInhibit(u)`. Cookies propres à leur appelant,
  libérés à sa déconnexion ; identifiants uint32 non nuls tirés au hasard, sans collision parmi les demandes actives,
  pour éviter la réutilisation déterministe des cookies retenus après un plantage. Méthodes enregistrées avant la publication du nom, aucun nom existant remplacé. Chromium demande cette inhibition pendant la lecture vidéo,
  y compris sans focus ; plein écran et Picture-in-Picture ne bloquent plus à eux seuls la veille sous Sway.
- `desktop.sh` garde ce service en dehors du moteur QML : cookies conservés au rechargement et à la relance automatique du shell,
  arrêt avec la surveillance (TERM, puis KILL après 1 s au plus si bloqué), cinq tentatives au plus. Socket privé `QS_IDLE_SOCKET` dans le runtime de la session,
  état JSON par ligne `{ready:true,count:N}` à la connexion puis aux changements. `Idle` désactive son suivi tant que N > 0,
  puis redémarre le délai ; déconnexion du socket → compteur nul et reconnexion chaque seconde. `idle state` expose
  `dbusReady` et `dbusInhibitors`. Journal séparé `qs-idle.<session>.log`. Après une relance **manuelle** complète du bureau,
  ou un plantage du service lui-même, les cookies D-Bus sont perdus : pause/reprise pour renouveler une lecture déjà en cours.
- Test du contrat sans compositeur : `python scripts/test-idle-inhibit.py` (bus privé). Les demandes de suspension manuelle
  et les inhibiteurs Wayland restent indépendants ; aucune déduction depuis MPRIS, aucune inhibition audio ajoutée.
- Verrouillage avant la veille du système (`idle.lockBeforeSleep`) : verrou « delay » de logind (`systemd-inhibit` sous
  `setpriv --pdeathsig`), `PrepareForSleep` suivi par `gdbus monitor`. Libération après confirmation du verrouillage par le compositeur,
  sans échéance QML de 2 s : logind plafonne déjà l’attente (`InhibitDelayMaxSec`). Au réveil, inhibition réarmée. Les deux processus
  sont relancés après 5 s s’ils s’arrêtent alors qu’ils sont attendus, jamais après une libération volontaire. Hyprland :
  `PrepareForSleep` suivi aussi pour le `reload` du réveil. Cette attente ne garantit pas le verrouillage si le shell est figé ou si le verrou est refusé.
- Animation `fadeDpms` coupée dans la config Hyprland (rallumage lent sinon). IPC de test : `idle state`.

### 7.13.1 Capot du laptop

- Veille : **logind** par défaut (capot fermé → veille, sur secteur comme batterie ; ignoré avec un écran externe ; 30 s de
  répit après un réveil ; veille aussi au retrait du dernier externe capot fermé). Verrouillage avant veille : § 7.13.
- Un écran éteint par la veille a son connecteur détaché (sysfs `enabled`, vérifié sous Hyprland) : logind ne voit plus
  l'externe et mettrait en veille un laptop branché capot fermé. `Idle.qml` bloque donc `handle-lid-switch` tant qu'un écran
  externe est **actif** dans `Compositor.outputs` (veille des écrans comprise ; laptop seulement, pas sous `QS_TEST`).
- Dalle : éteinte capot fermé, rallumée à l'ouverture par le compositeur (§ 3.1, `dotfiles/*/hosts/<laptop>`) ; Hyprland relit
  l'état du capot à chaque chargement (`/proc/acpi/button/lid/*/state`), le `hyprctl reload` du réveil la rallumerait. Espaces
  repris par `Outputs.qml`.

### 7.14 Agent polkit (`services/Polkit.qml`, `modules/polkit/`)

- `PolkitAgent` ; fenêtre `OverlayPopup` centrée sur l'écran focalisé : icône, message (texte brut), champ, erreur, Cancel /
  Authenticate. Échap, clic à côté ou sur une barre : annulent (pas un clic sur un autre écran).
- Identité affichée seulement si ce n'est pas l'utilisateur ; pas de choix d'identité (relancer la session PAM est risqué en 0.3.2).
- Fermée sans l'utilisateur (écran retiré, verrouillage) : demande gardée, rouverte. Jamais affichée pendant le verrouillage.
- Enregistrement raté : agent recréé (5 s, puis de plus en plus rarement, 5 min au plus).
- Limite de Quickshell 0.3.2 : une demande arrivée pendant une autre la remplace ; la première est annulée une fois l'agent libre.
  Chaque annulation compte comme un échec pour faillock.

### 7.15 Outil de capture (`modules/screenshot/`, `Print`)

- Modèle de l'outil de GNOME : image figée de chaque écran (`ScreencopyView` jusqu'à la première image), voile et cadre ; capture dès
  le choix fait — zone tracée, écran cliqué, fenêtre cliquée (rectangles donnés par le compositeur, empilement réel, espace spécial
  d'Hyprland compris). Entrée / Espace : écran présélectionné ; Échap ferme.
- Découpe à la résolution réelle (`grabToImage` corrigé de l'échelle), enregistrée dans `Images/screenshot/AAAA-MM-JJ-HHMMSS.png` et
  copiée (`wl-copy`). Fermé au verrouillage. IPC `screenshot area|screen|window` ; test : `select x y w h`, `capture`, `isActive`.
- `ScreencopyView` ne reçoit aucune image en rendu logiciel : l'outil ne se teste que sur de vrais écrans.

### 7.16 GPU et statistiques système

- Module GPU : cartes `/sys/class/drm/card*/device/vendor` (`0x10de` NVIDIA, `0x1002` AMD, `0x8086` Intel ; plusieurs : `boot_vga=1`).
  Affiche l'**utilisation** : `nvidia-smi --query-gpu=utilization.gpu` (NVIDIA, aucun capteur hwmon), `device/gpu_busy_percent` (AMD) ;
  Intel : compteur matériel Render/3D via `intel_gpu_top` (module masqué si outil/droits absents). Aucune somme des moteurs ni estimation. Un échec de `nvidia-smi` ne masque pas le module définitivement.
- Moniteur de statistiques (`modules/monitor/`, ouvert par CPU, mémoire, GPU, `qs ipc call monitor toggle`) : fenêtre native
  `FloatingWindow`, fermable par Super+Q et Échap, clic extérieur sans fermeture. Le compositeur gère bordures et coins
  (pas d’arrondis QML sur le cadre). Taille du contenu bornée par l’écran ; même écran d’ouverture et centrage dans la zone utile.
  `Compositor` vise seulement le PID Quickshell courant + titre `System Monitor — Quickshell`, puis l’identifiant natif exact :
  Sway via événement de fenêtre, Hyprland via attente bornée de la liste native. Recentrage après changement de dimensions,
  sans reprendre le focus ; aucun changement de raccourci ni règle globale de fenêtres. Fermeture au verrouillage.
  Relevés chaque seconde panneau ouvert ; CPU (total, température coretemp / k10temp / zenpower, cœurs), mémoire et swap, réseau, GPU (NVIDIA : charge, VRAM,
  température, consommation, ventilateur, fréquence, VRAM par processus via `nvidia-smi pmon` ; AMD : sysfs ; Intel :
  compteurs PMU ci-dessous ou sysfs en repli). `Gpu.cardPath` identifie la carte indépendamment d'un capteur de température.
  Intel avec droits : un seul `intel_gpu_top -J -s 5000` persistant, partagé entre barre et moniteur via `Gpu.intelStats`.
  `services/IntelGpu.js` extrait les objets du flux JSON ; première mesure de démarrage ignorée. Barre : Render/3D ; moniteur :
  3D, Copy, Video, Video+, Compute selon disponibilité, fréquence réelle moyenne sur l'intervalle (libellé `avg`), consommation
  GPU (pas celle du CPU), mémoire résidente par processus/application. Aucun total physique déduit de la mémoire partagée.
  Le moniteur réutilise le flux natif sans deuxième collecte Python Intel. Échec ou flux figé : anciennes mesures effacées,
  nouvelle tentative ; droits restaurés après mise à jour par le hook pacman (`scripts/intel-gpu-setup.sh`).
  Sans PMU et pour AMD : `scripts/gpu-stats.py` lit sysfs et les fdinfo des processus lisibles, panneau ouvert ; mémoire Intel
  de repli ~10 s, fréquence native de repli à 1 s. Identité PID + démarrage, filtre PCI et déduplication par client DRM.
  Mémoire Intel partagée signalée, aucune charge estimée ni température CPU présentée comme GPU.
  Disques (`df`),
  processus (charge comme top, tri, recherche), arrêt de ses propres processus avec confirmation (SIGTERM / SIGKILL).
- Vue par défaut à chaque ouverture : Applications, y compris les applications identifiables en arrière-plan ; bascule compacte
  à gauche de la recherche vers Processes (clic sur toute la pilule : inversion, pastille animée sur 250 ms). CPU/RSS/VRAM additionnés par application et nombre de processus à la place du PID.
  `Monitor.applications`, `stopApplication(id, force, confirmation)` ; `stopProcess(key, force)` garde l’identité choisie,
  `stop(pid, force)` conservé pour les appelants existants.
- `scripts/monitor-processes.py` : catalogue natif DesktopEntries transmis sur stdin JSON, relevé `/proc` (PID + starttime),
  fenêtres Hyprland natives / arbre IPC Sway pour les lanceurs indirects. Les applications reconnues forment des frontières dans
  l’arbre ; appartenance des orphelins conservée. Chromium : profils des lanceurs avant le nom d’exécutable, rapports de plantage
  rattachés par profil ; une webapp inconnue reste séparée par profil. Plusieurs app_id sur un même hôte : arrêt groupé désactivé.
- Confirmation : instances figées, descendants actuels de ces instances inclus ; nouvelles instances indépendantes exclues.
  UID et starttime revérifiés, signaux par pidfd, erreurs affichées ; aucun droit supplémentaire. Mémoire = somme des RSS,
  donc les pages partagées peuvent être comptées plusieurs fois. Processus non attribuables : vue Processes.
- Tests : `python scripts/test-monitor.py` ; ajouter `--chromium` pour trois profils headless jetables et les vrais signaux.
  Fixture QML `scripts/tests/monitor/shell.qml` à copier à la racine de la copie de test, puis lancer sur banc isolé :
  `MONITOR_TEST_PASS` vérifie sommes, tris, sélection, transitions, retour par défaut à Applications et compteur de visibilité.
  Pour le test natif, copier `scripts/tests/monitor/window-shell.qml` à la racine de la copie et le lancer sur banc QS_TEST=1,
  puis `python scripts/tests/monitor/window-check.py <PID_QS> sway|hyprland` avec le même environnement. Sway : démarrer avec
  un écran HEADLESS-1 de 1600x1200, le test ajoute HEADLESS-2. Vérifie flottement, focus, fermeture native sans cible (action
  de Super+Q), fenêtre jetable derrière conservée, réouverture et relevés arrêtés. Le script refuse une instance hors QS_TEST.

### 7.17 Calendrier (horloge)

Carte comme les autres (`CalendarPanel.qml` sur `Panel.qml`) : aperçu du mois au survol de l'horloge ; un clic l'épingle (flèches,
molette, ←/→ ; clic sur le titre : mois en cours) ; fermeture : Échap, clic sur l'horloge ou à côté, pointeur dehors 2 s ; 10 px de
marge au bord de l'écran. Limite : après un clic dans le calendrier, Échap et ←/→ ne répondent plus (pas d'API pour rendre le clavier
à la barre). Événements Thunderbird : `BACKLOG.md`.

## 8. Choix structurants

### 8.1 Quickshell hérite de qt6ct

`QT_QPA_PLATFORMTHEME=qt6ct` (`/etc/environment`) s'applique à Quickshell : style, police par défaut, thème d'icônes `breeze` (non
installé). Parades : `Theme.qml` nomme toujours famille **et** taille ; `//@ pragma IconTheme Papirus-Dark` (indispensable : sans lui,
seules les icônes de `hicolor` s'affichent) ; aucun contrôle Qt Quick Controls stylé par la plateforme.

### 8.2 Un seul processus pour tout le bureau

Barre, notifications, verrouillage, polkit, agent Bluetooth et veille vivent dans le même `qs`. `scripts/desktop.sh`, lancé par
l'`exec` de Sway et le `hyprland.start` d'Hyprland, le relance s'il s'arrête tant que le compositeur répond (abandon et message après
5 arrêts en une minute). Pas de service systemd : l'environnement systemd est commun aux sessions Sway et Hyprland (un `SWAYSOCK`
resté d'une session Sway tromperait `Compositor`), et rien ne lierait le service à la vie du compositeur. `$mod+Ctrl+W` =
`desktop.sh restart` (une relance voulue ne compte pas parmi les arrêts). Variables du processus : `scripts/qs-env.sh`, jamais
transmises aux applications lancées (`services/Launch.qml`). Fenêtre « config rechargée » de Quickshell gardée.

### 8.3 Polices embarquées

`Symbols Nerd Font Mono`, `HackNerdFont-Regular`, Font Awesome 7 Free / Brands et Font Awesome 4.7 sont versionnées dans
`assets/fonts/` (licences MIT, Bitstream Vera, SIL OFL : `assets/fonts/README.md`) et chargées par Quickshell lui-même (`FontLoader`
de `config/Theme.qml`) : version exacte pour la barre, quelle que soit la machine. Les applications et compositeurs utilisent les
paquets officiels des mêmes polices (`deps/arch-pacman.txt`) ; rien n'est copié dans `~/.local/share/fonts`. `install.sh` vérifie
avec `fc-list` les polices de `THEME.md`.

### 8.4 Polices Microsoft

Dépôt privé séparé `Crystal4276/fonts-ms` (polices propriétaires, jamais dans `qs-desktop`), cloné en option par `install.sh` dans
`~/.local/share/fonts/MS_Fonts`. Le bureau n'en dépend pas (`noto-fonts-cjk` en repli). Alternative : AUR `ttf-ms-win11-auto`.

## 9. Écran de connexion (phase 11)

**greetd** remplace SDDM ; l'écran de connexion est le **design de l'écran de verrouillage** (§ 7.12) augmenté des fonctions de SDDM
(choix décidé le 2026-11-04, à la place du thème SDDM `catppuccin-mocha-green`, gardé seulement comme référence dans
`docs/reference/`).

- **Chaîne** : greetd (VT 1, `/etc/greetd/config.toml`) lance `scripts/greeter.sh` sous l'utilisateur `greeter` → Sway minimal
  (`dotfiles/greetd/sway.conf` + écrans de la machine `dotfiles/sway/hosts/<hostname>.outputs.conf` ; Nvidia : `--unsupported-gpu`, et
  rendu Vulkan si c'est la seule carte) → `qs -p greeter.qml` → session choisie lancée par greetd, Quickshell s'arrête, Sway aussi.
- **Écran** (`modules/greeter/GreeterScreen.qml`, `LockContent.qml`) : une surface par écran (couche Overlay), clavier à l'écran principal
  (`Settings.primaryOf`, sans `Outputs` qui placerait des espaces de travail). Fond flouté : la copie du bureau (§ 7.11), sinon uni.
  Sur l'écran principal : horloge, date, initiale et nom (clic : compte suivant s'il y en a plusieurs), champ, message, **pastille de
  session** (clic : liste au style des panneaux ; ↑/↓ : précédente, suivante), éteindre / redémarrer / veille.
- **Service** (`services/Greeter.qml`) : comptes de `/etc/passwd` (UID 1000–59999, shell de connexion) ; sessions des fichiers
  `.desktop` de `wayland-sessions` puis `xsessions` (`XDG_DATA_DIRS`), sans ceux dont `TryExec` manque, X11 suffixées « (X11) » ; dernier
  compte et dernière session par compte dans `/var/lib/qs-desktop/greeter/state.json`, sinon `greeter.defaultSession` (§ 4).
  Une seule variante par bureau connu : GNOME standard, Hyprland standard, Qtile Wayland ; Sway selon `greeter.defaultSession`
  (sinon standard). Variante préférée absente : première disponible dans l'ordre de préférence ; sessions inconnues conservées.
  Les anciens choix mémorisés des variantes regroupées sont réassociés à la variante retenue sans changer le format d'état.
  Connexion : `Greetd.createSession` → mot de passe → `launch` de `scripts/greeter-session.sh wayland|x11` avec `XDG_SESSION_TYPE`,
  `XDG_SESSION_DESKTOP`, `XDG_CURRENT_DESKTOP` (`DesktopNames`) et `GREETER_SESSION_EXEC` (= `Exec`) : greetd recolle la commande avec
  des espaces pour `sh -c`, `Exec` ne peut donc pas y figurer tel quel.
- **Lancement de la session** (`scripts/greeter-session.sh`, sous l'utilisateur) : shell de connexion de l'utilisateur (profil lu, comme
  SDDM ; shell non POSIX : `/bin/sh` de connexion), puis `Exec` ; X11 : `startx` sur le terminal virtuel de la session (`xorg-xinit` ;
  sessions X11 masquées sans lui), le script lui-même comme client (`startx` recoupe les arguments aux espaces). Profil lu une seule
  fois (`source_profile = false` côté greetd). Sway Nvidia : session `sway-vulkan.desktop` (`env WLR_RENDERER=vulkan sway
  --unsupported-gpu`), versionnée dans `dotfiles/greetd/` (avec `DesktopNames=sway;wlroots`, absent de la version faite pour SDDM : portails), installée dans
  `/usr/local/share/wayland-sessions/` si Nvidia est la seule carte graphique.
- **PAM** : `/etc/pam.d/greetd` (celui du paquet + `pam_gnome_keyring.so` en `auth`, `password`, `session auto_start`, comme
  `/etc/pam.d/sddm`) ; `/etc/pam.d/greetd-greeter` pour la session du greeter lui-même (comme `sddm-greeter` : sans lui, greetd
  reprend `greetd` et lancerait le trousseau pour `greeter`).
- **Fichiers lisibles par `greeter`** (le dossier personnel ne l'est pas) : copie du dépôt dans `/usr/local/share/qs-desktop` (version
  committée, `git archive`) ; `/var/lib/qs-desktop/greeter/` (état, caches : `greeter` n'a pas de dossier personnel) ;
  `/var/lib/qs-desktop/<utilisateur>/` (fonds exportés par le bureau ; 750, groupe `greeter`, ACL par défaut `g:greeter:r` : lisibles quel que soit l'umask). Chemin : `Settings.greeterDir`.
- **Mise en place** : `scripts/greeter-setup.sh [--dry-run] install|enable|uninstall` (sudo par commande, sauvegardes
  dans `/var/lib/qs-desktop/backup/` — pas à côté : une copie dans `/etc/pam.d` serait un service PAM —, notées dans
  `/var/lib/qs-desktop/backups`, ancien gestionnaire noté dans `previous-dm`). `install` ne touche à aucun
  service et se relance après chaque changement du greeter ; `enable` : greetd au prochain démarrage. Repris par `install.sh` (phase 12).
- **Retour arrière** : `docs/ROLLBACK.md` ; SDDM reste installé jusqu'à ta décision.

### 9.1 Écran de démarrage Plymouth (profil travail)

Avant l'écran de connexion, sur les machines au profil travail : thème Plymouth `qs-corelab` (`dotfiles/plymouth/`, spécification
`docs/PLYMOUTH.md`) au design des fonds Core Lab, demande de phrase de passe LUKS comprise.

- **Thème** : plugin `script` ; images préparées par `scripts/plymouth-assets.py` (un jeu par échelle, anneaux découpés en arcs ;
  données dans le bloc généré du script). Plusieurs écrans : une seule scène (contrainte de Plymouth), à l'échelle de l'écran 1440p.
- **Installation** : `scripts/plymouth-setup.sh` (étape système d'`install.sh`) : hook de l'initramfs et `splash`. Deux modes :
  **UKI** (archinstall, le laptop : ligne de commande intégrée à l'image, `/etc/kernel/cmdline` + `/etc/cmdline.d`, GRUB non
  touché, image de secours sans Plymouth par noyau, `<image>~rescue.efi`) et **GRUB classique** (`splash` dans
  `/etc/default/grub`, `grub-mkconfig`). Mises à jour du noyau : le hook pacman de mkinitcpio refait les images ; machine
  GRUB + UKI : hook `90-qs-grub-uki.hook` (garde `10_linux` désactivé). Détail : `docs/ROLLBACK.md`.
- **Passage au greeter** : greetd attend `plymouth-quit-wait.service`, surchargé pour jouer la sortie du thème (statut
  `qs-corelab-exit`, 3,4 s) puis `plymouth deactivate` (image crust gardée) ; `plymouth-quit.service` ne quitte qu'après greetd.
  Le Sway du greeter part sur fond noir (~1 s, pas de `swaybg` : accepté).

## 10. Couverture de l'API Quickshell

Revue complète des types (documentation 0.3.0, `qmltypes` de 0.3.2, code source) ; à tenir à jour.

| Module | Utilisé | Écarté (raison) |
|---|---|---|
| `Quickshell` | `ShellRoot`, `Singleton`, `Variants`, `PanelWindow`, `FloatingWindow`, `Region`, `PopupAnchor`, `SystemClock`, `QsMenuOpener`, `DesktopEntries`, `LazyLoader`, `ScriptModel`, `PersistentProperties` (JSON en texte : un tableau JS ne passe pas d'un moteur à l'autre), `RetainableLock`, `execDetached`, `cachePath`, `statePath`, `clipboardText` | `QsMenuAnchor` (menus dessinés), `ColorQuantizer` (couleurs inventées), `ElapsedTimer` ; `EasingCurve` au besoin (animations : `BACKLOG.md`) |
| `Quickshell.Io` | `Process`, `FileView`, `SplitParser`, `StdioCollector`, `IpcHandler`, `JsonAdapter` (`vpn.json`) | `Socket*`, `DataStream*` (raccourcis par `IpcHandler`) |
| `Quickshell.I3`, `Quickshell.Hyprland` | tout le nécessaire à `Compositor` | `HyprlandFocusGrab` (`OutsideClick` commun aux deux), `GlobalShortcut` (raccourcis par `qs ipc`) |
| `Quickshell.WindowManager` | — | en réserve : `ext-workspace` n'indique ni focus ni état vide, ne crée pas d'espace |
| `Quickshell.Wayland` | `WlrLayershell`, `WlSessionLock`, `IdleMonitor`, `IdleInhibitor`, `ScreencopyView`, `ToplevelManager`, `Toplevel` | `ShortcutInhibitor` (le verrou bloque déjà), `BackgroundEffect` (flou hors charte, absent de Sway) |
| `Quickshell.Widgets` | `IconImage`, `ClippingRectangle` | — |
| `Quickshell.DBusMenu`, `.Services.SystemTray` | menus et icônes du tray | — |
| `Quickshell.Bluetooth`, `.Networking` | Bluetooth, réseau, Wi-Fi | `NMSettings` non utilisé à ce jour |
| `Quickshell.Services.Mpris`, `.Notifications`, `.UPower` (+ `PowerProfiles`), `.Polkit`, `.Pam` | tous | — |
| `Quickshell.Services.Pipewire` | `Pipewire`, `PwNode`, `PwNodeAudio`, `PwObjectTracker`, `PwNodePeakMonitor` | `PwLink*` (pas de routage audio) |
| `Quickshell.Services.Greetd` | `Greetd`, `GreetdState` (écran de connexion, § 9) | — |
| `Quickshell.X11` | — | sans objet sous Wayland |

Écartés aussi : réponse directe dans les notifications (Chromium ne la propose pas), historique du presse-papiers (`clipboardText`
lisible seulement avec le focus), disposition des écrans à la `wdisplays` (pas d'API de configuration des sorties).


### Contenu ouvert par application d'origine

Le processus `scripts/open-origin.py` appartient à `Compositor` : démarrage en session, reprise après 5 s s'il s'arrête, arrêt
et nettoyage du socket au rechargement ; un verrou assure une seule instance. Désactivé sur les bancs généraux `QS_TEST=1`.
La politique suit les origines Deluge / Thunderbird / Steam par identité de processus et les chemins natifs GIO, GApplication,
GTK CommandLine, FileManager1, portail et MPRIS. Les programmes enfants directs sont aussi suivis à la création de leur fenêtre.
Sous Hyprland, `lua/openorigin.lua` intervient synchroniquement dans `window.open`, à la fin du mapping mais avant le rendu.
Le suivi publie atomiquement les identités PID/démarrage et l'écran principal dans `$XDG_RUNTIME_DIR/qs-open-origin.state`
(mode 600, supprimé à l'arrêt). Requêtes limitées à 5 s ; l'ascendance native couvre les enfants directs. Les nouveaux clients
sont placés par ce hook uniquement, sans rattrapage IPC après affichage ; l'animation de transfert est temporairement suspendue
puis la règle configurée restaurée. Un lecteur existant est placé dès sa demande D-Bus, sans attendre le titre ou le contenu.
Sway conserve le suivi IPC après création : placement fonctionnel identique, sans garantie avant le premier rendu.
Le contenu ouvert est placé sur `Outputs.primary` et affiché, même avec un lecteur déjà ouvert. Une fenêtre de destination
est ciblée, les fenêtres manuelles sans requête correspondante ne sont pas déplacées ; aucun renvoi global de workspace.
Aucun chemin ni URI n'est écrit dans les logs ou l'état ; les requêtes et empreintes sont éphémères en mémoire.

`outputs primaryName` expose le nom de sortie détecté/configuré. Pour HTTP/HTTPS, la surcharge utilisateur de `chromium.desktop`
conserve l'identité du navigateur et utilise `browser-link.py` : l'origine est vérifiée auprès du suivi ; pour les trois sources,
réutiliser une fenêtre Chromium centrale, sinon en créer une. Les autres sources et les lancements sans URL restent natifs.
Les web apps conservent leur hôte `open-link` et le focus de la fenêtre qui reçoit leur lien.
