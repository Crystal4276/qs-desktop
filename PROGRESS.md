# Journal d'avancement

## Environnement

- Machine : `terrier` — Arch, i9-9900K, RTX 2080 (nvidia-utils 615.78)
- **Quickshell 0.3.2** (paquet Arch `quickshell 0.3.2-1`)
- Sway 1.12, Hyprland 0.56.2 (**config Lua** : `hyprctl keyword` indisponible, `dispatch` en syntaxe Lua)
- Écrans : DP-1 (LG 27GN950, gauche), DP-2 (Dell AW3418DW, centre, principal), DP-3 (LG 27GN950, droite)

## Phase 0 — Audit : faite et validée (2026-10-15)

Produit :
- `docs/INVENTORY.md` — Waybar (3 barres, tous les modules), Dunst, Rofi, nwg-menu, tray, raccourcis, autostart, sorties, attribution des espaces, secrets repérés
- `docs/THEME.md` — palette Catppuccin Mocha + couleurs Rofi, polices, géométrie mesurée de la barre (pilules 55 px, marges 10 px, rayon 20 px — corrigé : 1rem = 20 px), notifications, lanceur, power menu, nwg-menu
- `docs/SCRIPTS.md` — 9 scripts/commandes actifs, 11 scripts morts, hors périmètre
- `docs/ARCHITECTURE.md` — proposition : sorties configurées nativement par le compositeur (par description d'écran), `services/Outputs.qml` pour la répartition, règle « principal d'abord », format `hosts/*.json`, **8 questions ouvertes (Q1–Q8)**
- `docs/reference/` — 10 captures (barres, lanceur, power menu, nwg-menu, notifications)
- `deps/` — première version (pacman, AUR, optionnel, correspondances Fedora/Debian non vérifiées)
- `BACKLOG.md`

Constats importants :
- L'attribution 3 écrans n'est pas gauche → droite (1-3 au centre) → règle proposée « écran principal d'abord ».
- Hyprland en config Lua invalide les commandes `hyprctl keyword` / `dispatch moveworkspacetomonitor` prévues dans `CLAUDE.md`.
- La Waybar actuelle n'affiche ni titre de fenêtre ni mode Sway (prévus en phase 2) → Q4.
- Jetons NordVPN en clair dans les configs Sway/Hyprland/autostart → Q7.

État laissé : Waybar et Dunst actifs et inchangés, aucun écran virtuel, aucune instance `qs`, 3 notifications de test retirées de l'historique Dunst.

### Retours du 2026-10-15

- Q1–Q8 tranchées (`docs/ARCHITECTURE.md` § 8).
- Kanshi abandonné : il ne gère pas le HDR → sorties configurées nativement par Sway / Hyprland, par description (§ 3.1, § 8.1).
- Police Symbols Nerd Font Mono versionnée dans le dépôt (§ 8.2) ; calendrier en fenêtre Quickshell en phase 4, événements Thunderbird après la parité (§ 8.3).
- Fiches détaillées par module Waybar ajoutées dans `INVENTORY.md` § 1 (états, défauts Waybar, tooltips, clics).
- Polices vérifiées glyphe par glyphe : tout est dans Symbols Nerd Font Mono, sauf les barres cava (DejaVu Sans, ajoutée à `deps/`)
  et les icônes batterie (retirées de Nerd Fonts v3, à remplacer en phase 4).

- nwg-menu : remplacé par un menu d'applications maison (modèle Cinnamon) en **phase 8** ; aucune dépendance à nwg-menu ni à nemo dans l'état final.
- Dépendances par module : `deps/README.md` (ajout de `fakeroot`, requis par `checkupdates`).
- `custom/updates` sur DP-3 : oubli de config, non repris.

### Seconde passe et décisions (2026-10-15)

- Seconde passe de tout le bureau : `INVENTORY.md` § 10. Décisions R1–R11 : `ARCHITECTURE.md` § 10.1 (fond, verrouillage refait, veille, polkit,
  réseau, Bluetooth avec agent `bluetoothctl`, disques sans udiskie, outil de capture, greeter en phase 12, démarrage 1/4/7).
- `CLAUDE.md` : phases 2, 3, 4, 5, 8, 10 précisées ; **phase 8b** (services de session et utilitaires) et **phase 12** (écran de connexion) ajoutées.
- Fonds d'écran consolidés dans `~/Pictures/Wallpapers` (dépôt privé `Crystal4276/wallpapers`), configs Sway/Hyprland adaptées (non committées dans leurs dépôts),
  cache swww supprimé. Suppression des anciens originaux en attente (`WALLPAPERS.md` § État).

- Images hors glyphes recensées (`THEME.md` § 12) ; prérequis système d'un nouveau PC (`deps/README.md`).
- Dépôts `~/.config/sway` et `~/.config/hypr` : fonds d'écran + tes modifications en attente committés (non poussés).

### Troisième passe (2026-10-15)

- `INVENTORY.md` § 11 : session SDDM personnalisée, `QT_QPA_PLATFORMTHEME=qt6ct` (Quickshell en hérite), dconf (`text-scaling-factor 1.25`),
  polices CJK non portables (MS copiées à la main → `noto-fonts-cjk`), emojis, portail de partage d'écran (`slurp`), VPN, onduleur.
- **Correction de la charte** : `1rem` = 20 px et non 16 (facteur 1.25) → arrondis 20 px, paddings corrigés (`THEME.md`).
- `ARCHITECTURE.md` § 11 : risques qt6ct et processus unique (redémarrage auto, reprise du verrouillage).
- SDDM abandonné : greeter Quickshell indépendant en phase 12, apparence du thème Catppuccin reprise (`CLAUDE.md`).

- Polices Microsoft versionnées dans le dépôt privé `Crystal4276/fonts-ms` (optionnel) ; Tailscale et ZeroTier utilisés (hors shell) ; onduleur hors périmètre.

- NordVPN : module natif proposé (binaire `nordvpn`, phase 5), icône officielle masquée à la bascule (`ARCHITECTURE.md` § 11.4).

- GPU multi-constructeur (NVIDIA / AMD / Intel) en phase 4 ; fenêtre de statistiques système (équivalent btop) en fin de phase 8b (`ARCHITECTURE.md` § 11.5).

## Phase 1 — Squelette : faite et validée (2026-10-15)

Produit :
- `shell.qml` (pragmas `IconTheme Papirus-Dark` et `ShellId desktop`), imports `qs.config` / `qs.services` / `qs.modules.bar`.
- `config/Theme.qml` : traduction complète de `THEME.md` (palette, couleurs Rofi, polices, barre, curseur, couleurs des modules, glyphes, images,
  notifications, lanceur, power menu, menu d'applications). Seules manquent les icônes batterie (à choisir en phase 4, cf. INVENTORY § 1).
- `config/Settings.qml` + `hosts/default.json` + `hosts/terrier.json` : fusion au premier niveau, relecture à chaud ; barres décrites en pilules (ARCHITECTURE § 4).
- `services/Compositor.qml` (Sway / Hyprland : sorties actives avec description, espaces, sortie focalisée, `focusWorkspace`) ;
  `services/Outputs.qml` (écran principal, ordre « principal d'abord »). Titre de fenêtre et mode : phase 2.
- `modules/bar/Bar.qml` + `Pill.qml` : une barre par écran, pilules vides aux bonnes dimensions et couleurs, disposition selon la config machine.
- `scripts/dev.sh`, `shot.sh`, `crop.sh` ; lien `~/.config/quickshell/desktop` → dépôt.
- `assets/` : Symbols Nerd Font Mono + licence, 6 SVG (logo Arch ×2, power menu ×4).

Vérifié (Sway) :
- Géométrie au pixel sur DP-2 : pilules y 10 → 64 (55 px), bordure 1 px `#6c7086`, fond `#181825`, marges et espacement 10 px, fond transparent,
  fenêtres à y = 75 comme avec Waybar ; DP-1/DP-3 en scale 1.5 : 15 → 97 px physiques.
- Disposition : DP-2 3 + 4 pilules, DP-1 2 + 2, DP-3 2 + 2 via son entrée par description (prouvé en ajoutant une pilule à chaud dans `terrier.json`).
- Écrans à chaud : écran virtuel ajouté → barre « secondaire » ; désactivé → barre détruite ; réactivé → recréée ; retiré → détruite, sans avertissement.
  Attribution des espaces identique avant/après.
- qt6ct : police par défaut différente avec/sans (`DejaVu LGC Sans 12pt` / `Sans Serif 9pt`) ; thème `breeze` de qt6ct non installé →
  sans le pragma, la plupart des icônes manquent ; avec, toutes viennent de Papirus-Dark (ARCHITECTURE § 11.1).
- Glyphes au-delà de U+FFFF (`\u{f043e}`…) correctement lus ; hostname lu dans `/proc`.

Écarts restants : aucun pour le squelette (contenu des pilules : phases 2 et 4). Le bouton Arch, les espaces, etc. n'existent pas encore.
Non testé : Hyprland (phase 9 ; la conversion taille physique → logique des moniteurs Hyprland est à vérifier là).

À tester à la main : rien de spécifique (pas d'interaction en phase 1). Pour voir la barre : `pkill -SIGUSR1 waybar; scripts/dev.sh`,
puis `scripts/dev.sh stop; pkill -SIGUSR1 waybar`.

État laissé : Waybar et Dunst actifs, aucune instance `qs`, aucun écran virtuel.

Retour du 2026-10-15 : la pilule tray + power est native en QML ; le power menu pourra devenir un panneau de réglages rapides façon GNOME (BACKLOG, phase 8).

## Phase 2 — Espaces de travail et horloge : faite et validée (2026-10-15)

Produit :
- `services/Outputs.qml` : blocs d'espaces par écran (règle Q1 ou répartition imposée par la config machine), calculés seulement — appliqués en phase 3.
- `services/Compositor.qml` : état vide des espaces (Sway : champ `focus`), titre de la fenêtre active (événements `window` + `get_tree`),
  mode (`mode` + `get_binding_state` ; submap sous Hyprland). Exposés sans widget (Q4).
- `modules/bar/Workspaces.qml` : espaces de l'écran + espaces persistants de son bloc (sémantique Waybar), couleurs par position,
  vide / visible / survol, halo du focalisé, clic, molette (précédent / suivant avec bouclage, sans effet si le focus est sur un autre écran).
- `modules/bar/Clock.qml` : `U+E385␣␣HH:mm` (+ `␣␣U+F274␣ddd-dd` sur la barre principale), locale et fuseau du système.
- `Pill.qml` sans padding (chaque module porte le sien, comme Waybar), masquée si vide ; modules branchés par nom dans `Bar.qml`.
- `//@ pragma NativeTextRendering` (texte rendu par FreeType, comme Pango).
- `scripts/dev.sh` lit le journal en direct (`qs log`) ; `dev.sh log` le suit.

**Correction d'audit — polices des icônes** (`THEME.md` § 2) : dans les modules en `Inter`, les icônes venaient de polices de repli
(Hack Nerd Font, Font Awesome 7 Free / Brands, Font Awesome 4.7), pas de Symbols Nerd Font Mono. Décision : parité exacte →
ces 4 polices sont versionnées dans `assets/fonts/` (licences MIT / Bitstream Vera / SIL OFL, `assets/fonts/README.md`).

Vérifié (Sway, DP-2 à l'échelle 1, mêmes états que la référence) :
- Pilule des espaces : glyphes à la même position que la référence (32×34+60+12) ; écart moyen 3/255 sur la pilule (ancien rendu),
  5/255 sur le bouton focalisé avec le rendu natif. Halo calibré par mesure (`THEME.md` § 3).
- Horloge (heure figée sur celle de la référence pour la mesure) : pilule de 247 px contre 245, caractères à 1–2 px de leur position,
  calendrier à la même hauteur ; reste un écart d'anticrénelage (Qt et Pango ne hintent pas pareil).
- DP-1 / DP-3 : espaces et horloge conformes.
- Clic (crée et focalise un espace persistant), molette dans les deux sens, survol (couleur de position + fond 10 %) : testés par curseur simulé (`swaymsg seat - cursor`).
- Titre de la fenêtre active : suit les changements de fenêtre et d'espace (vide sur un espace vide). L'état focalisé de Quickshell converge vers celui de Sway sur les trois écrans.
- Changement d'écrans (écran virtuel) : barres et listes d'espaces suivent.

Écarts restants (acceptés ou à trancher) :
- horloge : +2 px de largeur, anticrénelage légèrement différent ;
- un espace hors de 1–9 ou nommé affiche son nom ; un espace 1–9 déplacé sur un autre écran affiche son glyphe (Waybar afficherait son numéro, faute d'icône définie pour cette barre) ;
- molette : active aussi sous Hyprland (Waybar l'y avait désactivée) — à trancher en phase 9 ;
- mode Sway : non testé (ta config ne définit aucun mode) ;
- avertissement « I3 event socket disconnected » à chaque démarrage : reconnexion interne de Quickshell, sans effet constaté.

À tester à la main : clic, molette et survol à la vraie souris sur les trois barres.

Notes de session :
- les clics simulés (`swaymsg seat - cursor`) comptent comme une activité : swayidle rallume les écrans ;
- écrans éteints par swayidle → `grim` bloque : utiliser un écran virtuel (`swaymsg output HEADLESS-N power on`) ;
- `pkill -SIGUSR1 waybar` est une bascule : toujours vérifier par capture que Waybar est bien revenu.

État laissé : Waybar et Dunst actifs, aucune instance `qs`, aucun écran virtuel, attribution des espaces identique.

## Phase 3 — Écrans dynamiques : faite et validée (2026-10-16)

Produit :
- `services/Outputs.qml` : répartition appliquée (anti-rebond 500 ms ; aussi quand la config machine change), en une commande :
  espaces mal placés déplacés, espace visible de chaque écran rétabli (recréé s'il était vide), focus rétabli ;
  espace créé hors de son écran déplacé 100 ms plus tard (reste focalisé si c'était le cas) ; cible IPC `outputs` (`blocks`, `apply`).
- `services/Compositor.qml` : `placeWorkspaces`, `moveFocusedWorkspace`, signal `workspaceCreated` (Sway) ; commandes tracées dans le journal.
  Hyprland : à écrire en phase 9.
- `scripts/test-outputs.sh` : session Sway isolée (headless) + instance Quickshell dédiée + fenêtres zenity ; 13 scénarios et contrôles.
- `dotfiles/sway/hosts/terrier.conf` : règles d'écran par description, reprise exacte des lignes actuelles (pour la phase 10).

Découvertes :
- Sway 1.12 : la **première** attribution `workspace N output X` l'emporte, les suivantes ne la remplacent pas → aucune attribution,
  placement par déplacements explicites (ARCHITECTURE § 3.2).
- `swaymsg` et `Quickshell.I3` lisent `I3SOCK` avant `SWAYSOCK`.
- Sway reconnaît les écrans par description : prouvé sans changement de mode (réglage `max_render_time` posé par description,
  relu sur le bon connecteur, remis à `off`).

Vérifié :
- `test-outputs.sh` : 0 échec sur 3 passages consécutifs (3 → 4 → 5 écrans, création d'espace, désactivation / réactivation,
  débranchement, 2 écrans, 1 écran, retour) ; focus et espaces visibles conservés, aucune fenêtre perdue, 15–17 commandes de placement.
- Sur le desktop à trois écrans : répartition calculée = attribution actuelle (1-3 DP-2, 4-6 DP-1, 7-9 DP-3) ; au démarrage, rien à déplacer.
- Répartition imposée par la config machine (`workspaceLayouts`) : testée avec les écrans réels + un virtuel (réussi), avant le passage en session isolée.

Incidents de session (assumés) :
- les premiers passages du test ont tourné **dans ta session** : tes espaces ont changé d'écran plusieurs fois pendant ~30 s
  (toujours restaurés, vérifié) ; une fois par erreur après la réécriture du script ;
- une fenêtre **Steam** (flottante, espace 9) a disparu pendant l'un de ces passages ; Steam tourne toujours (réouverture par son icône).
  Lien avec le test probable mais non établi.

Tests sur les écrans réels (à ta demande, le 2026-10-15), instance de dev sur ta session :
- DP-3 éteint (2 écrans : DP-2 1-5, DP-1 6-9), DP-1 + DP-3 éteints (1 écran : 1-9), DP-2 (principal, focalisé) éteint
  (DP-1 devient principal : 1-5, DP-3 6-9), chacun éteint puis rallumé à tour de rôle : répartition conforme, focus conservé,
  vue de chaque écran retrouvée au rallumage ; à la fin espaces, vue, focus, fenêtres (10) et réglages d'écran identiques au départ.
- Ces tests ont révélé et fait corriger : la couleur des espaces regroupés sur une barre (blanc au-delà de 3, cf. ci-dessous),
  la vue d'un écran rallumé (mémoire par configuration d'écrans) et le focus perdu quand l'écran focalisé s'éteint.
  Les deux derniers cas ont été ajoutés à `test-outputs.sh` (18 contrôles, 0 échec sur 3 passages).
- **Couleurs** (ton retour) : d'abord la couleur suivait l'espace (1, 4, 7 sarcelle ; 2, 5, 8 saphir ; 3, 6, 9 bleu) ; à la validation,
  remplacée par un **dégradé** teal → sapphire → blue selon la position dans la barre (identique à Waybar avec 3 espaces par barre,
  `THEME.md` § 3). Vérifié par capture en session isolée avec 5, 4 et 9 espaces sur une barre.
- **VRR** : `adaptive_sync on` accepté par Sway + Nvidia sur les trois écrans (statut `enabled`, aucune erreur), puis remis à `off`.
  L'effet réel (indicateur G-Sync de l'écran, absence de scintillement) demande un œil humain.

Reste impossible d'ici : retirer un vrai câble (Sway le traite comme un écran qui disparaît, ce qui est testé ; seul le nom du connecteur
peut changer, d'où l'identification par description), fermer un capot (pas de laptop).

État laissé : Waybar et Dunst actifs, aucune instance `qs`, aucun écran virtuel, attribution des espaces inchangée.

Retour du 2026-10-16 : phase validée ; tests reportés (voir « À faire par toi à la fin »).

## À faire par toi à la fin (tests impossibles d'ici)

Liste tenue à jour à chaque phase ; à dérouler une fois le projet terminé.

- **Souris réelle** (phases 2 et 4) : clic, survol et molette sur les trois barres ; molette au pavé tactile ; molette sur le volume,
  le curseur, les espaces de travail, le module média et le calendrier épinglé (les crans simulés valent 1 au lieu de 120).
- **Glisser le curseur de volume** (phase 4) : Sway ne transmet pas les déplacements simulés pendant un appui.
- **Clavier dans le calendrier épinglé** (phase 4) : Échap, ←/→ (aucun outil d'injection clavier installé).
- **Mise à jour réelle** (phase 4) : clic sur le module, confirmer avec `Y`, puis Entrée ; le compteur doit disparaître.
- **VRR** (phase 3) : juger l'effet à l'œil (indicateur G-Sync de l'écran, scintillement) avant de l'activer.
- **Débranchement physique d'un câble** sur le desktop (phase 3).
- **Phase 5** :
  - saisie au clavier dans les panneaux (mot de passe d'un nouveau réseau Wi-Fi, phrase de passe d'un disque chiffré, recherche de pays
    NordVPN), Échap dans les panneaux, Échap et ↑/↓/Entrée/→/← dans les menus du tray ;
  - **appairage d'un nouvel appareil Bluetooth** (code à confirmer, PIN) ; **connexion / déconnexion d'un appareil qui répond**
    (écouteurs sortis du boîtier, manette allumée) ;
  - boutons non cliqués volontairement : « Disconnect » du filaire (couperait le réseau), « Forget » d'un réseau Wi-Fi et d'un appareil
    Bluetooth (effaceraient tes réglages) ;
  - clic milieu (SecondaryActivate) et molette sur une icône d'application du tray ;
  - **vraie clé USB** (montage automatique, notifications, éjection / extinction).
- **Phase 6** : notifications de vraies applications (WhatsApp, Thunderbird, Chromium, Spotify…) : icônes et images, actions proposées
  (boutons), emojis ; clic milieu sur une notification qui contient un seul lien (ouverture dans le navigateur, non cliqué ici) ;
  Échap dans le centre de notifications.
- **Troisième passe** : carte média avec Spotify qui répond (lecture, pause, suivant, avance dans le morceau).
- **Phase 7** : `$mod+w` une fois branché (phase 10) ; lanceur avec ta vraie souris (molette, double clic) et ton clavier au quotidien.
- **Phase 8 (panneau de réglages)** : verrouiller, se déconnecter, redémarrer, éteindre (non cliqués ici) ; « Keep Screen On » (l'écran
  ne doit pas s'éteindre après 5 min) ; veilleuse le soir (après 20:00, écran plus chaud) ; trois boutons de profil d'énergie une fois
  `power-profiles-daemon` installé ; `$mod+Escape` et `$mod+d` une fois branchés (phase 10) ; glisser les curseurs ; sur le laptop :
  luminosité, batterie, mode avion.
- **Revue de code (2026-10-16)** : ↑ dans un menu du tray ouvert sans sélection (la dernière entrée doit être choisie) ; vraie clé USB
  chiffrée : déverrouiller, verrouiller, éjecter ; appairage Bluetooth en fermant le panneau juste après avoir confirmé le code
  (l'appareil doit se connecter et rester approuvé) ; NordVPN qui apparaît dans le tray quand le démon démarre après la session.
- **Deuxième passe** : vraie touche de volume / micro une fois les raccourcis branchés (phase 10) ; connexion limitée (Wi-Fi d'hôtel avec
  portail, ou câble sans Internet) ; sur le laptop : OSD de luminosité et alerte de batterie à 30 % et 15 %.
- **Panneau audio (revues du 2026-10-17)** : ouvert au clic droit sur l'icône du volume, un clic gauche doit le fermer (et couper le
  son, comme avant) ; idem au clic du milieu (sortie suivante).
- **Menu d'applications (2026-10-17)** : avec ta vraie souris — molette dans la liste, survol rapide des catégories, clic droit ;
  verrouiller / se déconnecter / redémarrer / éteindre depuis le menu (non cliqués ici) ; rendu sur tes écrans (testé en session isolée).
- **Séance de débogage (2026-10-16)** : musique Spotify à bas volume (cava doit rester affiché) ; vidéo YouTube dans Chromium avec
  Spotify en pause (la barre passe sur Chromium), puis Spotify relancé (retour sur Spotify) ; halo des espaces à l'œil sur les trois écrans.
- **Hyprland** (rappel demandé) : tu ouvres une session Hyprland, je prends la main et je déroule la liste de « Compatibilité Hyprland »
  ci-dessous (barres, répartition des espaces, modules, calendrier) ; puis le protocole complet en phase 9.
- **Laptop**, une fois installé : laptop seul, laptop + écrans externes, capot fermé (`bindswitch lid:on/off`), écran interne éteint,
  branchement à chaud avec fenêtres ouvertes (phase 3) ; batterie, rétroéclairage (`brightnessctl`), modules masqués selon le matériel,
  GPU AMD / Intel réels (phase 4).

## Phase 4 — Modules système de la barre : faite et validée (2026-10-16)

Produit :
- Services : `Audio` (Pipewire : volume, muet, sortie suivante à 60 % + notification — remplace `audio-toggle.sh`), `Media` (Mpris, lecteur
  choisi par `mediaPlayer`, troncature `Artiste - Titre` copiée de Waybar 0.15), `Cava` (`cava` en sortie brute, `config/cava.conf`,
  ne tourne que si un module l'affiche), `SystemStats` (`/proc/stat`, `/proc/meminfo`), `Gpu` (NVIDIA `nvidia-smi`, AMD / Intel hwmon,
  carte `boot_vga`), `Network` (interface de la route par défaut, `/proc/net/dev`), `Updates` (`checkupdates` toutes les 8600 s, mise à jour
  dans un terminal puis recomptage), `Battery` (UPower), `Brightness` (sysfs + `brightnessctl`).
- Modules : bouton Arch (survol ; n'ouvre rien avant la phase 8), mpris, cava, volume, curseur, mises à jour, GPU, CPU, mémoire, réseau,
  bouton power (n'ouvre rien avant la phase 8), batterie et rétroéclairage (laptop) ; `RichLabel` (une ligne, une police par segment),
  `InfoModule` (modules texte), `WheelSteps` (molette par crans de 120, aussi pour les espaces de travail).
- **Calendrier** (`CalendarPopup.qml`) : survol = aperçu, clic = épinglé (flèches, molette, ←/→, titre = mois en cours). Fermeture :
  Échap, clic ailleurs **transmis à ce qui est dessous** (ton retour), ou 5 s hors du calendrier (ta demande). Mécanisme : ARCHITECTURE § 8.3.
  Style : `THEME.md` § 3 « Calendrier », valeurs reprises de la charte.
- Config machine : `terminal` devient une liste (préfixe avec attente), `mediaPlayer` ajouté (ARCHITECTURE § 4).
- Pilules : visibles si l'un de leurs modules veut s'afficher (corrige une pilule qui ne réapparaissait jamais).
- Polices de `assets/fonts/` chargées depuis le dépôt (`FontLoader`).

Décisions :
- **Pas de tooltips** (ton retour du 2026-10-16) ; relevé de leur style conservé pour mémoire dans `INVENTORY.md` § 1, infos perdues en `BACKLOG.md`.
- Calendrier : survol + clic (ton choix).
- Icônes batterie : codes v2 transposés à l'identique en Nerd Fonts v3 (`THEME.md` § 2).

Découvertes :
- Waybar 0.15 (source lue) : paliers du volume à 33 / 66 % (l'inventaire disait 34 / 67, corrigé) ; tooltip mpris `spotify (paused): …` ;
  la batterie repassait au vert sous 15 % (état `critical` sans style) → ici rouge dès 30 % et en dessous (écart assumé).
- Pango dessine une espace placée entre deux icônes dans la police de la première (`pango-view --serialize-to` reproduit Waybar exactement) ;
  la copie système `fa-brands-400.woff2` n'a pas cette espace → 6 px d'écart, corrigé en chargeant les polices du dépôt.
- `FileView.reload()` est asynchrone : les calculs se font dans `onLoaded` (sinon le CPU restait à 0 %).
- Sous Sway, un `PopupWindow` avec `grabFocus` n'est pas fermé par un clic extérieur et bloque le clic sur l'horloge ; une surface
  « clavier à la demande » perd le focus à chaque réarrangement des couches (code de Sway 1.12 lu) ; un clic sur un popup de barre
  focalise l'espace de travail et émet un faux événement « focus » de fenêtre → mécanisme décrit en ARCHITECTURE § 8.3.
- `swaymsg seat - cursor press button4` envoie un pas de molette de 1 (un cran réel vaut 120) : tests faits avec 60 pressions = 1 cran.

Vérifié (Sway, écrans réels, Waybar masquée le temps des captures puis rétablie) :
- Rendu comparé à Waybar sur les trois écrans : mêmes modules, couleurs, polices, positions ; pilules à +1 / +2 px sur DP-2 (anticrénelage,
  comme l'horloge en phase 2) ; pilule média à 1 px ; DP-1 / DP-3 identiques à l'œil (bordure un peu plus nette que le rendu GTK ×2 réduit).
- Volume : molette ±5 % sur l'icône et le curseur (plafond 100 %), clic gauche muet / rétabli, clic sur le rail (10 %, 84 %), clic milieu
  (sortie suivante, volume 60 %, notification), clic droit pavucontrol (icône et curseur) ; paliers d'icône à 32/33 et 65/66 %, icône muette.
- Clics GPU / CPU / mémoire / mises à jour : commandes `nvtop`, `btop`, `btop`, `bash -c <mise à jour>` reçues par un terminal factice
  (copie de test du dépôt) ; recomptage après la mise à jour.
- Molette sur les espaces de travail : précédent / suivant avec bouclage, un cran = un espace.
- Calendrier (fenêtre de test zenity sur un espace vide) : aperçu au survol, épinglage, crans, flèches, titre, clic sur un jour (reste ouvert) ;
  fermeture par clic sur la fenêtre (elle reçoit le clic et le focus), sur le volume (qui passe en muet), sur l'horloge (pas de réouverture
  immédiate, un 2e clic rouvre), sur la barre d'un autre écran, par focus d'une fenêtre au raccourci, et après 5 s hors du calendrier
  (le délai repart si le pointeur revient) ; après un clic dans le calendrier, le clic sur la fenêtre ferme toujours ; le focus revient
  à la fenêtre qui l'avait.
- Module média (Spotify, ta permission) : clic gauche lecture / pause, droit suivant, milieu précédent, molette `playerctld shift` / `unshift`
  (lecteur actif Spotify → Chromium → Spotify) ; rendu en lecture identique à Waybar à 1–3 px ; Spotify remis en pause sur le même morceau.
- Mise à jour réelle (ta permission) : clic → terminal → `paru -Syu` (5 paquets, attend la confirmation) ; terminal fermé sans rien installer
  (verrou pacman libéré) → nouveau comptage (journal `Updates:`).
- Session isolée : cava alimenté par un signal de test (barres 4–5, masqué au silence) ; GPU AMD simulé (capteur `edge`, 52 °C), Intel sans capteur
  et aucune carte → module masqué ; rétroéclairage simulé (42 %) ; batterie absente → masquée ; écran secondaire : pilule volume présente.
- `test-outputs.sh` : 0 échec.

Écarts restants :
- tray absent (phase 5) : le bouton power est seul dans sa pilule, sans padding gauche (comme dans Waybar, où le tray le précède) ;
- silence de cava : décidé sur les barres à zéro (Waybar : échantillons d'entrée nuls) — différence seulement pour un son très faible ;
- réseau : interface de la route par défaut (`bridge0` ici) au lieu de `eno2` écrit en dur ; débits quasi identiques (même lien physique) ;
  sans route par défaut, le module se masque (Waybar affichait un texte « déconnecté ») ;
- avertissements Qt `QWaylandTextInputv3::disableSurface` à la fermeture du calendrier épinglé : sans effet.

À tester à la main : voir « À faire par toi à la fin » (molette réelle, glisser le curseur, clavier du calendrier, mise à jour confirmée, laptop).
Limites connues du calendrier : juste après un clic dans le calendrier, Échap ne marche plus et un clic sur le fond d'écran ne ferme pas
(la fermeture automatique s'en charge ; fond natif en phase 8b : WALLPAPERS.md). Sinon, un clic sur le fond ferme (`swaybg` laisse passer les clics).

État laissé : Waybar et Dunst actifs, aucune instance `qs`, volume 0,46 non muet, notification de test retirée de l'historique Dunst.

## Compatibilité Hyprland (2026-10-16, à ta demande)

Tests isolés impossibles ici : un Hyprland imbriqué dans Sway exige `xdg_wm_base` v6 (Sway 1.12 : v5) ; en headless ou imbriqué dans
mutter headless, il démarre mais n'alloue aucune image sur la carte Nvidia (`GBM: Failed to allocate a GBM buffer`). Traces effacées.
→ Tests à faire **ensemble dans une session Hyprland** (tu la lances, je prends la main).

Revu et complété d'après le code source d'Hyprland 0.56.2 et l'API Quickshell 0.3.2 :
- `Compositor` : écrans (description recomposée comme sous Sway, taille logique avec rotation), placement des espaces en une requête Lua,
  espace focalisé déplacé, création d'espace (`createworkspacev2`), focus de fenêtre (`activewindowv2`), submap, titre ;
- barre, modules, calendrier : rien de propre à Sway, hors le mécanisme de focus du calendrier (à vérifier sous Hyprland).

À vérifier dans la session Hyprland :
- barres sur les 3 écrans (rendu identique à Sway), espaces de chaque écran, clic et molette sur les espaces (Waybar avait désactivé la
  molette sous Hyprland : à trancher) ;
- répartition des espaces : écrans virtuels (`hyprctl output create headless`), désactivation, création d'espace hors de son bloc,
  focus conservé, règles `persistent` de la config actuelle ;
- modules (volume, média, cava, mises à jour, GPU, CPU, mémoire, réseau) : identiques, rien de propre au compositeur ;
- calendrier : survol, épinglage, fermeture par clic sur une fenêtre / un module / le fond, Échap, focus rendu à la fenêtre.
- notifications (phase 6) : écran choisi par description, repli si l'écran disparaît, survol, clics, boutons d'action ; centre de
  notifications (cloche, panneau, « ne pas déranger »).

## Phase 5 — Tray, réseau, Bluetooth, disques, NordVPN : faite et validée (2026-10-16)

Décisions (2026-10-16) : modules natifs **dans la pilule du tray** (mêmes icônes que les applets) ; leurs fenêtres sont des
**panneaux modernes** (style du calendrier, `THEME.md` § 3 « Panneaux ») ; menus du clic droit des applications : **copie des menus GTK**,
texte en **Inter** (police homogène : ta demande, désormais appliquée à tout texte de Quickshell) ; NordVPN : **derniers pays utilisés**
au lieu de la liste complète, recherche sur tous les pays (ta demande).

Produit :
- `Tray.qml` + `TrayMenu.qml` : tray (actions à l'appui comme Waybar) et menus copiés de GTK (cadre, survol, séparateurs, cases et radios
  du thème, icônes, sous-menus, clavier) ; `TrayIcon.qml` + `services/Icons.qml` : icônes choisies comme GTK (Papirus `16x16@2x/panel`
  pour 32 px), même taille que Waybar.
- Panneaux (`Panel.qml` et composants `PanelRow`, `PanelButton`, `PanelSwitch`, `PanelField`, `PanelSection`) :
  - `NetworkPanel` + `services/Network.qml` : filaire, Wi-Fi (interrupteur, réseaux, mot de passe, oubli), `nm-connection-editor` ;
  - `BluetoothPanel` + `services/Bluez.qml` : interrupteur, appareils, recherche, appairage via un agent `bluetoothctl` (jamais d'acceptation
    automatique, agent par défaut de blueman non touché) ;
  - `DisksPanel` + `services/Disks.qml` : volumes (monter, démonter, ouvrir, déverrouiller, verrouiller), éjection ; montage automatique et
    notifications avec les règles et les textes d'udiskie ;
  - `VpnPanel` + `services/Vpn.qml` : état, interrupteur, pause, derniers pays (historique local), recherche, villes.
- `BarState` : popups ouverts depuis la barre, fermés par un appui sur une barre.

Découvertes :
- Sway (wlroots) ferme un popup « grab » seulement au clic sur une **autre** application ; GTK gère lui-même les clics sur ses propres
  surfaces, Quickshell non → fermeture par la barre (`BarState.closePopups`).
- Un popup affiché ne se redimensionne pas proprement (Sway étire l'ancienne image) : menus affichés une fois leurs entrées reçues,
  panneaux à taille fixe avec zone de clic limitée au cadre (`mask`).
- `SIGUSR1` de Waybar : en mode masqué, la barre reste dessinée sous les fenêtres ; l'indicateur fiable est la zone réservée (y = 75 / 10).
- UDisks2 marque les images disque en boucle comme « système » ; udiskie les gère quand même (règle reprise).
- Le moteur JavaScript de Qt ne connaît pas le drapeau `s` des expressions régulières : le commit `99292c4` ne se chargeait pas,
  corrigé juste après (`5163895`).

Vérifié (Sway, ta session ; Waybar masquée le temps des tests puis rétablie) :
- tray : menus Steam, nm-applet (sous-menu Wi-Fi, « Connection Information » ouvert puis refermé), udiskie ; Activate (WhatsDesk masquée
  puis réaffichée sur l'espace 5) ; fermeture par clic sur la barre ou sur une autre application ; icônes à la taille de Waybar ;
- réseau : panneau, Wi-Fi coupé puis rallumé (panneau mis à jour sans artefact), fermeture par clic sur une fenêtre ;
- Bluetooth : panneau, recherche (appareils à proximité), connexion des écouteurs tentée (échec par délai : ils ne répondaient pas ;
  sortie audio inchangée), chaîne d'appairage jusqu'à l'erreur « AlreadyExists » sur un appareil déjà appairé ;
- disques (images de test, udiskie arrêté le temps du test puis relancé) : montage automatique + « Device mounted », Unmount, Mount, Open
  (nemo), Detach ; volume chiffré : mauvaise phrase → « Job failed », bonne → « Device unlocked », Lock → « Device locked » ;
  notifications de test retirées de l'historique de Dunst ;
- NordVPN : état réel, liste, villes, derniers pays (ordre, doublons, limite de 5 vérifiés par simulation) ; clics sur pays / ville vérifiés
  avec les actions neutralisées ; puis, avec ton accord, actions réelles par le panneau (script détaché, restauration garantie) :
  interrupteur coupé → déconnecté, rallumé → serveur recommandé (Israël, Tel Aviv), pause 5 min → « Paused », clic sur « Netherlands »
  dans les derniers pays → reconnecté (Amsterdam #1301) ; historique mis à jour à chaque connexion.
  Ta demande ensuite : l'interrupteur reconnecte au **dernier pays utilisé** (serveur recommandé seulement sans historique) ;
  vérifié : coupé puis rallumé → Pays-Bas (Amsterdam #1259).

Incident : pendant un test, un clic sur « Cities » a aussi été pris par la ligne du pays et a **connecté le VPN à l'Afghanistan** ;
reconnecté aussitôt aux Pays-Bas (Amsterdam, serveur #1308 au lieu de #1284) ; cause corrigée (les boutons consomment leur clic).

Écarts restants :
- jusqu'à la bascule (phase 10), nm-applet, blueman, udiskie et norduserd tournent encore ; leurs icônes sont masquées dans le tray
  Quickshell tant que le module natif correspondant est présent (doublons retirés à ta demande) ;
- ordre des icônes d'applications : celui de leur enregistrement auprès de Quickshell (Waybar avait le sien) ;
- fonctions des applets non reprises : `BACKLOG.md`.

À tester à la main : voir « À faire par toi à la fin » (ajouts de la phase 5).

État laissé : Waybar, Dunst et udiskie actifs, aucune instance `qs`, aucune image disque attachée, Wi-Fi activé, VPN connecté aux Pays-Bas
(Amsterdam #1259 ; l'historique des pays contient Netherlands, Israel, United Arab Emirates, laissés par les tests).

## Phase 6 — Notifications : faite et validée (2026-10-16)

Décisions (2026-10-16) : texte en **Inter** (police homogène) ; barre de progression remplie en **`blue`** (Dunst : couleurs par défaut hors
palette) ; **boutons d'action** en plus de la parité ; **centre de notifications** (ta demande en cours de phase) avec cloche dans le tray
et « ne pas déranger ».

Produit :
- `services/Notifs.qml` : serveur de notifications, comportement de Dunst 1.13.2 (code lu) — délais, pause au survol, tri, doublons,
  étiquettes de pile, remplacement, indicateurs, âge, markup, historique de 20 ; « ne pas déranger » ; IPC `notifications`
  (`close`, `closeAll`, `historyPop`, `count`).
- `modules/notifications/` : `NotificationPopups.qml` (coin bas-droit de l'écran de `notificationsOutput`, repli sur l'écran principal),
  `NotificationCard.qml` (géométrie de Dunst, `draw.c`).
- `modules/bar/NotificationsPanel.qml` + cloche dans `Tray.qml` (icônes Papirus `notification-inactive` / `-active` / `-disabled`).
- Charte (`THEME.md` § 4, § 12), architecture (§ 10.1.2), références `docs/reference/dunst-cases-{1,2}.png`, `BACKLOG.md`.

Découvertes :
- **Dunst affiche ses notifications sur DP-1 depuis les tests d'écrans de la phase 3** : `monitor = 1` est un numéro d'écran, et l'ordre a
  changé. Rétabli à ta prochaine session Sway ; la version Quickshell choisit l'écran par description.
- Le moteur JavaScript de Qt n'a pas `String.matchAll` ; `transient`, `escape` et `close` ne peuvent pas servir de noms en QML (mot réservé
  ou méthode existante).
- Un `HoverHandler` posé directement dans une `PanelWindow` ne reçoit rien ; dans un élément, si.
- Le `modelData` d'un `Repeater` sur un tableau JavaScript est une copie : pas de comparaison par identité.
- swayidle éteint les écrans après 5 min sans activité ; grim attend alors indéfiniment.
- Session isolée (headless) : pas de pointeur, donc clics et survol testés sur ta session.

Vérifié (Dunst arrêté le temps des tests puis relancé ; captures dans une session isolée ou sur tes écrans, Waybar masquée puis rétablie) :
- rendu comparé à Dunst (références d'origine et nouvelles) : position (coin bas-droit, 4 px), largeur 603 px, écart 20 px, cadre
  `overlay2` / `peach` en critique, coins 15, icône 100 px à 8 px du bord, texte à 32 px de l'icône, barre de progression centrée,
  indicateurs `(AU)` / `(U)`, doublon `(1)`, markup (italique, souligné, gras, barré ; `<span>` ignoré, texte gardé), image d'un fichier,
  emojis et CJK, âge `(1m 3s old)`, texte long renvoyé à la ligne, texte trop long coupé à 600 px ;
- délais : 3 s (`-t 3000`), 10 s (basse, normale), aucun (critique) ; survol : délai suspendu, puis 10 s après le départ du pointeur ;
- souris : gauche ferme, milieu lance l'action `default` (reçue par `notify-send -A`), droit ferme tout ; bouton « Marquer comme lu » →
  action `read` reçue ;
- remplacement par identifiant (progression 10 → 80 % en place), étiquette de pile, `CloseNotification` de l'application,
  `historyPop` (rappelée, elle reste affichée) ;
- centre : point bleu après une expiration, liste (la plus récente en haut, non vues en vert), « Clear », « Clear all », point retiré à la
  fermeture ; « ne pas déranger » : cloche barrée, notification normale directement dans le centre, critique affichée ;
- écran : session isolée à deux écrans, écran principal désactivé → la notification passe sur l'autre.

Écarts restants :
- hauteur des notifications : une ligne d'Inter est moins haute qu'une ligne de Noto Sans Mono (2 lignes : 86 px au lieu de 94) ;
- icône `audio-volume-high` : trouvée par Quickshell, pas par Dunst (la notification de référence n'avait pas d'icône) ;
- jusqu'à la bascule (phase 10), Dunst reste le serveur actif ; Quickshell prend le relais dès qu'il s'arrête.

À tester à la main : voir « À faire par toi à la fin » (ajouts de la phase 6).

État laissé : Waybar et Dunst actifs, aucune instance `qs`. L'arrêt de Dunst a vidé son historique (en mémoire) ; il est sauvegardé hors
du dépôt dans le dossier temporaire de session (`notif/dunst-history-backup*.json`). Les notifications reçues de tes applications pendant
les tests sont arrivées dans les instances de test (ex. une notification « Video (0:06) ») et ne sont plus consultables.

## Revue de l'API Quickshell (2026-10-16, à ta demande)

Tous les types de la documentation 0.3.0 passés en revue : `ARCHITECTURE.md` § 12 (utilisé / prévu / ajouté / écarté, avec la raison).
Ajouts au plan :
- **avant la phase 7**, mise à niveau du code déjà fait : `ScriptModel` (listes), `PersistentProperties` (historique des notifications,
  « ne pas déranger »), `JsonAdapter` (derniers pays VPN), et **`WindowManager`** (protocole `ext-workspace`, commun à Sway et Hyprland)
  pour les espaces de travail à la place du code propre à chaque compositeur — `scripts/test-outputs.sh` rejoué sur Sway ;
- phase 7-8 : `LazyLoader` (lanceur, menu d'applications) ; `IdleInhibitor` (« garder l'écran allumé », emplacement à décider en phase 8) ;
  `NMSettings` (connexions enregistrées dans le panneau réseau) ;
- phase 8b : outil de capture entièrement natif (`ScreencopyView`, `Toplevel`) au lieu de `grim`/`slurp` ;
- phase 9 : `HyprlandFocusGrab` pour fermer panneaux et calendrier sous Hyprland ;
- laptop : `PowerProfiles` (`power-profiles-daemon`, dépendance optionnelle).

### Mise à niveau faite (2026-10-16)

- `ScriptModel` sur toutes les listes construites en JavaScript (espaces de travail, tray, réseaux, Bluetooth, disques, pays VPN,
  notifications, centre) ; une entrée du centre est retirée par sa clé.
- `PersistentProperties` : historique des notifications et « ne pas déranger » gardés au rechargement (historique en texte JSON).
- `JsonAdapter` : derniers pays VPN dans `vpn.json` ; ton historique (Netherlands, Israel, United_Arab_Emirates) converti, ancien fichier supprimé.
- `WindowManager` : **non migré** après essai sous Sway (couverture partielle, voir `ARCHITECTURE.md` § 12) ; gardé en réserve pour Hyprland.
- Corrigé au passage : dégradé des espaces avec un index -1 (bouton en cours de retrait).

Vérifié (Sway, ta session ; Waybar masquée et Dunst arrêté le temps des tests, puis rétablis) : barre et espaces (changement d'espace) ;
panneaux VPN (derniers pays relus du nouveau fichier, réécrits dans le bon ordre), réseau, Bluetooth ; disques (image ext4 de test montée
automatiquement, puis détachée et supprimée) ; notifications : historique conservé après un rechargement, notification affichée conservée,
« Clear » retire l'entrée visée.

### Deuxième passe (2026-10-16) : faite

Bilan : `ARCHITECTURE.md` § 12.1. Tes choix, tous faits :
- **panneau audio** (clic droit sur le volume ou le curseur ; `pavucontrol` derrière « Advanced… ») : sortie, entrée, volume par application ;
- **molette du média** : passe d'un lecteur MPRIS à l'autre (`playerctld` exclu : simple relais) ; icônes de lecteurs de ta config Waybar ;
  `qs ipc call media playPause|next|previous` pour les touches ; `playerctl` retiré des dépendances ;
- **OSD** volume / micro / luminosité : `qs ipc call audio volumeUp|volumeDown|toggleMute|toggleMicMute|cycleSink`,
  `qs ipc call brightness up|down` (raccourcis branchés en phase 10) ; position et durée **à valider** (`THEME.md` « OSD ») ;
- **connexion limitée** : icônes Papirus `*-limited` / `*-no-route` et message dans le panneau réseau ;
- **alerte batterie** : notifications à 30 % et 15 % (seuils de ta config Waybar), une fois par décharge.
Ta demande en cours de route : **trois boutons de profil d'énergie** dans la future fenêtre de réglages (phase 8) ;
`power-profiles-daemon` ajouté aux dépendances principales (service à activer).

Découvertes : Quickshell n'expose pas `media.class` des nœuds Pipewire ; une lecture est de type `AudioOutStream` (Audio | Stream | Sink),
un enregistrement (cava) `Audio | Stream | Source`. `TextMetrics` ne mesure pas comme le rendu natif du texte (largeurs mesurées avec un
texte invisible).

Vérifié (Sway, ta session, Waybar masquée puis rétablie) : OSD volume (+5 % puis −5 %, retour à 0,41) et micro (coupé puis rétabli) ;
panneau audio (sortie, entrée, Spotify avec son icône ; muet et curseur de Spotify, volume remis à 100 %) ; molette du média dans les deux
sens (Spotify, deux Chromium). Incident : pendant le premier essai de molette, le module rétréci a laissé le pointeur sur le curseur de
volume, monté de 0,41 à 0,51 ; remis à 0,41.

### Troisième passe (2026-10-16) : faite

Bilan : `ARCHITECTURE.md` § 12.2. **Carte média** faite (centre de notifications). Planifiés : sélecteur de couleur et verrouillage avant
la veille (laptop seulement) en phase 8b ; bascules HDR et VRR dans la fenêtre de réglages (phase 8) ; vue des fenêtres après la
première version.
Vérifié : carte affichée avec Spotify (pochette, titre, position) ; Spotify ignorait toute commande MPRIS ce jour-là (même par D-Bus
direct), donc boutons, progression et avance dans le morceau vérifiés avec un faux lecteur MPRIS (Play, Next, Pause, SetPosition reçus) ;
icône par défaut des lecteurs vue sur ce faux lecteur.

### Quatrième passe (2026-10-16) : faite

Bilan : `ARCHITECTURE.md` § 12.3. Fait : commande `qs ipc call vpn connect [pays] | disconnect` (vérifiée exposée, pas exécutée : une
reconnexion couperait la session) ; section « Private networks » du panneau réseau (Tailscale : adresse, 8 appareils ; ZeroTier :
interface et adresse — vérifié sur ta session). Planifié : commandes HDR / VRR sur les écrans compatibles (phase 8). Autostart XDG laissé tel quel.

### Cinquième passe (2026-10-16) : rien de nouveau

Modules du code source = ceux de la documentation ; singleton `Quickshell` : seulement deux points pour la phase 10 (`reload()` en IPC
pour `$mod+Ctrl+W`, fenêtre « config rechargée » à garder ou masquer). `ARCHITECTURE.md` § 12.4.

## Phase 7 — Lanceur : faite et validée (2026-10-16)

Produit :
- `services/Apps.qml` : applications, filtres de Rofi (`OnlyShowIn` / `NotShowIn` / `TryExec`), tri par fréquence, recherche, lancement,
  historique (`launcher.json`, état local, repris de Rofi à la première ouverture).
- `modules/launcher/Launcher.qml` (IPC `launcher` : `toggle`, `open`, `close` ; `LazyLoader`) et `LauncherWindow.qml` (thème `launcher.rasi`).
- `Theme.qml` / `THEME.md` § 5 : taille en **points** (20 pt = 26,67 px, mesuré), espacement 2 px, glyphe du prompt `U+F444`.
- Comportement détaillé : `ARCHITECTURE.md` § 10.1.3 (code de Rofi 2.0.0 lu).

Vérifié (Sway, ta session ; instance de test limitée au lanceur, puis instance complète avec Waybar masquée puis rétablie) :
- rendu comparé à la capture Rofi : même position (1470, 252 sur DP-2), mêmes 17 lignes dans le **même ordre** (historique Rofi repris),
  mêmes couleurs, icônes et tailles ; 2 % de pixels différents (lissage des polices) ; aussi sur DP-1 (échelle 1.5) ;
- clavier, par un clavier virtuel (uinput) et seulement lanceur ouvert : recherche (« fire », « lib calc », « lib -calc »), Bas / Haut /
  Tab / Ctrl+N / Ctrl+P, Pages et Fin (pagination par 17), Début, édition Ctrl+A/E/B/H/K/U/W, Alt+B, Ctrl+Alt+H, Ctrl+Haut / Ctrl+Bas
  (textes saisis), Maj+Suppr (retiré de l'historique), Échap ;
- lancements : Calculatrice (Entrée, puis double clic ; compteur +1), htop dans `gnome-terminal` (`Terminal=true`), commande saisie par
  Ctrl+Entrée, par Entrée sans résultat, et dans un terminal par Ctrl+Maj+Entrée — fenêtres de test refermées ;
- souris : clic = sélection, molette (souris virtuelle) dans les deux sens, clic à côté et clic sur une barre = fermeture ;
- IPC `launcher toggle|open|close` sur l'instance complète ; ouverture sur l'écran focalisé (DP-1 puis retour du focus sur DP-2).

Écarts restants :
- glyphe du prompt : Qt lui donne une avance plus large que Pango, la largeur est donc calée sur une cellule Hack (même position mesurée) ;
- après Maj+Suppr, l'application reprend sa place alphabétique (Rofi la cachait jusqu'à la prochaine ouverture) ;
- l'historique Rofi est repris à la **première ouverture** du lanceur Quickshell : d'ici la bascule (phase 10), Rofi reste ton lanceur et
  son historique continue d'évoluer ; le fichier de test a été effacé pour que la reprise se fasse au moment de la bascule.

À tester à la main : voir « À faire par toi à la fin » (ajout de la phase 7).

État laissé : Waybar et Dunst actifs, aucune instance `qs`, focus sur DP-2.

## Phase 8 — Menus et scripts : faite, à valider (2026-10-17)

### Panneau de réglages façon GNOME : fait (2026-10-16)

- Bouton engrenage (`SettingsButton.qml`, module `settings` de hosts/*.json, ex-`power`) ; panneau `SettingsPanel.qml` : surface de la
  couche Overlay (ouvrable au clavier : `qs ipc call settings toggle`), fermée par Échap, un clic à côté, sur une barre ou sur un autre
  écran (`OutsideClick.qml`, aussi utilisé par le lanceur).
- Contenu : batterie (laptop), capture d'une zone (grim + slurp en attendant la phase 8b), verrouiller / se déconnecter / redémarrer /
  éteindre (tes 4 SVG en 32 px, sans confirmation) ; curseurs son et micro (clic sur l'icône : muet ; flèche : choix du périphérique,
  toujours affichée, puis « Advanced… »), luminosité (laptop) ; profils d'énergie (masqués sans `power-profiles-daemon`) ; bascules
  ne pas déranger, écran allumé (`IdleInhibitor` sur les barres), veilleuse (`wlsunset`, 20:00 – 06:00, 3239 K : tes réglages GNOME),
  HDR et VRR (tous les écrans compatibles, Sway ; Hyprland en phase 9), mode avion (laptop, `rfkill`).
- Services : `Session`, `Displays` (IPC `display toggleHdr|toggleVrr`), `NightLight`, `Profiles`, `Rfkill` ; composants partagés avec le
  panneau audio et l'OSD : `AudioDevices`, `MixerButton`, `PercentLabel`, `PanelFrame`.
- Vérifié (Sway, ta session) : ouverture par l'engrenage et par IPC ; fermetures ; ne pas déranger (cloche barrée) ; veilleuse (`wlsunset`
  lancé avec les bons réglages, relancé après un rechargement) ; HDR sur DP-1 et DP-3 puis rétabli ; VRR sur les trois écrans puis
  rétabli ; volume, muet, choix de la sortie (avec une sortie de test) et de l'entrée ; capture d'une zone (fichier et presse-papiers,
  supprimés ensuite).
- Non vérifiable ici : voir « À faire par toi à la fin ».

### Revue de code complète (2026-10-16, à ta demande) : 10 problèmes, tous corrigés

1. Clé chiffrée : le volume déchiffré n'avait pas de disque parent (affiché « locked », jamais démonté ni verrouillé avant l'éjection).
2. Verrouillage : démontage puis verrouillage l'un après l'autre (ils partaient en même temps).
3. Éjection : démonter, verrouiller, éteindre en séquence, arrêt à la première erreur (une éjection ratée éteignait le disque plus tard).
4. Lanceur : fermé par un clic sur un autre écran (il gardait le clavier).
5. Espace créé en arrière-plan sur le mauvais écran : l'écran d'arrivée garde l'espace qu'il affichait.
6. Popups ouverts suivis par une liste, retirés quand leur barre disparaît (écran retiré).
7. Menus du tray : ↑ sans sélection choisit la dernière entrée.
8. Notifications : une image envoyée en données reste dans l'historique (objet retenu par `RetainableLock`).
9. Écran principal : jamais élu sur une description vide.
10. Code en double entre le panneau audio, le panneau de réglages et l'OSD : composants partagés.
Vérifié sur ta session : image LUKS de test (déverrouiller, verrouiller, détacher, éjection d'un volume occupé), espace 3 créé sur DP-3
avec une règle provisoire (rétablie), écran virtuel retiré calendrier épinglé (`qs ipc call bar state` revient à zéro), notification de
test avec image (Dunst arrêté puis relancé).

### Revue de code, seconde passe (2026-10-16) : 10 problèmes, tous corrigés

Les 10 corrections de la première passe ont été revérifiées ; deux étaient incomplètes (1 et 3 ci-dessous).
1. Espace créé en arrière-plan, cas courant (seule fenêtre envoyée vers un espace d'un autre écran) : l'espace de départ était détruit
   puis recréé ailleurs. Sous Sway, les espaces qui ont des fenêtres sont maintenant déplacés par critère, sans s'y rendre. Nouveau
   scénario dans `scripts/test-outputs.sh` (il échoue avec l'ancien code : 2 corrections au lieu d'une ; 0 échec avec le nouveau).
2. cava : ne s'arrêtait plus quand plus aucun module ne l'affichait, après une relance.
3. Images en données des notifications reçues en « ne pas déranger » : gardées aussi.
4. NordVPN : module revérifié toutes les 30 s s'il est masqué (démon pas prêt à l'ouverture de session).
5. `scripts/test-outputs.sh` : instance de test sur son propre bus de session, sans montage automatique de tes disques, arrêt si la
   session de test est introuvable.
6. Bluetooth : appairage réussi après fermeture du panneau : appareil quand même approuvé et connecté.
7. Disques et filtres du lanceur : un changement pendant une lecture déclenche une nouvelle lecture (il était perdu).
8. NordVPN : liste de villes demandée pendant qu'une autre se charge : chargée ensuite.
9. `swaylock` ajouté aux dépendances jusqu'à l'écran de verrouillage natif.
10. Commande de mise à jour par défaut : `paru`, sinon `yay`, sinon `sudo pacman -Syu` (paru n'est pas forcément installé).
Vérifié : suite `test-outputs.sh` complète (0 échec), relance de cava, image en « ne pas déranger » (Dunst arrêté puis relancé),
deux listes de villes demandées coup sur coup (VPN resté connecté), image LUKS déverrouillée affichée montée puis détachée.

### Revue de code, troisième passe (2026-10-16) : autres catégories, 10 problèmes, tous corrigés

Sécurité, performance, conventions, documentation, portabilité, clavier.
1. **Injection de commande** : la valeur `TryExec` des fichiers `.desktop` passait dans une chaîne exécutée par un shell (au démarrage,
   sans clic). Vérifiée maintenant en argument ; fichiers piégés de test sans effet ; même liste masquée qu'avant sur ta machine (43).
2. Bluetooth : un appareil voisin ne peut plus imiter une question ou une réussite d'appairage par son nom.
3. Barre par défaut (laptop sans fichier machine) : batterie et rétroéclairage ajoutés (masqués sans le matériel).
4. Notifications : icônes locales seulement (une adresse http faisait télécharger l'image à chaque affichage).
5. Panneau de réglages et panneaux du tray utilisables au clavier : Tab / ↑ / ↓, Entrée / Espace, ← / → sur les curseurs, liseré `text`.
6. Carte média : position relue seulement centre de notifications ouvert.
7. GPU Nvidia sans `nvidia-smi` (nouveau) : capteur du noyau à la place, plus de sondage inutile.
8. Documentation remise d'accord avec le code (IPC `display`, agent Bluetooth, `vpn.json`, police des notifications).
9. Lanceur : champs de recherche en minuscules calculés une fois ; lignes gardées d'une frappe à l'autre.
10. Opacité « indisponible » et épaisseurs des menus du tray dans `Theme.qml`.
Vérifié : script des filtres extrait et lancé sur des fichiers piégés ; tri des lignes de bluetoothctl ; sources d'icônes ; repli GPU
(config de test, faux sysfs, sans puis avec un `nvidia-smi` en échec : 47 °C lus) ; recherche du lanceur (config de test, 233
applications) et rendu ; clavier dans le panneau de réglages (volume +5 % puis rétabli). Deux recherches `find /` laissées par les
agents de revue ont été arrêtées ; l'historique du lanceur recréé par un test a été supprimé (reprise de Rofi gardée pour la phase 10).

### Séance de débogage (2026-10-16, tes retours)

1. **Halo de l'espace actif** : le flou de MultiEffect (approché par paliers) faisait un carré diffus qui sortait de la pilule. Remplacé
   par l'ombre floue (`shadowBlur` 10) du glyphe dessiné dans un Canvas, mesurée contre la capture Waybar : écart moyen 1,3/255 (avant :
   6/255). Le halo est coupé aux limites du module : plus rien au-dessus de la pilule ni à gauche du premier espace (vérifié au pixel,
   DP-2 en échelle 1 et DP-1 en échelle 1.5).
2. **Halo sur chaque écran** (ta demande) : l'espace affiché sur chaque écran a son halo, plus seulement celui qui a le focus (Waybar :
   le focalisé seul). Vérifié sur les trois barres et au changement d'espace.
3. **cava** (ta demande) : affiché et lancé pendant toute lecture MPRIS, même à bas niveau ; masqué et arrêté quand rien ne joue (plus
   de détection du silence).
4. **Lecteur suivi** (ta demande) : Spotify s'il joue, sinon le lecteur qui joue (Chromium…), sinon Spotify. Un choix fait à la molette
   tient jusqu'au prochain démarrage d'une lecture.
5. Carte média : `root.QsWindow` valait `undefined` (erreur dans le journal depuis la troisième passe) : propriété attachée lue sur
   l'Item lui-même.
Vérifié : faux lecteurs MPRIS (script Gio) dans une instance de test dont le lecteur préféré est un faux — autre lecteur seul → suivi ;
préféré qui démarre → préféré ; préféré en pause → l'autre ; molette vers un lecteur en pause puis lecture ailleurs → lecteur qui joue ;
cava lancé pendant la lecture et arrêté après. Dans la vraie barre : cava visible pendant une lecture de 5 s, puis retour sur Spotify.
Incident de développement : une version du halo qui relisait les pixels du Canvas bloquait l'instance (100 % CPU, `qs kill` sans effet,
trois instances empilées) ; abandonnée, instances arrêtées.

### Menu d'applications (remplace nwg-menu) : fait (2026-10-17)

- `modules/menus/AppMenu.qml` (disposition de Cinnamon, style de nwg-menu, code propre sans dépendance à Cinnamon : `ARCHITECTURE.md`
  § 10.1.5), ouvert par le bouton Arch (vert tant qu'il est ouvert) ou `qs ipc call menu toggle`.
- Tes choix : dossiers XDG ; les 4 boutons de session ; catégories au survol ; « Recent Files ». Ta demande : **le survol n'efface jamais
  la recherche** (défaut de nwg-menu) — pendant une recherche, le survol des catégories ne fait rien, seul un clic la quitte.
- Favoris : clic droit → ajouter / retirer ; tes 4 épinglés de nwg-menu repris (Files, Geany, Windows 10, Windows 10 - QXL).
- Services : `Apps` (catégories freedesktop, favoris), nouveau `Places` (dossiers XDG, fichiers récents, `xdg-open`).
- Vérifié dans un Sway isolé sans écran (tes écrans étaient en veille ; pointeur et clavier virtuels propres à cette session, outil de
  test hors dépôt) : rendu en échelle 1 et 1.5 ; survol des catégories, dossiers, boutons ; **recherche « image » puis survol de trois
  catégories et des applications : recherche et résultats intacts** ; clavier (Gauche, Bas, Droite, Bas) ; « calc » + Entrée lance la
  Calculatrice et ferme le menu ; clic sur Documents ouvre le gestionnaire de fichiers ; ajout puis retrait d'un favori (fichier revenu
  à tes 4 favoris) ; Échap, clic à côté, bouton Arch (ouvre / ferme) ; Recent Files rempli (vérifié sans regarder la liste) ;
  rechargement à chaud menu ouvert. Boutons de session non cliqués.
- Écart à valider : tailles d'icônes (48 px applications, 24 px le reste, `THEME.md` § 7).

### Revue de code du menu (2026-10-17, `/code-review`) : 10 problèmes, tous corrigés

1. Survol d'une application : ne sélectionne plus que si la souris a bougé (une liste qui défile ou change sous un pointeur immobile
   volait la sélection du clavier ; Entrée lançait la ligne sous le pointeur).
2. Hauteur limitée à l'écran ; colonnes défilantes (petit écran de laptop).
3. `recently-used.xbel` (610 Ko, ~1000 entrées ici) : lu à l'ouverture du menu seulement, plus à chaque réécriture par GTK.
4. Icônes des fichiers récents : cherchées pour les lignes affichées, une fois par type.
5. Liste remise en haut seulement sur une action (saisie, catégorie), plus quand les données changent d'elles-mêmes.
6. Pages : nombre de lignes juste (espacement compté, comme le lanceur).
7. Entités XML : `&amp;` décodé en dernier.
8. Fichiers récents absents et dossiers XDG inexistants omis (ici 447 fichiers présents sur 994).
9. Visée vers la liste des applications : les catégories traversées en diagonale ne sont plus prises.
10. Tailles de police du menu : celles de `Theme.font` (doublons retirés).
Vérifié dans le Sway isolé : diagonale Games → une application du bas (Games gardé), descente verticale (catégorie prise à l'arrêt) ;
saisie et 9 × Bas sous un pointeur immobile (sélection du clavier respectée) ; écran de 500 px de haut (cadre limité, colonnes qui
défilent à la molette, recherche et boutons visibles) ; Recent Files rempli.
Remarqué au passage, hors menu : sur un écran de 1280 px de large, les modules du centre de la barre principale chevauchent ceux de
gauche — à traiter avec la config laptop (phase 11).

### Revue de code du menu, seconde passe (2026-10-17) : 10 problèmes, tous corrigés

1. Raccourci du menu (et des réglages) : ferme le panneau ouvert sur n'importe quel écran, au lieu d'en ouvrir un second ailleurs.
2. Ouvrir le menu, les réglages ou le lanceur ferme les autres popups : plus deux surfaces au clavier exclusif empilées.
3. Menu contextuel fermé quand la liste change (catégorie, saisie, défilement) ; son survol ne passe plus aux lignes dessous.
4. Pages dans la colonne des catégories : première / dernière catégorie (ne déplaçaient plus la sélection cachée des applications).
5. Fichiers récents relus pendant la vérification de leur présence : résultat périmé ignoré, vérification relancée.
6. Curseur de défilement : reste dans sa gouttière en bas de liste ; se fait glisser.
7. Colonne de gauche limitée à 270 px (`THEME.md` § 7, à valider) ; le cadre reste dans l'écran si sa largeur change.
8. Code commun du menu et du panneau de réglages dans `OverlayPopup.qml` ; recherche du bouton commune dans `BarState.toggleFrom`.
9. `Apps` : tri par nom et catégories calculés sur les applications, plus refaits à chaque lancement (l'historique change).
10. Largeur de la colonne des applications liée à celle du lanceur, comme documenté.
Trouvé en testant et corrigé : juste après l'ouverture, la première ligne survolée n'était pas sélectionnée.
Vérifié dans le Sway isolé : raccourci deux fois (ouvre, ferme) ; réglages puis menu, lanceur puis menu (un seul popup ouvert) ;
clic droit puis survol d'une catégorie (menu contextuel fermé, catégorie prise) ; premier survol après l'ouverture ; saisie sous un
pointeur immobile ; Pages dans les catégories ; glissement du curseur jusqu'en bas sur un écran de 500 px ; six ouvertures rapides
puis Recent Files rempli.

### Revue de code du menu, troisième passe (2026-10-17) : 7 problèmes, tous traités

1. Ligne survolée retenue par son identifiant (l'indice changeait avec la liste : sélection d'une autre ligne, ou hors liste).
2. Lanceur : `open` sur un lanceur déjà ouvert le remet à zéro sans se fermer (la saisie était enregistrée comme déjà tapée).
3. Fichiers récents : chaque vérification ne filtre que la liste qu'elle a vérifiée (indépendant de l'ordre des signaux).
4. Garde de 400 ms limitée à l'appui sur le bouton qui vient de fermer le panneau : un raccourci rapide rouvre toujours.
5. Menu et panneau de réglages en un seul exemplaire (`BarState`), déplacés sous le bouton qui les ouvre.
6. Le lanceur s'appuie aussi sur `OverlayPopup` (plus de copie de la surface, des fermetures et de la règle « un seul popup »).
7. Largeur de la colonne de gauche : posée sans te demander ; tu as choisi 270 px.
Vérifié dans le Sway isolé, avec deux écrans virtuels et une copie de config où la barre secondaire a aussi le bouton Arch et
l'engrenage : menu ouvert sur l'écran 1, clic sur le bouton de l'écran 2 (le menu s'y déplace), re-clic (fermé) ; trois raccourcis
rapides (ouvert, fermé, ouvert) ; menu ouvert à la souris puis raccourci (fermé) ; lanceur ouvert deux fois (reste ouvert) ; saisie
sous un pointeur immobile puis un pixel de mouvement (la ligne sous le pointeur est prise). Historique du lanceur recréé par
l'instance de test supprimé (reprise de Rofi gardée).

### Revue de code du menu, quatrième passe (2026-10-17) : 10 problèmes, tous corrigés

1. Panneau ouvert sur un écran qui disparaît : il se ferme (il serait resté au clavier sur un autre écran).
2. Plus d'import circulaire entre `modules/bar` et `modules/menus` : le menu est créé par `Menus.qml` (depuis `shell.qml`).
3. Lanceur déjà ouvert : `open` ne change plus son écran.
4. Ligne survolée retirée de la liste (filtrée par la recherche) : oubliée, plus de sélection d'une ligne absente du pointeur.
5. Vérification des fichiers récents : une nouvelle ne démarre qu'une fois la précédente lue et terminée (sans dépendre de l'ordre).
6. Garde de 400 ms remplacée par l'ordre réel des événements (`BarState.pressClosed`) : Échap puis un clic rapide rouvre.
7. Le lanceur passe aussi par `OverlayPopup.prepareOpen` (règle « un seul popup » à un seul endroit).
8. `BarState.settingsButton` inutilisé : retiré.
9. Doublons menu / réglages de `BarState` regroupés (`toggle`, `register`, `openedUnder`, `toggleFromShortcut` par type).
10. Ligne survolée vérifiée par son indice tenu à jour (plus de parcours de la liste à chaque mouvement).
Trouvé en testant et corrigé : `Menus.qml` sans `import QtQuick` (`Component.onCompleted` indisponible).
Vérifié dans le Sway isolé, deux écrans, copie de config avec bouton Arch et engrenage sur les deux barres : trois clics sur le même
bouton (ouvert, fermé, ouvert) ; Échap puis clic immédiat (rouvert) ; menu ouvert sur l'écran 2 puis écran débranché (fermé, rien
sur l'écran 1) ; « fir » sous le pointeur puis retour arrière et un pixel de mouvement (ligne réellement sous le pointeur choisie).

### Revue de code du menu, cinquième passe (2026-10-17) : 6 problèmes, tous corrigés

1. Fichiers récents : vérifications numérotées (la sortie porte son numéro) ; un échec de lancement ne bloque plus les suivantes.
2. Calendrier : même mécanisme que les panneaux (`BarState.pressClosed`) au lieu de son délai de 400 ms ; l'horloge réagit à
   l'appui (comme les boutons), sinon l'appui sur la barre était oublié avant le clic.
3. Lanceur : fermé si son écran change pendant qu'il est ouvert (écran retiré), comme les panneaux.
4. Ligne survolée : référence à la ligne elle-même, remise à vide à sa destruction (plus d'identifiant ni d'indice à synchroniser).
5. `BarState` : types de panneaux ou de boutons inconnus acceptés (listes vides par défaut).
6. Menu et panneau de réglages créés et inscrits de la même façon, par `modules/menus/Panels.qml` (ex-`Menus.qml`).
Vérifié dans le Sway isolé, deux écrans : menu puis réglages par raccourci ; lanceur ouvert sur l'écran 2 puis écran débranché
(fermé) ; calendrier épinglé, Échap puis clic immédiat (épinglé), clic (fermé, pas rouvert), clic (épinglé) ; recherche qui retire la
ligne survolée puis la rétablit (ligne sous le pointeur choisie) ; Recent Files rempli.

### Revues en boucle (2026-10-17, à ta demande : jusqu'à ne plus trouver que du négligeable)

Passe 1 (tout le travail du menu et des popups depuis `d447c18`) : 10 points.
- Corrigés : clic sur la bordure du menu contextuel qui lançait l'application dessous ; menu ouvert sous un pointeur immobile qui
  prenait la ligne ou la catégorie sous lui ; Entrée et flèches qui agissaient derrière le menu contextuel (Entrée valide maintenant
  son action) ; icônes cherchées pour toute la liste à chaque frappe (maintenant par ligne affichée) ; fichiers récents lus à chaque
  ouverture (maintenant seulement quand « Recent Files » s'affiche) ; « appui qui vient de fermer » remplacé par la cause : la barre
  ne ferme plus le popup dont le bouton est sous l'appui (`owner`), le bouton le ferme lui-même — l'horloge réagit de nouveau au
  clic ; commentaires « tout l'écran » faux (zone utile sous les barres) et commentaires trop longs raccourcis ; vérification des
  fichiers récents simplifiée.
- Jugé négligeable : vérification de présence bloquée par un montage réseau mort (spéculatif ; bloquerait aussi un gestionnaire de
  fichiers).
Vérifié (Sway isolé, deux barres avec bouton Arch et engrenage) : Arch ×3 (ouvert, fermé, ouvert) ; engrenage menu ouvert (réglages
seuls) ; engrenage (fermé) ; horloge ×3 (épinglé, fermé, épinglé) ; Échap puis clic (épinglé) ; Arch calendrier épinglé (menu seul) ;
raccourci sous un pointeur posé sur les catégories (All Applications, première ligne) ; clic sur la bordure du menu contextuel (rien
lancé) ; Entrée dans le menu contextuel (favori ajouté puis retiré : tes 4 favoris) ; Recent Files rempli.

Passe 2 : 10 points.
- Corrigés : icône d'un panneau du tray ouvert qui le refermait puis le rouvrait (les panneaux et le menu du tray ont aussi un
  `owner`) ; clic droit ou du milieu sur le bouton d'un panneau ouvert qui ne faisait rien (`ownerButtons` : boutons gérés) ; clic
  ailleurs dans le menu, menu contextuel ouvert, qui agissait (il ne fait plus que le fermer) ; survol jugé avant que le mouvement
  soit vu (décidé après l'événement, sur le compteur de mouvements du cadre : plus de bascule de catégorie ni de sélection quand la
  liste change sous un pointeur immobile) ; position du menu contextuel recalculée avec sa taille ; chemins d'icônes encodés
  (`Icons.fileUrl`, partagé avec les notifications et le tray) ; exception de `closePopups` passée en argument (plus d'état global).
- Gardé : les deux protections de la vérification des fichiers récents (le numéro protège de l'ordre des signaux).
- Tailles d'icônes du menu : à te demander (fin de boucle).
Vérifié (Sway isolé, deux barres) : Arch, clic droit sur Arch (fermé), engrenage, clic droit sur l'engrenage (fermé), horloge ×2,
Arch ×2 ; cloche du tray ×3 et clic droit ; clic sur une autre ligne, menu contextuel ouvert (fermé, rien lancé) ; diagonale (Games
gardé) ; descente (Internet) ; saisie sous un pointeur immobile (première ligne) puis Bas ×2.

Passe 3 : 8 points, tous corrigés : retour du pointeur sur la catégorie déjà choisie (remettait la liste à zéro) ; icône du tray
dont le menu s'ouvre au clic gauche (le clic gauche le referme) ; calendrier épinglé fermé dès l'appui sur l'horloge, même long ou
glissé ; survol sans effet sous le menu contextuel ; défilement vers la sélection lié à `selected` (plus à l'indice interne de la
liste) ; fichiers récents lus une fois par ouverture ; icône par type de fichier dans `Icons.mimeIcon` ; curseur de défilement
centré dans sa gouttière.
Vérifié (Sway isolé) : calendrier épinglé puis appui long (fermé), puis appui glissé (fermé), clic (épinglé) ; 30 × Bas puis retour
sur la catégorie choisie (sélection gardée) ; menu contextuel d'un favori puis passage sur les catégories (gardé) ; recherche puis
Pages (sélection visible).

Passe 4 : 8 points, tous corrigés : sélection qui suit son élément quand la liste change d'elle-même (et plus son numéro de ligne) ;
vérification des fichiers récents limitée à 5 s (gvfs ou montage réseau qui ne répond plus : liste montrée sans filtre) ; index de
recherche du lanceur plus refait à chaque lancement ; dossiers XDG relus à chaque ouverture ; règle « catégorie survolée prise » en
un seul endroit ; position sous un bouton partagée (`BarState.panelLeft`, menu, réglages, panneaux du tray) ; cache d'icônes par
type sans paramètre ambigu ; boutons de session du menu = `QuickButton` (style de nwg-menu, accessibles au clavier).
Vérifié (Sway isolé) : rendu, survol du bouton d'extinction, Recent Files, recherche et Pages, panneau de réglages inchangé.

Passe 5 : 8 points.
- Corrigés : **Tab dans le menu** (régression de la passe 4 : le focus passait aux boutons de session, puis Entrée verrouillait ou
  éteignait sans confirmation) — Tab / Maj+Tab déplacent la sélection, comme le lanceur, et les boutons de session ne prennent plus
  le focus ; panneau audio ouvert au clic droit qui ne se fermait plus au clic gauche — l'élément qui ouvre un panneau indique les
  boutons de souris qu'il gère (`Panel.toggle(item, boutons)`, `TrayMenu.openAt(…, boutons)`) ; sélection qui gardait l'identifiant
  d'un élément disparu ; liste des récents gardée après l'effacement de l'historique ; dossiers XDG relus seulement quand
  user-dirs.dirs change.
- Jugés négligeables : plafond du nombre de fichiers récents (lecture une fois par ouverture de la catégorie) ; import d'épingles
  nwg-menu dans des sous-dossiers (spéculatif ; tes 4 épingles sont reprises).
Vérifié (Sway isolé) : Tab ×3 puis Échap (menu fermé), Tab ×3 sans souris (sélection 0 → 1 → 3) ; panneau audio clic droit ×2
(ouvert, fermé) ; cloche gauche puis droit. Non testé ici (agirait sur ton vrai son) : clic gauche ou du milieu sur l'icône du
volume, panneau audio ouvert.

Passe 6 : 9 points, plus aucun défaut fréquent.
- Corrigés : largeur du menu limitée à l'écran (écran étroit de laptop : la colonne des applications se resserre) ; historique effacé
  qui pouvait réapparaître (vérification en cours ignorée) ; changement de user-dirs.dirs pendant une relecture (relu ensuite) ;
  menu contextuel fermé si les applications sont relues ; catégorie survolée oubliée quand la liste des catégories est recréée.
- Jugés négligeables : deux chemins pour la sélection au survol (mêmes conditions) ; fermeture diffusée à chaque type de popup
  (maintenabilité) ; double garde de lecture des récents ; icônes génériques de shared-mime-info (cosmétique).
Vérifié (Sway isolé) : menu à 2560 px (inchangé) et sur un écran de 900 px (tient dans l'écran).

Passe 7 : **aucun défaut significatif** (critère d'arrêt atteint). Petites corrections faites quand même : Tab bloqué sous le menu
contextuel ; dossiers XDG revérifiés à chaque ouverture (dossier créé ou supprimé) ; défilement différé après la mise à jour de la
liste ; résolution d'icône partagée (`Icons.iconSource`, lanceur, menu, notifications). Négligeable : texte du fichier des récents
gardé en mémoire.
Trouvé en testant après la passe 7 et corrigé : à la première ouverture après le démarrage, la sélection partait loin dans la liste
(la liste se remplit progressivement et la sélection suivait le premier élément arrivé). La sélection ne suit plus qu'un élément
choisi au clavier ou à la souris. Vérifié : première ouverture (haut de liste), Bas ×3, survol.

### Reste à faire

Phase 8 : rien d'autre au programme ; à valider par toi (rapport du 2026-10-17).

## Prochaine étape

Validation de la phase 8 (menu d'applications), puis phase 8b (fond d'écran, verrouillage, veille, polkit, capture, statistiques).

Décidé le 2026-10-16 pour la phase 8 (`ARCHITECTURE.md` § 10.1.4) : **plus de power menu séparé** ; le bouton power devient un
**engrenage blanc** (`U+F013`) qui ouvre un panneau de réglages façon GNOME : capture d'écran, tes 4 icônes d'alimentation (sans veille ni
confirmation), son, micro, luminosité (laptop), profil d'énergie, ne pas déranger, écran allumé, VRR, HDR, veilleuse (`wlsunset`, installé
installer), mode avion (laptop). Tray inchangé (réseau, Bluetooth, NordVPN, disques, cloche).

Rappel pour la phase 12 (ta précision du 2026-10-16) : **greetd remplace SDDM**, l'écran de connexion est un greeter Quickshell en QML
(apparence du thème SDDM reprise, thème SDDM non utilisé). Paquets `greetd` et `greetd-agreety` : dans `deps/`, donc installés par
`install.sh` ; mise en place du greeter (config, PAM, service) ajoutée à `install.sh` (ta demande : une installation neuve d'Arch + le
script = tout le bureau). Sur ce desktop, tu les installes au début de la phase 12 (`ARCHITECTURE.md` § 10.4).
