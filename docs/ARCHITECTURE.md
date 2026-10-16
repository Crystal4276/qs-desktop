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
   100 ms plus tard (focus à jour), il est déplacé sur son écran ; focalisé, il le reste ; créé en arrière-plan, le focus revient où il était.
   Aucune correction ne crée d'espace (pas de boucle possible).
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
réactivation, débranchement, écran de droite puis de gauche éteints (2 écrans, puis 1), retour à la référence.
Contrôles après chacun : répartition calculée = règle recalculée indépendamment (jq), espaces sur le bon écran, focus inchangé,
espace visible conservé ; à la fin, aucune fenêtre perdue, et nombre de commandes de placement borné (pas de boucle).

Pièges relevés :
- `swaymsg` et `Quickshell.I3` lisent **`I3SOCK` avant `SWAYSOCK`** : les deux doivent viser la session de test (garde-fou dans le script) ;
- un test lancé dans la vraie session déplace les espaces de l'utilisateur et se fait fausser par son activité : à proscrire ;
- les écrans virtuels portent tous la description « Unknown Unknown Unknown » : la répartition **imposée** par description se teste
  avec les écrans réels (fait une fois en phase 3, réussi) ;
- un écran virtuel créé pendant que swayidle a éteint les écrans hérite de `power off`.

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
      "left":  [["menu"], ["workspaces"], ["mpris", "cava", "volume", "slider"]],
      "right": [["updates"], ["gpu", "cpu", "memory"], ["clockDate"], ["tray", "power"]]
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
- `mediaPlayer` *(phase 4)* : lecteur suivi par le module mpris, nom D-Bus après `org.mpris.MediaPlayer2.` (option `player` de Waybar).

- Fusion **au premier niveau** : une clé du fichier machine remplace entièrement celle de `default.json` (pas de fusion profonde : plus prévisible).
- `bars` : par description d'écran, sinon par rôle (`primary` / `secondary`) — un écran inconnu reçoit donc toujours une barre.
  Chaque côté est une liste de **pilules**, chaque pilule une liste de modules (`THEME.md` § 3, « Groupes de pilules ») :
  la config décrit directement les groupes Waybar, sans noms de groupes intermédiaires.
- Modules : `menu`, `workspaces`, `mpris`, `cava`, `volume`, `slider`, `updates`, `gpu`, `cpu`, `memory`, `clock` (heure seule),
  `clockDate` (heure + date, barre principale), `network`, `tray`, `power`, `battery`, `backlight` (laptop).
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
Inter, DejaVu Sans et Noto Sans Mono restent des paquets (`deps/`). `install.sh` vérifie avec `fc-list` que chaque police de `THEME.md`
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
Échap ; clic n'importe où ailleurs, **qui atteint aussi ce qui est dessous** (fenêtre, module) ; pointeur hors du calendrier et de l'horloge pendant 5 s.

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
Limites : après un clic dans le calendrier, Échap ne marche plus (focus perdu) ; la fermeture automatique (5 s) s'en charge.
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
| R8 | `grim`/`slurp` au départ ; **outil de capture en fenêtre Quickshell** (écran entier, un écran, une fenêtre, une zone ; modèle de l'outil de capture GNOME), phase 8b. |
| R9 | Touches volume / média / luminosité via `qs ipc`, phase 10. |
| R10 | Écran de connexion : **phase 12, tout à la fin**, à concevoir ensemble. **SDDM abandonné** : greeter Quickshell indépendant (`Greetd`), reprenant uniquement l'apparence du thème `catppuccin-mocha-green` (thème lui-même écrit en QML : `/usr/share/sddm/themes/catppuccin-mocha-green/`, paquet AUR `catppuccin-sddm-theme-mocha` ; fond `backgrounds/wall.png`, police Noto Sans 9, horloge, icônes power/reboot/sleep). Aperçu : `docs/reference/sddm-catppuccin-preview.png` (aperçu générique du paquet ; la variante installée est verte). |
| R11 | Au démarrage : 1 / 4 / 7. |

### 10.1.1 Mise en œuvre de la phase 5 (2026-10-16)

- **Placement** : modules natifs dans la pilule du tray, après les applications (NordVPN, réseau, disques, Bluetooth) ; un clic ouvre
  leur **panneau** (`Panel.qml`, style du calendrier). L'icône StatusNotifier d'une application remplacée (nm-applet, blueman,
  udiskie, NordVPN) est masquée quand son module natif est présent (pas de doublon : ta demande ; utile aussi après la bascule si
  l'une d'elles est lancée par ailleurs) ; sans module natif (ex. NordVPN absent), l'icône de l'application reste.
- **Popups** : panneaux et menus du tray sont des popups « grab » (clavier pour la saisie) ; wlroots les ferme au clic sur une autre
  application (ce clic n'est pas transmis, comme les menus GTK), un clic sur une barre les ferme (`BarState.closePopups`). Un popup
  affiché ne se redimensionne pas proprement sous Sway : les menus n'apparaissent qu'avec leurs entrées, les panneaux ont une fenêtre de
  taille fixe et une zone de clic (`mask`) limitée au cadre.
- **Réseau** (R5) : `Quickshell.Networking` (filaire, Wi-Fi : interrupteur, réseaux, mot de passe, oubli) ; édition dans `nm-connection-editor`.
- **Bluetooth** (R6) : `Quickshell.Bluetooth` ; appairage par `bluetoothctl` lancé pour l'occasion, son agent servant à sa propre commande
  `pair` (l'agent par défaut de blueman n'est pas touché) ; demandes affichées dans le panneau, jamais acceptées automatiquement.
- **Disques** (R7) : `busctl` / `gdbus monitor` / `udisksctl` ; règles et textes d'udiskie (montage automatique, notifications, images
  disque en boucle prises en charge).
- **NordVPN** (§ 11.4) : commande `nordvpn` ; derniers pays utilisés (historique local) et recherche sur tous les pays.

### 10.2 Bluetooth : appairage et code PIN

Vérifié :
- Quickshell 0.3.2 parle à BlueZ (`org.bluez.Adapter1`, `Device1`, `Battery1` : lister, connecter, appairer, oublier), mais **n'implémente pas d'agent
  d'appairage** (`org.bluez.Agent1` absent du binaire).
- `man 5 org.bluez.Device`, méthode `Pair()` : *« In case there is no application agent and also no default agent present, this method will fail. »*
  Aujourd'hui c'est **blueman** qui fournit l'agent. Sans lui et sans autre agent, **aucun appairage ne fonctionne**, même sans code.
  Se reconnecter à un appareil **déjà appairé** n'a pas besoin d'agent.

Solution proposée (une dépendance officielle de plus, `bluez-utils`) : pendant un appairage seulement, Quickshell lance `bluetoothctl`
comme agent (`agent KeyboardDisplay`, `default-agent`), lit ses demandes (« Confirm passkey 123456 (yes/no) », « Enter PIN code ») et les affiche
dans une fenêtre de la charte ; la réponse est renvoyée à `bluetoothctl`. L'agent s'arrête à la fermeture de la fenêtre.

Dangers et parades :
- **Accepter automatiquement** (agent « oui à tout ») permettrait à un appareil à portée de s'appairer sans qu'on le voie → **jamais** d'acceptation
  automatique ; chaque demande passe par la fenêtre.
- **Agent permanent** : il accepterait aussi les demandes venues d'un téléphone à proximité → agent actif **uniquement** pendant un appairage lancé par toi.
- **Format de sortie de `bluetoothctl`** susceptible de changer entre versions → messages attendus centralisés dans le service, testés en phase 5
  avec un vrai appareil (code à confirmer et appareil sans code).

### 10.3 Disques amovibles sans udiskie

Je m'étais trompé : Quickshell n'a pas d'accès D-Bus générique en QML, mais trois outils système suffisent (vérifié en lecture sur cette machine) :
- **état** : `busctl --system --json=short call org.freedesktop.UDisks2 … GetManagedObjects` → JSON directement lisible en QML (14 systèmes de fichiers vus) ;
- **branchement / débranchement** : `gdbus monitor --system --dest org.freedesktop.UDisks2` (fonctionne sans droits ; `busctl monitor`, lui, exige root) ;
- **actions** : `udisksctl mount | unmount | power-off | unlock` (déverrouillage LUKS : phrase de passe saisie dans une fenêtre de la charte).

Dépendances : `udisks2` (déjà requis par udiskie), `glib2` (`gdbus`), `systemd` (`busctl`). Montage automatique à l'insertion et notifications reproduits
dans le service `Disks`. Les volumes système (`HintSystem`, `HintIgnore`) sont ignorés, comme le fait udiskie.

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

Clic : `nvtop` (gère AMD, Intel et NVIDIA). Ce desktop n'a qu'un GPU NVIDIA : les branches AMD et Intel seront testées avec une fausse arborescence sysfs
(dossier de test passé au service), puis sur une vraie machine quand l'occasion se présente — à signaler dans le rapport de phase 4.

**Moniteur système** : au départ, les clics CPU / mémoire ouvrent `btop` (parité). Ensuite, une **fenêtre Quickshell de statistiques système**
(équivalent de btop : CPU par cœur, mémoire et swap, températures, GPU, disques, réseau, processus) — ajoutée à la phase 8b, en dernier.
Les données viennent de `/proc` et `/sys` (déjà lus par les services de la barre) ; la liste des processus et l'arrêt d'un processus sont à concevoir à ce moment-là.
