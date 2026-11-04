# CLAUDE.md — Bureau Quickshell

## Mission

Ce dépôt est **la source unique de mon bureau** : une configuration Quickshell (QML) qui remplace Waybar, Dunst, Rofi, les applets
du tray et les scripts dispersés, plus les configs Sway et Hyprland (`dotfiles/`). La parité avec l'ancien bureau, Sway et Hyprland,
et la bascule sont faites (phases 0 à 10). Reste :

1. **Phase 11 — écran de connexion** : greetd + greeter Quickshell.
2. **Phase 12 — portabilité** : sur une nouvelle machine (ex. un laptop), je clone le dépôt, je lance `install.sh`, et j'ai mon
   bureau, écran de connexion compris.

Ensuite : maintenance et idées de `BACKLOG.md`, une à la fois, avec mon accord.

## Documents

- `PROGRESS.md` : état, tests à faire à la main, décisions en attente — **à lire en début de session**.
- `docs/DEVELOPMENT.md` : bureau réel, méthode, **bancs d'essai**, pièges de Quickshell / Qt / compositeurs — à lire avant de toucher au QML.
- `docs/ARCHITECTURE.md` : architecture actuelle (compositeur, écrans dynamiques, config machine, services, composants, API Quickshell).
- `docs/THEME.md` : règles de la charte ; `config/Theme.qml` porte les valeurs.
- `docs/PERFORMANCE.md`, `docs/ROLLBACK.md`, `deps/README.md`, `BACKLOG.md`.
- `docs/archive/` : historique figé des phases 0 à 10 (journal détaillé, inventaire de l'ancien bureau). **Ne l'ouvrir qu'en cas de
  besoin** (retrouver le pourquoi d'une décision).

## Machine de référence

Arch Linux, i9-9900K, RTX 2080 (pilotes propriétaires) ; Sway (principal) et Hyprland (config Lua) ; trois écrans (ultrawide central
3440x1440, deux 4K en scale 1.5) ; 9 espaces de travail 3 / 3 / 3. Détails et versions : `PROGRESS.md`. Cette machine est **la
référence, pas une hypothèse codée en dur**.

## Règles absolues

1. **Ne jamais me laisser avec un bureau cassé.** Le bureau tourne depuis ce dépôt : **chaque fichier QML sauvegardé recharge mon
   vrai bureau**. Préparer et tester sur une copie du dépôt (banc d'essai), puis copier d'un seul coup ; vérifier ensuite que
   l'instance réelle est vivante. Viser une instance par `--pid`, jamais par `-c desktop`. Tout test sur le compositeur réel
   (`swaymsg`, `hyprctl`) remet l'état initial. Détails : `docs/DEVELOPMENT.md`.
2. **Charte graphique** : aucune couleur, police, taille, marge, arrondi ou icône inventés ; tout vient de `config/Theme.qml`
   (`docs/THEME.md`). Si une valeur manque, demander plutôt que choisir.
3. **Pas de `sudo`, pas d'installation ni de désinstallation de paquets** sans me demander. Si un paquet manque, lister ce qu'il faut et pourquoi.
4. **Ne pas inventer d'API Quickshell.** Consulter la doc de la version installée (https://quickshell.org/docs/) avant d'utiliser un
   type ou une propriété dont tu n'es pas sûr ; en cas d'erreur QML, lire le log plutôt que deviner. Quickshell d'abord : pas de
   menu GTK, pas de rustine.
5. **Rien de spécifique à cette machine en dur** hors `hosts/` et `dotfiles/*/hosts/` : noms et nombre d'écrans, chemins vers
   `/home/…`, GPU Nvidia. Tout passe par la détection ou par la config par machine.
6. **Simplicité.** Pas de framework générique, pas d'abstraction « au cas où » : une abstraction sert au moins deux usages réels
   (Sway + Hyprland, desktop + laptop). Les idées vont dans `BACKLOG.md`, pas dans le code.
7. **NordVPN : aucune action réelle** (connexion, déconnexion, réglage), ni en test ni sur banc. Consigne à transmettre à tout sous-agent.
8. Les sauvegardes `~/.config/*.bak-*` et les données privées de `~/.config/qs-desktop.local/` ne sont jamais modifiées ni versionnées.

## Autonomie

Dans une phase, travaille de façon autonome : lis, code, teste, corrige, committe. Ne me demande que pour de vraies décisions
(choix d'UX, paquet à installer, action irréversible ou sur les fichiers système). **À la fin de chaque phase, arrête-toi** et donne-moi
un rapport court + captures. Je valide, puis on passe à la suite.

## Écrans dynamiques (comportement attendu)

- Le bureau s'adapte **à chaud** aux écrans **connectés et activés** (un écran éteint ou capot fermé ne compte pas). Source de
  vérité : sorties actives du compositeur. Barres créées et détruites avec les écrans ; chaque barre montre les espaces de son écran.
- 9 espaces, toujours numérotés 1 à 9, répartis en blocs contigus : écran principal d'abord, puis gauche → droite ; ce desktop
  reproduit exactement 1-3 au centre, 4-6 à gauche, 7-9 à droite. La config machine peut imposer une répartition par ensemble d'écrans.
- Au changement d'écrans : aucune fenêtre perdue, les espaces d'un écran disparu migrent, l'espace focalisé le reste si possible.
- Sorties configurées nativement par chaque compositeur, écrans identifiés par **description** (pas par connecteur) ; répartition
  par un seul mécanisme, `services/Outputs.qml`. Détails et règle pour 2, 4, 5 écrans : `docs/ARCHITECTURE.md` § 3.
- Tests : `scripts/test-outputs.sh sway|hyprland` (écrans virtuels, session isolée). Vrai câble, capot : à la main.

## Portabilité

### Config par machine

- Par défaut, tout est détecté : écrans, batterie (`UPower`), réseau, rétroéclairage, GPU. Un module dont le matériel est absent se masque.
- Ce qui ne se détecte pas va dans `hosts/<hostname>.json` (Quickshell) et `dotfiles/*/hosts/<hostname>.*` (compositeurs), avec des
  valeurs par défaut raisonnables pour un écran unique (`hosts/default.json`). Format : `docs/ARCHITECTURE.md` § 4.

### Dépendances (`deps/`)

- `arch-pacman.txt` (dépôts officiels, un par ligne, commentaire = usage), `arch-aur.txt`, `optional.txt` (matériel ou module
  optionnel), `README.md` (par module, prérequis d'un nouveau PC, correspondances Fedora et Debian/Ubuntu avec alternatives).
- Toute commande externe, police, thème d'icônes ou module Quickshell ajouté met à jour `deps/` **dans le même commit**.

### `install.sh` (phase 12)

À la racine, **idempotent** :
1. détecte la distribution ; sur Arch, propose d'installer `deps/` (`pacman -S --needed`, puis AUR via `paru` ou `yay` s'ils sont
   présents) ; ailleurs, affiche la liste à partir de `deps/README.md` ;
2. sauvegarde toute config existante avant de la remplacer (`~/.config/<x>.bak-<date>`) ;
3. crée les liens (`~/.config/quickshell/desktop`, configs Sway / Hyprland, WirePlumber, scripts dans `~/.local/bin`), copie les
   polices de `assets/fonts/`, génère les web apps (`deps/README.md`, « Web apps ») ;
4. génère le fichier de config machine s'il n'existe pas pour ce hostname ;
5. met en place les fichiers système, après confirmation (`sudo`) et avec sauvegarde : greetd + greeter Quickshell (config
   greetd, PAM avec déverrouillage de `gnome-keyring`, service activé à la place de l'ancien gestionnaire), tels que documentés en phase 11 ;
6. `--dry-run` : affiche tout sans rien modifier ;
7. `--uninstall` : retire les liens et restaure les sauvegardes (y compris l'ancien gestionnaire de connexion).

Si `podman` ou `docker` est disponible, tester `install.sh --dry-run` et la résolution des paquets dans un conteneur `archlinux` propre.

## Structure du dépôt

```
shell.qml                 # point d'entrée (pragmas IconTheme, ShellId desktop, NativeTextRendering)
config/Theme.qml          # singleton : toutes les valeurs de la charte
config/Settings.qml       # singleton : options + config machine
hosts/                    # config Quickshell par machine (<hostname>.json) + default.json
services/                 # singletons d'état (Compositor, Outputs, Audio, Notifs, …)
modules/                  # bar, notifications, launcher, menus, osd, lock, polkit, screenshot, wallpaper, monitor
assets/                   # images et polices embarquées
scripts/                  # desktop.sh, ipc.sh, dev.sh, qs-env.sh, test-outputs.sh, shot.sh, crop.sh, perf.sh
dotfiles/                 # sway/, hypr/ (+ hosts/), wireplumber/, webapps/
deps/                     # listes de dépendances
docs/                     # ARCHITECTURE, THEME, DEVELOPMENT, PERFORMANCE, ROLLBACK, reference/, archive/
install.sh                # phase 12
README.md                 # installation sur une nouvelle machine (phase 12)
PROGRESS.md, BACKLOG.md
```

## Conventions QML

- Services en `pragma Singleton` ; les widgets ne lisent que les services, jamais de `Process` dans l'UI.
- Aucune couleur, police ou taille hors de `Theme.qml`.
- Multi-écran via `Variants { model: Quickshell.screens }` ; modules de chaque écran selon la config machine, avec repli pour un écran inconnu.
- `services/Compositor.qml` : interface unique, `Quickshell.I3` sous Sway, `Quickshell.Hyprland` sous Hyprland (détection
  `SWAYSOCK` / `HYPRLAND_INSTANCE_SIGNATURE`).
- Services natifs de Quickshell d'abord (revue des types : `ARCHITECTURE.md` § 10, à tenir à jour) ; script externe seulement sans
  équivalent natif.
- Tout ce qu'un raccourci déclenche passe par un `IpcHandler` (`scripts/ipc.sh <cible> <fonction>`).
- Commentaires courts, en anglais ou en français, cohérents dans un même fichier.

## Environnement de développement

- `~/.config/quickshell/desktop` → ce dépôt. Le bureau est lancé par `scripts/desktop.sh` (autostart des deux compositeurs) ;
  `scripts/dev.sh` le relance et affiche les erreurs, `scripts/dev.sh log` suit le journal.
- Captures : `scripts/shot.sh <nom> [sortie|géométrie]` (dans `.shots/`), recadrage `scripts/crop.sh`.
- Bancs d'essai (Sway headless, Hyprland imbriqué, pointeur et clavier virtuels) : `docs/DEVELOPMENT.md`.

## Protocole de vérification

1. Banc d'essai d'abord, démarrage complet sans nouvel avertissement ; puis le bureau réel.
2. Captures du composant (`scripts/shot.sh`) comparées à la charte (`THEME.md`, `Theme.qml`) et, pour l'écran de connexion, à
   l'écran de verrouillage.
3. Tests fonctionnels scriptés quand c'est possible (`qs ipc`, `notify-send`, `wpctl`, `test-outputs.sh`…).
4. Ce qui ne se teste pas automatiquement (clics réels, câble, capot, vraie session de connexion) : listé dans `PROGRESS.md` pour que
   je le teste à la main.
5. Un composant n'est « fait » que si les écarts restants sont nuls ou listés et acceptés, **et** que ses dépendances sont dans `deps/`.

## Phases

Chaque phase : lire `PROGRESS.md` → faire → vérifier → mettre à jour `PROGRESS.md` → committer → **s'arrêter pour validation**.

Faites : 0 audit · 1 squelette · 2 espaces et horloge · 3 écrans dynamiques · 4 modules système · 5 tray, réseau, Bluetooth,
disques, NordVPN · 6 notifications · 7 lanceur · 8 menus et scripts · 8b fond, verrouillage, veille, polkit, capture, statistiques ·
9 parité Hyprland · 10 bascule (retour arrière : `docs/ROLLBACK.md`).

**Phase 11 — Écran de connexion.** SDDM ne sera plus utilisé : **greetd** le remplace, avec un greeter **Quickshell indépendant**
(module `Greetd`, en QML ; `ARCHITECTURE.md` § 9) qui reprend **le design de l'écran de verrouillage**, augmenté des fonctions de SDDM
(choix de la session Wayland ou X11, éteindre, redémarrer, veille ; décision du 2026-11-04, le thème SDDM n'est plus la référence).
Doit lancer la session Sway Nvidia (`WLR_RENDERER=vulkan sway --unsupported-gpu`) et déverrouiller `gnome-keyring` (PAM). À concevoir ensemble ; touche aux fichiers système, donc
rien sans mon accord explicite. Dépendances (greetd…) listées dans `deps/` ; sur ce desktop, je les installe moi-même au début de la
phase. Fichiers et procédure de mise en place versionnés et documentés, pour que `install.sh` les reprenne en phase 12 ; retour
arrière vers SDDM documenté.

**Phase 12 — Portabilité.** `install.sh` complet (`--dry-run`, `--uninstall`, étape système du greeter), finalisation de `deps/`
(correspondances Fedora/Debian vérifiées), `README.md` d'installation, test dans un conteneur Arch si possible, config machine par
défaut pour un laptop à écran unique. Vérifier qu'aucun chemin ou nom d'écran personnel ne reste en dur
(`grep -rn "/home/\|DP-2"` hors `hosts/` et `docs/`). Tests laptop : `PROGRESS.md`.

Suppression des anciens paquets seulement quand je le décide.

## Git

- Travail directement sur `master`. Petits commits, Conventional Commits (`feat(bar): …`).
- Push à la fin de chaque phase.
- `.gitignore` : `.shots/`, logs, fichiers temporaires.
- Rien de personnel ou sensible dans le dépôt (clés, jetons, adresses privées).

## Début de session

1. Lire ce fichier, puis `PROGRESS.md`.
2. Vérifier l'état : bureau vivant (`scripts/desktop.sh pid`) ; aucune instance de test, aucun banc, aucun écran virtuel `HEADLESS-*` qui traîne.
3. Reprendre là où `PROGRESS.md` s'est arrêté.

## Fin de session

Mettre à jour `PROGRESS.md`, arrêter les bancs et instances de test, retirer les écrans virtuels, remettre l'état du compositeur,
vérifier que le bureau réel est vivant, committer.
