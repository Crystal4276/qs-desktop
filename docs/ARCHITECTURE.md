# Architecture — proposition (phase 0, à valider)

Version cible : **Quickshell 0.3.2** (Arch). Les API citées ont été vérifiées dans les `qmltypes` installés
(`/usr/lib/qt6/qml/Quickshell/…`) ; les points encore incertains sont marqués **[à vérifier]** avec la phase où ils le seront.

## 1. Structure

Celle de `CLAUDE.md`, avec un seul ajout :

- `assets/` : images reprises de la config actuelle (logo Arch vert/mantle, 4 icônes du power menu). Aujourd'hui elles sont
  référencées par chemin absolu `/home/crystal/.config/sway/assets/…` depuis le CSS Waybar et le script Rofi ;
  le dépôt doit les embarquer pour être autonome.

## 2. Compositeur

`services/Compositor.qml` (singleton) choisit son backend au démarrage :

| | Sway | Hyprland |
|---|---|---|
| Détection | `SWAYSOCK` | `HYPRLAND_INSTANCE_SIGNATURE` |
| Module | `Quickshell.I3` (`I3.workspaces`, `I3.monitors`, `I3.focusedWorkspace`, `I3.dispatch()`, `I3IpcListener`) | `Quickshell.Hyprland` (`Hyprland.workspaces`, `.monitors`, `.focusedWorkspace`, `.activeToplevel`, `.dispatch()`, `.usingLua`) |

Interface exposée, identique pour les deux : `workspaces` (num, nom, écran, focalisé, visible, urgent, vide),
`outputs` (nom, description, x, y, taille logique, scale, focalisé), `focusedOutput`, `activeWindowTitle`, `mode`,
et les actions `focusWorkspace(n)`, `assignWorkspace(n, output)`, `moveWorkspace(n, output)`, `exit()`.

Point critique **Hyprland 0.56 en config Lua** : `hyprctl keyword` n'existe plus et `dispatch` attend une expression Lua
(`hl.dsp.focus({ workspace = 4 })`, `hl.dsp.workspace.move({ workspace = N, monitor = "DP-2" })`). Les commandes
`hyprctl keyword workspace …` / `moveworkspacetomonitor` prévues par `CLAUDE.md` ne fonctionneront donc pas telles quelles.
Quickshell 0.3.2 expose `Hyprland.usingLua` : le backend Hyprland générera la syntaxe Lua quand il est vrai, l'ancienne sinon.
L'attribution persistante d'un espace à un écran passera par `hyprctl eval 'hl.workspace_rule({…})'` **[à vérifier en phase 9]**.

`Quickshell.I3` n'expose ni le titre de la fenêtre active ni le mode : ils viendront d'un `I3IpcListener`
(abonnements `window` et `mode`) dans le backend Sway.

## 3. Écrans dynamiques

Deux problèmes séparés, deux mécanismes séparés, **un seul** par problème.

### 3.1 Configuration des sorties → **le compositeur lui-même**, écrans identifiés par description

*Révisé le 2026-10-15 : la proposition initiale (Kanshi) est abandonnée, voir « Pourquoi pas Kanshi ».*

Existant : positions/modes/échelles/HDR en dur par **connecteur** dans la config Sway et dans `lua/layout.lua` (Hyprland) ;
Kanshi installé mais inutilisé.

Proposition : chaque compositeur configure ses sorties **nativement**, avec des règles par **description** d'écran,
jamais par connecteur. Ces règles s'appliquent automatiquement à chaque connexion de l'écran concerné.

| | Sway 1.12 | Hyprland 0.56 (Lua) |
|---|---|---|
| Identification | `output "LG Electronics 27GN950 207NTLEFY824" …` (make model serial, `man 5 sway-output`) | `hl.monitor({ output = "desc:…", … })` **[syntaxe `desc:` en Lua à vérifier en phase 9]** |
| Mode, position, échelle | `mode`, `pos`, `scale` | `mode`, `position`, `scale` |
| HDR, profondeur | `hdr on/off/toggle`, `render_bit_depth 10` | `cm` (ex. `"hdr"`), `bitdepth` |
| VRR (G-Sync) | `adaptive_sync on/off/toggle` | `vrr` |
| Désactiver | `disable` | `disabled = true` |
| Écran inconnu | placé automatiquement à droite, mode préféré | règle de repli `output = ""`, `mode = "preferred"`, `position = "auto"` |
| Capot du laptop | `bindswitch --locked lid:on output <desc. interne> disable` / `lid:off … enable` | `hl.bind("switch:on:Lid Switch", …)` → `hl.monitor({ …, disabled = true })` |

Ces règles vivent dans la partie « machine » des configs compositeur (`dotfiles/sway/hosts/<hostname>.conf`,
`dotfiles/hypr/hosts/<hostname>.lua`, phase 10). Le reste de la config compositeur est commun à toutes les machines.

Pourquoi pas Kanshi :
- **Kanshi ne gère pas le HDR ni la profondeur de couleur** (le protocole `wlr-output-management` ne les transporte pas). On aurait
  donc **deux sources pour le même écran** : Kanshi pour mode/position, le compositeur pour le HDR. C'est exactement le risque de contradiction
  à éviter, d'autant que Sway 1.12 gère maintenant le HDR lui-même.
- Sous Hyprland, `hyprctl reload` (appelé par `hypridle` au réveil) réapplique les règles `monitor` et écraserait la configuration de Kanshi.
- Un démon de moins.
- Ce que Kanshi apporte en plus (des **profils conditionnels** : le même écran placé différemment selon les autres écrans présents)
  ne correspond à aucun besoin actuel. Desktop, laptop seul, laptop + écran externe et capot fermé se règlent tous avec des règles fixes par écran.
  Si un jour ce besoin apparaît (plusieurs docks avec des dispositions différentes), on réévaluera : noté dans `BACKLOG.md`.

Prix à payer : les réglages d'écran d'une machine sont écrits deux fois, une fois par compositeur (3 lignes chacun ici).
Les deux fichiers sont côte à côte dans le dépôt.

Règles de cette machine (reproduisent l'existant, par description) :

```
# Sway
output "LG Electronics 27GN950 207NTLEFY824"   mode 3840x2160@60Hz  pos 0 0    scale 1.5 hdr off render_bit_depth 10
output "Dell Inc. Dell AW3418DW #ASPFPBQwWjbd" mode 3440x1440@100Hz pos 2560 0 scale 1
output "LG Electronics 27GN950 207NTHMFY841"   mode 3840x2160@60Hz  pos 6000 0 scale 1.5 hdr off render_bit_depth 10
```

Le raccourci HDR (`$mod+d`) visera aussi les écrans par description (`output "LG …824" hdr toggle`).

Les espaces de travail (§ 3.2) ne dépendent pas de ce choix : ils suivent la liste des écrans **actifs**, quelle que soit la façon dont ils ont été configurés.

### 3.2 Répartition des espaces de travail → **service Quickshell `services/Outputs.qml`**

Pourquoi Quickshell :
- Quickshell tourne déjà et connaît le compositeur : une seule implémentation pour Sway et Hyprland via `Compositor` ;
- il réagit à **tout** changement de sorties actives, y compris un écran éteint via `output … disable` ou le capot ;
- la barre a de toute façon besoin de cette répartition pour n'afficher que les espaces de son écran : un seul
  calcul, une seule source de vérité ;
- les configs compositeur ne contiendront plus aucune ligne `workspace N output …` (jamais deux mécanismes en concurrence).

Si Quickshell ne tourne pas, rien n'est perdu : Sway et Hyprland déplacent d'eux-mêmes les espaces d'un écran disparu.

Algorithme :
1. Source de vérité : sorties **actives** du compositeur (`swaymsg -t get_outputs` → `active: true` ; Hyprland : `monitors`, hors `disabled`).
2. Anti-rebond : on recalcule 500 ms après le **dernier** événement de sortie (un branchement en produit plusieurs, le temps que le compositeur applique ses règles d'écran).
3. Si la config machine a une répartition imposée pour exactement cet ensemble de descriptions → on l'applique.
4. Sinon, règle générale (§ 3.3).
5. Application : attribution (`workspace N output X` sous Sway ; règle d'espace sous Hyprland) puis déplacement des espaces
   existants mal placés ; l'espace focalisé avant le changement est refocalisé s'il existe toujours.

### 3.3 Règle générale — **à valider**

Constat : l'attribution actuelle n'est **pas** « gauche → droite » : 1-3 sont sur l'écran **central** (DP-2), 4-6 à gauche, 7-9 à droite.
Une règle purement gauche → droite donnerait 1-3 à gauche et ne reproduirait pas l'existant sans exception.

Proposition :
- ordre des écrans : **écran principal d'abord**, puis les autres de gauche à droite (x, puis y) ;
- écran principal : celui désigné par la config machine, sinon le plus grand en surface logique (égalité → le plus à gauche) ;
- tailles des blocs : `floor(9 / n)` chacun, le reste (+1) donné aux premiers écrans dans l'ordre ci-dessus ;
- blocs contigus dans cet ordre.

| Écrans | Résultat |
|---|---|
| 1 | 1-9 |
| 2 | principal 1-5, autre 6-9 |
| 3 | principal 1-3, gauche 4-6, droite 7-9 → **identique à l'existant sans exception** (DP-2 est aussi le plus grand) |
| 4 | principal 1-3, puis 4-5, 6-7, 8-9 de gauche à droite |
| 5 | 1-2, 3-4, 5-6, 7-8, 9 |

Avantage : la machine actuelle tombe juste sans répartition imposée ; la config machine peut tout de même la fixer.

### 3.4 Tests

`scripts/test-outputs.sh` (phase 3) : écrans `HEADLESS-N` (`swaymsg create_output` / `hyprctl output create headless`),
désactivation, vérification via `get_workspaces` / `hyprctl workspaces -j`, `trap` de remise en état
(retrait des écrans virtuels + réattribution initiale enregistrée au début).

## 4. Config par machine

- Fichiers `hosts/<hostname>.json` et `hosts/default.json`. Hostname lu dans `/proc/sys/kernel/hostname`
  (la commande `hostname` n'est même pas installée ici).
- `config/Settings.qml` charge `default.json` puis superpose le fichier de la machine (s'il existe).
- Tout ce qui se détecte n'y figure pas : batterie (`UPower`, type batterie — attention, cette machine expose une
  alimentation USB-C `ucsi-source-psy` qui n'est pas une batterie), rétroéclairage (`/sys/class/backlight`), GPU Nvidia
  (`nvidia-smi` présent), interface réseau (route par défaut), `checkupdates` présent.

Format proposé :

```json
{
  "primaryOutput": "Dell Inc. Dell AW3418DW #ASPFPBQwWjbd",
  "workspaceLayouts": [
    {
      "Dell Inc. Dell AW3418DW #ASPFPBQwWjbd": [1, 2, 3],
      "LG Electronics 27GN950 207NTLEFY824": [4, 5, 6],
      "LG Electronics 27GN950 207NTHMFY841": [7, 8, 9]
    }
  ],
  "bars": {
    "primary":   { "left": ["menu", "workspaces", "media", "audio"], "right": ["updates", "system", "clock", "tray"] },
    "secondary": { "left": ["workspaces", "audio"], "right": ["system", "clock"] },
    "LG Electronics 27GN950 207NTHMFY841": { "left": ["workspaces", "audio"], "right": ["network", "clock"] }
  },
  "notificationsOutput": "primary",
  "terminal": "gnome-terminal",
  "updateCommand": "paru -Syu"
}
```

- `bars` : par description d'écran, sinon par rôle (`primary` / `secondary`) — un écran inconnu reçoit donc toujours une barre.
- `default.json` : pas d'écran principal imposé, aucune répartition imposée, barre `primary` complète, `secondary` minimale.
- Les noms (`system` = nvidia + cpu + memory, `media` = mpris + cava, `audio` = volume + curseur…) correspondent aux pilules de `THEME.md` § 3.
- Les icônes d'espaces de travail font partie de la charte → `Theme.qml`, pas de la config machine.

## 5. Thème

- La palette est **statique** (Catppuccin Mocha recopiée à la main dans 4 fichiers, aucun générateur) → `Theme.qml` la porte en dur.
- Les couleurs propres à Rofi (`#1E1D2F`, `#D9E0EE`, `#FAE3B0`…) sont gardées sous leurs propres noms pour le lanceur et le power menu.
- Thème d'icônes Qt : `//@ pragma IconTheme Papirus-Dark` dans `shell.qml` (pragma présent dans le binaire 0.3.2) **[à vérifier en phase 1]**.

## 6. Services (aperçu)

| Service | Source | Externe ? |
|---|---|---|
| `Compositor` | `Quickshell.I3` / `Quickshell.Hyprland` | non |
| `Outputs` | `Compositor` + `Settings` | non |
| `Audio` | `Quickshell.Services.Pipewire` | non (`pavucontrol` lancé au clic) |
| `Media` | `Quickshell.Services.Mpris` | non |
| `Cava` | `cava` en sortie brute (`Process`) | **oui** — pas d'équivalent natif |
| `SystemStats` | `/proc/stat`, `/proc/meminfo` via `FileView` | non |
| `Gpu` | `nvidia-smi` (`Process`) | **oui** — masqué si absent |
| `Network` | `/proc/net/dev` + `/proc/net/route` via `FileView` (débit) | non |
| `Updates` | `checkupdates` (`Process`) | **oui** — masqué si absent |
| `Notifs` | `Quickshell.Services.Notifications` | non |
| `Battery` | `Quickshell.Services.UPower` | non |
| `Brightness` | `/sys/class/backlight` + `brightnessctl` pour écrire | **oui** (écriture) |
| Tray | `Quickshell.Services.SystemTray` | non |

Les widgets ne lisent que ces services ; aucun `Process` dans l'UI.

## 7. Menus et scripts `rofi -dmenu`

Un seul script utilise `rofi -dmenu` : le **power menu**. Il est réécrit en QML (`modules/menus/PowerMenu.qml`), pas de remplaçant
dmenu générique (aucun autre usage ; `dmenu` de Dunst n'est ni installé ni utilisé).
Logout adapté au compositeur. Confirmation : aucune aujourd'hui → aucune (parité).

## 8. Décisions (2026-10-15)

| # | Décision |
|---|---|
| Q1 | Règle « principal d'abord, puis gauche → droite, reste sur les premiers » **validée**. |
| Q2 | Kanshi validé sous condition HDR / VRR, puis **remplacé** par la configuration native des compositeurs (Kanshi ne gère pas le HDR) — voir § 3.1 et § 8.1. |
| Q3 | Phase 4 : nwg-menu gardé, lancé par le bouton QML (parité). **À terme : nouveau menu entièrement refait en QML, sur le modèle du menu de Cinnamon** (Cinnamon n'est pas installé : il faudra une capture de référence). Inscrit dans `BACKLOG.md`. |
| Q4 | Parité : ni titre de fenêtre ni mode dans la barre (le service les expose quand même ; idée en `BACKLOG.md`). |
| Q5 | `custom/logout`, `custom/reboot`, `custom/power` ignorés. |
| Q6 | Scripts morts abandonnés. |
| Q8 | Dunst sera **désinstallé** au moment de la bascule (phase 10). |

### 8.1 HDR et VRR (G-Sync)

Vérifié dans `man 5 kanshi` (kanshi 1.9) :
- **VRR** : oui, `adaptive_sync on|off` par sortie dans un profil Kanshi.
- **HDR** : **non**. Le protocole utilisé par Kanshi (`wlr-output-management`) ne transporte ni le HDR ni la profondeur de couleur.

Conséquence : avec Kanshi, le HDR aurait dû rester dans le compositeur, soit deux sources de configuration pour le même écran.
Comme Sway 1.12 et Hyprland 0.56 gèrent nativement mode, position, échelle, HDR, profondeur de couleur et VRR, **tout** passe par le compositeur
(§ 3.1) : une seule source par compositeur, pas de contradiction possible. Kanshi est retiré de `deps/`.

VRR : aujourd'hui **désactivé** (ligne `output * adaptive_sync on` commentée dans la config Sway). Il reste désactivé ; l'activer revient à
ajouter `adaptive_sync on` (Sway) ou `vrr = 1` (Hyprland) à la règle de l'écran. Le fonctionnement réel avec le pilote Nvidia
(G-Sync natif du Dell, « G-Sync Compatible » des LG) sera testé en phase 3.

### 8.2 Polices embarquées

Décision : `Symbols Nerd Font Mono` (2,5 Mo, licence MIT, non empaquetée sur Fedora/Debian) est **versionnée dans le dépôt**
(`assets/fonts/SymbolsNerdFontMono-Regular.ttf` + sa licence), et `install.sh` la copie dans `~/.local/share/fonts` sur toutes les distributions.
Inter, DejaVu Sans et Noto Sans Mono restent des paquets (`deps/`). `install.sh` vérifie avec `fc-list` que chaque police de `THEME.md`
est présente et s'arrête sinon. L'ajout du fichier se fait en phase 1, avec `Theme.qml`.

### 8.3 Calendrier

Décision : le tooltip calendrier de l'horloge devient une **fenêtre Quickshell** (popup soignée, aux couleurs de la charte), en phase 4.
C'est une évolution assumée de la parité : même contenu (mois en cours, aujourd'hui mis en évidence), présentation plus riche.
Ouverture : au clic sur l'horloge **[le survol ou le clic : à trancher en phase 4]**.

Événements Thunderbird : faisable, mais **après la parité** (`BACKLOG.md`). Constat (types seulement, aucun contenu lu) : le profil Thunderbird
a 6 calendriers — 3 CalDAV, 2 Owl (Exchange / Microsoft 365), 1 local. Thunderbird garde une copie locale des calendriers distants dans
`calendar-data/cache.sqlite` (et le local dans `local.sqlite`), lisibles en lecture seule avec `sqlite3`. Difficultés à prévoir :
lire la base sans gêner Thunderbird (WAL actif ; lecture `immutable` ou copie), dépliage des événements récurrents, fuseaux horaires,
et vérifier que les calendriers Owl sont bien dans ce cache. Alternative plus propre pour les CalDAV : interroger directement le serveur
— mais pas pour Owl/Exchange.

## 9. Questions d'origine (archivées)

- **Q1 — Règle de répartition** (§ 3.3) : « principal d'abord, puis gauche → droite, reste sur les premiers » te convient-elle pour 2 et 4+ écrans ?
- **Q2 — Kanshi** (§ 3.1) : d'accord pour que Kanshi devienne l'unique gestionnaire des sorties (Sway et Hyprland), à partir de la phase 3 pour les tests et de la phase 10 pour la bascule ?
- **Q3 — nwg-menu** (bouton Arch) : (a) le garder, lancé par le bouton QML (parité immédiate, une dépendance de plus) ;
  ou (b) le réécrire en QML (catégories, favoris, dossiers, boutons session) — plus long. Recommandation : **(a)** maintenant, (b) dans `BACKLOG.md`.
- **Q4 — Phase 2** : `CLAUDE.md` prévoit titre de fenêtre et mode Sway, mais **ta Waybar n'affiche ni l'un ni l'autre** (et la config Sway n'a aucun `mode`).
  Les ajouter (où, avec quel style ?) ou s'en tenir à la parité (service prêt, pas de widget) ? Recommandation : parité, idée en BACKLOG.
- **Q5 — Modules fantômes** : `custom/logout`, `custom/reboot`, `custom/power` sont listés sur DP-1 mais pas définis (invisibles). On les ignore ?
- **Q6 — Scripts morts** (`SCRIPTS.md`) : d'accord pour tous les marquer « abandonnés » (ils restent dans `~/.config`, simplement pas repris) ?
- **Q7 — Secrets** : jeton NordVPN en clair dans `sway/config`, `hyprland.conf` et `autostart/nordvpn.desktop`. Rien ne sera versionné avec ;
  tu voudras peut-être le révoquer, puisque `~/.config/sway` et `~/.config/hypr` sont des dépôts git.
- **Q8 — Dunst en phase 10** : Dunst est activé par D-Bus ; si Quickshell n'a pas encore pris le nom, D-Bus relancera Dunst. Il faudra
  désactiver son activation (`systemctl --user mask dunst`) au moment de la bascule — je demanderai à ce moment-là.
