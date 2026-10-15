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

### 3.1 Configuration des sorties → **Kanshi**, pour les deux compositeurs

Existant : positions/modes/échelles en dur par connecteur dans la config Sway et dans `lua/layout.lua` (Hyprland) ;
Kanshi installé mais inutilisé (profil `qtile` obsolète).

Proposition : **Kanshi** gère seul les sorties, avec un profil par ensemble d'écrans, écrans identifiés par
**description** (`"LG Electronics 27GN950 207NTLEFY824"`), jamais par connecteur.

Pourquoi :
- un seul fichier (`dotfiles/kanshi/config`) pour Sway **et** Hyprland (les deux implémentent `wlr-output-management`) ;
- profils conditionnels (« laptop seul », « laptop + externe », « desktop 3 écrans », « desktop sans DP-1 ») que ni Sway
  ni les règles `monitor` de Hyprland ne savent exprimer ;
- Quickshell 0.3.2 n'expose pas `wlr-output-management` : il ne peut pas faire ce travail lui-même.

Conséquences (appliquées en phase 10, pas avant) :
- Sway : plus de lignes `output … pos/mode/scale` (les fonds `output * bg` restent, ou passent par Kanshi) ;
- Hyprland : ne garder qu'un repli générique `monitor = , preferred, auto, 1` ; `hypridle.conf` → `after_sleep_cmd`
  ne doit plus faire `hyprctl reload` (qui remettrait le repli) mais `kanshictl reload` ;
- capot du laptop : `bindswitch --locked lid:on output <interne> disable` (Sway) / `hl.bind("switch:on:Lid Switch", …)`
  (Hyprland), dans la partie « machine » de la config compositeur ; Kanshi et Quickshell voient ensuite l'écran inactif.

Profil de cette machine (reproduit l'existant) :

```
profile desktop {
  output "LG Electronics 27GN950 207NTLEFY824" mode 3840x2160@60Hz position 0,0    scale 1.5
  output "Dell Inc. Dell AW3418DW #ASPFPBQwWjbd" mode 3440x1440@100Hz position 2560,0 scale 1
  output "LG Electronics 27GN950 207NTHMFY841" mode 3840x2160@60Hz position 6000,0 scale 1.5
}
```

(`hdr off` et `render_bit_depth 10` sont des options Sway que Kanshi ne gère pas : elles restent dans la config Sway, par description.)

### 3.2 Répartition des espaces de travail → **service Quickshell `services/Outputs.qml`**

Pourquoi Quickshell plutôt qu'un `exec` de profil Kanshi :
- Quickshell tourne déjà et connaît le compositeur : une seule implémentation pour Sway et Hyprland via `Compositor` ;
- il réagit à **tout** changement de sorties actives, y compris un ensemble d'écrans sans profil Kanshi, ou un écran
  éteint via `output … disable` / capot ;
- la barre a de toute façon besoin de cette répartition pour n'afficher que les espaces de son écran : un seul
  calcul, une seule source de vérité ;
- aucun profil Kanshi ne contiendra d'`exec` qui touche aux espaces (jamais deux mécanismes en concurrence).

Si Quickshell ne tourne pas, rien n'est perdu : Sway et Hyprland déplacent d'eux-mêmes les espaces d'un écran disparu.

Algorithme :
1. Source de vérité : sorties **actives** du compositeur (`swaymsg -t get_outputs` → `active: true` ; Hyprland : `monitors`, hors `disabled`).
2. Anti-rebond : on recalcule 500 ms après le **dernier** événement de sortie (un branchement en produit plusieurs, et Kanshi reconfigure).
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
    "LG Electronics 27GN950 207NTHMFY841": { "left": ["workspaces", "audio"], "right": ["updates", "network", "clock"] }
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

## 8. Questions ouvertes (décisions à prendre par toi)

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
