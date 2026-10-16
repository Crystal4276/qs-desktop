# CLAUDE.md — Migration du bureau vers Quickshell

## Mission

Remplacer toute la couche « shell » de mon bureau (Waybar, Dunst, Rofi, menus Rofi, tray/status notifier, scripts divers) par **une seule configuration Quickshell** (QML), versionnée dans ce dépôt.

Quatre objectifs, dans cet ordre :

1. **Parité fonctionnelle et visuelle complète** avec mon bureau actuel, dans le respect strict de ma charte graphique. On reproduit d'abord, on améliore ensuite.
2. **Écrans dynamiques** : le bureau s'adapte au nombre d'écrans connectés et actifs, et répartit automatiquement mes 9 espaces de travail entre eux.
3. **Rassembler tout ce qui est dispersé** (scripts, thèmes, configs Sway/Hyprland liées au bureau) dans ce dépôt, analysé et rangé.
4. **Portabilité** : sur une nouvelle machine (ex. un laptop), je clone le dépôt, je lance un script d'installation, et j'ai mon bureau. Les dépendances sont listées et installables avec pacman (et documentées pour d'autres distributions).

Le travail se fait **par phases**, une à la fois, chacune vérifiée avant de passer à la suivante.

## Machine actuelle

- Arch Linux, CPU Intel i9-9900K, GPU Nvidia RTX 2080 (pilotes propriétaires).
- Compositeurs : **Sway** (principal) et **Hyprland** (occasionnel). La config doit fonctionner sur les deux.
- Trois écrans : ultrawide central 3440x1440 @100 Hz sur **DP-2**, encadré de deux écrans 27" 4K en **scale 1.5**. Vérifier les noms réels avec `swaymsg -t get_outputs` / `hyprctl monitors`.
- 9 espaces de travail répartis 3 / 3 / 3 entre les trois écrans.
- Quickshell est déjà installé. Vérifier la version avec `qs --version` en début de projet et la noter dans `PROGRESS.md`.

Cette machine est **la référence, pas une hypothèse codée en dur** : voir « Écrans dynamiques » et « Portabilité ».

## Règles absolues

1. **Ma config actuelle est en lecture seule** jusqu'à la phase 10 : `~/.config/sway`, `~/.config/hypr`, `~/.config/waybar`, `~/.config/dunst`, `~/.config/rofi`, `~/.config/kanshi` s'il existe, et tous les scripts qu'elles appellent. On lit, on ne modifie pas. Agir sur le compositeur en cours d'exécution via IPC (`swaymsg`, `hyprctl`) est autorisé pour tester, à condition de remettre l'état initial ensuite.
2. **Ne jamais me laisser avec un bureau cassé.** Tout arrêt temporaire de Waybar ou Dunst, tout écran virtuel créé ou espace de travail déplacé pour tester doit être restauré avant la fin de la session (voir « Coexistence »).
3. **Respect de la charte graphique.** Aucune couleur, police, taille, marge, arrondi ou icône inventés : tout vient de ma config actuelle (voir « Charte graphique »). Si une valeur manque, demander plutôt que choisir.
4. **Pas de `sudo`, pas d'installation de paquets** sans me demander. Si un paquet manque, lister ce qu'il faut et pourquoi.
5. **Ne pas inventer d'API Quickshell.** L'API évolue entre versions. Consulter la doc correspondant à la version installée (https://quickshell.org/docs/) avant d'utiliser un type ou une propriété dont tu n'es pas sûr. En cas d'erreur QML, lire le log plutôt que deviner.
6. **Rien de spécifique à cette machine en dur** : noms d'écrans, nombre d'écrans, chemins absolus vers `/home/…`, présence d'un GPU Nvidia. Tout passe par la détection ou par la config par machine.
7. **Simplicité.** Pas de framework générique, pas d'abstraction « au cas où ». Une abstraction n'existe que si elle sert au moins deux usages réels (ex. Sway + Hyprland, desktop + laptop). Les idées d'amélioration vont dans `BACKLOG.md`, pas dans le code.

## Autonomie

Dans une phase, travaille de façon autonome : lis, code, teste, corrige, committe. Ne me demande que pour de vraies décisions (choix d'UX non déductible de ma config actuelle, paquet à installer, action irréversible). **À la fin de chaque phase, arrête-toi** et donne-moi un rapport court + les captures avant/après. Je valide, puis on passe à la suivante.

## Charte graphique

Ma charte est répartie dans plusieurs fichiers, notamment des **CSS**. À explorer au minimum :

- `~/.config/waybar/style.css` et tout fichier qu'il `@import` ;
- le thème Rofi (`~/.config/rofi/*.rasi` et fichiers importés) ;
- `~/.config/dunst/dunstrc` (couleurs par urgence, police, bordures, padding, icônes) ;
- couleurs et bordures de fenêtres dans les configs Sway/Hyprland ;
- tout fichier de palette partagé (ex. `colors.css`, `colors.rasi`, fichiers générés par un outil de thème comme pywal/wallust/matugen) — chercher avec `grep`/`find` dans `~/.config` ;
- GTK/Qt/icônes/curseur s'ils influencent le rendu (`~/.config/gtk-3.0`, `gtk-4.0`, `qt5ct`/`qt6ct`, thème d'icônes utilisé par le tray et le lanceur) ;
- polices utilisées (`fc-list` pour vérifier qu'elles sont installées, y compris les Nerd Fonts / polices d'icônes).

En phase 0, produire `docs/THEME.md` : la palette complète (nom → valeur → où elle est utilisée), polices et tailles, marges, arrondis, opacités, animations éventuelles, thème d'icônes. `config/Theme.qml` est la traduction fidèle de ce document, et rien d'autre.

Si la palette vient d'un outil de génération (pywal…), ne pas la recopier en dur : faire lire le fichier généré par `Theme.qml`, pour que le changement de thème reste possible.

## Écrans dynamiques

Le bureau doit s'adapter **à chaud** à l'ensemble des écrans **connectés et activés** (un écran désactivé, comme l'écran du laptop capot fermé, ne compte pas).

### Comportement attendu

- **9 espaces de travail**, toujours numérotés 1 à 9 ; les raccourcis `$mod+1…9` ne changent pas, seule leur répartition sur les écrans change.
- **Répartition en blocs contigus**, écrans triés de gauche à droite selon leur position :
  - 1 écran → 1-9 ;
  - 3 écrans → 3 / 3 / 3, en reproduisant **exactement** l'attribution actuelle de mon desktop (la relever en phase 0) ;
  - 2 écrans, 4 écrans ou plus : proposer une règle en phase 0 (ex. 5 / 4 avec le reste sur l'écran principal) et me la faire valider.
- La config par machine peut imposer une répartition précise pour un ensemble d'écrans donné ; sinon, la règle générale s'applique.
- Cas à gérer et à tester :
  - laptop seul ;
  - laptop + un ou plusieurs écrans externes ;
  - laptop capot fermé ou écran interne éteint, avec seulement des écrans externes ;
  - desktop avec ses trois écrans ;
  - un écran du desktop éteint ou débranché ;
  - branchement ou débranchement pendant que des fenêtres sont ouvertes.
- Au changement d'écrans : aucune fenêtre perdue, les espaces de travail d'un écran disparu migrent vers les écrans restants, l'espace de travail focalisé le reste si possible.
- Les barres apparaissent et disparaissent avec les écrans. Chaque barre n'affiche que les espaces de travail de son écran.

### Mise en œuvre

Deux problèmes distincts, à ne pas mélanger :

1. **Configuration des sorties** (activer/désactiver, résolution, taux de rafraîchissement, échelle, position) selon les écrans présents. Sway n'a pas de profils natifs ; **Kanshi** (wlr-output-management) gère des profils par ensemble d'écrans et fonctionne avec Sway et Hyprland. Hyprland sait aussi le faire en partie avec ses règles `monitor`. En phase 0, regarder ce que j'utilise déjà, puis proposer une seule approche commune aux deux compositeurs, avec justification.
2. **Répartition des espaces de travail** : une seule implémentation, utilisée sous Sway et Hyprland. Candidats :
   - un service Quickshell `services/Outputs.qml`, qui réagit aux changements d'écrans (Quickshell tourne déjà, aucun démon de plus) ;
   - un script lancé par Kanshi (`exec` de profil).

   Choisir en phase 0 et le justifier dans `ARCHITECTURE.md`. Un seul mécanisme doit faire ce travail, jamais deux en concurrence.

Points techniques :

- La source de vérité est la liste des sorties **actives** renvoyée par le compositeur (`swaymsg -t get_outputs` → `active: true`, `hyprctl monitors`), pas une hypothèse.
- Prévoir un délai anti-rebond : un branchement déclenche plusieurs événements, et Kanshi peut être en train de reconfigurer.
- Côté compositeur :
  - **Sway** : `workspace N output X` pour l'attribution, plus déplacement des espaces existants (`workspace N; move workspace to output X`) ;
  - **Hyprland** : `hyprctl keyword workspace N,monitor:X` et `hyprctl dispatch moveworkspacetomonitor N X`.
- Dans la config par machine, identifier les écrans par **description** (marque/modèle/numéro de série), pas par connecteur : `DP-2` peut changer de nom sur un dock ou un autre câble.
- Capot du laptop : `bindswitch lid:on/off` sous Sway, `bindl = , switch:on:Lid Switch` sous Hyprland, ou via Kanshi, selon l'approche choisie.

### Tests sans débrancher de câble

- **Sway** : `swaymsg create_output` crée un écran virtuel `HEADLESS-N`. On peut le positionner (`swaymsg output HEADLESS-1 pos … res …`) et le capturer avec `grim -o HEADLESS-1`. Le retirer ensuite avec `swaymsg output HEADLESS-1 unplug`.
- **Hyprland** : `hyprctl output create headless` / `hyprctl output remove <nom>`.
- `swaymsg output <nom> disable/enable` simule un écran éteint. À utiliser sur les écrans réels seulement après m'avoir prévenu, et toujours rétablir.
- Écrire un script `scripts/test-outputs.sh` qui :
  1. enchaîne plusieurs scénarios (ajout et retrait d'écrans virtuels, désactivation) ;
  2. après chaque étape, vérifie la répartition attendue via `swaymsg -t get_workspaces` ou `hyprctl workspaces -j` ;
  3. remet tout en état à la fin, même en cas d'échec (`trap`).

## Scripts dispersés

J'ai des scripts liés au bureau un peu partout. Les retrouver **tous** en phase 0 :

- suivre chaque `exec`, `bindsym … exec`, `exec-once`, `bind = … exec`, `on-click`, `exec` de module Waybar, script Rofi, `script` de règle Dunst, `exec` de profil Kanshi, et remonter jusqu'aux fichiers réels ;
- explorer aussi `~/.local/bin`, `~/bin`, `~/scripts`, `~/.config/*/scripts`, les services et timers utilisateur (`~/.config/systemd/user`), et l'autostart (`~/.config/autostart`) ;
- lire chaque script en entier, y compris ceux qu'il appelle à son tour.

Pour chacun, une fiche dans `docs/SCRIPTS.md` :

| Champ | Contenu |
|---|---|
| Chemin | emplacement actuel |
| Appelé par | raccourci, module, autre script, service… |
| Rôle | ce qu'il fait réellement |
| Dépendances | commandes et paquets utilisés |
| Décision | **QML natif** (remplacé par un service Quickshell), **gardé** (déplacé dans `scripts/` du dépôt et nettoyé), ou **abandonné** (mort ou redondant — à confirmer avec moi) |

Les scripts gardés vivent dans le dépôt et sont appelés par des chemins relatifs au dépôt ou installés dans le `PATH` par l'installeur — jamais par un chemin absolu personnel.

## Portabilité

Le dépôt doit devenir **la source unique de mon bureau** :

- Quickshell (cette config), scripts gardés, fichiers de thème, config Kanshi si elle est retenue ;
- en fin de projet, les configs Sway et Hyprland (au moins tout ce qui concerne le bureau : raccourcis, autostart, apparence, sorties), versionnées ici.

### Config par machine

- Par défaut, tout est détecté : écrans (voir « Écrans dynamiques »), batterie via `UPower`, Wi-Fi/réseau, présence de rétroéclairage, GPU.
- Un module dont le matériel est absent se masque (ex. module GPU Nvidia sur un laptop Intel, module batterie sur le desktop).
- Les réglages qui ne se détectent pas vont dans un fichier par machine, choisi selon le hostname, avec des valeurs par défaut raisonnables pour un écran unique. Exemples : quels modules sur quel écran, écran principal, répartition imposée des espaces de travail. Le fichier de cette machine-ci reproduit exactement mon setup actuel.

### Dépendances

- Tenir à jour **dès la phase 1** un dossier `deps/` :
  - `deps/arch-pacman.txt` : paquets des dépôts officiels, un par ligne, avec un commentaire indiquant à quoi il sert ;
  - `deps/arch-aur.txt` : paquets AUR (séparés, car ils demandent un helper) ;
  - `deps/optional.txt` : dépendances liées au matériel ou à un module optionnel (ex. `nvidia-utils` pour le module GPU) ;
  - `deps/README.md` : tableau de correspondance des noms de paquets pour au moins Fedora et Debian/Ubuntu, avec mention des paquets non disponibles sur ces distributions et de leur alternative.
- Chaque fois qu'un composant utilise une commande externe, une police, un thème d'icônes ou un module Quickshell, la dépendance est ajoutée dans le même commit.
- Les polices et le thème d'icônes sont des dépendances comme les autres.

### Installation

- `install.sh` à la racine, **idempotent** (relançable sans dégât) :
  1. détecte la distribution ; sur Arch, propose d'installer les paquets de `deps/` (`pacman -S --needed`, puis AUR via `paru` ou `yay` s'ils sont présents) ; ailleurs, affiche la liste à installer à partir de `deps/README.md` ;
  2. sauvegarde toute config existante avant de la remplacer (`~/.config/<x>.bak-<date>`) ;
  3. crée les liens symboliques (`~/.config/quickshell/desktop`, configs Sway/Hyprland/Kanshi, scripts dans `~/.local/bin`) ;
  4. génère le fichier de config machine s'il n'existe pas pour ce hostname ;
  5. met en place les fichiers système du bureau, après confirmation (`sudo`) et avec sauvegarde : écran de connexion greetd + greeter Quickshell (config greetd, PAM avec déverrouillage de `gnome-keyring`, activation du service à la place de l'ancien gestionnaire) — ajouté en phase 12 ;
  6. option `--dry-run` qui affiche tout sans rien modifier ;
  7. option `--uninstall` qui retire les liens et restaure les sauvegardes (y compris l'ancien gestionnaire de connexion).
- But : sur une installation neuve d'Arch (ex. le laptop), cloner le dépôt et lancer `install.sh` suffit à déployer tout le bureau, écran de connexion compris.
- Si `podman` ou `docker` est disponible, tester `install.sh --dry-run` et la résolution des paquets dans un conteneur `archlinux` propre. On ne peut pas y tester Wayland, mais on vérifie que les noms de paquets existent.

## Structure du dépôt

```
shell.qml                 # point d'entrée Quickshell
config/Theme.qml          # singleton : traduction fidèle de docs/THEME.md
config/Settings.qml       # singleton : options + chargement de la config machine
hosts/                    # config par machine (<hostname>.json) + default.json
services/                 # singletons d'état : Compositor, Outputs, Audio, Network, Notifs, SystemStats, Battery…
modules/bar/              # barre et ses widgets
modules/notifications/    # popups + historique
modules/launcher/         # lanceur d'applications
modules/menus/            # menus (power, etc.)
modules/osd/              # éventuels OSD (volume, luminosité)
scripts/                  # scripts gardés + outils de dev (dev.sh, shot.sh, crop.sh, test-outputs.sh)
dotfiles/sway/            # config Sway (phase 10)
dotfiles/hypr/            # config Hyprland (phase 10)
dotfiles/kanshi/          # profils Kanshi, si retenu
deps/                     # listes de dépendances (voir « Portabilité »)
install.sh
docs/INVENTORY.md         # inventaire exhaustif de l'existant
docs/THEME.md             # charte graphique extraite
docs/SCRIPTS.md           # fiches des scripts
docs/ARCHITECTURE.md      # choix d'architecture
docs/reference/           # captures de référence de l'existant
README.md                 # installation sur une nouvelle machine, en quelques lignes
PROGRESS.md               # journal d'avancement — à lire en début de chaque session
BACKLOG.md                # améliorations futures, hors parité
```

Adapter si l'inventaire le justifie, mais documenter le changement dans `ARCHITECTURE.md`.

## Conventions QML

- Services en `pragma Singleton` ; les widgets ne lisent que les services, jamais de `Process` dispersés dans l'UI.
- Aucune couleur, police ou taille codée en dur hors de `Theme.qml`.
- Multi-écran via `Variants { model: Quickshell.screens }` : une barre par écran actif, créée et détruite à chaud. Les modules affichés sur chaque écran viennent de la config machine, avec un repli raisonnable pour un écran inconnu.
- **Compositeur** : `services/Compositor.qml` expose une interface unique (espaces de travail, fenêtre active, mode, sortie focalisée, liste des sorties) et s'appuie sur `Quickshell.I3` sous Sway et `Quickshell.Hyprland` sous Hyprland. Détection via `SWAYSOCK` / `HYPRLAND_INSTANCE_SIGNATURE`.
- Préférer les services natifs de Quickshell aux scripts externes : `Quickshell.Services.Pipewire` (audio), `.SystemTray`, `.Notifications`, `.Mpris`, `.UPower`, `DesktopEntries`, etc. Garder un script externe seulement si aucun équivalent natif n'existe (ex. `nvidia-smi` pour le GPU).
- Tout ce qui doit être déclenché par un raccourci clavier passe par un `IpcHandler` (`qs ipc call <target> <fonction>`).
- Commentaires courts, en anglais ou en français, mais cohérents dans un même fichier.

## Environnement de développement

- Nom de config : `desktop`. Pendant les phases 1 à 9, lien `~/.config/quickshell/desktop` → ce dépôt (le seul lien créé avant la phase 10).
- Lancer l'instance de dev depuis le dépôt : `qs -p . > /tmp/qs-dev.log 2>&1 &`. Quickshell recharge à chaud à chaque sauvegarde ; surveiller `/tmp/qs-dev.log` après chaque modif.
- Fournir en phase 1 dans `scripts/` :
  - `dev.sh` : (re)lance l'instance de dev proprement (tue l'ancienne, relance, affiche les erreurs) ;
  - `shot.sh <nom> [sortie|géométrie]` : capture avec `grim` (`grim -o <sortie> …` ou `grim -g "x,y wxh" …`) dans `.shots/` (ignoré par git) ;
  - `crop.sh` : recadre une capture (ImageMagick) sur la zone utile — les captures pleine résolution des trois écrans sont trop grandes pour être comparées utilement.

### Coexistence avec le bureau actuel

- **Waybar** : pour comparer, masquer/afficher avec `pkill -SIGUSR1 waybar` (bascule de visibilité, non destructif). Toujours la réafficher en fin de session.
- **Dunst** : il possède le nom D-Bus `org.freedesktop.Notifications`, donc le serveur de notifications Quickshell ne peut pas tourner en même temps. En phase 6 seulement, arrêter Dunst le temps des tests (`systemctl --user stop dunst` ou `pkill dunst` selon comment il est lancé — vérifier), puis le relancer à la fin.
- **Tray** : plusieurs hôtes StatusNotifier peuvent coexister ; pas de conflit attendu avec Waybar, mais le vérifier.
- **Rofi** : aucun conflit, le lanceur Quickshell peut être testé via `qs ipc`.
- **Écrans et espaces de travail** : avant tout test de la phase 3, enregistrer l'attribution actuelle (`swaymsg -t get_workspaces`). À la fin, retirer les écrans virtuels et restaurer cette attribution.

## Protocole de vérification (obligatoire pour chaque composant)

1. **Référence** : capture de l'existant (Waybar visible, Dunst, Rofi…) dans `docs/reference/` — faite en phase 0, complétée si besoin.
2. **Capture du nouveau composant** dans les mêmes conditions (même écran, même zone, même état : même espace de travail, une notification identique, etc.).
3. **Comparaison visuelle** : ouvrir les deux images (outil Read) et lister les écarts : position, taille, marges, **couleurs (comparer aux valeurs de `THEME.md`)**, police, icônes, arrondis, ordre des modules, comportement multi-écran.
4. **Tests fonctionnels** scriptés quand c'est possible :
   - espaces de travail : `swaymsg workspace N`, `hyprctl dispatch workspace N` → vérifier la mise à jour ;
   - écrans : `scripts/test-outputs.sh` (voir « Écrans dynamiques ») ;
   - audio : `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+` → vérifier le widget ;
   - notifications : `notify-send` avec urgences, icônes, actions (`-A`), remplacement, expiration ;
   - lanceur/menus : `qs ipc call …` puis captures ;
   - scripts gardés : les exécuter et comparer leur sortie à celle de l'ancienne version.
5. **Ce qui ne peut pas être testé automatiquement** (clics, survols, menus contextuels du tray, vrai branchement de câble, fermeture du capot) : le lister explicitement dans le rapport de phase pour que je le teste à la main.
6. Un composant n'est « fait » que si les écarts restants sont nuls ou listés et acceptés, **et** que ses dépendances sont dans `deps/`.

## Phases

Chaque phase : lire `PROGRESS.md` → faire → vérifier → mettre à jour `PROGRESS.md` (fait / écarts restants / à tester à la main) → committer → **s'arrêter pour validation**.

**Phase 0 — Audit (aucun code QML).**
Lire toute la config existante et produire :
- `docs/INVENTORY.md` :
  - chaque module Waybar (y compris les modules `custom/*`, intervalles, formats, tooltips, actions au clic/scroll) ;
  - chaque règle Dunst (urgences, timeouts, positions, règles par application, historique, commandes `dunstctl` utilisées) ;
  - chaque mode Rofi et chaque menu custom ;
  - le tray ;
  - les raccourcis clavier Sway/Hyprland qui invoquent ces outils, et l'autostart ;
  - la configuration actuelle des sorties (lignes `output`/`monitor`, Kanshi éventuel) et l'attribution exacte des 9 espaces de travail aux écrans ;
- `docs/THEME.md` (voir « Charte graphique ») ;
- `docs/SCRIPTS.md` (voir « Scripts dispersés ») ;
- les captures de référence ;
- une première version de `deps/` à partir de tout ce qui est utilisé aujourd'hui ;
- une proposition de `docs/ARCHITECTURE.md`, qui couvre en particulier :
  - le traitement des scripts qui utilisent `rofi -dmenu` (réécriture en QML ou remplaçant compatible) ;
  - le format de la config par machine ;
  - l'approche « Écrans dynamiques » (configuration des sorties et répartition des espaces de travail, règle pour 2 et 4+ écrans).

**Phase 1 — Squelette.** `shell.qml`, `Theme` (complet dès maintenant), `Settings` + config machine, `Compositor`, une barre vide par écran actif, aux bonnes dimensions et aux bonnes couleurs, apparaissant et disparaissant avec les écrans, scripts de dev, lien `~/.config/quickshell/desktop`.

**Phase 2 — Barre : modules de base.** Espaces de travail (seulement ceux de l'écran de la barre), horloge — sous Sway. Titre de fenêtre et mode Sway : exposés par `Compositor`, sans widget (parité, `ARCHITECTURE.md` § 8).

**Phase 3 — Écrans dynamiques.** Répartition automatique des espaces de travail ; sorties configurées nativement par le compositeur, par description d'écran (Kanshi écarté, `ARCHITECTURE.md` § 3.1). `scripts/test-outputs.sh` passe sur tous les scénarios avec écrans virtuels. Sur mon desktop à trois écrans, le résultat est strictement identique à l'attribution actuelle. Liste des tests à faire à la main (vrai câble, capot) dans le rapport.

**Phase 4 — Barre : modules système.** Tous les autres modules inventoriés (audio, réseau, CPU/RAM/températures, GPU, MPRIS, modules custom…) avec leurs tooltips et actions. Modules matériels masqués si le matériel est absent ; prévoir dès maintenant batterie et luminosité pour le futur laptop si cela reste simple. Le tooltip calendrier devient une fenêtre Quickshell soignée. Module GPU multi-constructeur (NVIDIA via `nvidia-smi`, AMD et Intel via sysfs, masqué si aucune température lisible — `ARCHITECTURE.md` § 11.5).

**Phase 5 — Tray, réseau, Bluetooth, disques.** Tray (icônes, menus contextuels, clics) ; menus natifs remplaçant `nm-applet`, `blueman` (appairage via un agent `bluetoothctl` piloté par Quickshell) et `udiskie` (`busctl` / `gdbus` / `udisksctl`) ; module NordVPN natif (binaire `nordvpn`) remplaçant son icône de tray — `ARCHITECTURE.md` § 10 et § 11.4.

**Phase 6 — Notifications.** Popups conformes aux règles Dunst, actions, urgences, historique et équivalents des commandes `dunstctl` que j'utilise (via IPC). Les popups s'affichent sur l'écran prévu, avec un repli si cet écran a disparu.

**Phase 7 — Lanceur.** Remplacement de `rofi -show drun` (recherche, icônes, navigation clavier), ouvert sur l'écran focalisé.

**Phase 8 — Menus custom et scripts.** Power menu, menu d'applications maison sur le modèle du menu Cinnamon (remplace nwg-menu), et tous les autres menus Rofi inventoriés ; application des décisions de `SCRIPTS.md` (scripts remplacés en QML, gardés et rapatriés dans `scripts/`, ou abandonnés après mon accord).

**Phase 8b — Services de session et utilitaires.** Fond d'écran natif et utilitaire de changement de fond (`docs/WALLPAPERS.md`) ; écran de verrouillage natif au design entièrement refait (moderne, dans la charte) ; veille des écrans (`IdleMonitor`) ; agent polkit ; outil de capture d'écran (écran entier, un écran, une fenêtre, une zone — modèle de l'outil GNOME), d'abord sur `grim`/`slurp` ; en dernier, fenêtre de statistiques système (équivalent de btop).

**Phase 9 — Parité Hyprland.** Rejouer le protocole de vérification complet sous Hyprland, y compris `test-outputs.sh`.

**Phase 10 — Bascule.** Sur une branche dédiée et avec mon accord :
- rapatrier les configs Sway/Hyprland dans `dotfiles/`, avec sauvegarde préalable ;
- remplacer les attributions fixes `workspace N output …` par le mécanisme dynamique ;
- faire pointer les raccourcis clavier vers `qs ipc call …` ;
- autostart `qs -c desktop` dans Sway (`exec`) et Hyprland (`exec-once`) ;
- retirer de l'autostart Waybar, Dunst, Rofi, swaybg, swayidle/hypridle, polkit-gnome, nm-applet, blueman, udiskie ;
- au démarrage, chaque écran affiche le premier espace de son bloc (1 / 4 / 7) ;
- documenter la procédure de retour arrière.

Suppression des anciens paquets seulement quand je le décide.

**Phase 11 — Portabilité.** `install.sh` complet (`--dry-run`, `--uninstall`), finalisation de `deps/` (y compris correspondances Fedora/Debian), `README.md` d'installation, test dans un conteneur Arch si possible, et une config machine par défaut pour un laptop à écran unique. Vérifier qu'aucun chemin ou nom d'écran personnel ne reste en dur (`grep -rn "/home/\|DP-2"` hors `hosts/`).

**Phase 12 — Écran de connexion (tout à la fin).** SDDM ne sera plus utilisé : **greetd** le remplace, avec un greeter **Quickshell indépendant** (module `Greetd`, écrit en QML ; `ARCHITECTURE.md` § 10.4), qui reprend seulement l'apparence du thème SDDM actuel `catppuccin-mocha-green` (référence : `docs/reference/sddm-catppuccin-preview.png`). Doit lancer la session Sway Nvidia (`WLR_RENDERER=vulkan sway --unsupported-gpu`) et déverrouiller `gnome-keyring` (PAM). À concevoir ensemble ; touche aux fichiers système, donc rien sans mon accord explicite. Dépendances (greetd…) listées dans `deps/` comme toutes les autres, donc installées par `install.sh` ; sur ce desktop, je les installe moi-même au début de la phase. La mise en place du greeter est ajoutée à `install.sh`.

## Git

- Petits commits, messages de type Conventional Commits (`feat(bar): workspaces via I3 IPC`).
- Push à la fin de chaque phase.
- `.gitignore` : `.shots/`, logs, fichiers temporaires.
- Rien de personnel ou sensible dans le dépôt (pas de clés, de tokens, de chemins vers des données privées). Vérifier les scripts rapatriés avant de les committer.

## Début de session

1. Lire ce fichier, puis `PROGRESS.md`.
2. Vérifier l'état : Waybar et Dunst tournent-ils ? Une instance `qs` de dev traîne-t-elle ? Reste-t-il un écran virtuel `HEADLESS-*` ?
3. Reprendre là où `PROGRESS.md` s'est arrêté.

## Fin de session

Mettre à jour `PROGRESS.md`, restaurer Waybar/Dunst et l'attribution des espaces de travail si besoin, retirer les écrans virtuels, tuer l'instance de dev, committer.
