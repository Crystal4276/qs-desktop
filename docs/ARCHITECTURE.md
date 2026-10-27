# Architecture — proposition (phase 0, à valider)

Version cible : **Quickshell 0.3.2** (Arch). Les API citées ont été vérifiées dans les `qmltypes` installés
(`/usr/lib/qt6/qml/Quickshell/…`) ; les points encore incertains sont marqués **[à vérifier]** avec la phase où ils le seront.

## 1. Structure

Celle de `CLAUDE.md`, avec trois ajouts :

- `assets/` : images reprises de la config actuelle (logo Arch vert/mantle, 4 icônes du power menu). Aujourd'hui elles sont
  référencées par chemin absolu `/home/crystal/.config/sway/assets/…` depuis le CSS Waybar et le script Rofi ;
  le dépôt doit les embarquer pour être autonome.
- `dotfiles/wireplumber/` *(2026-10-27)* : règle WirePlumber dont dépend la coupure des sons pendant « ne pas déranger »
  (§ 4, `doNotDisturb`) ; liée dans `~/.config/wireplumber/` par `install.sh`.
- `dotfiles/webapps/` *(2026-10-27)* : extension Chromium `open-links/` et son hôte natif `open-link`, chargés par les web apps
  (WhatsApp, Discord, Word, Excel, PowerPoint, Notion : `chromium --app … --user-data-dir=<profil isolé>
  --load-extension=…/open-links`). Un lien ouvert dans un nouvel onglet ou une nouvelle fenêtre part dans le profil Chromium
  principal, sauf s'il reste dans les domaines de l'app (Microsoft 365, Notion : liste `SITES` de l'extension) (onglet ajouté, navigateur démarré s'il ne tourne
  pas) ; les popups (connexion OAuth) restent dans la web app. Modèles des lanceurs (`applications/`) et du manifeste de l'hôte
  (`qs_desktop.open_link.json`), développés par `install.sh` (phase 11 ; procédure : `deps/README.md`, « Web apps »).

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

Algorithme (implémenté et testé en phase 3, Sway) :
1. Source de vérité : sorties **actives** du compositeur (`swaymsg -t get_outputs` → `active: true` ; Hyprland : `monitors`, hors `disabled`).
2. Anti-rebond : on recalcule 500 ms après le **dernier** changement d'écrans ou de répartition (config machine modifiée).
3. Si la config machine a une répartition imposée pour exactement cet ensemble de descriptions → on l'applique.
4. Sinon, règle générale (§ 3.3).
5. Application, en **une seule commande** au compositeur : chaque espace existant mal placé rejoint l'écran de son bloc ;
   chaque écran affiche ensuite, parmi les candidats qui y sont chez eux (recréés s'ils étaient vides) :
   l'espace que l'utilisateur y a choisi depuis le dernier placement ; sinon la vue de cette configuration d'écrans si elle a déjà
   existé (un écran éteint puis rallumé retrouve exactement la vue d'avant) ; sinon celle d'avant le changement ;
   sinon le premier espace existant de son bloc, sinon le premier de son bloc. Enfin, l'espace focalisé **avant** le changement
   est refocalisé (le compositeur déplace le focus dès qu'un écran focalisé disparaît, avant Quickshell).
   Mémoire : vue par configuration (`layoutKey`), relevée 300 ms après chaque changement d'espaces et à chaque placement.
6. **Espace créé hors de son écran** (ex. `$mod+3` depuis l'écran de gauche, ou fenêtre envoyée vers un espace inexistant) :
   100 ms plus tard (focus à jour), il est déplacé sur son écran ; focalisé, il le reste, et son écran de départ reprend l'espace
   qu'il affichait (recréé si Sway l'a détruit parce qu'il était vide) ; créé en arrière-plan, le focus revient où il était.
   **Bouche-trou** : un écran vidé de son seul espace en reçoit un de Sway, au premier numéro libre. Il n'est pas déplacé (Sway en
   recréerait un, sans fin : boucle constatée le 2026-10-26) ; l'écran affiche à la place le premier espace de son bloc qui n'est
   pas ailleurs, et le bouche-trou, masqué et vide, disparaît. Une correction ne crée donc que des espaces chez eux : pas de boucle.
7. Un espace déplacé à la main reste où il est jusqu'au prochain changement d'écrans.

**Aucune attribution `workspace N output X`** (contrairement à ce que prévoyait `CLAUDE.md`) — vérifié sur Sway 1.12 : la **première**
attribution d'un espace l'emporte ; les commandes suivantes ne la remplacent pas. Une attribution envoyée pour 3 écrans
ne pourrait donc plus être corrigée pour 4. La création au bon endroit est assurée par l'étape 6 ; en phase 10, les raccourcis
`$mod+N` passeront par `qs ipc` et focaliseront directement le bon écran (`focus output X; workspace number N`), sans détour visible.

Les commandes envoyées sont écrites dans le journal (`Compositor: placement des espaces : …`).
Hyprland *(écrit le 2026-10-16, d'après le code source d'Hyprland 0.56.2 ; à tester dans une session Hyprland)* :
- placement en **une seule requête** : `hyprctl dispatch X` exécute `hl.dispatch(X)`, qui accepte une fonction Lua ; `Compositor` envoie
  `function() hl.dispatch(hl.dsp.workspace.move({ workspace = N, monitor = "X" })) … hl.dispatch(hl.dsp.focus({ monitor = "X" }))
  hl.dispatch(hl.dsp.focus({ workspace = N })) … end` (même séquence que sous Sway ; Lua vérifié avec `luac` et exécuté avec un faux `hl`) ;
- espace focalisé déplacé : `hl.dsp.workspace.move({ monitor = "X" })` ; création d'espace : événement `createworkspacev2` ;
- config Hyprland non-Lua : placement non pris en charge (avertissement) — seule la config Lua est utilisée ;
- tant que la config actuelle (`lua/workspaces.lua`) attache les espaces aux écrans par des règles `persistent`, elles peuvent contrarier
  le placement : elles disparaissent à la bascule (phase 10), comme les lignes `workspace N output` de Sway.

### 3.3 Règle générale — validée (Q1)

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

`scripts/test-outputs.sh` (phase 3) tourne dans une **session Sway isolée** (backend headless, `WLR_BACKENDS=headless`, sans `sudo`),
avec sa propre instance Quickshell : la session de travail n'est jamais touchée (ni écrans, ni fenêtres, ni focus).
La session de test reproduit les trois écrans du bureau (4K × 1.5 / 3440x1440 / 4K × 1.5) et ouvre des fenêtres `zenity`
sur les espaces 1, 2, 4–9. Scénarios : ajout de 1 puis 2 écrans, création d'un espace depuis un autre écran, désactivation /
réactivation, débranchement, écran de droite puis de gauche éteints (2 écrans, puis 1), retour à la référence, fenêtre seule
envoyée vers un espace inexistant, espace créé depuis un écran qui affichait un espace vide, seul espace d'un écran déplacé à la
main (bouche-trou), écran principal et focalisé éteint puis rallumé.
Contrôles après chacun : répartition calculée = règle recalculée indépendamment (jq), espaces sur le bon écran, focus inchangé,
espace visible conservé ; à la fin, aucune fenêtre perdue, et nombre de commandes de placement borné (pas de boucle).

Pièges relevés :
- `swaymsg` et `Quickshell.I3` lisent **`I3SOCK` avant `SWAYSOCK`** : les deux doivent viser la session de test (garde-fou dans le script) ;
- un test lancé dans la vraie session déplace les espaces de l'utilisateur et se fait fausser par son activité : à proscrire ;
- les écrans virtuels portent tous la description « Unknown Unknown Unknown » : la répartition **imposée** par description se teste
  avec les écrans réels (fait une fois en phase 3, réussi) ;
- un écran virtuel créé pendant que swayidle a éteint les écrans hérite de `power off` ;
- l'état de Quickshell 0.3.2 (`Quickshell.I3`) se périme : l'espace affiché par un écran (`active`) n'est mis à jour que par un
  événement « focus » ou une relecture des sorties, jamais par un déplacement d'espace ; le focus ne suit que les événements
  « focus », dont Sway envoie parfois un faux (seul espace d'un écran déplacé : focus annoncé sur le bouche-trou) et dont le
  champ `focused` est souvent faux. `Compositor` relit donc `get_workspaces` après chaque événement d'espace et lit focus et
  visibilité dans l'objet IPC de chaque espace (`focused`, `visible`), pas dans l'état de Quickshell (code de Quickshell lu,
  comportement de Sway vérifié dans le banc). Sorties : seules celles que `get_outputs` dit `active: true`.

## 4. Config par machine

- Fichiers `hosts/<hostname>.json` et `hosts/default.json`. Hostname lu dans `/proc/sys/kernel/hostname`
  (la commande `hostname` n'est même pas installée ici).
- `config/Settings.qml` charge `default.json` puis superpose le fichier de la machine (s'il existe).
- Tout ce qui se détecte n'y figure pas : batterie (`UPower`, type batterie — attention, cette machine expose une
  alimentation USB-C `ucsi-source-psy` qui n'est pas une batterie), rétroéclairage (`/sys/class/backlight`), GPU Nvidia
  (`nvidia-smi` présent), interface réseau (route par défaut), `checkupdates` présent.

Format (implémenté en phase 1, `hosts/default.json`, `hosts/terrier.json`) :

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
    "primary": {
      "left":  [["menu"], ["workspaces"], ["mpris", "volume", "slider"]],
      "right": [["updates"], ["gpu", "cpu", "memory"], ["clockDate"], ["tray", "settings"]]
    },
    "secondary": { "left": [["workspaces"], ["volume", "slider"]], "right": [["gpu", "cpu", "memory"], ["clock"]] },
    "LG Electronics 27GN950 207NTHMFY841": { "left": [["workspaces"], ["volume", "slider"]], "right": [["network"], ["clock"]] }
  },
  "notificationsOutput": "primary",
  "terminal": ["gnome-terminal", "--wait", "--"],
  "mediaPlayer": "spotify",
  "updateCommand": "paru -Syu"
}
```

- `terminal` *(phase 4)* : préfixe qui lance une commande dans un terminal **et attend sa fin** (le module mises à jour recompte à la fermeture) ;
  une liste, car chaque terminal a sa syntaxe (`foot`, `kitty` : pas de `--`).
- `mediaPlayer` *(phase 4)* : lecteur préféré du module mpris, nom D-Bus après `org.mpris.MediaPlayer2.` (option `player` de Waybar) :
  suivi s'il joue ; sinon un lecteur qui joue ; sinon lui (choix du 2026-10-16, `services/Media.qml`).
- `updateCommand` *(phase 4)* : commande de mise à jour du module mises à jour ; absente (`default.json`) : `paru`, sinon `yay`, sinon
  `sudo pacman -Syu` (revue de code : `paru` n'est pas forcément installé sur une nouvelle machine).
- `nightLight` *(phase 8)* : veilleuse, `{ "from": "20:00", "to": "06:00", "temperature": 3239 }` (`default.json` : tes réglages GNOME).
- `doNotDisturb` *(2026-10-26)* : horaire de départ du « ne pas déranger », `{ "schedule": true, "from": "21:00", "to": "07:00" }` ;
  ensuite réglé depuis le panneau de réglages (fichier d'état `do-not-disturb.json`). `muteApps` *(2026-10-27)* : applications qui
  jouent elles-mêmes le son de leurs notifications, coupées pendant « ne pas déranger » (`services/Audio.qml`), par
  `application.id` du flux (web apps : donné dans leur lanceur, `env PULSE_PROP_OVERRIDE=application.id=whatsapp chromium …`) ou
  par binaire (application Discord) ; vide par défaut, `["discord", "whatsapp"]` dans `hosts/terrier.json`. Le navigateur et les
  appels de l'application Discord gardent le son ; un flux rétabli à la main reste audible. Va avec
  `dotfiles/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf` (WirePlumber ne retient ni volume ni coupure de ces flux, qui
  resteraient coupés le lendemain), copié dans `~/.config/wireplumber/` le 2026-10-27 ; lien posé par `install.sh` (phase 11).

- Fusion **au premier niveau** : une clé du fichier machine remplace entièrement celle de `default.json` (pas de fusion profonde : plus prévisible).
- `bars` : l'écran principal reçoit `primary` ; les autres, par description d'écran, sinon `secondary` — un écran inconnu reçoit
  donc toujours une barre, et un écran qui a sa propre entrée mais devient principal (les autres éteints) garde tray et réglages.
  Chaque côté est une liste de **pilules**, chaque pilule une liste de modules (`THEME.md` § 3, « Groupes de pilules ») :
  la config décrit directement les groupes Waybar, sans noms de groupes intermédiaires.
- Modules : `menu`, `workspaces`, `mpris`, `volume`, `slider`, `updates`, `gpu`, `cpu`, `memory`, `clock` (heure seule),
  `clockDate` (heure + date, barre principale), `network`, `tray`, `settings` (engrenage, ex-`power`), `battery`, `backlight` (laptop).
  Un module dont la donnée ou le matériel manque se masque ; une pilule dont tous les modules sont masqués disparaît.
- `default.json` : pas d'écran principal imposé, aucune répartition imposée, barre `primary` complète, `secondary` minimale.
- La description d'un écran est « marque modèle numéro de série », recomposée depuis `make`, `model`, `serial` sous les deux compositeurs
  (`swaymsg -t get_outputs`, `hyprctl monitors`) : les mêmes clés valent pour Sway et Hyprland.
- Les icônes d'espaces de travail font partie de la charte → `Theme.qml`, pas de la config machine.
- Le fichier machine est relu à chaud (`FileView.watchChanges`) : la barre change sans redémarrer Quickshell (vérifié en phase 1).

## 5. Thème

- La palette est **statique** (Catppuccin Mocha recopiée à la main dans 4 fichiers, aucun générateur) → `Theme.qml` la porte en dur.
- Les couleurs propres à Rofi (`#1E1D2F`, `#D9E0EE`, `#FAE3B0`…) sont gardées sous leurs propres noms pour le lanceur et le power menu.
- Thème d'icônes Qt : `//@ pragma IconTheme Papirus-Dark` dans `shell.qml` — **vérifié en phase 1** (rendu réel comparé avec et sans le pragma, § 11.1).
- `//@ pragma ShellId desktop` : la config est lancée tantôt depuis le dépôt (`qs -p .`), tantôt via `~/.config/quickshell/desktop` ;
  un identifiant fixe garantit que `qs ipc` et les dossiers d'état visent la même instance dans les deux cas (doc Quickshell, « Advanced Options »).
- Imports : modules Quickshell `qs.config`, `qs.services`, `qs.modules.bar` (dossiers du dépôt), sans `qmldir` écrit à la main.

## 6. Services (aperçu)

| Service | Source | Externe ? |
|---|---|---|
| `Compositor` | `Quickshell.I3` / `Quickshell.Hyprland` | non |
| `Outputs` | `Compositor` + `Settings` | non |
| `Audio` | `Quickshell.Services.Pipewire` | non (`pavucontrol` lancé au clic) |
| `Media` | `Quickshell.Services.Mpris` | non |
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

Un seul script utilise `rofi -dmenu` : le **power menu**. Il n'est pas réécrit tel quel : ses actions passent dans le **panneau de
réglages** façon GNOME (§ 10.1.4, ta décision du 2026-10-16). Pas de remplaçant dmenu générique (aucun autre usage ; `dmenu` de Dunst
n'est ni installé ni utilisé). Logout adapté au compositeur. Confirmation : aucune aujourd'hui → aucune (parité, confirmé).

## 8. Décisions (2026-10-15)

| # | Décision |
|---|---|
| Q1 | Règle « principal d'abord, puis gauche → droite, reste sur les premiers » **validée**. |
| Q2 | Kanshi validé sous condition HDR / VRR, puis **remplacé** par la configuration native des compositeurs (Kanshi ne gère pas le HDR) — voir § 3.1 et § 8.1. |
| Q3 | **nwg-menu est remplacé par un menu maison en QML, sur le modèle du menu de Cinnamon, dans le cadre du projet (phase 8).** État final : aucune dépendance à nwg-menu. D'ici là, le bouton Arch de la barre QML existe (apparence, survol) mais n'ouvre rien ; Waybar reste le bureau réel jusqu'à la bascule. Cinnamon n'est pas installé : il faudra une capture de référence de son menu au début de la phase 8. Style : charte de `THEME.md` (§ 7 reprend le style actuel de nwg-menu). |
| Q4 | Parité : ni titre de fenêtre ni mode dans la barre (le service les expose quand même ; idée en `BACKLOG.md`). |
| Q5 | `custom/logout`, `custom/reboot`, `custom/power` ignorés. |
| Q6 | Scripts morts abandonnés. |
| Q8 | Dunst sera **désinstallé** au moment de la bascule (phase 10). |
| Pilule tray + power | Sous Waybar, le bouton power collé au tray dans une même pilule est une astuce CSS. Le résultat visuel est à garder (une seule pilule `["tray", "power"]`), pas la technique : en QML, c'est simplement une pilule qui contient les deux modules. Le power menu pourra devenir un **panneau de réglages rapides façon GNOME** (`BACKLOG.md`), à discuter au début de la phase 8. |

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
Inter et Noto Sans Mono restent des paquets (`deps/`). `install.sh` vérifie avec `fc-list` que chaque police de `THEME.md`
est présente et s'arrête sinon. L'ajout du fichier se fait en phase 1, avec `Theme.qml`.

**Complété en phase 2** (parité exacte, choisie le 2026-10-15) : les icônes des modules texte viennent en réalité de polices de repli
(`THEME.md` § 2). Sont aussi versionnées, même traitement : `HackNerdFont-Regular.ttf` (MIT + Bitstream Vera),
`FontAwesome7Free-Regular-400.otf` et `FontAwesome7Brands-Regular-400.otf` (SIL OFL 1.1), `FontAwesome4-Regular.ttf` (Font Awesome 4.7, SIL OFL 1.1).
Inventaire et licences : `assets/fonts/README.md`. Total 5,7 Mo.

### 8.3 Calendrier

Décision : le tooltip calendrier de l'horloge devient une **fenêtre Quickshell** (popup soignée, aux couleurs de la charte), en phase 4.
C'est une évolution assumée de la parité : même contenu (mois en cours, aujourd'hui mis en évidence), présentation plus riche.
Ouverture — **tranché le 2026-10-16 : survol + clic**. Le survol montre le mois en cours et se ferme quand le pointeur quitte l'horloge ;
un clic l'épingle (navigation : flèches, molette, clavier ←/→ ; clic sur le titre : mois en cours). Fermeture de l'épinglé (ta demande) :
Échap ; clic n'importe où ailleurs, **qui atteint aussi ce qui est dessous** (fenêtre, module) ; pointeur hors du calendrier et de l'horloge pendant 2 s (aussi quand le survol d'une fenêtre la
focalise : `focus_follows_mouse` ; le calendrier se fermait sinon dès la sortie du pointeur, corrigé le 2026-10-21).

Mise en œuvre (Sway 1.12, code source lu) :
- le calendrier est un `PopupWindow` attaché à l'horloge, sans `grabFocus` (Sway ne ferme pas un tel popup au clic extérieur et il bloque le clic sur l'horloge) ;
- pendant le survol de l'horloge, sa barre accepte le clavier « à la demande » ; le clic qui épingle lui donne donc le focus (Échap, ←/→).
  Un clic sur une fenêtre le lui reprend → fermeture. Seul un clic donne durablement le focus à une surface « à la demande » :
  Sway le lui retire à chaque réarrangement des couches (`arrange_layers`), d'où l'échec des variantes avec une surface dédiée ;
- un appui sur une barre (n'importe quel écran) ferme le calendrier puis est transmis au module (`BarState.closePopups`, appui non accepté) ;
- un clic dans le calendrier, que Sway traite comme un clic sur l'espace de travail, retire aussi le focus à la barre : il ne ferme pas ;
  ensuite, c'est l'événement IPC « une fenêtre reçoit le focus » (`Compositor.windowFocused`, filtré sur `focused` : Sway l'envoie aussi à tort
  lors d'un clic sur un popup) qui ferme au clic sur une fenêtre ;
- à la fermeture, la barre repasse sans clavier : Sway rend le focus à la fenêtre qui l'avait.
Limites : après un clic dans le calendrier, Échap ne marche plus (focus perdu) ; la fermeture automatique (2 s) s'en charge.
Clic sur le fond d'écran : `swaybg` déclare une zone d'entrée vide (code lu) ; le clic atteint l'espace de travail, Sway le focalise,
la barre perd le clavier et le calendrier se ferme (vérifié sur DP-2 et DP-1). Seule exception : juste après un clic dans le calendrier,
le focus est déjà sur l'espace de travail et un clic sur le fond ne change rien → la fermeture automatique s'en charge.
**Décidé le 2026-10-16** : pas d'ajout provisoire (une couche au-dessus de `swaybg` a été essayée puis retirée). En **phase 8b**, le fond
d'écran natif pourra recevoir ce clic lui-même : fermer le calendrier (`BarState.closePopups()`) et focaliser l'espace de l'écran, comme
`swaybg` le permet aujourd'hui (WALLPAPERS.md).

**Tooltips** (décision du 2026-10-16) : aucun tooltip dans la barre Quickshell (`INVENTORY.md` § 1).

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

## 10. Seconde passe : décisions à prendre

Issue de `INVENTORY.md` § 10. Objectif rappelé : à terme, le bureau ne dépend que de Quickshell (plus le compositeur et le système).

| # | Sujet | Recommandation | Pourquoi |
|---|---|---|---|
| R1 | Fond d'écran | **Décidé** : natif, avec un **utilitaire de changement de fond** moderne (vignettes) ; pas d'image imposée. Fonds consolidés en un seul dossier. Détails et questions W1–W4 : `docs/WALLPAPERS.md` | supprime `swaybg` ; panoramas découpés à la volée selon les écrans |
| R2 | Verrouillage | **natif** (`WlSessionLock` + PAM), apparence de `swaylock.conf` | supprime `swaylock` ; protocole sûr (si Quickshell plante, la session reste verrouillée) |
| R3 | Veille écrans | **natif** (`IdleMonitor` 300 s → DPMS via le compositeur ; réveil échelonné repris de `hypridle`) | une seule implémentation pour Sway et Hyprland ; supprime `swayidle` et `hypridle`. Les règles `inhibit_idle` du compositeur restent respectées (`respectInhibitors`) **[à vérifier]** |
| R4 | Agent polkit | **natif** (`PolkitAgent`) | fenêtre de mot de passe aux couleurs de la charte ; supprime `polkit-gnome` |
| R5 | Réseau | **natif**, menu dans la barre, `nm-connection-editor` en repli pour l'édition | supprime `nm-applet` ; NordVPN a sa propre icône dans le tray |
| R6 | Bluetooth | **natif**, avec test d'appairage en phase dédiée ; si l'appairage échoue, garder `blueman` pour ce seul usage | supprime `blueman` si le test passe |
| R7 | Disques amovibles | **garder `udiskie`** (son icône apparaît dans le tray Quickshell) | aucun équivalent natif |
| R8 | Captures d'écran | **garder `grim`/`slurp`** pour l'instant ; outil QML en `BACKLOG.md` | faisable (`ScreencopyView`) mais non prioritaire |
| R9 | Touches volume / média / luminosité | **natif via `qs ipc`** (phase 10) | supprime `pactl`, `wpctl`, `playerctl` des raccourcis |
| R10 | Écran de connexion (SDDM) | **hors périmètre** | demanderait greetd et des fichiers système (`sudo`) |
| R11 | Espace affiché au démarrage | premier espace de chaque écran (1 / 4 / 7), géré par `Outputs` | Sway (9) et Hyprland (7) ne sont pas d'accord aujourd'hui |

Proposition de placement dans les phases (CLAUDE.md n'est pas modifié sans ton accord) :
- R5, R6, R7 : **phase 5 (tray)**, puisqu'ils remplacent des icônes du tray ;
- R1, R2, R3, R4 : nouvelle **phase 8b — services de session**, après les menus ;
- R9, R11 : **phase 10 (bascule)**.

### 10.1 Décisions (2026-10-15)

| # | Décision |
|---|---|
| R1 | Fond natif + utilitaire de changement de fond (phase 8b). Fonds consolidés : voir `WALLPAPERS.md`. |
| R2 | Verrouillage natif (phase 8b), **design entièrement refait** : moderne, dans la charte (palette, polices). L'apparence de `swaylock.conf` (`THEME.md` § 11) n'est **pas** à reproduire. Maquette à valider avant implémentation. |
| R3 | Veille des écrans native (`IdleMonitor`), phase 8b. |
| R4 | Agent polkit natif, phase 8b. |
| R5 | Réseau natif (phase 5), `nm-connection-editor` en repli pour l'édition des connexions. |
| R6 | Bluetooth natif (phase 5) — voir § 10.2. |
| R7 | Disques natifs (phase 5) — voir § 10.3. |
| R8 | **Outil de capture en fenêtre Quickshell** (écran entier, un écran, une fenêtre, une zone ; modèle de l'outil de capture GNOME), phase 8b, **entièrement natif** (`ScreencopyView`, `Toplevel` : § 12, revue du 2026-10-16) au lieu de `grim`/`slurp`. |
| R9 | Touches volume / média / luminosité via `qs ipc`, phase 10. |
| R10 | Écran de connexion : **phase 12, tout à la fin**, à concevoir ensemble. **SDDM abandonné, remplacé par greetd** (§ 10.4) : greeter Quickshell indépendant (`Greetd`), reprenant uniquement l'apparence du thème `catppuccin-mocha-green` (thème lui-même écrit en QML : `/usr/share/sddm/themes/catppuccin-mocha-green/`, paquet AUR `catppuccin-sddm-theme-mocha` ; fond `backgrounds/wall.png`, police Noto Sans 9, horloge, icônes power/reboot/sleep). Aperçu : `docs/reference/sddm-catppuccin-preview.png` (aperçu générique du paquet ; la variante installée est verte). |
| R11 | Au démarrage : 1 / 4 / 7. |

### 10.1.1 Mise en œuvre de la phase 5 (2026-10-16)

- **Placement** : modules natifs dans la pilule du tray, après les applications (NordVPN, réseau, disques, Bluetooth) ; un clic ouvre
  leur **panneau** (`Panel.qml`, style du calendrier). L'icône StatusNotifier d'une application remplacée (nm-applet, blueman,
  udiskie, NordVPN) est masquée quand son module natif est présent (pas de doublon : ta demande ; utile aussi après la bascule si
  l'une d'elles est lancée par ailleurs) ; sans module natif (ex. NordVPN absent), l'icône de l'application reste.
- **Popups** : les menus du tray sont des popups « grab » ; wlroots les ferme au clic sur une autre application (ce clic n'est pas
  transmis, comme les menus GTK), un clic sur une barre les ferme (`BarState.closePopups`). Un popup affiché ne se redimensionne pas
  proprement sous Sway : les menus n'apparaissent qu'avec leurs entrées.
- **Panneaux du tray** (corrigé le 2026-10-20) : surfaces Overlay à clavier exclusif (`OverlayPopup`, comme le panneau de réglages et
  le lanceur), et non plus des popups « grab » : sous Sway, un popup `grabFocus` ouvert depuis une barre ne reçoit jamais le clavier
  (ni saisie, ni Échap). Fermés par un appui à côté du cadre (non transmis), sur une barre ou sur un autre écran, ou par Échap.
- **Réseau** (R5) : `Quickshell.Networking` (filaire, Wi-Fi : interrupteur, réseaux, mot de passe, oubli) ; édition dans `nm-connection-editor`.
  Depuis le 2026-10-19 (ta demande), deux icônes : **réseau** (filaire et réseaux privés ; visible si un câble est branché ou
  sans Wi-Fi) et **Wi-Fi** (`WifiPanel.qml`). Le Wi-Fi s'inspire de GNOME (niveaux de signal et seuils 20 / 40 / 50 / 80 % de
  `signalToIcon`, qualité en mots), de KDE (réseau courant déplié avec ses détails) et de Cinnamon / GNOME (liste avec force du
  signal). Glyphe dessiné en QML (`WifiIcon.qml`) sur la géométrie Papirus, pour l'animer (glissement de niveau, balayage pendant
  la connexion). Détails absents de `Quickshell.Networking` (bande, canal, largeur, débit du lien, adresse IPv4) : `nmcli`,
  relu toutes les 5 s seulement panneau ouvert.
  Panneau réseau refait le 2026-10-19 (ta demande) : onglets Wired / Tailscale / ZeroTier (`NetworkPanel.qml`). Filaire
  (`WiredCard.qml`) : détails `nmcli` (IPv4, passerelle, DNS, domaine, IPv6 ; un port de pont est lu sur son pont) et graphe
  du trafic (`TrafficGraph.qml`, aussi dans la carte Wi-Fi). Tailscale (`services/Tailscale.qml`) : `status --json` et
  `debug prefs` sans droits ; actions (`up` / `down`, `set --exit-node / --accept-dns / --accept-routes / --shields-up /
  --exit-node-allow-lan-access`) grâce à `--operator=$USER` (ton choix ; à proposer par install.sh). ZeroTier
  (`services/ZeroTier.qml`) : `zerotier-cli -j` avec le jeton copié dans `~/.zeroTierOneAuthToken` (ton choix ; install.sh),
  sinon interfaces `zt*` en lecture seule. Actions des deux par un lanceur commun (`services/CliRunner.qml` : présence du
  programme, une commande à la fois, message d'erreur). Relus toutes les 5 s panneau ouvert ; panneau fermé, 60 s sans câble
  seulement. L'icône réseau reste visible
  sans câble si Tailscale ou ZeroTier sont là (`network-vpn`). Copies : `wl-copy` (`Quickshell.clipboardText` n'atteint pas le
  presse-papiers sans appui récent).
- **Bluetooth** (R6) : `Quickshell.Bluetooth` ; appairage par `bluetoothctl` lancé pour l'occasion, son agent servant à sa propre commande
  `pair` (l'agent par défaut de blueman n'est pas touché) ; demandes affichées dans le panneau, jamais acceptées automatiquement.
- **Disques** (R7) : `busctl` / `gdbus monitor` / `udisksctl` ; règles et textes d'udiskie (montage automatique, notifications, images
  disque en boucle prises en charge).
- **NordVPN** (§ 11.4) : commande `nordvpn` ; onglets Recent (historique local, un pays par entrée, avec la ville si elle a été
  choisie) / All countries ; la recherche montre tous les pays filtrés ; l'interrupteur reconnecte à la dernière entrée (refonte du
  2026-10-20). Toutes les commandes `nordvpn` (statut, listes, actions) passent par une seule file, une à la fois : une lecture du
  statut suit chaque action et voit toujours son effet ; prix : une liste demandée pendant une connexion attend sa fin.

### 10.1.2 Mise en œuvre de la phase 6 (2026-10-16)

- **Serveur** : `services/Notifs.qml` (`Quickshell.Services.Notifications`), comportement relu dans le code de Dunst 1.13.2 :
  délais (celui de l'application, sinon 10 s basse / normale, jamais critique), suspendus sous le pointeur ; tri urgence puis arrivée ;
  doublons « (N) » ; étiquettes de pile (`x-dunst-stack-tag`, `x-canonical-private-synchronous`…) ; remplacement par identifiant ;
  indicateurs `(A)` `(U)` ; âge au-delà de 60 s ; markup Pango traduit pour Qt (`<a>` et `<img>` réduits à leur texte, balises inconnues
  ignorées). Capacités annoncées : celles de Dunst.
- **Écran** : `notificationsOutput` de la config machine (`primary` ou description d'écran), l'écran principal à défaut (vérifié : écran
  désactivé → les notifications passent sur l'écran restant). Dunst choisissait un **numéro** d'écran (`monitor = 1`), qui change quand
  l'ordre des écrans change (constaté après les tests de la phase 3 : notifications sur DP-1 jusqu'à la prochaine session Sway).
- **Souris** (dunstrc) : gauche ferme, milieu lance l'action `default` (ou l'unique action, ou ouvre l'unique lien) puis ferme, droit ferme
  tout. Ajout : **boutons** pour les actions nommées (Dunst ne les montrait pas ; son menu `dmenu` n'était pas installé).
- **Historique et centre de notifications** (ta demande) : les 20 dernières notifications fermées (`history_length`), en mémoire comme
  Dunst ; cloche du tray (`NotificationsPanel.qml`) ; « ne pas déranger » : seules les critiques s'affichent, les autres vont dans le centre.
- **IPC** (`qs ipc call notifications …`) : `close`, `closeAll`, `historyPop`, `count` — équivalents de `dunstctl close`, `close-all`,
  `history-pop`, `count` ; aucun raccourci ne les appelle aujourd'hui (INVENTORY § 2).
- **Coexistence** : tant que Dunst tourne, il garde le nom D-Bus ; Quickshell le prend dès que Dunst s'arrête (et le rendrait si Quickshell
  s'arrête, Dunst étant activé par D-Bus). `notify-send` (audio, disques, NordVPN) passe par le serveur actif.

### 10.1.3 Mise en œuvre de la phase 7 : lanceur (2026-10-16)

Comportement relu dans le code de Rofi 2.0.0 (`modes/drun.c`, `history.c`, `helper.c`, `keyb.c`, `widgets/listview.c`).

- **Service** `services/Apps.qml` : `DesktopEntries.applications`, plus les filtres de Rofi que Quickshell n'applique pas — `OnlyShowIn` /
  `NotShowIn` selon `XDG_CURRENT_DESKTOP` (`sway` ici : réglages GNOME, Yelp, Tweaks… masqués), `TryExec` introuvable, `Exec` absent.
  Les clés sont lues par un court script `find` + `awk` (première entrée par identifiant, priorité XDG), relancé quand les applications changent.
- **Ordre** : historique (du plus lancé au moins lancé), puis le reste par nom. Historique comme Rofi : +1 par lancement, tri stable,
  compteurs ramenés au plus petit, 25 entrées. Stocké dans `launcher.json` (état local de Quickshell, hors du dépôt, `JsonAdapter`) ;
  **repris de Rofi** (`~/.cache/rofi3.druncache`, `rofi-entry-history.txt`) quand ce fichier n'existe pas encore.
- **Recherche** (`-drun-match-fields all`) : mots séparés par des espaces, tous requis, sans casse, dans nom, nom générique, `Exec`,
  catégories, mots-clés, commentaire ; « -mot » exclut. Pas de tri par pertinence (`sort: false`).
- **Lancement** : commande de l'entrée (codes `%f`… retirés par Quickshell), dossier `Path`, dans `Settings.terminal` si `Terminal=true`
  (Rofi : `gnome-terminal -e`). Texte saisi sans résultat, ou Ctrl+Entrée : lancé comme commande (`sh -c`) ; Maj+Entrée sans résultat
  et Ctrl+Maj+Entrée : dans un terminal.
- **Fenêtre** (`modules/launcher/`) : surface Overlay couvrant la zone utile de l'écran focalisé (comme Rofi, qui centre sa surface dans
  la zone utile), clavier exclusif, cadre centré arrondi vers le haut et la gauche ; clic à côté ou sur une barre = fermeture
  (`click-to-exit`). Liste par pages entières (`scroll-method 0`), sans boucle (`cycle: false`). Chargée à la première ouverture
  (`LazyLoader`). IPC `qs ipc call launcher toggle|open|close`.
- **Clavier** (défauts de Rofi) : Entrée / Ctrl+J / Ctrl+M ; Haut / Bas / Ctrl+P / Ctrl+N / Tab / Maj+Tab ; Pages ; Début / Fin
  (sélection, pas curseur) ; Ctrl+Haut / Ctrl+Bas : textes saisis précédemment (20, enregistrés à la fermeture) ; Maj+Suppr : retire
  de l'historique ; édition Emacs (Ctrl+A/E/B/F/H/D/K/U/W, Alt+B/F, Ctrl+Alt+H/D) ; Échap. **Souris** : clic = sélection, double clic =
  lancement, molette = ligne suivante / précédente.
- **Non repris** : modes `run` et `ssh` (`SCRIPTS.md`), actions des applications (désactivées dans ta config Rofi).
- **Petit écart voulu** : après Maj+Suppr, Rofi retire l'application de la liste jusqu'à la prochaine ouverture ; ici elle reprend sa place
  alphabétique.

### 10.1.5 Menu d'applications (phase 8, remplace nwg-menu)

Disposition du menu de Cinnamon (référence : `docs/reference/cinnamon-menu.png`), style de nwg-menu (`THEME.md` § 7). Code écrit pour
ce projet, **sans dépendance ni emprunt à Cinnamon** (ta consigne) : catégories tirées directement des fichiers `.desktop`.

- **Ouverture** : bouton Arch de la barre (vert tant que le menu est ouvert) ou `qs ipc call menu toggle` (bouton de l'écran focalisé) ;
  surface Overlay (clavier exclusif), cadre sous le bouton, aligné sur sa pilule, 10 px sous la barre (`-mt 10` de nwg-menu). Chargé à
  la première ouverture (`LazyLoader`). Fermeture : Échap, clic à côté, sur une barre ou sur un autre écran, lancement.
- **Colonne de gauche** (tes choix du 2026-10-17) : dossier personnel et dossiers XDG (Documents, Téléchargements, Musique, Images,
  Vidéos, via `xdg-user-dir`) ; favoris ; verrouiller, se déconnecter, redémarrer, éteindre (tes 4 SVG, sans confirmation).
- **Favoris** : clic droit sur une application → « Add to favorites » / « Remove from favorites » ; état local
  (`app-menu.json`), repris au premier démarrage des applications épinglées de nwg-menu (`~/.cache/nwg-pin-cache`).
- **Catégories** (au survol, ton choix) : « All Applications », puis les catégories principales freedesktop non vides — une application
  va dans la première qu'elle déclare dans l'ordre Administration (`System`), Preferences (`Settings`), Programming, Games, Graphics,
  Sound & Video, Internet, Office, Education, Science, Accessories (`Utility`) ; sinon « Other » —, puis « Recent Files » (ton choix :
  fichiers locaux de `recently-used.xbel` encore présents, du plus récent au plus ancien ; fichier lu seulement quand cette catégorie
  s'affiche).
- **Visée** (principe du menu de Cinnamon, code propre) : un pointeur qui va d'une catégorie vers la liste des applications, entre les
  coins haut et bas de cette liste, ne change pas de catégorie en traversant les autres ; dès qu'il s'arrête (30 ms), la catégorie sous
  lui est prise. Le survol d'une application ne la sélectionne que si la souris a bougé depuis la dernière touche : une liste qui
  défile ou change sous un pointeur immobile ne vole pas la sélection du clavier.
- **Hauteur** : au plus celle de l'écran sous la barre ; au-delà, chaque colonne défile (petit écran de laptop). Colonne de gauche :
  270 px au plus (noms de favoris abrégés au-delà). Curseur de défilement à faire glisser.
- **Un seul popup à la fois** : ouvrir le menu, le panneau de réglages ou le lanceur ferme les autres (`OverlayPopup.beginOpen`,
  `BarState.closePopups`). Le menu et le panneau de réglages existent **en un seul exemplaire**, placé sous le bouton qui l'ouvre,
  sur son écran : un clic sur le bouton d'un autre écran l'y déplace ; le raccourci (`qs ipc call menu toggle`, de même pour
  `settings`) le ferme s'il est ouvert, où qu'il soit, sinon l'ouvre sous le bouton de l'écran focalisé (`BarState.toggle`,
  `toggleFromShortcut`). Les deux sont créés par `modules/menus/Panels.qml` (depuis `shell.qml`), qui inscrit leurs LazyLoader
  dans `BarState` : pas d'import circulaire entre les modules de la barre et des menus.
- **Appui sur le bouton d'un panneau ouvert** (ou sur l'horloge, calendrier épinglé) : un appui sur une barre ferme les popups,
  sauf celui dont le bouton (`owner`) est sous l'appui ; c'est ce bouton qui le ferme. Pas de délai ni d'état temporaire : un appui
  suivant, Échap puis un clic, ou un raccourci rouvrent toujours.
- **Écran ou bouton disparu** (écran débranché ou éteint) : le panneau ouvert se ferme (lanceur compris : tout changement d'écran
  d'un panneau ouvert le ferme).
- Base commune du menu, du panneau de réglages et du lanceur : `modules/bar/OverlayPopup.qml` (surface Overlay plein écran, clavier
  exclusif, fermeture par un appui à côté, sur une barre ou sur un autre écran ; signal `closing`).
- **Recherche** en bas : la saisie va toujours au champ ; même recherche que le lanceur (`Apps.filter`). **Le survol n'efface jamais la
  recherche** (défaut de nwg-menu, ta demande) : pendant une recherche, survoler une catégorie ne fait rien ; seul un clic la quitte.
- **Applications** : nom + description (commentaire, sinon nom générique), par nom ; clic ou Entrée : lancement (`Apps.launch`, compté
  dans l'historique du lanceur) ; dossiers et fichiers : `xdg-open`.
- **Clavier** : Haut / Bas, Pages : sélection ; Gauche (hors recherche) : colonne des catégories, que Haut / Bas parcourent ; Droite ou
  Entrée : retour aux applications ; Échap : ferme le menu contextuel, puis le menu.
- **Fermeture automatique** (ta demande du 2026-10-21) : pointeur sorti du cadre et resté dehors 2 s (délai du calendrier épinglé) ;
  pas pendant une recherche (un clic à côté ferme alors), ni sous le menu contextuel, ni si le pointeur n'est jamais entré (menu
  ouvert au raccourci) ; une touche relance le délai.
- Services : `Apps` (catégories, favoris, partagé avec le lanceur), `Icons` (`iconSource`, `mimeIcon`), `Places` (dossiers, fichiers récents, ouverture).

### 10.1.4 Panneau de réglages façon GNOME (phase 8, décidé le 2026-10-16)

Remplace le power menu Rofi. Base : les réglages rapides de GNOME 51 (code de gnome-shell lu : `js/ui/panel.js`, `js/ui/status/*`).

- **Bouton** : le bouton power du bout de la barre devient un **engrenage** `U+F013` (Symbols Nerd Font Mono, 28 px, couleur `text`) ;
  il ouvre le panneau, au style des panneaux du tray (`THEME.md` § 3). `$mod+Escape` l'ouvrira aussi (IPC).
- **Ligne du haut** : à gauche la batterie en % (laptop), le bouton **capture d'écran** (outil natif de la phase 8b) ; à droite tes
  **4 icônes SVG** du power menu, redimensionnées : verrouiller, se déconnecter, redémarrer, éteindre. **Pas de veille, pas de
  confirmation** (comme Rofi). Pas de bouton Réglages GNOME.
- **Curseurs** : sortie son (flèche → choix de la sortie, contenu du panneau audio), luminosité (laptop). Micro retiré le 2026-10-26
  (ta demande : jamais réglé là ; il reste dans le panneau audio).
- **Bascules** (grille de 2 colonnes, comme GNOME) : profil d'énergie (Performance / Équilibré / Économie, ta demande de trois boutons),
  ne pas déranger, garder l'écran allumé (`IdleInhibitor`), VRR et HDR (écrans compatibles seulement), **veilleuse** (`gammastep`),
  **mode avion** (`rfkill`, dès qu'il y a une radio Wi-Fi ou Bluetooth ; laptop seulement jusqu'au 2026-10-26). Ne pas déranger :
  horaire (`doNotDisturb` de `hosts/*.json` au départ, puis clic droit sur la bascule : heures et interrupteur, fichier d'état).
- **Survol de l'engrenage** (2026-10-26) : aperçu comme les cartes du tray (le panneau dérive de `Panel.qml`).
- **Tray inchangé** : réseau, Bluetooth, NordVPN, disques et cloche gardent leur icône et leur panneau ; ils ne sont pas dupliqués dans
  le panneau de réglages.
- Repris de GNOME mais écarté : style sombre (thème toujours sombre), Réglages GNOME, veille, confirmation.
- **Mise en œuvre** : surface de la couche Overlay plutôt que popup (un popup Wayland ne peut pas prendre le clavier sans clic, donc pas
  d'ouverture par `$mod+Escape`) ; surfaces transparentes sur les autres écrans pendant qu'il est ouvert (`OutsideClick.qml`), sinon un
  clic ailleurs laisserait le clavier bloqué sur lui. Flèche du choix de périphérique toujours affichée (avec un seul périphérique, GNOME
  la cache : tu ne la voyais pas). Veilleuse : `gammastep` lancé par le shell (fondu d'environ 4 s à l'activation, à l'arrêt par SIGTERM et aux
  heures de l'horaire ; wlsunset, utilisé jusqu'au 2026-10-26, changeait d'un coup), réglages de `hosts/*.json` (`nightLight`) écrits
  dans son fichier de config, état dans un fichier d'état local. HDR / VRR : commandes `output` de Sway ; Hyprland en phase 9 (sa config Lua n'a pas d'équivalent sûr connu).

### 10.1.6 Phase 8b : fond d'écran natif (2026-10-17)

Voir `WALLPAPERS.md` § « Mise en œuvre ». Remplace `swaybg` (Sway) et le fond de Hyprland à la bascule (phase 10).

### 10.1.7 Phase 8b : écran de verrouillage (2026-10-17)

- `modules/lock/LockScreen.qml` : `WlSessionLock` (protocole ext-session-lock) + `PamContext` (configuration `login` de
  `/etc/pam.d`). Design validé (maquette du 2026-10-17) : `LockContent.qml`, fond actuel de chaque écran (`WallpaperView`, celui que
  l'écran affiche, choix courant de l'utilitaire compris) flouté et assombri, horloge, date ; initiale, nom et champ sur l'écran
  principal (`Outputs.primary` ; à défaut, l'écran focalisé au verrouillage), saisie prise quel que soit l'écran qui a le clavier
  (demande du 2026-10-19). Majuscules verrouillées déduites des lettres
  tapées. Entrée valide, Échap efface, Ctrl+Retour arrière efface tout.
- Verrouiller : `Session.lock()` (panneau de réglages, menu d'applications), `qs ipc call lock lock`, veille (à venir). **Aucun
  déverrouillage par IPC.** Les popups ouverts se ferment au verrouillage.
- **Sûreté** : si Quickshell s'arrête pendant le verrouillage, le compositeur garde la session verrouillée (Sway : écran rouge).
  Reprise : relancer Quickshell (depuis un autre terminal virtuel : `WAYLAND_DISPLAY=wayland-1 qs -c desktop &`, puis
  `qs ipc call lock lock`) ; la nouvelle instance reprend le verrou et se déverrouille avec le mot de passe. Vérifié dans un Sway isolé.
- Tests : PAM factice (`pam_permit` / `pam_deny`) dans un dossier temporaire, branché seulement dans une configuration de test
  (`LockScreen.pamDirectory`) ; le verrouillage réel avec ton mot de passe est dans la liste « À faire par toi ».
- Revue du 2026-10-27 : verrou refusé ou perdu (un autre client ext-session-lock le tient, ex. swaylock) → `locked` repasse à
  faux (détecté par `secure` qui retombe alors que `locked` est vrai) ; sans cela, plus aucun verrouillage jusqu'au redémarrage.
  Frappe gardée pendant la vérification PAM, pour l'essai suivant (comme swaylock ; Entrée y est ignoré, comme swaylock) : le
  mot de passe vérifié est figé à l'appui sur Entrée (`pending`). Messages de PAM montrés si l'essai échoue (faillock : compte
  bloqué). Mot de passe long : les derniers points restent visibles.

### 10.1.8 Phase 8b : veille des écrans (2026-10-17)

- `services/Idle.qml` : `IdleMonitor` (inhibitions respectées : règles `inhibit_idle` du compositeur, « Keep Screen On », vidéos
  des applications Wayland). Après `idle.timeout` s (300 par défaut, comme swayidle et hypridle) : `Compositor.setPower` éteint les
  écrans (Sway `output * power off`, Hyprland `hl.dsp.dpms`). Reprise : tous rallumés d'un coup, Sway comme Hyprland (Sway
  `output * power on`, comme swayidle). Le suivi est relancé quand le délai change (la config machine est lue après sa création ;
  sinon le délai par défaut restait en place — vérifié).
- Pas de rallumage en deux temps (revue du 2026-10-27). Le délai de ton hypridle (écran principal 3 s après les autres)
  contournait un bogue de Hyprland : non repris, un seul comportement pour les deux compositeurs (à tester en phase 9). Sous
  Sway, chaque commande `output` réapplique la configuration de tous les écrans en un seul commit (Sway 1.12,
  `apply_output_configs`) : rallumer le principal à part refaisait un modeset qui éteignait de nouveau les écrans déjà rallumés (vu : latéraux allumés puis éteints, central, latéraux). De plus, rallumer par nom
  laissait `power off` sur la config `*` : un écran branché ensuite restait éteint. Sur banc (3 sorties headless) : 1 commit au
  lieu de 2, écran branché après une veille allumé.
- Quickshell relancé écrans éteints (rechargement, plantage) : le nouveau suivi n'est pas en veille ; 2 s après le démarrage, les
  écrans éteints sont rallumés (sans cela, noirs jusqu'à 5 min sans activité — vérifié sur banc).
- Verrouillage avant la mise en veille du système (`idle.lockBeforeSleep`, par défaut sur une machine avec batterie) : verrou
  « delay » de logind (`systemd-inhibit`), `PrepareForSleep` suivi par `gdbus monitor` ; écran verrouillé puis verrou relâché (au plus
  2 s). Ton desktop ne verrouille pas aujourd'hui avant la veille : désactivé ici (pas de batterie).
- Au réveil sous Hyprland : `hyprctl reload` (`after_sleep_cmd` de ton hypridle : la disposition des écrans ne survit pas à la
  veille) ; `PrepareForSleep` est donc aussi suivi sous Hyprland, même sans verrouillage avant la veille.
- Non repris : les inhibitions D-Bus (`org.freedesktop.ScreenSaver`) que hypridle respectait — les applications Wayland passent par
  le protocole d'inhibition, que `IdleMonitor` respecte.
- IPC de test : `qs ipc call idle state`.

### 10.1.9 Phase 8b : agent polkit (2026-10-17)

- `modules/polkit/PolkitDialog.qml` : `PolkitAgent` + fenêtre au style des panneaux (`OverlayPopup`, centrée sur l'écran focalisé,
  clavier exclusif) : icône et message de l'application, champ (masqué si polkit le demande), message d'erreur, Cancel /
  Authenticate. Entrée valide ; Échap, un clic à côté, sur une barre ou sur un autre écran annulent.
- Un seul agent par session : tant que `polkit-gnome` tourne (lancé par Sway jusqu'à la bascule), l'enregistrement de Quickshell
  échoue (avertissement dans le journal, sans effet). À la phase 10, `polkit-gnome` sort de l'autostart.
- Identité : affichée (« Password for … ») seulement si ce n'est pas toi (plusieurs administrateurs : polkit propose le premier ;
  `Identity.string` / `displayName` sont lisibles). Pas de choix : changer `selectedIdentity` relance la session PAM de façon
  risquée dans Quickshell 0.3.2 (annulation comptée comme un échec).
- Enregistrement raté (polkit-gnome, ou instance d'avant un plantage pas encore partie) : jamais retenté par Quickshell ; l'agent
  est recréé (5 s, puis de plus en plus rarement, 5 min au plus).
- Fermée par toi (Échap, Cancel, clic à côté, autre popup) : demande annulée. Fermée sans toi (écran retiré, verrouillage,
  surface fermée par le compositeur : `OverlayPopup.closingLost`, `BarState.closePopups(keep, lost)`) : demande gardée,
  rouverte sur l'écran focalisé. Jamais affichée pendant le verrouillage (`Session.lockActive`, dès la demande) : elle prendrait
  le clavier de l'écran de verrouillage, et le mot de passe tapé pour déverrouiller (même raison : l'outil de capture est
  fermé au verrouillage et ne s'ouvre pas pendant). Rechargement de la config : la demande en cours est réaffichée.
- Quickshell 0.3.2 (aussi sur `master`) : une demande arrivée pendant une autre la remplace (file d'attente inopérante) ; la
  première est annulée une fois l'agent libre (sinon son application attendrait indéfiniment).
- Message en texte brut (la commande de `pkexec` y figure). Champ vide jamais envoyé. Chaque demande annulée compte comme un
  échec pour faillock (`polkit-agent-helper-1`, comme avec polkit-gnome) : `deny = 10` sur 15 min ici.

### 10.1.10 Phase 8b : outil de capture (2026-10-17)

- `services/Screenshot.qml` + `modules/screenshot/ScreenshotTool.qml` (modèle de l'outil de GNOME) : image figée de chaque écran
  (`ScreencopyView` en continu jusqu'à la première image, puis arrêtée : une capture demandée à la création échoue, « no recording
  context ») ; voile `#ffffff20` et cadre rose de 4 px (ta sélection slurp actuelle) ; capture dès que le choix est fait (ta
  demande du 2026-10-19 : ni redimensionnement ni bouton de capture) — zone tracée (au relâchement), écran cliqué, fenêtre cliquée
  (rectangles des fenêtres des espaces affichés donnés par le compositeur : `Toplevel` ne fournit pas leur position) ; barre
  d'outils en bas de l'écran de départ (aide du mode choisi, modes avec leur nom, fermer) ; Entrée / Espace capturent l'écran présélectionné, Échap ferme.
- Capture : découpe de l'image figée (`ShaderEffectSource`) à la résolution réelle de l'écran, enregistrée dans
  `Images/screenshot/AAAA-MM-JJ-HHMMSS.png` (comme ta touche Impr.) et copiée dans le presse-papiers (`wl-copy`).
- Ouvert par le bouton du panneau de réglages (mode zone) et `qs ipc call screenshot area|screen|window` (touche Impr., phase 10).
  IPC de test : `select x y w h`, `capture`, `isActive`.
- `ScreencopyView` ne reçoit aucune image dans une session Sway sans GPU (rendu logiciel) : l'outil ne se teste que sur tes écrans.

### 10.2 Bluetooth : appairage et code PIN

Vérifié :
- Quickshell 0.3.2 parle à BlueZ (`org.bluez.Adapter1`, `Device1`, `Battery1` : lister, connecter, appairer, oublier), mais **n'implémente pas d'agent
  d'appairage** (`org.bluez.Agent1` absent du binaire).
- `man 5 org.bluez.Device`, méthode `Pair()` : *« In case there is no application agent and also no default agent present, this method will fail. »*
  Aujourd'hui c'est **blueman** qui fournit l'agent. Sans lui et sans autre agent, **aucun appairage ne fonctionne**, même sans code.
  Se reconnecter à un appareil **déjà appairé** n'a pas besoin d'agent.

Solution proposée (une dépendance officielle de plus, `bluez-utils`) : pendant un appairage seulement, Quickshell lance `bluetoothctl`
comme agent (`agent KeyboardDisplay`, sans `default-agent` : BlueZ utilise l'agent de la session qui lance `pair`, l'agent par
défaut n'est pas touché), lit ses demandes (« [agent] Confirm passkey 123456 (yes/no) », « [agent] Enter PIN code ») et les affiche
dans une fenêtre de la charte ; la réponse est renvoyée à `bluetoothctl`. L'agent s'arrête à la fermeture de la fenêtre.

Dangers et parades :
- **Nom d'appareil piégé** : seules les lignes `[agent] …` et les résultats de `pair` en début de ligne sont lus ; les lignes
  `[NEW]` / `[CHG]` portent les noms des appareils voisins, qui pourraient imiter une question (revue de code du 2026-10-16).
- **Accepter automatiquement** (agent « oui à tout ») permettrait à un appareil à portée de s'appairer sans qu'on le voie → **jamais** d'acceptation
  automatique ; chaque demande passe par la fenêtre.
- **Agent permanent** : il accepterait aussi les demandes venues d'un téléphone à proximité → agent actif **uniquement** pendant un appairage lancé par toi.
- **Format de sortie de `bluetoothctl`** susceptible de changer entre versions → messages attendus centralisés dans le service, testés en phase 5
  avec un vrai appareil (code à confirmer et appareil sans code).

### 10.2.1 Panneau Bluetooth enrichi (2026-10-26, ta demande)

Revue des modules de KDE (bluedevil), GNOME (gnome-shell, gnome-bluetooth) et blueman (Cinnamon 6 n'a pas d'applet propre : il
utilise blueman). Tes choix :
- **Ligne** (`BluetoothDeviceItem.qml`) : « état · type · batterie » (type déduit de l'icône BlueZ), « Connection failed » après un
  échec demandé depuis le panneau, icône qui pulse pendant une action ; un clic déplie les détails (nom d'origine, type, adresse
  copiable, batterie, appairé, approuvé, adaptateur), le renommage (alias BlueZ ; vide = nom de l'appareil) et la reconnexion
  automatique. Connect / Disconnect et Forget restent sur la ligne.
- **Ordre figé** tant que le panneau est ouvert (GNOME) ; retrié à l'ouverture suivante.
- **Notifications** de connexion et de déconnexion (ConnectionNotifier de blueman) : « Connected » remplacé par « Connected 80% »
  quand BlueZ publie la batterie (`notify-send --print-id` puis `--replace-id`).
- **Reconnexion automatique** (AutoConnect de blueman) : au démarrage, à l'allumage, dès qu'un appareil choisi apparaît, puis toutes les 60 s ; appareils choisis déconnectés ; liste
  dans `~/.local/state/quickshell/by-shell/desktop/bluetooth.json`, reprise du réglage de blueman (`gsettings`) s'il n'existe pas.
  Tentatives silencieuses (ni animation, ni « Connection failed ») ; pas de notification « Automatically connected » en plus de
  « Connected » (blueman envoie les deux).
- **Profil audio** d'un casque connecté (PulseAudioProfile de blueman) : `pw-dump bluez_card.<adresse>` (profils disponibles sauf
  `off`), `wpctl set-profile` ; `Quickshell.Services.Pipewire` n'expose pas les profils. Lus quand les détails sont dépliés.
- **Veille suspendue** tant qu'une manette (icône `input-gaming`) est connectée : même `IdleInhibitor` que « Keep Screen On ». Le
  module de blueman passe par `xdg-screensaver`, sans effet sous Sway.
- **Icône du tray animée** pendant l'allumage, une connexion, une déconnexion ou un appairage (GNOME, KDE).
- **Batterie faible** d'un appareil connecté (GNOME) : notification à 30 % puis 15 % (seuils de la batterie du laptop, config
  Waybar), réarmée quand la batterie remonte au-dessus de 40 % (ton choix du 2026-10-27), pas à la reconnexion.

Écartés : envoi et parcours de fichiers (OBEX), commandes média AVRCP (carte média MPRIS), force du signal (absente de l'API),
base de codes PIN, partage de connexion (PAN/DUN), confirmation de « Forget », clic milieu, pastille, visibilité temporaire,
blocage d'un appareil.

### 10.3 Disques amovibles sans udiskie

Je m'étais trompé : Quickshell n'a pas d'accès D-Bus générique en QML, mais trois outils système suffisent (vérifié en lecture sur cette machine) :
- **état** : `busctl --system --json=short call org.freedesktop.UDisks2 … GetManagedObjects` → JSON directement lisible en QML (14 systèmes de fichiers vus) ;
- **branchement / débranchement** : `gdbus monitor --system --dest org.freedesktop.UDisks2` (fonctionne sans droits ; `busctl monitor`, lui, exige root) ;
- **actions** : `udisksctl mount | unmount | power-off | unlock` (déverrouillage LUKS : phrase de passe saisie dans le panneau des disques,
  passée en fichier de clé sur l'entrée standard ; `busctl` pour sortir le support d'un lecteur qui ne s'éteint pas).
- **disque LUKS branché** (comme la fenêtre d'udiskie, ton choix du 2026-10-27) : le panneau s'ouvre de lui-même sous l'icône du tray de
  l'écran focalisé, champ de la phrase de passe prêt ; refermé une fois le disque déverrouillé. Pas au démarrage de Quickshell.

Dépendances : `udisks2` (déjà requis par udiskie), `glib2` (`gdbus`), `systemd` (`busctl`). Montage automatique à l'insertion et notifications reproduits
dans le service `Disks`. Les volumes système (`HintSystem`, `HintIgnore`) sont ignorés, comme le fait udiskie.

### 10.4 Écran de connexion : greetd au lieu de SDDM (phase 12, précisé le 2026-10-16)

- **greetd remplace SDDM** comme gestionnaire de connexion. L'écran de connexion est un **greeter Quickshell** écrit en QML
  (`Quickshell.Services.Greetd`, présent dans Quickshell 0.3.2), au style repris du thème SDDM `catppuccin-mocha-green`. Le thème SDDM
  lui-même n'est ni modifié ni réutilisé.
- **Compositeur du greeter** : greetd lance le greeter sous l'utilisateur `greeter`, qui a besoin d'un compositeur Wayland. Proposition :
  **Sway**, déjà installé et connu pour marcher sur cette carte Nvidia (`WLR_RENDERER=vulkan sway --unsupported-gpu`), avec une config
  minimale qui lance `qs` puis quitte. `cage` (compositeur kiosque, dépôt `extra`) serait un paquet de plus, non testé sur Nvidia ici.
- **Fichiers système** (`sudo`, avec ton accord, au moment de la phase 12) :
  - `/etc/greetd/config.toml` (commande du greeter) ;
  - config Quickshell du greeter lisible par l'utilisateur `greeter` (ton dossier personnel ne l'est pas), ainsi que les polices du dépôt ;
  - `/etc/pam.d/greetd` : lignes `pam_gnome_keyring.so` reprises de `/etc/pam.d/sddm` (auth, password, session), pour déverrouiller le trousseau ;
  - bascule `systemctl disable sddm` puis `systemctl enable greetd`.
- **Sessions proposées** : fichiers de `/usr/share/wayland-sessions/` (dont `sway-vulkan.desktop`, créé à la main pour SDDM).
- **Retour arrière** : `systemctl disable greetd` puis `systemctl enable sddm`. SDDM et son thème restent installés tant que tu n'as pas validé.
  Le greeter console `greetd-agreety` sert de secours si le greeter Quickshell ne démarre pas.
- **Dépendances** (`deps/arch-pacman.txt`, section « Écran de connexion ») : `greetd` et `greetd-agreety`, tous deux du dépôt `extra`,
  installés par `install.sh` comme toutes les autres (sur ce desktop : par toi, au début de la phase 12). `greetd` exige un paquet qui
  fournit `greetd-greeter` : `greetd-agreety`, listé explicitement pour que l'installation ne pose pas la question.
- **Déploiement** : `install.sh` installe aussi les fichiers système ci-dessus, après confirmation et avec sauvegarde, puis active
  greetd à la place de l'ancien gestionnaire ; `--uninstall` rétablit l'ancien. Sur une installation neuve d'Arch (laptop), le script
  suffit pour arriver sur l'écran de connexion du bureau.

## 11. Risques relevés par la troisième passe

### 11.1 Quickshell hérite de qt6ct

`QT_QPA_PLATFORMTHEME=qt6ct` (`/etc/environment`) s'applique à Quickshell : style Kvantum, police par défaut et thème d'icônes `breeze` de qt6ct.
Parades : `Theme.qml` nomme toujours la police (jamais la police par défaut) ; thème d'icônes forcé par `//@ pragma IconTheme Papirus-Dark` ;
aucun contrôle Qt Quick Controls stylé par la plateforme (composants dessinés à la main).

**Vérifié en phase 1** (Quickshell lancé avec et sans la variable) :
- police par défaut : `DejaVu LGC Sans 12pt` avec qt6ct, `Sans Serif 9pt` sans → confirme qu'aucun texte ne doit dépendre de la police par défaut ;
  `Theme.qml` nomme donc toujours la famille **et** la taille ;
- icônes : le thème `breeze` choisi dans qt6ct **n'est pas installé** sur cette machine. Sans le pragma, seules les icônes d'applications
  présentes dans `hicolor` s'affichent (Firefox) ; `utilities-terminal`, `audio-volume-high`… manquent. Avec `//@ pragma IconTheme Papirus-Dark`,
  toutes viennent de Papirus-Dark, que qt6ct soit actif ou non. Le pragma est donc indispensable, pas une précaution.

### 11.2 Un seul processus pour tout le bureau

Barre, notifications, verrouillage, agent polkit, agent Bluetooth et veille vivent dans le même processus `qs`. S'il plante :
- tout disparaît en même temps → lancer `qs` comme **service systemd utilisateur avec redémarrage automatique** (plutôt qu'un simple `exec` du compositeur), à décider en phase 10 ;
- **écran verrouillé** : le protocole `ext-session-lock` garde la session verrouillée si le verrouilleur meurt (c'est voulu, c'est sûr) ; il faut donc que le `qs` redémarré
  puisse reprendre le verrouillage, et documenter un **retour de secours** depuis un TTY. À tester explicitement en phase 8b, sans risque pour ta session (écran virtuel ou session de test).

### 11.3 Polices Microsoft — décidé : dépôt privé `Crystal4276/fonts-ms` (créé le 2026-10-15)

Tu veux garder les 540 polices Microsoft (363 Mo, `/usr/share/fonts/MS_Fonts/`), utiles pour les documents Word.
Ce sont des polices **propriétaires** : leur usage personnel avec ta licence Windows ne pose pas de problème, mais les versionner, c'est les
stocker chez un tiers (GitHub), et elles ne doivent jamais être publiques.

Proposition : **dépôt privé séparé** `fonts-ms` (même principe que `wallpapers`), cloné par `install.sh` dans `~/.local/share/fonts/MS_Fonts`
(pas de `sudo`), **optionnel** ; jamais dans `qs-desktop`, qui doit rester partageable. Le bureau lui-même ne dépend pas de ces polices :
`noto-fonts-cjk` reste la police de repli pour le japonais, le chinois et le coréen, afin qu'un PC sans ce dépôt (laptop) affiche correctement les titres.
Alternative sans stockage : paquet AUR `ttf-ms-win11-auto`, qui extrait les polices d'une image ISO de Windows téléchargée à l'installation (plusieurs Go).

### 11.4 NordVPN : module natif au lieu de l'icône du tray

Aujourd'hui : icône NordVPN dans le tray (fournie par `norduserd`), raccourcis `$mod+u` (`nordvpn c Netherlands`) et `$mod+i` (`nordvpn d`),
connexion à Netherlands au démarrage.

Vérifié sur `nordvpn` 5.4.1 (lecture seule) :
- `nordvpn status` : lignes `Clé: valeur` (Status, Server, Hostname, Country, City, Current technology, Transfer, Uptime…) ; pas de sortie JSON ni de flux d'événements → lecture périodique (toutes les quelques secondes) et immédiatement après chaque action ;
- actions : `connect [pays | ville | code pays | serveur | groupe]`, `disconnect`, `pause 5m|15m|30m|1h|24h`, `countries`, `cities <pays>` ;
- `nordvpn settings` → `Tray: enabled` : l'icône officielle se masque avec `nordvpn set tray off` (réversible) ; `Notify: enabled` : les notifications de NordVPN arriveront dans nos notifications.

Proposition (phase 5, avec le réseau) : service `services/Vpn.qml` + widget dans la barre :
- icône d'état (connecté / déconnecté / en pause), tooltip : pays, ville, serveur, durée, données échangées ;
- clic : panneau dans la charte — connexion rapide (serveur recommandé, Netherlands), choix du pays puis de la ville avec recherche, pause, déconnexion ;
- raccourcis `$mod+u` / `$mod+i` → `qs ipc call vpn connect|disconnect` (phase 10) ;
- module masqué si `nordvpn` est absent ou si tu n'es pas connecté au compte (message « You are not logged in »).

Points d'attention : le format texte de `nordvpn status` peut changer d'une version à l'autre (lecture centralisée dans le service, testée à chaque mise à jour) ;
`nordvpn set tray off` modifie un réglage de NordVPN → appliqué seulement à la bascule (phase 10), avec ton accord.
Emplacement du widget dans la barre : à décider en phase 5 (nouveau widget, sans équivalent dans la Waybar actuelle).

### 11.5 GPU multi-constructeur et moniteur système

**Module GPU** (phase 4) — détection, sans rien supposer de la machine :
1. cartes : `/sys/class/drm/card*/device/vendor` (`0x10de` NVIDIA, `0x1002` AMD, `0x8086` Intel) ; s'il y en a plusieurs, celle marquée `boot_vga=1` (écran principal) ;
2. lecture selon le constructeur :

| Constructeur | Température | Charge / mémoire | Externe ? |
|---|---|---|---|
| NVIDIA (pilote propriétaire ou `nvidia-open`) | `nvidia-smi` (le pilote **n'expose aucun capteur hwmon** : vérifié sur cette machine) | `nvidia-smi` | `nvidia-utils` |
| AMD (`amdgpu`) | `device/hwmon/hwmon*/temp*_input` (capteurs `edge` / `junction`) | `device/gpu_busy_percent`, `mem_info_vram_used` / `_total` | non (sysfs) |
| Intel dédié (Arc, pilote `xe` ou `i915`) | `device/hwmon/hwmon*/temp*_input` si présent | — | non |
| Intel intégré (iGPU) | pas de capteur propre (puce partagée avec le CPU) | — | — |

3. aucune température GPU lisible → module masqué (cas iGPU seul).

**Changé le 2026-10-20 (ta demande)** : le module de la barre affiche l'**utilisation** du GPU (`{usage:2}%`, comme le CPU) au lieu de la température : `nvidia-smi --query-gpu=utilization.gpu` (NVIDIA), `device/gpu_busy_percent` (AMD). Intel n'expose pas d'utilisation dans sysfs → module masqué (la température reste lue pour le moniteur système).

Clic : `nvtop` (gère AMD, Intel et NVIDIA). Ce desktop n'a qu'un GPU NVIDIA : les branches AMD et Intel seront testées avec une fausse arborescence sysfs
(dossier de test passé au service), puis sur une vraie machine quand l'occasion se présente — à signaler dans le rapport de phase 4.

**Moniteur système** : au départ, les clics CPU / mémoire ouvrent `btop` (parité). Ensuite, une **fenêtre Quickshell de statistiques système**
(équivalent de btop : CPU par cœur, mémoire et swap, températures, GPU, disques, réseau, processus) — ajoutée à la phase 8b, en dernier.
Les données viennent de `/proc` et `/sys` (déjà lus par les services de la barre) ; la liste des processus et l'arrêt d'un processus sont à concevoir à ce moment-là.

**Fait (phase 8b, 2026-10-19, tes choix)** : panneau surgissant `modules/monitor/MonitorPanel.qml` (service `services/Monitor.qml`,
relevés seulement panneau ouvert, chaque seconde), ouvert par les modules CPU, mémoire **et GPU** (les informations de nvtop y sont
fusionnées) et `qs ipc call monitor toggle`. Contenu : processeur (total, température coretemp / k10temp / zenpower, cœurs),
mémoire et swap, réseau, GPU (NVIDIA : `nvidia-smi` — charge, mémoire vidéo, température, consommation, ventilateur, fréquence ;
mémoire vidéo par processus via `nvidia-smi pmon` ; AMD : sysfs), disques locaux (`df`), processus (charge instantanée comme top,
en % d'un cœur ; tri par colonne ; recherche) ; arrêt de **tes** processus seulement, avec confirmation (« End process » : SIGTERM,
« Force quit » : SIGKILL). btop et nvtop ne sont plus nécessaires.

## 12. Couverture de l'API Quickshell (revue du 2026-10-16, à ta demande : « utiliser au maximum ce que Quickshell propose »)

Référence : liste des types de la documentation 0.3.0 (https://quickshell.org/docs/v0.3.0/types/), comparée aux fichiers `qmltypes`
de la version installée (0.3.2) et au code source de Quickshell, Sway 1.12 et Hyprland 0.56.2 (protocoles réellement pris en charge).
Légende : **utilisé** (déjà dans le code), **prévu** (phase indiquée), **ajouté** (nouvel usage décidé par cette revue), **écarté** (raison).

| Module | Types | Statut |
|---|---|---|
| `Quickshell` (cœur) | `ShellRoot`, `Singleton`, `Variants`, `PanelWindow`, `PopupWindow`, `Region`, `PopupAnchor`/`PopupAdjustment`, `Edges`, `ExclusionMode`, `ShellScreen`, `SystemClock`, `QsMenuOpener`/`QsMenuEntry`/`QsMenuHandle` | **utilisé** |
| | `DesktopEntries`, `DesktopEntry`, `DesktopAction` | **utilisé** : lanceur (phase 7, `services/Apps.qml`), menu d'applications (phase 8). `DesktopAction` non affiché (`-no-drun-show-actions`) |
| | `FloatingWindow` | **prévu** : fenêtre de statistiques, sélecteur de fond (phase 8b) |
| | `LazyLoader` | **utilisé** : panneau audio, lanceur, panneau de réglages, menu d'applications ; prévu : statistiques, capture |
| | `ScriptModel` | **utilisé** : listes construites en JavaScript (espaces de travail, tray, réseaux, appareils Bluetooth, disques, pays VPN, notifications, centre) — délégués conservés, données mises à jour sur place |
| | `PersistentProperties` | **utilisé** : historique des notifications (en texte JSON : un tableau JavaScript ne passe pas d'un moteur QML au suivant, « JSValue can't be reassigned to another engine ») et « ne pas déranger » conservés au rechargement de la config |
| | `RetainableLock` | **utilisé** (revue de code) : garde l'image en données d'une notification dans l'historique |
| | `ObjectModel`, `Reloadable`, `Scope`, `Retainable`, `BoundComponent`, `TransformWatcher`, `Intersection`, `QuickshellSettings` | utilisés indirectement ou au besoin ; aucun usage propre identifié |
| | `QsMenuAnchor`, `QsMenuButtonType` | **écarté** : menus du tray dessinés par nous (copie des menus GTK, phase 5) |
| | `ColorQuantizer` | **écarté** : couleurs tirées d'une image, contraire à la charte (aucune couleur inventée) |
| | `EasingCurve` | **après la première version** : pas d'animation pour la parité (THEME § 10) ; animations à ajouter ensuite, au fur et à mesure (ta demande, `BACKLOG.md`) |
| | `ElapsedTimer` | **écarté** : pas de mesure de durée utile |
| `Quickshell.Io` | `Process`, `FileView`, `SplitParser`, `StdioCollector`, `IpcHandler` | **utilisé** |
| | `JsonAdapter`, `JsonObject` | **utilisé** : derniers pays VPN (`vpn.json`, ancien `vpn-recent.json` converti) ; la config machine reste lue à la main (fusion `default.json` + machine) |
| | `Socket`, `SocketServer`, `DataStream`, `DataStreamParser` | **écarté** : les raccourcis passent par `IpcHandler` |
| `Quickshell.I3` | `I3`, `I3IpcListener`, `I3Monitor`, `I3Workspace` | **utilisé** (Sway) |
| `Quickshell.Hyprland` | `Hyprland`, `HyprlandMonitor`, `HyprlandWorkspace`, `HyprlandEvent` | **utilisé** (écrit, à tester) |
| | `HyprlandFocusGrab` | **ajouté** (phase 9) : sous Hyprland, fermeture des panneaux et du calendrier par un clic ailleurs, sans le mécanisme de contournement de Sway |
| | `HyprlandToplevel`, `HyprlandWindow` | au besoin, via `Toplevel` (ci-dessous) |
| | `GlobalShortcut` | **écarté** : raccourcis par `qs ipc` sur les deux compositeurs (un seul mécanisme) |
| `Quickshell.WindowManager` | `WindowManager`, `Windowset`, `WindowsetProjection`, `ScreenProjection` | **évalué, en réserve** (sonde sous Sway, 2026-10-16) : le protocole commun `ext-workspace` déplace et active bien un espace, mais n'indique ni l'espace focalisé, ni l'état vide, ni ne crée d'espace (pas d'API de création dans Quickshell), et son déplacement ne garde pas le focus comme la commande Sway sur laquelle la répartition validée est réglée. Migrer obligerait à mélanger deux sources pour le même état : pas de gain net. Gardé pour Hyprland si le placement en Lua échoue pendant la session de test, ou pour une config Hyprland non-Lua. Note : la liste n'est remplie qu'après le premier accès (initialisation paresseuse). |
| `Quickshell.Wayland` | `WlrLayershell`, `WlrLayer`, `WlrKeyboardFocus` | **utilisé** |
| | `WlSessionLock`, `WlSessionLockSurface` | **prévu** : verrouillage (phase 8b) |
| | `IdleMonitor` | **prévu** : veille des écrans (phase 8b), `respectInhibitors` |
| | `IdleInhibitor` | **utilisé** (phase 8) : bascule « garder l'écran allumé » du panneau de réglages, posée sur chaque barre |
| | `ScreencopyView`, `ToplevelManager`, `Toplevel` | **ajouté** (phase 8b) : outil de capture **entièrement natif** (aperçu figé de l'écran, sélection de zone, choix d'une fenêtre avec aperçu, enregistrement par `grabToImage`) au lieu de `grim`/`slurp` ; liste des fenêtres pour le menu d'applications si utile |
| | `ShortcutInhibitor` | **écarté** : le verrouillage bloque déjà les raccourcis (protocole de verrouillage) |
| | `BackgroundEffect` | **écarté** : flou d'arrière-plan absent de la charte, et Sway 1.12 ne le prend pas en charge |
| `Quickshell.Widgets` | `IconImage` | **utilisé** |
| | `ClippingRectangle`, `WrapperRectangle`, `WrapperItem`, `WrapperMouseArea`, `MarginWrapperManager`… | au besoin (image arrondie : pochette, avatar du verrouillage / greeter) |
| `Quickshell.DBusMenu` | `DBusMenuHandle`, `DBusMenuItem` | **utilisé** (menus du tray) |
| `Quickshell.Bluetooth` | tous | **utilisé** (phase 5) |
| `Quickshell.Networking` | `Networking`, `NetworkDevice`, `WifiDevice`, `WifiNetwork`… | **utilisé** (phase 5) |
| | `NMSettings` | **ajouté** : connexions enregistrées de NetworkManager (dont VPN NetworkManager, noté au BACKLOG) dans le panneau réseau |
| `Quickshell.Services.Mpris` | tous | **utilisé** |
| `Quickshell.Services.Notifications` | tous | **utilisé** (phase 6) |
| `Quickshell.Services.Pipewire` | `Pipewire`, `PwNode`, `PwNodeAudio`, `PwObjectTracker` | **utilisé** |
| | `PwNodePeakMonitor` | **utilisé** : niveau capté par chaque entrée (panneau audio) |
| | `PwLink`, `PwLinkGroup`, `PwNodeLinkTracker` | **écarté** : pas de routage audio dans le bureau |
| `Quickshell.Services.SystemTray` | tous | **utilisé** |
| `Quickshell.Services.UPower` | `UPower`, `UPowerDevice` | **utilisé** (batterie, laptop) |
| | `PowerProfiles` | **utilisé** (phase 8, ta demande) : **trois boutons** de profil d'énergie (économie / équilibré / performance) dans la fenêtre de réglages (phase 8), sur toutes les machines ; nécessite `power-profiles-daemon` (dépendance principale, service à activer) |
| `Quickshell.Services.Polkit` | `PolkitAgent`, `AuthFlow` | **prévu** : agent polkit (phase 8b) |
| `Quickshell.Services.Pam` | `PamContext` | **prévu** : verrouillage (8b), greeter (12) |
| `Quickshell.Services.Greetd` | `Greetd` | **prévu** : écran de connexion (phase 12, § 10.4) |

Restent hors Quickshell, faute d'équivalent : `nvidia-smi` (GPU), `checkupdates`, `nordvpn`, `busctl` / `gdbus` /
`udisksctl` (UDisks2 : pas d'accès D-Bus générique en QML), `bluetoothctl` (agent d'appairage), `notify-send` (envoi, indépendant du serveur).
`grim` reste un outil de développement (`scripts/shot.sh`) ; `slurp` reste pour le portail de partage d'écran (`xdg-desktop-portal-wlr`).

### 12.1 Deuxième passe : outils externes et manques couverts par Quickshell (2026-10-16)

Chaque commande lancée par le code, chaque élément de l'inventaire (autostart, raccourcis, § 10.1 d'INVENTORY) confronté à l'API.
Tes choix (tous retenus), faits avant la phase 7 :

| Élément | Avant | Natif |
|---|---|---|
| Clic droit sur le volume | `pavucontrol` | **panneau audio** (`Pipewire` : sortie, entrée, volume par application, micro) ; `pavucontrol` gardé derrière un bouton « Advanced… » |
| Molette sur le module média | `playerctld shift / unshift` (sans effet visible : le module suit Spotify) | **choix du lecteur** parmi les lecteurs MPRIS (`Mpris.players`) ; le module et les touches média suivent le lecteur choisi ; `playerctl` n'est plus une dépendance |
| Touches volume / luminosité | aucun retour visuel | **OSD** (fenêtre temporaire, style des panneaux), déclenché par `qs ipc` |
| Icône réseau | nm-applet ne signale pas l'absence d'Internet | **connexion limitée** (`Networking.connectivity`) : icônes Papirus `*-limited` / `*-no-route` |
| Batterie (laptop) | aucune alerte | **notification** aux seuils bas et critique (`UPower`) |

Restent externes, avec la raison :
- `nm-connection-editor` (édition complète des connexions : `NMSettings` ne couvre pas tout), `btop` / `nvtop` (remplacés par la fenêtre
  de statistiques en phase 8b), `brightnessctl` (écriture du rétroéclairage : pas d'accès D-Bus générique ni de droits en QML),
  `xdg-open`, `notify-send` (envoi indépendant du serveur), `wl-copy` (le presse-papiers de Quickshell, `clipboardText`, ne gère que le
  texte : les captures copient des images) ;
- hors shell : bascule HDR (commande du compositeur ; interrupteur possible dans le futur panneau de réglages rapides, phase 8),
  autostart des applications (compositeur), choix de l'écran pour le partage d'écran (`slurp` pour `xdg-desktop-portal-wlr` ;
  `BACKLOG.md`), commandes `sh` qui listent des fichiers (icônes, rétroéclairage).

### 12.2 Troisième passe : propriétés inutilisées, programmes installés, fonctions sans équivalent (2026-10-16)

Angles nouveaux : membres des types déjà utilisés (`MprisPlayer`, `Notification`, `UPowerDevice`, `Toplevel`…), paquets de bureau
installés mais absents de l'inventaire (`hyprpicker`, `colorpicker`, `wdisplays`, `wpaperd`, `azote`, `nwg-look`, `lightdm`), et fonctions
qu'aucun outil n'assure aujourd'hui. Tes choix :

| Ajout | Moyen | Quand |
|---|---|---|
| **Carte média** dans le centre de notifications : pochette, titre, artiste, position cliquable, précédent / lecture / suivant | `MprisPlayer` (`trackArtUrl`, `position`, `length`, `canSeek`…), `ClippingRectangle` | fait |
| **Sélecteur de couleur** (remplace `hyprpicker`, lancé à la main, Hyprland seulement) : écran figé, loupe, code `#rrggbb` copié | `ScreencopyView`, `Quickshell.clipboardText` | phase 8b (avec la capture) |
| **Verrouillage avant la veille**, **sur laptop seulement** (ta précision) | signal `PrepareForSleep` de logind suivi par `gdbus monitor` (comme UDisks2) ; actif si une batterie de laptop est détectée, réglable par la config machine | phase 8b |
| **Bascules HDR et VRR** dans la fenêtre de réglages (en plus de `$mod+d` pour le HDR) | commandes du compositeur (Sway : `output … hdr`, `adaptive_sync` ; Hyprland : règles d'écran) | phase 8 |
| **Vue des fenêtres** (aperçus en direct, clic pour y aller, façon « Activités » de GNOME) | `ToplevelManager`, `Toplevel`, `ScreencopyView` | après la première version (`BACKLOG.md`) |

Écartés : réponse directe dans les notifications (`inlineReply`) — WhatsApp et Discord tournent dans Chromium, qui ne la propose pas ;
`wdisplays` (disposition des écrans) — Quickshell n'a pas d'API de configuration des sorties ; historique du presse-papiers —
`clipboardText` ne lit le presse-papiers que lorsqu'une fenêtre Quickshell a le focus ; batteries des périphériques — UPower n'en voit
aucun ici, et celle des appareils Bluetooth est déjà dans leur panneau.
Note de test : Spotify ignorait toute commande MPRIS ce jour-là (même envoyée directement par D-Bus) ; boutons et position vérifiés avec
un faux lecteur MPRIS.

### 12.3 Quatrième passe : actions au clavier et inventaire relu (2026-10-16)

Chaque raccourci de Sway et d'Hyprland confronté aux commandes `qs ipc` (tous les raccourcis passeront par elles en phase 10) :
- **VPN** (`$mod+u` = `nordvpn c Netherlands`, `$mod+i` = `nordvpn d`) : il manquait la commande → `qs ipc call vpn connect [pays]`
  (sans pays : dernier pays utilisé) et `vpn disconnect`. Le choix entre « Netherlands » et « dernier pays » se fera en phase 10.
- **HDR** (`$mod+d` nomme DP-1 et DP-3 en dur) : Sway indique les écrans compatibles (`features.hdr` : DP-1, DP-3 ; DP-2 non) et ceux
  qui gèrent le VRR (`features.adaptive_sync`) → commandes `qs ipc call display toggleHdr` / `toggleVrr` sur les écrans compatibles, sans nom en dur, qui
  serviront aussi aux bascules de la fenêtre de réglages (phase 8 ; Hyprland en phase 9).
- Les autres raccourcis sont du compositeur (espaces, fenêtres, applications) ou déjà prévus : lanceur (phase 7), power menu (phase 8),
  captures (phase 8b), volume / micro / luminosité / média (faits), sortie audio suivante (`audio cycleSink`).

Inventaire relu (§ 10.2, § 11.4 d'INVENTORY) — tes choix :
- **Réseaux privés** : section « Private networks » dans le panneau réseau (fait) — Tailscale par `tailscale status --json` (sans
  droits), ZeroTier par ses interfaces `zt*` (`zerotier-cli` exige le jeton de root) ; lecture seule, masquée si absents.
- **Autostart XDG** (`~/.config/autostart`) : laissé tel quel (applications de démarrage dans la config du compositeur).

### 12.4 Cinquième passe : modules du code source et singleton `Quickshell` (2026-10-16)

- Les modules installés (0.3.2) sont exactement ceux de la page 0.3.0, plus `Quickshell.X11` (sans objet sous Wayland) : aucun module
  non documenté à exploiter.
- Singleton `Quickshell` : `reload()` → commande `qs ipc` pour remplacer `$mod+Ctrl+W` (`killall waybar && waybar`) à la bascule
  (phase 10) ; `inhibitReloadPopup()` → garder ou masquer la fenêtre « config rechargée » sur le bureau final (décision en phase 10) ;
  `cachePath` / `dataPath` → miniatures du sélecteur de fond (phase 8b) ; le reste est déjà utilisé (`env`, `execDetached`, `iconPath`,
  `shellPath`, `statePath`, `screens`, `clipboardText`).
- **Aucune fonction nouvelle trouvée** : les passes convergent.
