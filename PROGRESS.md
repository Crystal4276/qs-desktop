# Journal d'avancement

## Environnement

- Machine : `terrier` — Arch, i9-9900K, RTX 2080 (nvidia-utils 615.78)
- **Quickshell 0.3.2** (paquet Arch `quickshell 0.3.2-1`)
- Sway 1.12, Hyprland 0.57.0 (phase 9 ; 0.56.2 aux phases précédentes ; **config Lua** : `hyprctl keyword` indisponible, `dispatch` en syntaxe Lua)
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
- **Statistiques (phase 8b)** : colonne VRAM des processus (jeu ou navigateur) ; « Force quit » sur une application vraiment figée.
- **Veille (phase 8b)** : écrans éteints après 5 min sans activité, rallumés (principal 3 s après) ; sur le laptop, verrouillage
  avant la mise en veille (fermer le capot, rouvrir : écran verrouillé).
- **Verrouillage (phase 8b)** : verrouiller depuis le panneau de réglages, déverrouiller avec ton vrai mot de passe (une erreur
  d'abord, pour voir le message) ; majuscules verrouillées ; sur tes trois écrans.
- **Fond d'écran (phase 8b)** : utilitaire depuis le bouton du panneau de réglages ; image pour un seul écran (tes deux LG doivent
  pouvoir avoir des images différentes).
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

## Phase 8 — Menus et scripts : faite et validée (2026-10-17)

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
- Tailles d'icônes validées le 2026-10-17 : 48 px applications, 24 px le reste (`THEME.md` § 7).

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
- Tailles d'icônes du menu : validées (48 / 24 px).
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

Passe 8 (confirmation) : **rien de sérieux**, fin de la boucle. Petites corrections faites : indice hors liste ignoré par `choose` ;
choix effacé avant de changer de liste ; dossiers réassignés seulement s'ils changent, un seul mécanisme de relecture (à l'ouverture) ;
`Apps.iconSource` supprimé (appel direct à `Icons.iconSource`) ; image de notification donnée par chemin ou nom d'icône acceptée.
Vérifié (Sway isolé) : catégorie, retour à All Applications, icônes du lanceur.
Bilan de la boucle : 8 passes, 10 → 10 → 8 → 8 → 8 → 9 → 5 → 7 points, de plus en plus mineurs ; dernier défaut notable trouvé en
testant (sélection à la première ouverture).

### Reste à faire

Phase 8 : rien d'autre au programme ; à valider par toi (rapport du 2026-10-17).

## Phase 8b — Services de session et utilitaires : validée (2026-10-19)

Ordre : fond d'écran natif et utilitaire de changement de fond ; verrouillage (maquette à valider d'abord) ; veille ; agent polkit ;
outil de capture ; fenêtre de statistiques système.

### Fond d'écran natif et utilitaire : fait (2026-10-17)

- `modules/wallpaper/Background.qml` + `services/Wallpapers.qml` : une surface par écran (couche Background, sans zone d'entrée,
  comme swaybg) ; images simples, panoramas découpés selon la position réelle des écrans, triptyques à 3 écrans. Choix mémorisé
  localement ; départ : `wallpaper` de la config machine (ici le triptyque green-storm, comme Sway).
- Utilitaire `modules/wallpaper/PickerWindow.qml` (`qs ipc call wallpaper-picker toggle`) : onglets, vignettes, application
  immédiate, un écran ou tous (`WALLPAPERS.md` § « Mise en œuvre »). `PanelButton` a un état « choisi » (onglets).
- Vérifié dans un Sway isolé à 3 écrans (2560 / 3440 / 2560) : triptyque green-storm (gauche / centre / droite), panorama étalé
  sans coupure (comparé au fichier), utilitaire (onglets, triptyque choisi, image pour un écran, clavier, Échap), clic sur le fond
  d'un autre écran (focus déplacé, comme swaybg). État de test effacé : retour au triptyque.
- Tes choix (2026-10-17) : vignettes 240 × 135 ; utilitaire ouvert par un bouton du panneau de réglages (glyphe `U+F0E09`, à côté
  de la capture) ; ton fond courant est toujours celui utilisé (verrouillage compris), le triptyque de la config machine n'étant que
  le fond de départ.

### Écran de verrouillage natif : fait (2026-10-17)

- Maquette validée telle quelle ; `modules/lock/LockScreen.qml` + `LockContent.qml` (`ARCHITECTURE.md` § 10.1.7). Remplace swaylock
  (retiré de `deps/`).
- Vérifié dans un Sway isolé (PAM factice) : mot de passe refusé (« Wrong password », saisie effacée, toujours verrouillé) ;
  accepté (déverrouillé, bureau rendu) ; arrêt brutal de Quickshell pendant le verrouillage (session gardée verrouillée par Sway),
  nouvelle instance qui reprend le verrou et déverrouille ; deux écrans (champ sur l'écran focalisé, puis sur celui qui reçoit la
  frappe).

### Veille des écrans : faite (2026-10-17)

- `services/Idle.qml` (`ARCHITECTURE.md` § 10.1.8) : écrans éteints après 300 s, rallumés avec l'écran principal 3 s après les
  autres (config machine, repris de hypridle) ; verrouillage avant la mise en veille du système sur un laptop.
- Vérifié dans un Sway isolé à deux écrans (délai de 5 s, principal à 2 s) : extinction des deux écrans ; réveil au mouvement
  (secondaire d'abord, principal ensuite) ; « Keep Screen On » activé dans le panneau de réglages : plus d'extinction. Défaut trouvé
  et corrigé : le délai lu dans la config machine n'était pas pris en compte (suivi relancé quand il change).
- Non testable ici : verrouillage avant la mise en veille (laptop, liste « À faire par toi ») ; tant que swayidle tourne (avant la
  phase 10), les deux éteignent les écrans, sans conflit.

### Agent polkit : fait (2026-10-17)

- `modules/polkit/PolkitDialog.qml` (`ARCHITECTURE.md` § 10.1.9) : remplace polkit-gnome à la bascule.
- Vérifié : polkit-gnome arrêté une minute, agent de la session isolée enregistré, `pkexec true` → fenêtre affichée dans la session
  isolée (aucune sur tes écrans), Échap → demande annulée (`pkexec` : « Request dismissed », code 126). polkit-gnome relancé
  ensuite (la première relance avait échoué — `pgrep -f` voyait sa propre commande — puis refaite et vérifiée). Aucun mot de passe
  tapé (une erreur compterait dans faillock).

### Outil de capture : fait, testé par toi sur tes écrans (2026-10-19)

- `services/Screenshot.qml` + `modules/screenshot/ScreenshotTool.qml` (`ARCHITECTURE.md` § 10.1.10) ; le bouton du panneau de
  réglages l'ouvre (plus de grim / slurp).
- Non vérifié : `ScreencopyView` ne reçoit pas d'image dans un Sway isolé sans GPU (configuration minimale comprise), et tes écrans
  étaient en veille. Vérification prévue quand ils seront allumés : ouverture et sélection par IPC, fichier comparé
  numériquement à `grim` sur la même zone (sans regarder l'image), puis supprimé.

### Panneau de statistiques système : fait (2026-10-19)

- Tes choix : panneau surgissant ; les informations de nvtop fusionnées (le module GPU ouvre aussi ce panneau) ; tri et arrêt avec
  confirmation. `modules/monitor/MonitorPanel.qml` + `services/Monitor.qml` (`ARCHITECTURE.md` § 11.5). btop et nvtop retirés de
  `deps/`.
- Vérifié dans un Sway isolé : toutes les mesures (cœurs, température, mémoire, swap, réseau, GPU RTX 2080 avec charge, mémoire
  vidéo, température, consommation, ventilateur, fréquence, 16 disques en deux colonnes) ; recherche « sleep », choix d'un `sleep`
  de test, « End process » → confirmation → processus arrêté, liste à jour. Ton instance, panneau fermé : 1 tic CPU en 10 s.
- Largeur, jauges, lignes : validées pour une première version (`THEME.md` § 7 quater).

### Retours de tes tests (2026-10-19)

- Polkit testé par toi (Nemo) : fonctionne ; mot de passe refusé : champ rouge et « Wrong password », comme le verrouillage.
- Verrouillage testé par toi : champ du mot de passe désormais sur l'écran principal (saisie prise quel que soit l'écran qui a le
  clavier) ; vérifié dans un Sway isolé à deux écrans, focus sur le petit écran.
- Capture : plus de poignées, de déplacement, de redimensionnement ni de bouton de capture ; capture dès que la zone (au
  relâchement), l'écran ou la fenêtre est choisi. Barre d'outils : ligne d'aide du mode et nom sous chaque glyphe. Testé par toi :
  les trois modes fonctionnent ; barre validée.
- Statistiques : liste des processus toutes les 2,6 s (`update_ms` de ton btop) ; un processus choisi fige l'ordre des lignes
  (vérifié : aucun pixel de différence en 8 s, contre une liste qui bouge sans sélection). « End process » / « Force quit » testés
  par toi : fonctionnent. Boucle de liaison à l'arrêt du processus choisi corrigée.
- Polkit : ton choix, garder l'agent Quickshell. polkit-gnome est arrêté depuis le 2026-10-19 ; ta config Sway le relancera au
  prochain démarrage de session (il reprendra alors la place jusqu'à la bascule de la phase 10, qui le retire de l'autostart).

Retour du 2026-10-19 : phase validée.

### Revues en boucle de la phase 8b (2026-10-19, à ta demande)

4 passes : 10 → 10 (+2) → 8 → 8 points ; la quatrième ne trouve que du mineur (« la boucle peut s'arrêter »). Commits 4321403,
3dc3266, 78d18c0 et la passe 4. Points notables corrigés : rechargement de la config pendant le verrouillage (déverrouillait sans
mot de passe), outil de capture qui pouvait rester invisible en bloquant le bureau, panorama décodé par écran (≈ 1 000 → 710 Mo
dans le test). Laissés (négligeables) : écrans de même description (choix de fond partagé), recalcul du fond à chaque
changement de focus. À vérifier en phase 9 : après `hyprctl reload` au réveil, répartition des espaces (Outputs) et VRR/HDR.

### Module Wi-Fi séparé du réseau (2026-10-19, ta demande)

- Nouvelle icône Wi-Fi dans le tray (après l'icône réseau) : glyphe dessiné `modules/bar/WifiIcon.qml` (géométrie et couleurs
  Papirus, 5 niveaux aux seuils de GNOME, balayage animé pendant la connexion, croix si coupé, « ! » si sans Internet).
- Nouveau panneau `WifiPanel.qml` : interrupteur, carte du réseau courant (`WifiCard.qml` : qualité en mots, jauge colorée,
  bande / canal / largeur, débit du lien, sécurité, IPv4, trafic), autres réseaux (glyphe + cadenas, bande, %), mot de passe
  redemandé en rouge s'il est refusé, échec de connexion signalé. Détails lus par `nmcli` seulement panneau ouvert.
- Panneau réseau réduit au filaire + réseaux privés ; icône réseau masquée sans câble branché quand il y a du Wi-Fi (laptop).
  (Remplacé plus bas, même jour : onglets Tailscale / ZeroTier dans le panneau réseau, icône visible sans câble.)
- Vérifié : Sway isolé (vitrine hors dépôt) — tous les états du glyphe, cartes connecté fort / faible / en connexion, vrai
  panneau avec tes réseaux réels (<Wi-Fi 5 GHz> 5 GHz, <Wi-Fi 2,4 GHz> 2.4 GHz) ; animation (images différentes) ; ton instance recharge sans
  erreur, capture du tray `.shots/wifi-after-tray.png`.
- Tests réels sur ton desktop (ta demande, 2026-10-19 ; VPN coupé par toi, car NordVPN se reconnecte à chaque changement de
  réseau et coupait Claude Code) : panneau dans un Sway isolé, données NetworkManager réelles, actions par IPC au lieu de clics ;
  captures `.shots/wifi-test-*.png`.
  - Connexion à <Wi-Fi 5 GHz> (animation dans ton tray, carte : 53 %, 5 GHz canal 36 80 MHz, 650 Mb/s, IPv4), bascule vers <Wi-Fi 2,4 GHz>,
    Disconnect, interrupteur coupé (croix, « Wi-Fi is off ») puis rallumé : conformes.
  - **Corrigé** : « Cancel » ne faisait rien (Quickshell refuse `WifiNetwork.disconnect()` avant la connexion) → déconnexion
    de l'interface ; vérifié (connexion interrompue, aucun faux message d'échec).
  - **Corrigé** : bande absente jusqu'à 5 s après le rallumage → relue dès que la liste des réseaux change.
  - État remis comme avant : `wlan0` déconnecté, connexion automatique désactivée (appareil et <Wi-Fi 5 GHz> / <Wi-Fi 2,4 GHz>), filaire seul
    en route par défaut. NordVPN à relancer par toi.
- Non testable ici (réseaux ouverts, filaire prioritaire) : mot de passe refusé, accès limité, ligne « Traffic » (affichée
  seulement si le Wi-Fi porte la route par défaut). À tester sur le laptop.
- Valeurs nouvelles à valider : `THEME.md` § 3 « Module Wi-Fi » (couleurs de qualité, glyphe 48 px, durées d'animation).

### Panneau réseau refait (2026-10-19, ta demande)

- Onglets Wired / Tailscale / ZeroTier (`NetworkPanel.qml`). Filaire : carte (`WiredCard.qml`) avec graphe du trafic sur 2 min
  (`TrafficGraph.qml`, aussi dans la carte Wi-Fi), adaptateur, IPv4, passerelle, DNS, domaine, IPv6, adresse matérielle, pont.
- Tailscale (`services/Tailscale.qml`, `TailscaleView.qml`), tes choix : interrupteur up / down, nœud de sortie, options (DNS,
  routes, Shields Up, accès au LAN), appareils (en ligne, système, direct / relayé, vu il y a…, clic = copie de l'IP).
  `sudo tailscale set --operator=$USER` lancé par toi.
- ZeroTier (`services/ZeroTier.qml`, `ZeroTierView.qml`) : nœud, réseaux (état, adresses, DNS, quitter avec confirmation),
  rejoindre ; lecture seule sans le jeton (`~/.zeroTierOneAuthToken`, copié par toi le 2026-10-19). Vérifié : nœud en ligne,
  ton réseau, option DNS activée puis désactivée (`zerotier-cli` confirme, remise à son état initial).
- Icône réseau : visible aussi sans câble si Tailscale / ZeroTier sont là (`network-vpn`). `PrivateNetworks.qml` supprimé.
- Vérifié (Sway isolé, données réelles) : onglets, carte filaire et graphe ; Shields Up activé puis désactivé, Tailscale
  coupé puis relancé (états et prefs vérifiés par `tailscale`) ; copie (`wl-paste`). `Quickshell.clipboardText` ne remplit pas
  le presse-papiers sans clic : remplacé par `wl-copy`.
- Phase 11 : install.sh doit proposer `tailscale set --operator` et la copie du jeton ZeroTier (avec sudo et confirmation).
- Non testé : nœud de sortie (aucun dans ton tailnet), Accept routes, ZeroTier « Leave » / « Join » (pour ne pas quitter ton
  réseau), « Sign in » (compte connecté), clics réels (comme toujours en headless).

### Revues en boucle du Wi-Fi et du panneau réseau (2026-10-19, ta demande)

- 17 passes de `/code-review high` sur `5c19f11^..HEAD`, chaque point vérifié avant correction, un commit par passe
  (5c397f6 … f6ee8f6). Arrêt : la passe 17 ne trouve plus que des cas limites, déjà corrigés, et du négligeable.
- Bugs notables trouvés et corrigés : « Cancel » qui désactivait la connexion automatique de l'appareil ; `tailscale up` /
  `login` refusés avec une option dès qu'un réglage n'est pas par défaut (vérifié en réel) ; dépendance circulaire entre
  singletons (liaisons `undefined` au démarrage) ; onglet Tailscale / ZeroTier perdu si le démon n'est pas prêt au démarrage ;
  commande qui ne démarre pas (Quickshell n'émet pas `exited`) ou lecture figée qui bloquaient tout pour la session ; jeton
  ZeroTier périmé (401) ; route `0.0.0.0/1` d'un VPN prise pour la route par défaut ; panneaux qui débordaient d'un petit écran
  (le cadre défile désormais, et suit le focus clavier, listes internes comprises).
- Deux régressions de ma part, rattrapées aux passes suivantes : `up --timeout` (passe 5 → 6), `fallBack()` supprimée par
  erreur (passe 9 → 10). Depuis, un jeu de 14 vérifications sur banc (Sway isolé, données réelles, ZeroTier sans jeton et avec
  un jeton périmé, actions Tailscale réversibles, copie, commande introuvable) est rejoué à chaque passe.
- Composants communs créés en route : `CliRunner`, `Poller` (services) ; `PanelCard`, `CardHeader`, `DetailsGrid`,
  `PanelList`, `StatusIcon`, `NetworkSettingsButton` ; `TrayButton` accepte un glyphe dessiné.
- Restent, jugés négligeables : un peu de code semblable entre Tailscale.qml et ZeroTier.qml ; un tray sur plusieurs barres
  partage l'onglet affiché ; NordVPN a encore son propre lanceur (BACKLOG). À valider par toi : les valeurs « nouveau, à
  valider » de `THEME.md` (signalées à chaque passe).
- État de ta machine remis : Wi-Fi déconnecté (connexion auto. de l'appareil à « non »), Shields Up désactivé, DNS ZeroTier
  désactivé, filaire seul en route par défaut. **NordVPN est encore coupé** (coupé par toi pour les tests Wi-Fi).
- À tester à la main : défilement à la souris d'un panneau sur petit écran, clics réels, nœud de sortie, Accept routes,
  Join / Leave ZeroTier, Sign in Tailscale, et tout le Wi-Fi sur le laptop (mot de passe, portail captif).

### Pill système (2026-10-20, ta demande)

- Module GPU : **utilisation** (`{usage:2}%`, comme le CPU) au lieu de la température ; `nvidia-smi` (NVIDIA),
  `gpu_busy_percent` (AMD) ; masqué sur Intel (aucune utilisation dans sysfs). Température toujours lue pour le moniteur.
- Icône mémoire : `U+EFC5` (`nf-fa-memory`, barrette de RAM) au lieu de `U+F035B` (puce, trop proche de l'icône CPU).
- Largeur fixe des pills système et réseau, la plus petite possible : chaque valeur prend la largeur de la plus large de ses
  valeurs possibles (0-100 %, 0 à la mémoire totale, débits jusqu'à `999.9GB/s`), mesurée avec la police (`FontMetrics`),
  alignée à droite ; chiffres proportionnels (`tnum` les élargissait). `InfoModule` : un `Text` par segment.
- Pour réduire encore (tes choix) : CPU et GPU plafonnés à 99 % ; débits à 3 chiffres significatifs (« 4.32MB/s »,
  « 14.3MB/s », « 833kB/s ») au lieu d'une décimale, aussi dans le graphe du panneau réseau.
- Écart icône → valeur : une espace au lieu de deux (format Waybar) dans ces deux pills (ta demande) ; horloge, date et mises
  à jour gardent deux espaces.
- Écart valeur → icône suivante : un seul padding de module (10 px) au lieu de deux (20 px) entre deux modules texte d'une
  même pilule (`InfoModule.trailing`, fixé par Bar.qml), et 10 px au lieu de deux espaces entre les deux débits.
- Horloge : même règle (`Clock` devient un `InfoModule`) : une espace après l'icône, 10 px avant le calendrier.
- Les icônes Nerd Font débordent de leur avance (3,8 à 11,3 px) : chaque segment prend sa largeur dessinée
  (`tightBoundingRect`), sinon une seule espace laisse l'icône toucher le chiffre.
- Horloge à largeur fixe minimale : l'heure réserve la plus large de 00:00 à 23:59, la date le plus large des jours de la
  semaine (locale) × 01 à 31.

### Panneau NordVPN (2026-10-20, ta demande)

- Bug « plus de liste en tapant » : `nordvpn countries` lu même en échec (démon pas prêt, réseau coupé pendant les tests Wi-Fi) ;
  des mots du message d'erreur passaient pour des pays et restaient en cache, la recherche ne trouvait rien. Listes (pays, villes)
  lues seulement si la commande réussit, rechargées à l'ouverture suivante ; message « Countries unavailable » / « Cities unavailable ».
- Refonte (tes choix) : onglets **Recent / All countries** ; taper bascule sur tous les pays filtrés (débuts de nom, puis de mot,
  puis le reste), effacer revient à l'onglet ; focus dans la recherche à l'ouverture (BACKLOG) ; Entrée connecte au premier
  résultat, Échap efface puis ferme.
- Récents **pays + ville** : une entrée par pays (« Netherlands/Amsterdam » dans `vpn.json`, ancien historique gardé) ; une ville
  choisie est retenue, un pays seul l'efface ; l'interrupteur et `qs ipc call vpn connect` reconnectent à la dernière entrée.
- Ligne d'état : « Connecting to Pays, Ville… », « Disconnecting… », « Pausing… » ; détails, trafic et pause masqués pendant l'action.
- Service : actions sur `CliRunner` (BACKLOG) ; relecture du statut refaite si une lecture périodique était en cours ; historique
  enregistré dès la connexion (avant : jusqu'à 5 s plus tard, la liaison `connected` n'étant pas encore à jour dans `onStatusChanged`).
- Vérifié sans toucher ta connexion : Sway isolé, faux `nordvpn` (lectures transmises au vrai, actions simulées), historique isolé
  (`XDG_STATE_HOME`) : onglets, recherche « ne » / « un » / « ger » / sans résultat, Entrée, villes (chargement, échec puis nouvel
  essai), ville retenue, interrupteur off / on vers la ville retenue, IPC (`netherlands`, vide, pays inconnu), échec de connexion
  (récents inchangés), liste des pays en échec puis rechargée, pause.
- À tester à la main : saisie au clavier réelle, Échap (efface puis ferme), clics, et une vraie connexion à une ville.

### Croix d'effacement des recherches (2026-10-20, ta demande)

- `modules/bar/ClearButton.qml` : croix `U+F0156` (glyphe « fermer » déjà dans la charte), dans tous les champs de recherche :
  NordVPN et statistiques système (`PanelField.search`), lanceur, menu d'applications (avant la loupe). Visible si le champ
  n'est pas vide ; clic : recherche effacée, focus gardé — NordVPN revient à l'onglet d'avant.
- Échap dans les champs de recherche des panneaux (NordVPN, statistiques) : efface d'abord, puis ferme. Lanceur et menu
  inchangés (Échap ferme, comme Rofi et nwg-menu).
- Vérifié en Sway isolé : rendu des quatre champs avec du texte (captures). À tester à la main : le clic sur la croix (pas de
  pointeur dans la session isolée) et Échap dans les statistiques. (Clic vérifié ensuite avec le pointeur virtuel, ci-dessous.)

### Panneaux du tray : clavier sous Sway (2026-10-20, ton signalement)

- Bug : impossible d'écrire dans la recherche NordVPN. Sous Sway 1.12, un `PopupWindow` `grabFocus` ouvert depuis une barre ne
  reçoit jamais le clavier (ni saisie, ni Échap) — reproduit en Sway isolé avec pointeur et clavier virtuels. Touchait aussi le mot
  de passe Wi-Fi, la phrase de passe des disques, le code Bluetooth, l'ID ZeroTier.
- Correction : `Panel.qml` est une surface Overlay à clavier exclusif (`OverlayPopup`), comme le panneau de réglages et le lanceur
  (`openUnder`, `initialFocus`). Fermeture : clic à côté du cadre (non transmis, comme avant), sur une barre ou un autre écran,
  Échap ; le clavier revient ensuite à la fenêtre d'avant. Le panneau des statistiques n'était pas touché (déjà Overlay).
- Outil de test (hors dépôt, scratchpad) : client Wayland `zwlr_virtual_pointer_v1` + `zwp_virtual_keyboard_v1` (pywayland) pour
  cliquer et taper dans le Sway isolé. Tant qu'il tourne, le clavier virtuel existe : interroger le focus pendant, pas après.
- À tester à la main sur tes écrans : saisie dans NordVPN, Wi-Fi (mot de passe), disques (phrase de passe) ; Échap ; clic à côté
  d'un panneau (ferme, clic non transmis) ; clic sur une fenêtre d'un autre écran (ferme) ; panneaux réseau, Bluetooth, disques,
  notifications, audio (clic droit sur le volume) : ouverture sous l'icône, fermeture, focus rendu à l'application.

### Revue en boucle de NordVPN et des panneaux (2026-10-20, ta demande)

- 17 passes de `/code-review high` sur `7368623^..HEAD`, chaque point vérifié dans le code puis rejoué sur banc, un commit par
  passe ; arrêt : la passe 17 ne trouve plus que des cas limites (démon lent plus de 30 s après le choix d'une ville, casse
  « and » / « And » avant le chargement de la liste), des redites et du style.
- Principaux défauts corrigés : villes en attente affichées « unavailable » ; noms comparés à la casse près ; demande périmée
  appliquée à une connexion faite ailleurs ; ancienne connexion qui réapparaissait un instant après une action ; commande
  `nordvpn` figée qui verrouillait le panneau (bornes 300 s / 10 s) ; démon lent qui masquait le module ; message d'erreur
  remplacé par la ligne de progression ; liste des pays polluée par un message d'information.
- Ajouts : annulation d'une connexion en cours (interrupteur, ou `qs ipc call vpn disconnect`) : SIGINT puis SIGTERM après 3 s
  (SIGINT ignoré si Quickshell a été lancé avec `&`), puis déconnexion normale ; lignes et interrupteur atténués pendant une
  action ; raccourci refusé pendant une action signalé par une notification ; `PanelTabs`, `PanelRow.locked`,
  `PanelSwitch.locked`, `CliRunner` (`lastLineError`, `noAnswer`, `interrupt`, `stop`).
- Banc : Sway isolé, faux `nordvpn` (lectures transmises au vrai, actions simulées : connexion lente, figée, en échec, statut lent,
  démon injoignable), historique séparé (`XDG_STATE_HOME`), veille désactivée (elle éteignait l'écran virtuel).
- **Incident** : l'agent de revue de la passe 8 a lancé lui-même un `nordvpn connect` vers un pays inexistant pour vérifier une
  hypothèse, ce qui a coupé ta VPN à 09:59 (journal de `nordvpnd`). Les passes suivantes ont reçu la consigne de lecture seule
  (vérifiée dans leurs traces). Ta VPN est restée déconnectée : à reconnecter par toi.
- Écarté (BACKLOG) : file unique pour toutes les commandes `nordvpn` (faite ensuite, voir ci-dessous).
- À tester à la main (impossible sans toucher ta VPN) : vraie connexion à une ville puis interrupteur (reconnexion à la ville) ;
  annulation d'une vraie connexion lente (le démon abandonne-t-il bien sa connexion au SIGINT ?) ; notification d'erreur réelle.

### NordVPN : file unique des commandes (2026-10-20, ta demande)

- `services/Vpn.qml` : statut, listes des pays et des villes, connexion, déconnexion et pause passent par une seule file, une
  commande à la fois (un seul `CliRunner`, qui expose maintenant `code` et `output`). Une lecture du statut est mise en tête de
  file après chaque action : elle voit toujours son effet. Disparaissent : les quatre processus, le tampon des lectures anciennes
  (`stamp`), `refreshAgain`, `awaitingStatus` et sa limite de 30 s (remplacée par trois essais de la lecture qui suit l'action),
  `pendingCities`/`citiesFetching` (une seule liste de villes en attente : la dernière demandée).
- Nouveau : une connexion encore en attente (derrière une liste) est retirée de la file par l'interrupteur, puis la déconnexion
  suit (sens de l'interrupteur ; sans message si tu n'étais pas connecté).
- Prix : une liste demandée pendant une connexion (5 min au plus) attend sa fin ; le panneau est de toute façon verrouillé.
- Banc (faux `nordvpn`, appels IPC par PID du banc seulement) : connexion, échec (notification, retour à l'état réel), annulation
  d'une connexion figée (SIGINT, SIGTERM après 3 s, déconnexion), raccourci refusé pendant l'annulation, connexion en attente
  retirée, file des villes (France, Germany, France : Germany abandonnée, France pas relancée), statut lent après une action
  (« Connecting… » gardé, lecture refaite), démon figé (module masqué après trois lectures, réaffiché au retour).
- À tester à la main : les mêmes points que ci-dessus (vraie connexion, vraie annulation), plus l'ouverture du panneau pendant une
  connexion lente (« Loading countries… » jusqu'à sa fin si la liste n'était pas encore chargée).
- Revue en boucle (3 passes de `/code-review high`, lecture seule) : cible d'une connexion en attente effacée par une lecture
  commencée avant elle (ville perdue dans les récents) ; relecture passée devant une action en attente ; actions mises en tête
  de file ; `timeout -k 5` (commande qui ignore SIGTERM) et lecture ainsi tuée comptée comme sans réponse (code 9, CrashExit,
  vérifié sur banc), pas comme un échec qui masquait le module ; villes redemandées gardant leur place. Arrêt : la passe 3 ne
  trouve plus que des commentaires à préciser et des cas déjà tranchés.

### Centre de notifications : carte média et lignes refaites (2026-10-20, ta demande)

- Inspiration lue dans le code : KDE (`plasma-workspace`, `NotificationHeader.qml`, `Summary.qml`, `Body.qml`, `HeadingButtons.qml` :
  heure relative), GNOME (`messageList.js`, `_message-list.scss` : corps replié / déplié à 6 lignes, lecteur), Cinnamon
  (`messageTray.js`).
- Carte média (`MediaCard.qml`, nouveau `MediaButton.qml`) : bande compacte (≈ 96 px au lieu de ≈ 170), pochette 76 px (ta demande :
  +25 %), titre gras, « artiste · album », boutons ronds à droite (lecture en rond `text`, le `green` étant trop fort), position en
  trait fin avec bouton au survol, temps de part et d'autre ; clavier : Gauche / Droite ±5 s sur la position.
- Lignes (`NotificationRow.qml`) : en-tête gris (titre sans le préfixe de l'application, heure relative, croix), corps 16 px sur
  2 lignes (ton choix), clic pour déplier ; non vues : en-tête `green`.
- Corrigé au passage (préexistant) : une icône nommée ou un chemin (`notify-send -i …`) arrive dans `image` en `image://icon/…` ;
  `Notifs` la prenait pour une image en données et la remplaçait par une icône vide au rechargement de la config.
- Vérifié sur banc (Sway isolé, bus D-Bus à part, faux lecteur MPRIS, notifications factices) : rendu, pause / lecture, survol de la
  position et des boutons, dépliage, icônes gardées après rechargement. À tester à la main : déplacement dans le morceau (le faux
  lecteur ne gère pas `SetPosition`), vraie notification avec image en données (avatar) après rechargement.

### Notifications : icônes de Chromium et de ses applications web (2026-10-20, ton signalement)

- Cause : Chromium (et ChatGPT, Claude… qu'il fait tourner) envoie son icône dans un fichier temporaire
  (`/tmp/org.chromium.Chromium.scoped_dir.*/logo.png`) qu'il efface à la fermeture de la notification. Dunst la chargeait à la
  réception ; Quickshell la relisait plus tard (historique, rechargement) : fichier disparu, icône vide (journal : « Cannot open »).
- `Notifs.keepIcon` : toute icône en fichier local est copiée dès la réception dans `<cacheDir>/notification-icons/<md5>.<ext>`
  (même logo, même fichier ; une vraie copie des octets via `FileView`, sans processus). Dossier vidé au démarrage de Quickshell
  (l'historique ne survit pas à un redémarrage).
- Deux pièges de Quickshell 0.3.2 relevés : un `FileView` dont on change `path` rend encore les données de l'ancien fichier (un
  `FileView` par fichier) ; `FileView.setData` crée les dossiers manquants.
- Vérifié sur banc : deux logos différents dans des fichiers temporaires (`image-path` et `app_icon` en `file://`), fichiers effacés,
  config rechargée : chaque notification garde son logo ; un même logo n'est copié qu'une fois.
- Les notifications ChatGPT / Claude déjà dans ton historique restent sans icône (fichiers déjà effacés) ; les prochaines l'auront.
- Le banc partage le cache de ta session (même identifiant de shell `desktop`) : ses démarrages ont vidé le dossier ; les icônes
  des notifications reçues pendant ces tests peuvent manquer.

### Revue en boucle du système de notifications (2026-10-20, ta demande)

Passe 1 (`/code-review high`, 10 remarques, vérifiées une à une) :
- Copie des icônes refaite : plus de nom par contenu (`Qt.md5` donne le même hash à deux PNG différents, vérifié) ; une copie par
  notification, faite à l'arrivée et à chaque changement d'image (plus dans une liaison), dans
  `$XDG_RUNTIME_DIR/quickshell-notification-icons/<instance>` (vidé en fin de session ; plus de `rm -rf` au démarrage, ni de
  dossier partagé entre instances). Pas de copie pour les fichiers des dossiers de données (thèmes, `/usr/share/pixmaps`).
  Écriture bloquante, échec détecté (`saveFailed`). Fichier relu à chaque fois (même chemin réécrit : nouvelle image) ; illisible :
  dernière copie de cette notification. Copies inutilisées effacées une seconde après (croix, « Clear all », historique plein) ;
  table des copies gardée au rechargement (`PersistentProperties`). Extension prise sur le nom du fichier seulement.
- Pièges vus sur banc : `flatMap` / `Object.fromEntries` absents du moteur JS ; `onNotificationChanged` émis aussi à la création
  (copie en double) ; au rechargement, Quickshell réémet les notifications affichées *après* la restauration de l'historique
  (un nettoyage immédiat effaçait la copie de la popup).
- En-tête des lignes : « titre · application » quand l'icône ne montre pas l'application (avatar, aucune icône).
- Position du lecteur : touches et clic sans effet si le lecteur a disparu ou n'accepte plus les déplacements.
- `GlyphButton` (ex-`MediaButton`) : bouton rond commun au lecteur et à la croix des lignes ; rayon de la pochette dans `Theme`.
- Vérifié sur banc : icônes temporaires (`image-path`, `app_icon` en `file://`), thème et `/usr/share` non copiés, rechargement
  avec popup affichée (icône gardée), fermeture, croix, « Clear all » (copies effacées), avatar en données, sans icône.

Passe 2 (fichiers complets, 10 remarques, toutes confirmées et corrigées) :
- « Ne pas déranger » : une notification reste suivie sans affichage jusqu'à son délai ; ses mises à jour (`replaces_id`,
  étiquette de pile, doublon) modifient sa ligne au lieu d'en ajouter une (vu sur banc : Quickshell réutilise l'identifiant d'une
  notification suivie, en donne un nouveau sinon).
- Rechargement de la config : les notifications réémises (`lastGeneration`) reprennent leur rôle (affichée / silencieuse), âge,
  délai, compteur et ordre, sans repasser par « ne pas déranger » ; une notification rappelée de l'historique est recréée.
- Remplacement en place : l'ordre par urgence est refait (une mise à jour critique passe en tête).
- Ligne de l'historique mise à jour après les liaisons de l'Entry (`Qt.callLater` : le signal arrivait avant, la ligne gardait
  l'ancien texte).
- Icônes : chemin `image://icon//…` converti en `file://` (sinon damier de Quickshell au lieu d'une erreur) ; image illisible →
  icône de l'application → icône générique (popup et ligne) ; nom de l'application dans l'en-tête si l'icône générique s'affiche.
- Copies limitées aux dossiers temporaires (`/tmp`, `TMPDIR`, `XDG_RUNTIME_DIR`, `XDG_CACHE_HOME`) ; dossiers des instances
  terminées effacés au démarrage (`qs list --all` ; rien effacé si la liste ne contient pas l'instance elle-même).
- Entités numériques (`&#39;`, `&#x2014;`) décodées dans le centre ; pas de « · » orphelin sans nom d'application.
- Position du lecteur : envoyée au relâchement seulement (une commande D-Bus au lieu d'une par mouvement).
- Vérifié sur banc : fusion des mises à jour pendant « ne pas déranger » (90 % affiché), popup gardée au rechargement avec « ne pas
  déranger » actif, `historyPop` puis rechargement, popup critique remontée, replis d'icônes, dossiers d'instances mortes effacés.

Passe 3 (10 remarques ; 9 corrigées telles quelles, 1 autrement) :
- Une silencieuse remplacée alors qu'elle doit s'afficher (« ne pas déranger » coupé, ou devenue critique, par étiquette ou
  par identifiant) s'affiche ; sa ligne quitte l'historique jusqu'à sa fermeture. Une notification affichée le reste.
- `historyPop` sur la ligne d'une silencieuse encore suivie : c'est elle qui s'affiche (actions, mises à jour).
- Ligne d'une silencieuse effacée (croix, « Clear all ») : elle est fermée ; poussée hors des 20 : elle expire. Sinon ses mises à
  jour se perdaient.
- Mise à jour en attente appliquée à la fermeture d'une silencieuse.
- Ligne mise à jour : non vue, en tête, nouvelle clé (le `ScriptModel` du centre gardait l'ancien objet d'une ligne déplacée de
  même clé : contenu périmé à l'écran, vu sur banc).
- Moins de travail par mise à jour : `popups` réassigné seulement si l'ordre change, image en données retenue une fois tant
  qu'elle ne change pas.
- Rechargement : le délai repart de zéro (autrement que proposé : le survol qui le suspend n'est pas enregistré, un délai repris
  trop tôt faisait disparaître la notification) ; état recréé par une seule fonction (`stateProps`).
- Icône générique dans `Theme.notificationCentre.genericIcon`.
- Vérifié sur banc : mise à jour après « vu » (contenu, vert, en tête), silencieuse devenue critique (affichée), `historyPop`
  d'une silencieuse, « ne pas déranger » coupé puis même étiquette, « Clear all » puis même étiquette (nouvelle ligne),
  rechargement puis mise à jour (même ligne).

Passe 4 (9 remarques, toutes corrigées) : image en données d'une silencieuse rappelée gardée jusque dans l'historique (verrou
compté tant que la notification est suivie) ; silencieuse rappelée par `historyPop` : reste affichée comme toute notification
rappelée ; mise à jour par identifiant après « ne pas déranger » coupé : affichée (comme par étiquette) ; notification rappelée
remplacée par une nouvelle : l'ancienne copie n'est plus reprise ; lien « www.… » ouvert en `http://` ; entité numérique hors de
l'Unicode laissée telle quelle (au lieu d'une erreur) ; lignes archivées avant la restauration de l'historique gardées ; texte des
popups refait chaque seconde seulement une fois l'âge affiché (après 60 s) ; `Notifs.invoke` supprimé (simple relais).
Vérifié sur banc : avatar d'une silencieuse rappelée (popup, puis ligne), mise à jour après « ne pas déranger » coupé, entités.

Passe 5 (6 remarques, toutes corrigées) : remplacement par identifiant = âge et délai repartent, délai normal pour une
rappelée (comme Dunst) ; nom d'icône absent du thème (`image-path`) → icône de l'application (plus de damier) ; doublons :
seules les icônes du thème se comparent (Chromium écrit la même image dans un fichier différent à chaque fois ; les images en
données ont une adresse par notification) ; étiquette de pile gardée dans la copie (une notification rappelée reste remplaçable) ;
position du lecteur passée par le service `Media` (`seek`, `step`, `refreshPosition`) ; branche morte de `keepIcon` retirée.
Ajout vu pendant le test Chromium : aperçu replié d'une ligne du centre sur une seule ligne logique (Chromium met l'origine du site
et une ligne vide avant le texte).
Vérifié sur banc : doublons Chromium fusionnés, nom d'icône absent, aperçu « chatgpt.com La distinction… », rappelée remplacée par
son étiquette.

Passe 6 (7 remarques, toutes corrigées) : image d'une silencieuse affichée (promote) gardée ; « < » qui n'ouvre pas une balise
connue affiché tel quel (popup et centre ; StyledText l'avalait jusqu'au « > » suivant, Dunst repassait en texte brut) ;
boutons d'action : la fenêtre de l'application est affichée si elle demande l'activation ; « settings » seule n'est plus ouverte
au clic gauche ; verrous d'images libérés après un remplacement ; minuterie des délais arrêtée quand aucune silencieuse n'a de
délai ; commentaire des boutons à jour. Vérifié sur banc : « 3 < 5 passed, 2 > 1, **gras** & fin », action `settings` seule.

Passe 7 (8 remarques, toutes corrigées) : liens dédoublonnés (`<a href="X">X</a>` comptait deux liens : rien ne s'ouvrait) ;
lien ouvert au clic gauche même si la seule action est masquée ; notification « resident » plus fermée après son action ; ligne
effacée d'une silencieuse en cours de mise à jour qui revenait sous une nouvelle clé ; rappelée sans indicateur « A » (plus
d'action utilisable) ; position du lecteur relue dès l'ouverture du panneau ; titre affiché en texte brut dans le centre comme
dans la popup ; états de rechargement pas encore repris gardés si un second rechargement suit (abandonnés après 2 s).
Vérifié sur banc : rappelée sans « (A) », lien doublé compté une fois. Non vérifiable sur banc : « resident » (notify-send ferme
lui-même sa notification après l'action).

Passe 8 (3 remarques, aucune dans le code des notifications lui-même : fin de la boucle) : ouverture d'une notification dont la
fenêtre était déjà urgente (Sway n'envoie pas de nouvel « urgent » ; le changement de titre, Chromium changeant d'onglet, est
aussi pris) ; lecteur choisi à la molette gardé quand c'est lui qui démarre ; lecteurs déjà en lecture au démarrage de
Quickshell (`lastPlaying` initialisé). Vérifié sur banc : Chromium marqué urgent avant la notification, clic gauche → espace 2,
onglet A.

### Actions des notifications (2026-10-20, ta demande)

- Revue : une popup montre un bouton par action nommée, sauf « default » (clic milieu). Thunderbird (« Marquer comme lu »,
  « Supprimer ») : gardés, ton choix. Chromium et ses applications web : bouton « Paramètres » (identifiant `settings`, vérifié dans
  `notification_platform_bridge_linux.cc`) qui ouvre les réglages de notification du site : **masqué** (ta décision), pour
  tout navigateur Chromium (règle sur l'identifiant, `Notifs.hiddenActions`).
- Vérifié sur banc : popup Chromium sans bouton, popup Thunderbird avec ses deux boutons.

### Ouvrir une notification : bon espace de travail, bon onglet (2026-10-20, ta demande)

- Constat sur banc (Chromium jetable, profil temporaire, page locale qui notifie depuis un onglet en arrière-plan) : à
  l'activation, Chromium choisit lui-même l'onglet de la notification puis demande l'activation de sa fenêtre ; Sway
  (`focus_on_window_activation` par défaut : `urgent`) la marque seulement urgente. Quickshell 0.3.2 ne transmet pas de jeton
  d'activation.
- `Compositor.focusNextActivation()` : la première fenêtre devenue urgente dans les 3 s suivant l'ouverture est affichée
  (Sway : `[con_id=…] focus` sur l'événement `window`/`urgent` ; Hyprland : événement `urgent`, `focuswindow`, à vérifier en
  phase 9). Les autres fenêtres urgentes ne sont pas touchées.
- Souris (ton choix) : **gauche ouvre** (action par défaut, ou lien, puis fenêtre affichée) et ferme, **milieu ferme**, droit
  ferme tout (dunstrc : gauche et milieu inversés). Centre de notifications : clic sur une ligne = déplier seulement (ton choix ;
  la notification y est déjà fermée, Chromium ne peut plus choisir l'onglet).
- Vérifié sur banc : Chromium sur l'espace 2, onglet B actif, notification de l'onglet A ; clic gauche sur la popup depuis
  l'espace 1 → espace 2, Chromium au premier plan, onglet A.
- À tester à la main : tes vraies applis web (ChatGPT, WhatsApp web…) : l'onglet n'est choisi que si le site le demande au
  clic (la plupart le font) ; Thunderbird (ouvre le message).

### Menu d'applications et lanceur : surlignage et boutons de session (2026-10-21, ta demande)

- Surlignage (survol, sélection, catégorie choisie) du menu et du lanceur : le `green` plein (texte `mantle`) devient le fond
  `surface0` du survol des cartes des panneaux, texte inchangé (ton choix parmi 4 maquettes : `surface0`, blanc 10 %, verre, vert
  teinté). Le sélecteur de fonds garde son cadre `green` : il marque le fond actuel (un état), le survol y est déjà en `surface0`.
- Boutons lock / logout / reboot / shutdown du menu : boutons carrés du panneau de réglages (fond `surface0`, survol `surface1`,
  coins 10 px, mêmes dimensions) au lieu du survol rond de nwg-menu (ton choix).
- Effet verre façon iOS : noté dans `BACKLOG.md` (sur un panneau opaque, la transparence ne se voit pas).
- Vérifié sur banc (captures). À tester à la main : survol au pointeur dans le menu et le lanceur.

### Menu d'applications et lanceur : profilage et revue en boucle (2026-10-21, ta demande)

- **Première ouverture lente** (ton signalement) : mesurée sur banc à ~1,15 s avant la première image (puis ~0,1 s). Cause : le
  service `Apps` n'était créé qu'au premier accès, et DesktopEntries livre les applications une par une (230 changements d'affilée) ;
  chaque changement recalculait tris, catégories et liste du menu (~1 s de JavaScript, pile d'appels relevée sous gdb). Liste relue en
  une fois (`Qt.callLater`), `Apps` créé au démarrage : première ouverture ~0,11 s, comme les suivantes (2 calculs au lieu de 230).
- Passe 1 : lanceur borné à la hauteur de l'écran (laptop : le haut sortait de l'écran) ; sélection du lanceur gardée dans la liste
  quand elle raccourcit d'elle-même (Entrée lançait le texte comme commande) ; Tab / Maj+Tab du menu suivent la colonne active (ils
  déplaçaient en aveugle la sélection des applications) ; fichiers récents : entités numériques (`&#39;`) décodées ; raccourci
  `menu|settings toggle` : repli sur la barre de l'écran principal ; commentaires périmés. Écartés : historique de saisie du lanceur
  (identique à Rofi 2.0.0, `view.c` relu), relecture des dossiers XDG à chaque ouverture (asynchrone, négligeable).
- Passe 2 : le survol d'une ligne à moitié visible ne fait plus défiler la liste (seul le clavier la fait défiler) ; catégorie vidée
  pendant l'ouverture → toutes les applications ; recherche effacée à la fermeture (le menu caché ne recalcule plus ses résultats) ;
  fichiers récents dédoublonnés par chemin. Écartés après mesure : fenêtres « clic à côté » des autres écrans (les garder ne change
  rien : ~200 ms par ouverture sur banc à trois écrans dans les deux cas, rendu logiciel du banc), préchargement du menu (sa création
  coûte 25 ms), icônes asynchrones (aucun gain mesuré). Négligeables : objets de ligne recréés à chaque frappe, pas de Page Haut/Bas
  approximatif quand des lignes n'ont pas de description.
- Passe 3 (points mineurs) : colonne des catégories qui défile (petit écran) : la catégorie choisie au clavier reste visible (vérifié
  en 1024 × 600) ; Haut / Bas ramènent en vue une sélection sortie par la molette ; saisie du lanceur effacée à la fermeture ;
  Ctrl+G et Ctrl+[ ferment le lanceur (`kb-cancel` de Rofi) ; filtres des applications : listes recalculées seulement si le résultat
  change. Négligeable : catégorie survolée au tout premier mouvement après l'ouverture, prise à l'arrêt du pointeur.
- Passe 4 : défilement des listes réservé aux touches (la passe 3 faisait aussi défiler la colonne des catégories au survol, et un
  choix au clavier restait « collé » : la liste sautait ensuite d'elle-même) ; Gauche montre la catégorie active ; catégorie
  disparue : liste remise en haut ; entités XML décodées en une passe (`&#38;amp;`) ; lanceur ouvert sur l'écran principal quand
  l'écran focalisé est inconnu, comme le menu.
- Passe 5 (aucune régression, points mineurs) : catégorie déjà choisie (Haut sur la première, clic) : sélection et défilement gardés ;
  Droite / Entrée vers les applications ramènent la sélection en vue ; survols en attente annulés à la fermeture ; entité numérique
  invalide gardée telle quelle ; `Outputs.focusedScreen()` (écran focalisé, sinon principal, sinon le premier) partagé par le lanceur,
  le sélecteur de fonds, le dialogue polkit et le moniteur.
- Passe 6 : survols en attente vraiment annulés à la fermeture (la passe 5 les déclenchait au lieu de les annuler ; sans effet visible,
  l'ouverture suivante remettait tout à zéro) ; code mort retiré.
- Passe 7 : colonnes du menu remises en haut à l'ouverture (petit écran : la colonne des catégories restait défilée) ; sélection remise
  à zéro tout de suite à chaque nouvelle liste (une flèche tapée juste après une lettre était écrasée). Question pour toi : un
  raccourci (lanceur, menu…) pressé pendant une demande polkit l'annule, comme un clic à côté (règle « un seul popup ») : gardé.
- Passe 8 : rien de sérieux ; défilement à la molette encore animé arrêté avant de remettre une colonne en haut. **Boucle terminée.**
- À tester à la main : première ouverture du menu après le démarrage de Quickshell (rapide) ; défilement au survol / au clavier ;
  menu et lanceur sur un petit écran (laptop).

### Menu d'applications : fermeture automatique (2026-10-21, ta demande)

- Pointeur sorti du cadre (barre, fenêtre, autre écran) et resté dehors 5 s (même délai que le calendrier épinglé) → fermeture.
  Jamais pendant une recherche (un clic à côté ferme alors), ni sous le menu contextuel, ni si le pointeur n'est jamais entré
  (ouverture au raccourci) ; une touche relance le délai. Vérifié sur banc (les trois cas).
- Délai ramené à 2 s (ton choix), pour le menu et le calendrier épinglé.
- Calendrier épinglé : il se fermait dès la sortie du pointeur au lieu d'attendre (ton signalement). Cause : `focus_follows_mouse`
  (actif par défaut dans ta config Sway, `follow_mouse = 1` sous Hyprland) focalise la fenêtre survolée, et ce changement de focus
  fermait le calendrier aussitôt. Pointeur dehors, c'est maintenant le délai de 2 s qui ferme.
- Recherche sans résultat (ton choix, maquette C) : « No results for “…” » au centre de la liste avec une loupe 48 px et une astuce,
  soulignement du champ en `red`. Fichiers récents vides : « No recent files » au même format, une fois la liste vérifiée.
- Polkit : un raccourci pressé pendant une demande l'annule — gardé (ton choix).

### Survols de la barre et aperçu des cartes du tray (2026-10-21, ta demande)

- Pilule GPU / CPU / mémoire : au survol de n'importe quel point, fond `green` (couleur de la mémoire) sur toute la pilule, textes et
  icônes `mantle`, comme le bouton Arch (`Pill.highlightColor`, choisi par `pillHighlight` des modules).
- Horloge (avec ou sans date) : survol, ou calendrier épinglé, → fond `yellow`, texte `mantle`.
- Tray (NordVPN, réseau, Wi-Fi, disques, Bluetooth, notifications ; tes choix) : arrêt de **300 ms** sur l'icône → aperçu de sa
  carte (pas en passant), **sans clavier** (la fenêtre où tu tapes le garde ; vérifié : Échap atteint la fenêtre) et sans capter
  les clics hors du cadre (ils atteignent les fenêtres, masque d'entrée). Fermé **300 ms** après que le pointeur a quitté la carte
  et les icônes natives du tray ; glisser d'une icône à l'autre garde la carte jusqu'à ce que la suivante la remplace. Clic sur
  l'icône ou dans la carte → épinglée : clavier (Échap vérifié), fermeture comme avant (clic à côté, Échap). Fermée pointeur sur
  l'icône (clic, Échap…) → pas d'aperçu tant que le pointeur y reste. Pas d'aperçu par-dessus un popup épinglé (menu, réglages,
  calendrier, menu d'application du tray ; sauf les menus natifs ouverts par `display()`, dont la fermeture n'est pas connue).
  Icônes d'applications et engrenage : inchangés.
- Aperçu « léger » : recherche Bluetooth et scan Wi-Fi seulement une fois la carte épinglée (vérifié sur l'adaptateur :
  `Discovering` faux en aperçu, vrai épinglé) ; notifications marquées vues seulement après épinglage (un simple aperçu garde le
  point bleu). Les lectures (statut NordVPN, détails `nmcli`, Tailscale / ZeroTier) restent : elles remplissent la carte affichée.
- **Durées à valider** : 300 ms d'arrêt avant l'aperçu, 300 ms avant sa fermeture (`Theme.panel.previewDelay` / `previewGrace`,
  THEME.md § 3 « Panneaux »). Pas dans ta charte : choisies par moi.
- Revue en boucle (`/code-review high`, 5 passes) : passe 1 délai d'intention, clics transmis pendant l'aperçu, survol du cadre vu
  avant ses enfants, survol de l'horloge partagé ; passe 2 suppression après toute fermeture, balayage du tray sans aperçus en
  cascade, état épinglé explicite (`BarState.popupPinned`), survol en bloc seulement si tous les modules de la pilule le demandent,
  délai repris quand un popup bloquant se ferme ; passe 3 « vues » seulement après épinglage, icône masquée sous le pointeur, plus
  de couleur littérale ; passe 4 recherches radio réservées aux cartes épinglées ; passe 5 recherche Bluetooth arrêtée si la barre
  est détruite carte épinglée. Écartés : fusion avec la machine d'états du calendrier (remaniement), lectures de l'aperçu. **Boucle
  terminée** (passe 5 : plus que des détails).
- Banc : Sway isolé + pointeur **et clavier** virtuels (pywayland, scratchpad). Piège : la veille de l'instance de test éteint
  l'écran virtuel (`grim` bloque) → `inhibit_idle` sur une fenêtre du banc, ou `swaymsg output '*' power on`.
- À tester à la main : saisie au clavier après épinglage (mot de passe Wi-Fi, recherche NordVPN) ; trajet naturel icône → carte ;
  ressenti des deux délais.
### Cartes du tray : réglages et prise en main de la session (2026-10-21, ta demande)

- Aperçu après **150 ms** d'arrêt (ton choix) ; carte épinglée fermée quand le pointeur reste **2 s** hors d'elle et de son icône
  (comme le calendrier et le menu), jamais pendant une saisie (champ non vide focalisé). Vérifié sur banc (sauf la saisie).
- `scripts/takeover.sh` : prend la main sur la session Sway en cours, sans toucher aux configs (bascule durable : phase 10).
  Arrête Waybar, Dunst, swaybg, swayidle, polkit-gnome, nm-applet, blueman, udiskie (lignes de commande notées dans
  `$XDG_RUNTIME_DIR/qs-takeover.cmds`), relance l'instance de dev (agent polkit inscrit), raccourcis → `qs ipc` jusqu'au prochain
  `reload` : `$mod+w` lanceur, `$mod+Escape` réglages, `Print` / `$mod+Print` / `$mod+Shift+Print` captures zone / écran / fenêtre,
  touches volume et micro (OSD), `$mod+s` sortie audio, luminosité, `$mod+d` HDR, `$mod+Ctrl+w` relance du shell (nouveau sous
  Sway). VPN inchangé. `scripts/takeover.sh restore` : ancien bureau. Lancé par toi le 2026-10-21 : tous les outils arrêtés,
  polkit inscrit sans erreur.
- Validé par toi le 2026-10-21 : dialogue polkit (`pkexec true`), tous les raccourcis ci-dessus.
- Reste à tester à la main : veille à 300 s, montage automatique d'une clé USB, `restore` puis `takeover` à nouveau.
- Lien `~/.config/quickshell/desktop` corrigé (il pointait vers `qs-dektop`, faute de frappe) : `qs -c desktop` fonctionne.
- Reste : démarrage automatique = phase 10 (config Sway).

### Fichiers qui ne s'ouvraient plus (Nemo, torrents) — 2026-10-21, ta demande

- **Cause** : le montage FUSE du portail de documents (`/run/user/1000/doc`) avait disparu alors que `xdg-document-portal` tournait
  toujours. Tout lancement d'application Flatpak (dont Deluge, `org.deluge_torrent.deluge`) échouait dans `bwrap` (« Can't find source
  path /run/user/1000/doc/by-app/… »), en silence : `xdg-open` renvoie 0. Origine inconnue (service démarré le 2026-10-20, journal
  inaccessible) ; rien dans ce dépôt ne démonte quoi que ce soit.
- **Corrigé** : `systemctl --user restart xdg-document-portal` → montage revenu ; lancement vérifié dans le bac à sable de Deluge
  (commande neutre, aucun torrent ajouté).
- `~/.config/mimeapps.list` nettoyé (sauvegarde `~/.config/mimeapps.list.bak-2026-10-21`) : `deluge.desktop` →
  `org.deluge_torrent.deluge.desktop` (+ `x-scheme-handler/magnet`), `xed.desktop` (désinstallé) retiré ou remplacé par
  `geany.desktop` (déjà l'éditeur effectif ; `text/x-qml` n'avait plus aucune application), entrées `teams`, `SideQuest` et
  `transmission-gtk` (désinstallés) retirées.
- `scripts/dev.sh` : l'instance lancée depuis un terminal n'avait pas `XDG_CURRENT_DESKTOP` et gardait les jetons d'activation
  (`DESKTOP_STARTUP_ID`, `XDG_ACTIVATION_TOKEN`) du terminal, hérités par toutes les applications lancées depuis Quickshell. Désormais :
  jetons retirés, `XDG_CURRENT_DESKTOP` repris de l'environnement systemd s'il manque. Vérifié (`sway` dans l'environnement de `qs`).
- `scripts/takeover.sh` : bit exécutable rétabli (perdu dans la copie de travail).
- Avertissements `quickshell.desktopentry` « invalid line (no =) » au démarrage : fichiers SteamVR de
  `~/.local/share/applications` (`valve-*.desktop`), sans effet.
- **À faire / surveiller** :
  - à tester à la main : ouvrir un `.torrent` depuis Nemo et depuis Chromium, un lien `magnet:` ;
  - le Deluge déjà lancé garde l'ancien montage mort : sans effet pour `~/Downloads` et `/mnt` (accès direct), mais pour un torrent
    situé ailleurs, redémarrer Deluge ;
  - si le problème revient (`mount | grep /run/user/1000/doc` vide) : relancer le service et chercher ce qui démonte le dossier ;
  - phase 10 : `qs` lancé par `exec` de Sway / `exec-once` de Hyprland hérite de l'environnement de session ; garder l'import de
    `XDG_CURRENT_DESKTOP` (`systemctl --user import-environment`) dans les configs rapatriées.

## Avertissements au démarrage et plantage à l'arrêt (2026-10-26)

- Sway redémarré le 2026-10-24 : son autostart avait relancé Dunst, polkit-gnome, swayidle, nm-applet, blueman et udiskie, et le
  fichier d'état de `takeover.sh` datait de la session précédente (un `restore` les aurait relancés en double). Désormais propre à
  la session Sway (`qs-takeover.<socket>.cmds`) ; `dev.sh` signale quand Dunst ou polkit-gnome tournent encore. Prise en main refaite.
- « I3 event socket disconnected » au démarrage : `I3IpcListener` se connectait dès ses abonnements posés, puis recréait sa connexion
  après le chargement (`onPostReload`, Quickshell 0.3.2). Abonnements posés après le chargement (`services/Compositor.qml`) : plus
  d'avertissement au démarrage, deux connexions au socket Sway (contrôleur + écouteur). Reste au rechargement à chaud (écouteur de
  l'ancienne génération détruit), sans effet.
- Avertissements `desktopentry` : tabulation finale sans retour à la ligne dans les trois `valve-*.desktop` de SteamVR. Correction
  hors dépôt, à faire par toi (commande dans le rapport de session) ; SteamVR peut les réécrire.
- **Plantages** (`~/.cache/quickshell/crashes/`, 2026-10-19 et 2026-10-26) : bogue de Quickshell 0.3.2, pas de la config. `qs kill`
  moins d'une seconde après un rechargement à chaud, pendant que l'ancienne génération est encore détruite :
  `EngineGeneration::currentGeneration()` renvoie nul (deux générations), Quickshell quitte sans détruire la nouvelle, puis la
  détruit après la fermeture de la connexion Wayland ; `IdleNotification` (`IdleMonitor` de `services/Idle.qml`) envoie alors une
  requête sur un objet Wayland mort → SIGSEGV. Sans conséquence (le processus s'arrêtait, `dev.sh` relance). N'arrive pas en
  production (pas de rechargement à chaud). Contournement : attendre une seconde après une sauvegarde avant `$mod+Ctrl+w`.

## Panneau de réglages, veilleuse, captures, ne pas déranger programmé (2026-10-26, ta demande)

État final, après 6 tours de revue de code (`f28ae4c..HEAD`, jusqu'à des constats négligeables).

- **Survol de l'engrenage** : le panneau de réglages dérive de `Panel.qml` ; survol et appui communs aux icônes du tray et à
  l'engrenage (`modules/bar/PreviewArea.qml`, ta demande). Aperçu après 150 ms, passage direct vers une icône du tray, épinglé au
  clic, fermé 2 s après la sortie du pointeur (pas pendant un glissé commencé dans le cadre, ni pendant une saisie). Dans l'aperçu
  des réglages, **le premier clic épingle seulement** (verrouiller, éteindre… sans confirmation : pas de clic perdu dessus) ; les
  cartes du tray gardent le clic qui épingle et atteint l'élément. Raccourci des réglages : aperçu → épinglé (sous le bouton de
  l'écran focalisé), panneau épinglé → fermé. Chaque bouton de barre a sa fonction `toggle()` (`BarState.load`).
- **Micro** retiré du panneau (reste dans le panneau audio).
- **Mode avion** : visible dès qu'il y a une radio (`rfkill` : Wi-Fi `phy0` et Bluetooth `hci0` sur ce desktop). Pas essayé.
- **Veilleuse** : `gammastep` remplace `wlsunset` (`deps/` à jour). Fondu d'environ 4 s à l'activation, à la désactivation et aux
  heures de l'horaire. Désactivation par SIGUSR1 (réversible pendant le fondu), arrêt 6 s plus tard pour libérer le réglage gamma ;
  SIGUSR1 seulement 1 s après le lancement. Réglage gamma tenu par un autre client (ancienne instance au rechargement) :
  gammastep l'écrit sur stderr (« Zero outputs support gamma adjustment ») sans quitter ; il est arrêté et relancé (vérifié après
  deux rechargements). Après 10 échecs de suite : un essai par minute, et aussitôt qu'un écran apparaît ou que la config change.
  Nuit dans la même journée (00:30 – 06:00) : températures inversées dans `gammastep.ini` (vérifié avec `gammastep -p`).
  `qs ipc call nightlight toggle|isEnabled`.
- **Captures sans curseur** (vérifié par toi) : Sway sur Nvidia dessine un curseur logiciel dans l'image de l'écran (même `grim`
  sans `-c` le capture). `hide_cursor` de Sway écarté (au moins 100 ms, relancé par le moindre mouvement). Les surfaces de l'outil
  demandent un curseur vide, la capture commence 50 ms après l'entrée du pointeur ; sous un pointeur immobile, Sway n'envoie cette
  entrée qu'après un déplacement : `seat - cursor move 0 0` par le socket IPC (`Compositor.nudgeCursor`), toutes les 50 ms à partir
  de la création des surfaces, 1 s au plus (puis capture quand même). Écran sans image figée 3 s après le début de la capture :
  fermeture (écran de départ) ou surface rendue transparente au pointeur (autres écrans). Hyprland : rien de tout cela (curseur
  matériel), capture immédiate, à vérifier en phase 9.
- **Ne pas déranger programmé** : 21:00 – 07:00 (`doNotDisturb` dans `hosts/default.json`, puis `do-not-disturb.json`). Aux heures
  de début et de fin (et au démarrage de la session), l'horaire s'impose ; entre les deux, la bascule à la main reste libre.
  Activer l'horaire ou changer ses heures de sorte qu'on entre dans la plage : activé (sauf s'il l'est déjà à la main) ; qu'on en
  sorte : désactivé seulement s'il l'avait été par l'horaire. Heures identiques acceptées (plage vide). Tuile : horaire en
  sous-titre ; **clic droit**, touche Menu ou Maj+F10 : ligne « Schedule » (deux heures, masque `HH:MM`, deux points fixes ;
  Entrée ou sortie du champ enregistre, Échap annule et rend le clavier au panneau, un second Échap le ferme) et interrupteur.
  `qs ipc call notifications setSchedule|setDoNotDisturb|doNotDisturbState`.
- Laissé tel quel (revues) : relance avec fondu de la veilleuse quand sa config machine change (rare) ; l'outil de capture prend
  le pointeur pendant son démarrage (environ 100 ms) ; une surface Overlay plus haute sous le pointeur (popup) priverait l'outil de
  l'entrée du pointeur (capture avec curseur au bout d'1 s, non observé).
- **Vérifié par toi** : capture sans curseur ; heure tapée puis Entrée ; chiffre modifié au milieu d'une heure, Échap (annule),
  Échap (ferme) ; mode avion.
- **À tester à la main** : ressenti du fondu de la veilleuse (20:00 ce soir) ; à 21:00, la cloche barrée ; facultatif : tuile
  « Do Not Disturb » choisie au clavier (Tab), puis touche Menu (à droite d'AltGr) ou Maj+F10 → ligne « Schedule ».
- Note de dev : un nouveau fichier QML dans un module n'est vu qu'au redémarrage de l'instance (`scripts/dev.sh`), pas au
  rechargement à chaud (« X is not a type »).

## Panneau audio : carte du périphérique par défaut, niveau des entrées (2026-10-26, ta demande)

- Sortie et entrée par défaut en **carte** en tête de section (langage du panneau Wi-Fi : fond `base`, icône 48 px, nom `green`,
  « Default output / input »), curseur de volume dans la carte ; les autres périphériques en lignes dessous, un clic les choisit.
  Même carte dans la liste des sorties du panneau de réglages (`THEME.md` « Panneau audio »).
- **Niveau capté** par chaque entrée : `PwNodePeakMonitor` natif (Quickshell 0.3.2, aucune dépendance), trait de 4 px sous le
  curseur (carte) ou sous le nom (autres entrées), montée immédiate, descente lissée 100 ms ; capture seulement panneau épinglé
  (pas en aperçu : survoler l'icône n'ouvre pas les micros) ; pas de
  niveau pour une entrée Bluetooth (la capture ferait passer le casque du profil A2DP au profil micro).
  Vérifié : niveau du C920 différent d'une capture à l'autre.
- Calibrage (ta remarque : barre vers 80–90 % en silence) : la crête de Quickshell est en échelle cubique comme les volumes
  (0,24 en silence pour -37 dBFS mesurés avec `pw-record`) ; conversion corrigée (60 × log10), échelle -40 → 0 dBFS : silence vers
  10 %. Dégradé `blue` → `green` → `yellow` → `peach` → `red` sur la largeur (ta demande). Vérifié par toi : micro coupé, changement
  d'entrée, échelle (« ça fonctionne bien »). Revue de code en boucle ensuite (Bluetooth exclu, descente lissée image par image…).
- Micro coupé : il ne transmet que des zéros (mesuré) ; plus de capture, creux atténué comme en aperçu.
- Revue de code : 6 tours (`8468a22..HEAD`), jusqu'à des constats négligeables ou déjà tranchés. Laissés : une capture par entrée
  (ta demande) ; moniteur de crête dans le widget (type natif, pas un `Process`) ; source virtuelle bâtie sur un micro Bluetooth
  non reconnue (cas absent ici). Vérifié avec `pw-dump` : épinglé → une capture par entrée, entrée coupée → sa capture fermée,
  fermé → aucune.
- **À tester à la main** : descente de la barre après un mot (100 ms, à valider) ; aperçu au survol (creux atténué, rien n'est
  capté) ; liste des sorties dépliée dans le panneau de réglages.

## Pilule média de la barre : revue de code (2026-10-26, ta demande)

Lecteur, visualiseur, icône et curseur de volume (`Mpris`, `CavaModule`, `Volume`, `Slider`, services `Media`, `Cava`, `Audio`).
2 tours (`e6fae14..HEAD`), le second sans constat notable.

- **Lecteur suivi après une pause** : un lecteur suivi parce qu'il jouait (ex. Chromium) le reste en pause, au lieu de laisser
  la place au lecteur préféré ; le clic suivant (ou `qs ipc call media playPause`) reprend donc la même lecture. Avant : le clic
  lançait Spotify. Vérifié avec deux faux lecteurs MPRIS sur un bus D-Bus privé (ancienne et nouvelle version).
- **Volume au-dessus de 100 %** (réglé dans pavucontrol) : la molette de l'icône et les touches ne le ramènent plus d'un coup à
  100 % ; monter ne fait rien, baisser retire 5 points (comme Waybar).
- **Visualiseur** : masqué tant que cava n'a rien envoyé (démarrage, relance après un arrêt, cava absent sur une autre machine) ;
  avant, une case vide de 20 px dans la pilule.
- **Panneau audio** : l'icône et le curseur de volume annoncent leur survol, comme les boutons du tray ; le panneau épinglé ne se
  ferme plus tout seul pendant que le pointeur y reste (molette, glissé), et se ferme 2 s après qu'il a quitté l'icône.
- Vérifié sans suite : cava suit déjà la sortie par défaut (WirePlumber, `target.node = -1`) ; un volume écrit est relu aussitôt
  (crans de molette rapides cumulés) ; coût du visualiseur à 100 images/s : 0,5 à 2,6 % d'un cœur pour tout Quickshell ; cava
  stable pendant la lecture.
- Laissés (négligeables) : reste de défilement du pavé tactile jamais remis à zéro (`WheelSteps`) ; panneau ouvert depuis
  l'icône fermé 2 s après un passage sur le curseur voisin ; un panneau audio par module (icône et curseur).
- **À tester à la main** : pause d'une vidéo Chromium depuis la barre, puis clic → même vidéo ; clic droit sur l'icône de volume,
  pointeur gardé dessus → reste ouvert, pointeur ailleurs → fermé 2 s plus tard.
- **cava retiré** (ta demande, même jour : n'apporte rien, coûte du CPU) : `services/Cava.qml`, `modules/bar/CavaModule.qml`,
  `config/cava.conf`, le module `cava` des configs machine et de `Bar.qml`, ses jetons de `Theme.qml` (police DejaVu Sans,
  taille, paddings, couleur, glyphes) ; `cava` et `ttf-dejavu` sortis de `deps/` (`pipewire-pulse` reste pour pavucontrol) ;
  `THEME.md`, `ARCHITECTURE.md` et `INVENTORY.md` mis à jour. Recherche de code mort : aucun jeton, propriété ni composant
  orphelin. Instance relancée sans erreur, plus aucun processus cava.
- **Réglages du thème inutilisés retirés** (ta demande) : groupe `powerMenu` (power menu Rofi non repris, remplacé par le
  panneau de réglages), `font.powerMenuLabel`, `module.menuLogo`, `module.menuBackground`, `icon.power`,
  `notification.progressMinWidth` (largeur de notification fixe à 600 px : jamais atteint). Gardés : toutes les couleurs du § 1
  (palette, `hoverWhite`), même inutilisées, pour de futurs éléments ; couleurs Rofi inutilisées (`ugt`, `bga`, `bdr`)
  retirées ensuite (ta demande), celles du lanceur gardées ;
  **toutes les couleurs centralisées** dans `Theme.color` (palette, Rofi du lanceur, texte GTK, Papirus, blancs translucides) ;
  les autres groupes n'y font que référence ; vérifié : 154 couleurs identiques à l'ancien thème (8 bits) ; `embeddedFonts` (charge les polices) ;
  `icon.spotify` (lu par la table des lecteurs). `Settings.qml` et les configs machine : rien d'inutilisé.

## Espaces de travail : revue de code (2026-10-26, ta demande)

`Compositor`, `Outputs`, `Workspaces` et `test-outputs.sh`. 3 tours (`e419399..HEAD`), le dernier sans constat notable. Tout
reproduit dans une session Sway isolée (banc headless) avant correction, puis vérifié.

- **Boucle sans fin** : un écran vidé de son seul espace reçoit de Sway un espace « bouche-trou » au premier numéro libre ; s'il
  n'était pas chez lui, la correction le déplaçait, Sway en recréait un, etc. (~8 commandes/s, mesuré ; elle tournait aussi au
  démarrage du banc). Désormais l'écran affiche à la place un espace de son bloc. Sans les `workspace N output` de ta config Sway
  (retirés en phase 10), elle se serait produite pour de vrai.
- **Halo et mémoire de vue faux** : Quickshell 0.3.2 ne met jamais à jour l'espace affiché par un écran quand un espace change
  d'écran (code lu) ; après certains déplacements, aucun espace n'était « affiché » sur un écran (barre sans halo) et un écran
  rallumé retrouvait une mauvaise vue. Relecture des sorties après chaque déplacement (Sway ; Hyprland : même ajout, à vérifier
  en phase 9).
- **Focus faux** : Sway annonce parfois le focus sur le bouche-trou alors qu'il reste ailleurs, et le champ `focused` de ses
  événements est souvent faux (vérifié) ; un déplacement à la main finissait avec le focus sur un espace vide au centre. Le focus
  est maintenant relu (`get_workspaces`) après chaque événement d'espace.
- **`$mod+N` vers un espace inexistant depuis un autre écran** : si l'écran de départ affichait un espace vide, il affichait
  ensuite un autre de ses espaces ; il retrouve maintenant le sien, comme avec tes attributions actuelles.
- `test-outputs.sh` : deux scénarios ajoutés (espace créé depuis un écran qui affichait un espace vide ; seul espace d'un écran
  déplacé à la main). 0 échec, trois passages ; 16 commandes de placement au lieu de 24 à 30.
- Laissés (négligeables) : `workspace_auto_back_and_forth` (absent de ta config) fausserait les commandes `workspace number N`
  du placement ; `$mod+N` moins de 300 ms après avoir changé d'espace sur l'écran de départ lui rend l'espace d'avant ; espaces
  nommés sans numéro (inutilisés) confondus dans la barre ; quelques ms sans espace focalisé après chaque changement (relecture).
- **Phase 9** : rejouer bouche-trou et focus sous Hyprland (même logique, non testée).

## Panneau Bluetooth enrichi (2026-10-26, ta demande)

Revue de KDE, GNOME et blueman (Cinnamon utilise blueman) ; tes choix et ce qui est écarté : `ARCHITECTURE.md` § 10.2.1.

- Lignes : état · type · batterie, « Connection failed », icône qui pulse ; détails dépliables (adresse copiable, appairé,
  approuvé, adaptateur, nom d'origine), renommage, reconnexion automatique, profil audio ; ordre figé panneau ouvert.
- Repris de blueman : notifications Connected / Disconnected (+ batterie), reconnexion auto toutes les 60 s (ton réglage pour la
  manette Xbox repris), profil audio, veille suspendue avec une manette connectée. Icône du tray animée, alerte batterie faible.
- Vérifié (Sway isolé, BlueZ et PipeWire réels, bus de session privé) : panneau et détails ; connexion de la manette éteinte →
  « Connecting… » + icône animée, puis « Connection failed » ; reconnexion auto à 60 s sans animation ni échec affiché ; liste
  reprise de blueman (`bluetooth.json`) ; renommage du casque puis nom d'origine rétabli (alias = nom, vérifié par
  `bluetoothctl`) ; remplacement de la notification « Connected » → « Connected 80% » et alerte batterie (mêmes commandes
  `notify-send`) ; lecture des profils sur une vraie carte PipeWire (casque Razer filaire, même format).
- **Incident** : un banc précédent sur bus privé avait lancé un second `gvfsd` (activé par `gsettings`) ; le montage
  `/run/user/1000/gvfs` de ta session était cassé (« Transport endpoint is not connected »). Banc corrigé (`GIO_USE_VFS=local`) ;
  réparé (montage mort démonté, `gvfsd-fuse` relancé : unité utilisateur `gvfsd-fuse-restore` jusqu’à ta prochaine session) ;
  `test-outputs.sh` protégé de la même façon.
- **À tester à la main** : connexion réelle du casque et de la manette (notification, batterie, profil audio A2DP ↔ HFP, veille
  suspendue manette connectée), animation au clic sur Connect, saisie d'un nouveau nom au clavier, « Copy address ».
- Valeurs à valider : rythmes d'animation (`THEME.md` § 3 « Panneau Bluetooth »).

### Revue en boucle du module Bluetooth (2026-10-26 → 27, ta demande)

9 passes de `/code-review high` (`d444bc0..HEAD`), chaque point vérifié (code, banc isolé, simulation) avant correction, un commit
par passe (`967cb92` … `c5df0c8`). Arrêt : la passe 9 ne trouve plus rien de réel.
- Principaux défauts corrigés : profils audio lus avant que PipeWire crée la carte, ou relus trop tôt après un changement
  (relus quand les nœuds de l'appareil changent ; lectures périmées ignorées) ; « Forget » qui laissait l'appareil en
  reconnexion automatique ; état précédent d'un appareil lié au lieu d'être fixé (« Connection failed » pouvait manquer) ;
  reconnexion automatique qui attendait 60 s au démarrage (blueman la lance tout de suite) ; première connexion après un
  appairage non annoncée ; carte audio périmée après un redémarrage de BlueZ ; reprise de blueman relancée à chaque démarrage
  sans blueman ; nom d'appareil commençant par « - » lu comme une option de `notify-send`.
- Alerte de batterie d'un appareil : gardée d'une connexion à l'autre et même si BlueZ recrée l'appareil, réarmée seulement
  au-dessus de **40 %** (ton choix du 2026-10-27).
- Écarté (vérifié faux) : faux « Connected » au démarrage — Quickshell livre les appareils avec leurs propriétés déjà lues.
- Laissés (négligeables) : double lecture `pw-dump` après un changement de profil ; objets orphelins seulement si `pw-dump` ou
  `notify-send` manquent ; échec de profil après une connexion établie (montré par « Connected » puis « Disconnected ») ;
  notification de batterie qui peut réapparaître moins de 10 s après avoir été fermée (comme blueman) ; reconnexion auto
  immédiate seulement pour le premier appareil choisi ; appairage bloqué si l'appareil disparaît en plein appairage (rare,
  code antérieur).

## Écrans dynamiques : revue en boucle (2026-10-27, ta demande)

5 passes de `/code-review high` (`Outputs`, `Compositor`, `Settings`, barres, `test-outputs.sh`, configs machine), chaque point
vérifié (code, banc Sway isolé, ancien code rejoué) avant correction, un commit par passe (`a660c6e` … passe 5). Arrêt : la
passe 5 ne trouve plus que du négligeable (le banc de l'agent : 26 contrôles, 0 échec).
- **Espace focalisé vide qui change d'écran** (ex. écran de droite éteint, espace 4 vide focalisé à gauche) : l'écran
  d'arrivée affichait d'abord sa vue mémorisée, Sway détruisait l'espace, le focus final le recréait à gauche, puis une seconde
  correction. Reproduit sur l'ancien code (2 corrections), scénario ajouté à `test-outputs.sh` (1 correction).
- **Barre** : un écran qui a sa propre entrée (`LG …841`) et devient principal (les deux autres éteints) n'avait ni tray ni
  réglages ni menu ; l'écran principal reçoit maintenant toujours la barre `primary` (`ARCHITECTURE.md` § 4). Clic sur un espace
  persistant : créé directement sur l'écran de la barre (avant : sur l'écran focalisé, puis déplacé).
- **Banc de test** : l'instance de test agissait sur ton vrai système (reconnexion Bluetooth automatique, agent polkit, fichiers
  d'état partagés) ; isolée (`QS_TEST`, `XDG_STATE_HOME` à part) et arrêtée avec tout son groupe de processus. **52 processus
  orphelins** des passages précédents (bus privés, `gdbus monitor` sur le bus système) arrêtés.
- **Veilleuse** : un `gammastep` orphelin (laissé par un `qs kill` le 26 à 18 h 43) tenait le gamma ; ton instance échouait à
  lancer le sien depuis (38 essais) et le bouton veilleuse n'agissait plus. Arrêté ; ton instance a repris la main. Cause :
  `qs kill` laisse vivre les processus enfants. Les processus longs (moniteurs UDisks2 / logind, `gammastep`, agent
  `bluetoothctl`) passent par `setpriv --pdeathsig TERM` et meurent avec Quickshell (11 autres moniteurs orphelins arrêtés).
- Robustesse : vue mémorisée gardée capot fermé sans écran (aucun instantané sans écran actif) ; répartition imposée triée,
  ignorée avec un avertissement si chaque numéro 1–9 n'y est pas une fois, entrées mal formées ignorées ; Sway : visibilité
  des espaces lue dans l'IPC, seules les sorties `active: true` ; espace nommé « 3 web » reconnu par le déplacement ;
  Hyprland : écran en miroir sans bloc d'espaces ; moins de relectures (`get_tree` sur titre d'une fenêtre non focalisée).
- Laissés (négligeables ou par choix) : en config Hyprland classique, pas de placement (Lua seulement, § 3) et
  `focusmonitor` + `workspace` non atomiques ; barre invisible sur un écran miroir ; focus choisi dans les 500 ms suivant un
  changement d'écrans remplacé par le focus d'avant ; relance de Quickshell = nouvelle répartition (un espace déplacé à la main
  revient chez lui) ; hosts/*.json invalide pendant l'édition = config par défaut le temps de la corriger ; deux écrans
  identiques sans numéro de série indiscernables ; instance de test joignable par `qs ipc` sans `--pid` pendant le test.
- **Phase 9** : moniteur Hyprland listé avant d'être lu (description vide) — à vérifier.

## Veille des écrans : revue en boucle (2026-10-27, ta demande)

Symptôme signalé : à la reprise, latéraux allumés puis éteints, puis central, puis latéraux ; central lent. 3 passes, chaque
point reproduit sur l'ancien code dans un Sway isolé (3 sorties headless, `sway -d`, veille à 5 s, pointeur virtuel) avant
correction ; banc dans le scratchpad de la session (`idle-bench.sh`), `test-outputs.sh` : 0 échec.
- **Rallumage en deux temps sous Sway** (cause du symptôme) : `primaryWakeDelay` (3 s, repris de hypridle) s'appliquait aussi
  sous Sway, où chaque commande `output` réapplique la config de **tous** les écrans en un seul commit (code de Sway 1.12 lu).
  Rallumer le central 3 s après refaisait un modeset qui coupait de nouveau les latéraux. Sous Sway, tout est rallumé d'un coup
  (`output * power on`, comme ton swayidle) : banc, 1 commit au lieu de 2, les 3 sorties à +32 ms (avant : central à +3 s).
  Ta décision : le délai de hypridle contournait un bogue de Hyprland, pas un modèle à suivre ; un seul comportement pour les
  deux compositeurs, tous rallumés ensemble. `primaryWakeDelay` retiré (`Settings`, `hosts/terrier.json`) ; Hyprland testé en
  phase 9.
- **Écran branché après une veille resté éteint** (Sway) : rallumer par nom laissait `power off` sur la config `*`.
  Corrigé par le même `output * power on` (banc : sortie créée après une veille allumée ; avant : éteinte).
- **Quickshell relancé écrans éteints** (rechargement à chaud, plantage) : le nouveau suivi n'est pas en veille ; écrans noirs
  jusqu'à 5 min sans activité. Rallumés 2 s après le démarrage (`Compositor.outputs[].powered`). Vu en direct cette nuit : un
  premier essai (rallumage dès le chargement) a fait planter ton instance pendant un rechargement à chaud (bug connu de
  Quickshell 0.3.2, ancienne génération en destruction) ; le délai de 2 s l'évite. Instance relancée par `dev.sh` (la copie
  relancée après plantage ne suivait plus les fichiers).
- `systemd-inhibit` (verrou avant la veille du système, laptop) sous `setpriv --pdeathsig` : verrou relâché si Quickshell plante.
- **À surveiller** : second plantage de ton instance à 08 h 25, 6 s après un rechargement à chaud, sans rapport avec la veille
  (aucune commande d'alimentation) : même pile que celui de 04 h 43 (événement I3 → liaison QML → `lookupSingletonProperty`).
  Les deux après un rechargement ; à étudier à part s'il se produit hors rechargement.
- **À tester à la main** : une vraie reprise sur tes trois écrans (attendre 5 min) — les trois doivent s'allumer ensemble, sans
  extinction intermédiaire. Le central (AW3418DW) peut rester un peu plus lent à sortir de veille : c'est l'écran lui-même.

## Écran de verrouillage : revue en boucle (2026-10-27, ta demande)

3 passes de `/code-review high` (`LockScreen`, `LockContent`, `Session`, `Idle`), chaque point vérifié avant correction sur un
banc isolé (Sway headless à 2 sorties, Quickshell sur une copie de `modules/lock`, PAM factice `pam_exec` : `test` accepté,
`bad…`/`slow…` avec 2 s de délai, faux faillock par `pam_echo`, frappe simulée par IPC ; arrêté ensuite), un commit par passe
(`6ce414e`, `72a71cf`, `2c559de`). Arrêt : la passe 3 ne trouve plus que du négligeable ou du réfuté.
- **Verrou refusé** (reproduit : swaylock tenant déjà le verrou) : `locked` restait vrai sans verrou réel ; tout verrouillage
  suivant (menu, IPC, avant la veille du laptop) était ignoré jusqu'au redémarrage de Quickshell. Il repasse à faux (avertissement
  dans le journal) ; vérifié : reverrouillage possible une fois swaylock parti ; déverrouillage + reverrouillage dans le même tour
  non annulé.
- **Frappe pendant la vérification** : les caractères tapés pendant le délai d'échec de PAM (~2 s) étaient perdus, et l'essai
  suivant partait tronqué (une erreur de plus dans faillock). Gardés pour l'essai suivant, comme swaylock ; Entrée reste ignoré
  pendant la vérification, comme swaylock.
- **Messages de PAM** : compte bloqué par faillock (`deny = 10` chez toi) affiché tel que PAM l'envoie, au lieu de « Wrong
  password » avec le bon mot de passe ; une erreur interne de PAM n'est plus présentée comme un mauvais mot de passe.
- **Mot de passe long** (plus de 15 caractères) : les points ne bougeaient plus ; les derniers restent visibles, points entiers.
- Graisses et tailles de l'écran passées dans `Theme.lock` (`THEME.md` § 11.1 complété).
- Laissés (négligeables ou réfutés) : modules PAM qui bloquent ou demandent deux fois (empreinte, OTP, homed : absents de ta
  pile) ; refus synchrone (protocole absent : hors Sway/Hyprland) ; rechargement manuel pendant le verrouillage (`Session.locked`
  pas resynchronisé) ; `LockScreen` écrit `Session.locked` (convention : lecture seule) ; `Idle` : processus `gdbus`/`systemd-inhibit`
  non relancés s'ils meurent, délai modifié écrans éteints, contrôle unique à 2 s après un redémarrage (rallume aussi un écran
  éteint à la main lors d'un rechargement à chaud), `hyprctl reload` au réveil (ta décision).
- **À tester à la main** : verrouiller (panneau de réglages) et déverrouiller avec ton vrai mot de passe ; se tromper puis
  retaper aussitôt pendant le délai (les caractères doivent apparaître) ; un caractère à touche morte (ex. `ê`) dans le champ, si
  ton mot de passe en contient (frappe simulée par IPC sur le banc, pas par un vrai clavier).

## Ne pas déranger : sons des applications coupés (2026-10-27, ta demande)

- Le shell ne joue aucun son : Discord et WhatsApp jouent le leur, sur leur propre flux. Pendant « ne pas déranger » (horaire
  ou à la main), `services/Audio.qml` coupe les flux de `doNotDisturb.muteApps` (`hosts/terrier.json` : `discord`, `whatsapp` ;
  vide par défaut), comparé à l'`application.id` du flux ou à son binaire. Rétablis à la fin.
- **Refonte (passe 10, ta décision)** : les web apps reçoivent un `application.id` à leur lancement, dans leur lanceur (hors du
  dépôt, sauvegardés en `.bak-2026-10-27`) : `~/.local/share/applications/WebApp-Whatsapp8699.desktop` et
  `WebApp-DiscordWeb2996.desktop`, `Exec=env PULSE_PROP_OVERRIDE=application.id=whatsapp chromium …` (`discord`). L'application
  Discord (Electron, ta demande : les deux versions) est reconnue par son binaire, quel que soit son lancement. Supprimés :
  lecture de `/proc`, mémoire des processus, coupure d'office, `muteWebApps`.
  **Si webapp-manager régénère un lanceur, remettre la variable.** Le lanceur WhatsApp `whatsdesk` (autostart Sway) : non
  traité (s'ajoute de la même façon : `whatsdesk` dans `muteApps` et dans la règle).
- **Gardent le son** (ta demande : première version refusée, elle coupait tout Chromium, donc YouTube) : le navigateur et les
  appels de l'application Discord (flux `WEBRTC VoiceEngine`). Les appels des web apps (Discord, WhatsApp) sont des flux comme
  les autres : coupés s'ils commencent pendant « ne pas déranger » ; rétablir leur ligne dans le panneau audio (laissée ensuite).
  Un son en cours à 21:00 n'est jamais touché.
- Règle WirePlumber `dotfiles/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf` (ton accord) : volume et coupure non
  retenus pour les flux de lecture `application.id` = `discord` / `whatsapp`, et les flux « Chromium » du binaire `Discord`
  (pas ses appels) ; sans elle, la coupure de la nuit resterait le lendemain. Le navigateur retrouve son volume retenu.
  Copiée (pas liée : seul lien avant la phase 10, `~/.config/quickshell/desktop`) dans `~/.config/wireplumber/wireplumber.conf.d/`
  (ancienne règle retirée), WirePlumber redémarré. `install.sh` la liera (phase 11).
- Banc (sortie virtuelle `module-null-sink` enregistrée, un bip par cas, 3 tours, 39/39) : navigateur, web apps WhatsApp et
  Discord, application Discord et son appel, avant / pendant / après « ne pas déranger ». Cibles : 0 ms audible pendant, dès le
  premier bip ; les autres : bip entier.
- **À faire à la main** : relancer les web apps WhatsApp et Discord (elles tournaient avant la modification des lanceurs).
  **À tester** : après 21:00, un message WhatsApp et un message Discord sans son, une vidéo YouTube avec ; le matin, les sons
  reviennent.
- Limites : une application de la liste coupée à la main avant « ne pas déranger » n'est pas touchée (ni coupée ni rétablie par
  le shell). Un lien ouvert depuis une web app s'ouvrait dans une fenêtre Chromium de son profil, coupée la nuit : il part
  maintenant dans le profil principal (section « Web apps : liens ouverts dans le navigateur »). Seuls les flux « Chromium » sont visés : un programme lancé
  depuis une web app (Spotify par un lien) hérite de son `application.id` mais garde son nom, donc son son.
- **Phase 11** : les lanceurs des web apps sont hors du dépôt ; `install.sh` devra leur ajouter `PULSE_PROP_OVERRIDE` (ou
  signaler leur absence), sinon `muteApps` ne fait rien pour elles.

### Revue en boucle (2026-10-27, ta demande)

- **Passe 1** : flux coupés gardés dans un fichier d'état (`audio-hush.json`, `id:pid`), donc au redémarrage de Quickshell ;
  rien n'est touché avant que « ne pas déranger » et PipeWire soient chargés (au rechargement, tout était rétabli) ; doublon dans
  la liste ; `/proc` lu par `FileView` (plus de `sh`/`awk`/`tr`), lectures non relancées (`ScriptModel`) ; `muteApps` changé :
  appliqué aussitôt.
- **Passe 2** : un son déjà en cours quand « ne pas déranger » commence (ou au rechargement) n'est plus coupé d'office (trou
  audible dans Spotify à 21:00) ; processus lus gardés 10 min après leur dernier flux (le navigateur n'était plus relu à chaque
  son) ; **rétabli à la main pendant « ne pas déranger » : laissé** (pour entendre un appel WhatsApp, rétablir sa ligne dans le
  panneau audio) ; Discord seulement dans `hosts/terrier.json` (la règle WirePlumber n'existe pas encore ailleurs) ; `muteApps`
  validé ; `Audio` créé au démarrage (`shell.qml`), absent de l'instance de `test-outputs.sh`.
- **Passe 3** : `syncHush` non réentrante (une coupure changée pendant la passe la rappelait : un flux pouvait sortir de la
  liste et rester coupé après 07:00) ; rien n'est coupé d'office si `muteApps` est vide ; flux en cours au début repérés par
  `id:pid` (un id resservi échappait à la coupure d'office) ; rien n'est parcouru hors « ne pas déranger » quand aucune coupure
  n'est à rétablir ; `hosts/terrier.json` ne donne que `muteApps` (horaire par défaut de `Settings.qml`). Gardé : l'exception
  des appels Discord (`WEBRTC VoiceEngine`) reste dans le code, un seul usage.
- **Passe 4** : un son déjà en cours quand « ne pas déranger » commence n'est jamais coupé, même d'une application de la liste
  (un appel WhatsApp à 21:00 ; les sons de notification ouvrent chacun un flux neuf) ; garde de réentrance en `try/finally` ;
  processus relus chaque nuit ; `Notifs.loaded` posé à la fin de `persist.onLoaded` (ne dépend plus de l'ordre de reprise des
  propriétés). Écartés : applications hors Chromium/Discord dans `muteApps` (il faudrait étendre la règle WirePlumber : noté
  dans `Settings.qml`), valeurs par défaut répétées dans `Settings.qml` (même motif que `nightLight`, `idle`).
- **Passe 5** : flux en cours au début suivis par objet (`playingNodes`, élagué) : un nouveau son qui reprenait l'id d'un flux
  terminé échappait à la coupure ; coupure d'office limitée aux flux « Chromium » (seuls visés par `--class=`, protégés par la
  règle WirePlumber) : un son court d'une autre application (Firefox…) coupé d'office puis fini avant la lecture de `/proc`
  restait retenu coupé par WirePlumber, même le jour ; passes groupées par `Qt.callLater` (plus de garde de réentrance) ;
  recherches par `Set` ; commentaire de la règle WirePlumber corrigé (« 100 % » faux).
- **Passe 6** : rétabli à la main pendant la lecture de `/proc` (après un rechargement) : gardé, plus recoupé ; flux suivis
  seulement si `muteApps` n'est pas vide ; une écriture du fichier d'état par changement. Écarté : un flux Chromium ouvert à
  21:00 mais silencieux est épargné toute la nuit ; Chromium ferme ses flux au repos (aucun flux Discord ni WhatsApp ouvert en
  temps normal, vérifié), donc seulement un son joué quelques secondes avant 21:00.
- **Passe 7** : `muteWebApps` séparé de `muteApps` (sans web app, aucun flux Chromium n'est coupé d'office) ; flux repérés par
  `id:object.serial` (un serial ne resert jamais ; le pid ne distinguait pas deux flux du même processus audio) ;
  `Notifs.loaded` posé avant la reprise de l'historique (une erreur de lecture ne bloque plus le rétablissement). Écartés :
  règle WirePlumber à ne poser que sur une machine qui coupe des applications (noté pour `install.sh`, phase 11) ; web apps de
  Chrome/Brave (documenté) ; deux optimisations sans effet mesurable (passes groupées par `Qt.callLater`).
- **Passe 8** : fichier d'état écrit aussitôt (plus d'écriture différée : un plantage pouvait perdre une coupure) ;
  `Notifs.loaded` posé en tête de `persist.onLoaded` ; copie installée de la règle WirePlumber resynchronisée (commentaire).
  Limite documentée : web app en Flatpak (pid du bac à sable, `/proc` de l'hôte : non reconnue). Proposé à part, pas fait :
  nommer les flux de la web app au lancement (voir le rapport).
- **Passe 9** : clé `id:serial:pid` (un serial resert après un redémarrage de PipeWire, le fichier d'état reste) ; un flux
  encore en lecture de `/proc` n'est plus pris pour « rétabli à la main » (événement PipeWire en retard) ; règle WirePlumber
  limitée aux flux de lecture (les micros Discord/Chromium gardent leur volume retenu ; WirePlumber relancé) ; `playingNodes`
  vidé à la fin ; § 1 de `ARCHITECTURE.md`. Écarté : rechargement à chaud au moment exact d'une coupure (les deux générations
  écrivent le fichier ; fenêtre de quelques ms, flux long seulement).
- **Passe 10 → refonte** (proposée par les passes 7 et 8, décidée par toi) : flux nommés au lancement (ci-dessus). Repris des
  ajustements de la passe 10 : règle WirePlumber ciblée (la ligne « binaire Discord » touchait ses appels : restreinte aux flux
  « Chromium ») ; aucune passe la nuit si `muteApps` est vide ; seuls les flux visés ou touchés sont suivis. Sans objet après
  la refonte : vieillissement des processus lus. Écartés : événement PipeWire en retard pris pour un geste sur un flux Discord
  (au pire, flux non rétabli jusqu'à sa fermeture, quelques secondes) ; configuration lue vide pendant l'écriture de
  `hosts/terrier.json` en pleine nuit.
- **Dernière revue** : seuls les flux « Chromium » sont visés, comme la règle WirePlumber (un programme lancé depuis une web app
  héritait de son `application.id` : Spotify ouvert par un lien aurait été coupé ; un flux Discord d'un autre nom aurait été
  coupé sans être protégé par la règle) ; passe relancée quand la liste des flux suivis change (flux devenu visé déjà prêt).
  Documentés : liens ouverts dans le profil de la web app ; lanceurs hors du dépôt (phase 11).
- Banc : 39/39 + son en cours sans trou (4 s, 0 ms de trou), rétabli à la main gardé (y compris après rechargement), rechargement
  à chaud pendant « ne pas déranger » (coupure gardée, rétablie à la fin), coupure manuelle de jour respectée.

## Cloche des notifications : clic droit = « ne pas déranger » (2026-10-27, ta demande)

- `modules/bar/Tray.qml` : clic gauche sur la cloche, carte des notifications (inchangé) ; clic droit, bascule « ne pas
  déranger » (comme l'interrupteur de la carte : à la main, l'horaire reprend à sa prochaine heure). Carte ouverte : elle le
  reste. `PreviewArea.qml` / `TrayButton.qml` : `panelButtons` (boutons qui ouvrent la carte, gauche et droit par défaut) et
  `otherPressed` ; les autres boutons de la barre sont inchangés.
- **À tester à la main** : clic droit sur la cloche (icône barrée, sons de Discord/WhatsApp coupés), puis de nouveau (rétablis) ;
  carte ouverte au survol ou épinglée : elle reste ouverte et son interrupteur suit.

## Web apps : liens ouverts dans le navigateur (2026-10-27, ta demande)

- WhatsApp et Discord (web apps Chromium, profil isolé `~/.local/share/ice/profiles/<app>`) : un lien ouvert dans un nouvel
  onglet ou une nouvelle fenêtre part dans le profil Chromium principal. Navigateur ouvert : un onglet de plus ; fermé : il démarre
  sur la page. Les sessions des web apps restent dans leur profil (pas de nouvelle connexion).
- `dotfiles/webapps/open-links/` : extension (MV3, identifiant fixe par sa clé publique) ; sur `onCreatedNavigationTarget` d'une
  fenêtre ordinaire (lien `target=_blank`, `window.open` puis adresse), envoie l'URL à l'hôte natif puis ferme l'onglet. Popups
  (`window.open` avec dimensions : connexion OAuth) et navigation dans la fenêtre de l'app : inchangées. Hôte absent : le lien
  reste dans la web app.
- `dotfiles/webapps/open-link` : hôte natif (Python), lance `chromium -- <url>` détaché, sans `PULSE_PROP_OVERRIDE` ni
  variables `CHROME_*` (sinon un navigateur démarré ainsi serait coupé pendant « ne pas déranger »).
- Posés hors du dépôt : `--load-extension=…/dotfiles/webapps/open-links` dans les deux lanceurs
  (`~/.local/share/applications/WebApp-{Whatsapp8699,DiscordWeb2996}.desktop`, sauvegardes `.bak-2026-10-27` d'origine) et le
  manifeste de l'hôte dans `NativeMessagingHosts/` de chaque profil. Sway lance Discord par `gtk-launch` : couvert.
- Banc (profil jetable, page de test pilotée par le protocole DevTools, `chromium` factice) : lien `_blank` et `window.open`
  puis adresse envoyés une fois chacun, environnement nettoyé ; popup et lien dans la fenêtre gardés ; navigateur lancé encore
  vivant après la fermeture de la web app.
- **À faire à la main** : relancer WhatsApp et Discord. **À tester** : un lien dans chacune, navigateur ouvert puis fermé.
- Testé par toi sur WhatsApp et Discord : liens ouverts dans le navigateur principal.
- **Phase 11** : lanceurs et manifeste de l'hôte versionnés comme modèles (`dotfiles/webapps/applications/`,
  `qs_desktop.open_link.json`) ; procédure complète d'installation (paquets, règle WirePlumber, lanceurs, hôte, `muteApps`) dans
  `deps/README.md`, « Web apps : ce que fait `install.sh` ». Elle remplace les notes phase 11 des deux sections précédentes.

## Web apps Word, Excel, PowerPoint, Notion : liens vers le navigateur (2026-10-27, ta demande)

- Même extension, chargée par les quatre lanceurs (sauvegardes `.bak-2026-10-27`) ; manifeste de l'hôte dans leurs profils.
  Pas de coupure de nuit pour elles (pas de sons de notification).
- Règle ajoutée : un lien qui reste dans les domaines de l'app d'origine (liste `SITES` : Microsoft 365 — `sharepoint.com`,
  `cloud.microsoft`, `office.com`… ; Notion) s'ouvre comme avant dans la web app (document Word ouvert depuis Word, page Notion
  en nouvel onglet) ; les autres partent au navigateur. Domaine d'origine lu sur le cadre principal de l'onglet source
  (`webNavigation.getFrame`, sans permission `tabs`). WhatsApp et Discord : inchangés (aucun groupe, tout part).
- Modèles des quatre lanceurs dans `dotfiles/webapps/applications/`, ouverts sur l'accueil de l'app (les adresses actuelles
  sont des documents SharePoint personnels) ; procédure d'installation complétée (`deps/README.md`, « Web apps »).
- Banc (profil jetable, sites simulés par un serveur HTTPS local et `--host-resolver-rules`) : 12/12 — gardés dans l'app :
  Notion → Notion (`target=_blank` et `window.open` puis adresse), SharePoint → Excel, SharePoint → SharePoint, popup ;
  envoyés une fois : Notion → site externe ou SharePoint, SharePoint → site externe ou Notion, Discord → Discord ou Notion.
- **À tester** : dans chaque app, un lien externe (navigateur principal) ; dans Word/Excel/PowerPoint, ouvrir un autre document
  depuis l'app (reste dans la web app) ; dans Notion, ctrl+clic sur une page (reste dans la web app).

## Fond d'écran : boucle de revue (2026-10-27, ta demande)

3 passes sur le fond d'écran et son utilitaire (`services/Wallpapers.qml`, `modules/wallpaper/`, bouton du panneau de réglages),
chaque point vérifié sur un Sway isolé à 3 écrans (même disposition, état à part, pointeur virtuel pour les clics). Arrêt : la passe 3
ne trouve plus que du négligeable.
- **Écran noir au changement de fond** (~0,5–1 s, le temps du décodage) : l'ancien fond reste affiché jusqu'au nouveau
  (`retainWhileLoading` ; panoramas : le précédent gardé jusqu'à la mesure du suivant). Mesuré : 0 image noire entre deux images ou
  deux panoramas (avant : 1 à 2). Reste un court vide en passant d'une image à un panorama ou l'inverse.
- **Panorama** : taille du fichier lue une seule fois dans le service (avant : l'image entière décodée par chaque écran, et encore
  3 fois au verrouillage). Pic mémoire d'un changement de panorama : +95–114 Mo au lieu de +170–233 Mo.
- **Utilitaire ouvert depuis le panneau de réglages** : sur l'écran du panneau (avant : sur l'écran focalisé, souvent un autre —
  reproduit : focus à gauche, clic sur l'engrenage central → utilitaire à gauche). Raccourci IPC : écran focalisé, inchangé.
- Fond actuel entouré de vert même si un écran débranché a sa propre image ; onglet vide : « No wallpapers in ~/…/simple ».
- Vérifié aussi : panorama et triptyque recalculés à l'extinction puis au retour d'un écran ; onglet Triptychs disparu → Images ;
  écran de verrouillage avec un panorama.
- Négligeable, laissé tel quel : deux écrans de même description (sans numéro de série) partagent leur image propre (limite commune
  à toute la config par machine) ; `qs ipc call wallpaper set` ne vérifie pas le type (outil de test).
- **Cache de vignettes** (ton accord, même jour) : les vignettes mettaient 2 à 2,7 s à apparaître à la première ouverture après un
  démarrage (originaux de 1 à 13 Mo décodés un par un). Chaque vignette décodée depuis l'original est enregistrée telle qu'affichée
  (`grabToImage`, PNG) dans `~/.cache/quickshell/by-shell/desktop/wallpaper-thumbs/`, nommée d'après le chemin, la date de l'image et
  la taille ; ensuite lue à la place de l'original. Vignettes d'images supprimées ou modifiées effacées à la lecture du dossier (pas
  si le dossier est illisible). Banc (cache à part) : première ouverture après redémarrage complète dès la première capture
  (~0,5 s, limite de mesure ; avant : 2 à 2,7 s) ; vignettes en cache relues sans être réécrites ; images, panoramas, triptyques
  (une vignette par partie), écrans à l'échelle 1 et 1,5 ; vignette périmée effacée, fichier étranger au cache gardé.
- Tu as constaté l'accélération. Seconde boucle de revue sur le code du jour (4 passes, arrêt : la passe D ne trouve rien) :
  - A : les vignettes étaient réencodées et réécrites à chaque changement d'onglet (25/25 mesurées) → une seule fois ;
  - B : image remplacée sous le même nom pendant que Quickshell tourne : le cache mémoire de Qt (par adresse) resservait
    l'ancienne, enregistrée comme vignette de la nouvelle (reproduit sur un dossier de test) → vignettes hors de ce cache ;
  - C : conséquence de B, première session : une vignette recréée au défilement redécodait l'original alors que son fichier venait
    d'être écrit (6,5 s de processeur contre 4,7 s au retour de défilement) → relue depuis ce fichier (4,6 s).
  - Vérifié : aucune vignette vide (celles hors de la zone visible aussi) ; passage panorama → image sans réapparition d'un ancien
    fond ; image supprimée → vignette effacée.
- **À tester** : engrenage puis bouton fond d'écran avec le focus sur un autre écran (utilitaire sur l'écran central) ; cliquer
  plusieurs fonds à la suite (plus d'écran noir).

## Revues restantes avant la phase 9 (2026-10-27, ta demande)

Audit de couverture (boucles de `PROGRESS.md` croisées avec git, fichier par fichier) : les boucles `/code-review` portaient
sur des plages de commits, un fichier inchangé dans la plage n'y était que du contexte ; la revue globale du 2026-10-16
(3 passes, 10 constats chacune) n'a pas convergé. Code jamais passé dans une boucle, par ordre de risque :

1. **Disques** : `services/Disks.qml`, `modules/bar/DisksPanel.qml` (montage, LUKS, éjection). **Fait** (ci-dessous).
2. **Agent polkit** : `modules/polkit/PolkitDialog.qml` (seulement la boucle commune de la phase 8b). **Fait** (ci-dessous).
3. **Web apps** : `dotfiles/webapps/open-link`, `open-links/background.js`, règle WirePlumber. **Fait** (ci-dessous).
4. **Tray StatusNotifier** : `TrayMenu.qml`, `TrayIcon.qml`, partie applications de `Tray.qml`. **Fait** (ci-dessous).
5. **Statistiques système** : `services/Monitor.qml`, `modules/monitor/`. **Fait** (ci-dessous).
6. **Modules système de la barre** (phase 4) : `Gpu`, `SystemStats`, `Updates`, `Battery`, `Brightness`, `Displays`,
   `Profiles` et leurs widgets (`Cpu`, `Memory`, `GpuModule`, `InfoModule`, `NetworkModule`, `UpdatesModule`,
   `BatteryModule`, `Backlight`, `WheelSteps`, `RichLabel`), contenu de `CalendarPopup`. **Fait** (ci-dessous ; `Battery`,
   `Brightness`, `BatteryModule`, `Backlight` non revus : matériel absent, à reprendre sur le laptop).
7. **OSD et widgets partagés** : `Osd.qml`, `VolumeSlider`, `PercentLabel`, `MixerButton`, `OutsideClick`, `PanelButton`,
   `PanelSection`. **Fait** (ci-dessous).
8. **Scripts** : `takeover.sh`, `dev.sh`, `shot.sh`, `crop.sh`. **Fait** (ci-dessous).
9. **Ajouts postérieurs à leur boucle** : clic droit sur la cloche (`Tray`, `PreviewArea`, `TrayButton`), fermeture auto du
   menu et `EmptyState`, titre de la carte des réglages, largeurs fixes de `NetworkModule`, `shell.qml`. **Fait** (ci-dessous).

Hors périmètre : chemins propres à Hyprland (phase 9), `Theme.qml` (valeurs). Méthode : `/code-review high` sur les fichiers
entiers, chaque point vérifié sur banc isolé avant correction, un commit par passe, arrêt quand une passe ne trouve plus que
du négligeable. Bancs et agents en lecture seule pour tes vrais disques et ta VPN.

### Disques : revue en boucle (2026-10-27, ta demande)

9 passes de `/code-review high` sur les fichiers entiers (`2a1b753` … `7f70372`), chaque point vérifié avant correction sur un
banc : images de test (ext4 « Clé », LUKS « Coffre »), instance Quickshell à part avec faux `busctl` / `udisksctl` / `notify-send`,
puis Sway isolé avec clavier et pointeur virtuels (`luks-bench.sh`, scratchpad). Arrêt : la passe 9 ne trouve plus rien de sérieux.
- **Chemins accentués** : les octets d'UDisks2 étaient lus en Latin-1 (`/run/media/…/ClÃ©`) : affichage et « Open » faux. UTF-8.
- **Clé USB LUKS réelle** : une fois déverrouillé, le volume disparaissait du panneau (UDisks2 dit « système » tout volume dm sans
  disque ; invisible sur les images de test). Jugé sur son volume chiffré, comme udiskie. Reproduit en faisant passer l'image pour
  une clé USB.
- **Démontage annulé au rechargement** : `Disks` n'était créé qu'au premier affichage du tray, son état n'était donc pas repris,
  et tout était remonté. Créé au démarrage (`shell.qml`), état gardé (`PersistentProperties`). Le montage au démarrage de
  Quickshell reste, comme udiskie.
- Robustesse : commande qui ne démarre pas (notification au lieu du silence) ; première lecture ratée réessayée, de plus en plus
  rarement ; relecture qui échoue réessayée ; signaux des tâches d'UDisks2 ignorés et relectures sans changement sans effet ;
  ordre fixe et numérique (`sdb2` avant `sdb10`) ; boutons atténués pendant une action (double clic, montage automatique en
  cours) ; image « autoclear » détachée sans faux « Job failed » ; lecteur qui ne s'éteint pas (DVD) éjecté (`Drive.Eject`) ;
  clé remplacée par une autre sous le même nom reconnue comme nouvelle (chemin + étiquette + taille) ; parent chiffré ignoré
  (`HintIgnore`) : volume déchiffré ignoré aussi ; déverrouillage réservé à LUKS (`--key-file`).
- **Phrase de passe au branchement** (ton choix du 2026-10-27, comme la fenêtre d'udiskie) : file unique `Disks.pending`,
  affichée par le panneau des disques ouvert, sinon ouvert sous le tray de l'écran focalisé (ou principal), champ prêt. Mauvaise
  phrase : champ rouge et vidé ; autre échec (polkit, appareil occupé) : demande abandonnée, la notification dit pourquoi ;
  réussite : disque suivant, puis panneau refermé s'il s'était ouvert tout seul. Attend la fermeture d'un autre popup épinglé ou
  de l'outil de capture (saisie en cours qui serait perdue) ; reprise sur un autre écran si le sien disparaît ; pas de fermeture
  automatique pendant la demande ; Échap ou clic à côté abandonnent les demandes (les boutons Unlock restent).
- Dépendances : `libnotify` et `util-linux` (`setpriv`) ajoutés à la ligne des disques de `deps/README.md`.
- BACKLOG : VeraCrypt / BitLocker (udisksctl ne lit une phrase qu'au terminal) ; images en boucle de root (`SetupByUID`).
- Laissés (choix ou négligeables) : montage automatique au démarrage de Quickshell (udiskie aussi) ; pas de demande au
  démarrage ; changement d'étiquette d'un volume = retiré puis ajouté ; séquence coupée par un rechargement à chaud (dev).
- **À tester à la main** : vraie clé USB (avec un nom accentué si possible) : montage, « Open », Eject ; vraie clé LUKS :
  demande au branchement, mauvaise puis bonne phrase, Lock, Eject.
- Vu en passant, hors périmètre : avertissement `services/Bluez.qml[31:5]: Unable to assign [undefined] to bool` à chaque
  rechargement à chaud (propriété `busy`) — à regarder avec le module Bluetooth.

### Agent polkit : revue en boucle (2026-10-27 / 28, ta demande)

6 passes de `/code-review high` sur les fichiers entiers (`055007b` … `5955b39`), chaque point vérifié sur un banc : copie du dépôt
dans un Sway isolé, **vrai polkitd** (`pkexec true`), clavier et pointeur virtuels, ton instance arrêtée le temps de chaque scénario
(un seul agent par session) puis relancée ; 16 scénarios rejoués après chaque passe. Arrêt : la passe 6 ne trouve qu'un défaut
d'une image (capture en cours au verrouillage).
- **Plus d'agent après un plantage** : vu dans ton journal (plantage connu de Quickshell à 18 h 23, relancé seul) : l'instance
  relancée trouvait l'ancienne encore enregistrée (coredump en cours) et Quickshell ne réessaie jamais : plus aucun agent dans ta
  session (vérifié par une sonde D-Bus). Agent recréé de lui-même (5 s, puis de plus en plus rarement).
- **Clavier volé à l'écran de verrouillage** : une fenêtre à clavier exclusif ouverte pendant le verrouillage (dialogue polkit,
  lanceur par IPC, demande de phrase d'un disque, outil de capture) prenait la frappe : le mot de passe tapé pour déverrouiller
  partait ailleurs (vérifié sur l'ancien code avec le lanceur). `Session.lockActive` (dès la demande) : aucun popup ne s'ouvre, ceux
  qui sont ouverts se ferment en gardant ce qui était en cours (demande polkit, phrase de passe), rouverts au déverrouillage.
- **Demande gardée quand ce n'est pas toi qui fermes** : écran retiré (la surface fermée par le compositeur n'émettait aucun
  `closing` : demande invisible, Échap sans effet), verrouillage, rechargement de la config (demande en cours plus affichée).
- **Deux demandes à la fois** : défaut de Quickshell 0.3.2 (aussi sur `master`) : la seconde remplace la première, qui restait
  sans réponse (son application attendait indéfiniment). Annulée une fois l'agent libre ; limites restantes et signalement amont :
  BACKLOG.
- Sécurité et détails : message en texte brut (du HTML glissé dans la commande de `pkexec` s'affichait) ; champ vide jamais
  envoyé ; mot de passe effacé à la fermeture ; Échap pendant la vérification ; refus gardé à la réouverture, effacé pour une
  nouvelle demande ; identité affichée si ce n'est pas toi (plusieurs administrateurs) ; agent dans un service (`services/Polkit.qml`).
- **faillock** : chaque demande annulée compte comme un échec (programme d'aide de polkit, comme avec polkit-gnome ; `deny = 10`
  sur 15 min ici). Les bancs ont ainsi bloqué ton compte vers 20 h 29 (10 annulations en 2 min) : compteur remis à zéro à 20 h 37
  (`faillock --reset`, ton fichier) puis après chaque scénario ; aucun échec restant.
- **Incident pendant les bancs** : de 20 h 27 à 20 h 37 environ, ton instance relancée par le banc était branchée sur le socket du
  Sway isolé (espaces de travail figés) ; relancée sur le tien, banc corrigé, vérifié à chaque relance depuis.
- BACKLOG : polkitd redémarré (agent perdu, comme polkit-gnome) ; signalement à Quickshell (file d'attente, nouvel essai).
- Laissés (choix ou négligeables) : pas de choix d'identité ; dialogue polkit prioritaire sur les autres popups et la capture ;
  nouvel essai toutes les 5 min tant que polkit-gnome tourne (jusqu'à la phase 10) ; réponse vide jamais envoyée.
- **À tester à la main** : une vraie demande (Nemo, `pkexec true`) : mot de passe faux puis bon ; verrouiller (`Super+…`) avec
  une demande ouverte puis déverrouiller : la demande revient ; disque LUKS branché puis verrouillage : la demande de phrase
  revient au déverrouillage.

### Web apps : revue en boucle (2026-10-28, ta demande)

3 passes de `/code-review high` (`988bf91`, `528a5ed`, `c33ce6e`) sur les fichiers entiers (extension, hôte, manifeste,
modèles de lanceurs, règle WirePlumber, procédure d'installation), chaque point vérifié sur un banc : Chromium jetable dans un
Sway isolé (rien sur ton bureau), sites simulés en HTTPS local, hôte réel avec un `chromium` factice ; règle WirePlumber
testée sur ton WirePlumber (redémarré, ton
accord).
- **Onglet fermé à tort** : un lien cliqué dans une fenêtre remplie par l'app elle-même (`window.open()` puis contenu écrit)
  partait au navigateur et la fenêtre se fermait (reproduit sur l'ancienne version) : onglet vide suivi 10 s seulement.
- **Lien perdu** : réponse « refusé » de l'hôte, onglet fermé quand même : il reste maintenant dans la web app. Page source lue
  aussitôt (une popup de connexion qui se ferme faisait sortir un document Microsoft) ; `1drv.ms`, `office365.com` ajoutés.
- **Règle WirePlumber** : un programme lancé depuis WhatsApp ou Discord (lecteur vidéo…) héritait de leur identifiant et
  perdait la mémoire de son volume ; limitée aux flux « Chromium », comme `Audio.qml`. Copie installée mise à jour.
- **Modèles de lanceurs** : `MimeType=text/html…` retiré (les web apps se déclaraient lecteurs HTML et ignoraient le fichier) ;
  `StartupWMClass` = app_id réel (sous Wayland, Chromium ignore `--class` : l'app_id vient de l'adresse de départ). Phase 10 :
  la règle Sway qui place Discord sur l'espace 5 devra viser `chrome-discord.com__channels_@me-Default` (`deps/README.md`).
- Procédure d'installation (`deps/README.md`) : fichier identique non réécrit, première sauvegarde gardée, copies générées
  retirées par `--uninstall`, WirePlumber redémarré seulement si la règle change, chemins à caractères spéciaux refusés.
- **Limite (BACKLOG)** : un lien envoyé au navigateur est aussi demandé par la web app (l'extension ne peut pas l'empêcher :
  même en fermant l'onglet aussitôt, 2 liens sur 5 partaient). Un lien à usage unique peut être consommé par la web app.
- Laissés : adresse posée plus de 10 s après `window.open()` (reste dans la web app) ; onglet nommé réutilisé ; `xdg-open`
  depuis une web app qui démarre le navigateur principal (fermé) avec l'identifiant de la web app (coupé la nuit) ; ids en dur
  dans la règle WirePlumber (phase 11) ; formulaire POST ouvert dans un nouvel onglet (rouvert en GET dans le navigateur).
- Arrêt : passe 3 sans défaut bloquant (deux détails de documentation corrigés). Banc : 15 cas de domaines et popups, plus
  onglet vide, refus de l'hôte, requête en double.
- **À faire** : relancer les six web apps (nouvelle extension). **À tester** : un lien externe dans WhatsApp, Discord, Word et
  Notion (navigateur principal) ; un document ouvert depuis Word (reste dans l'app).

### Tray : revue en boucle et cartes des applications (2026-10-28, ta demande)

Revue en deux temps, chaque point vérifié sur un banc (Sway isolé, bus de session à part, application StatusNotifier factice
pilotée — mode libayatana et menu de Steam relevé sur ta session —, fenêtres et sonde de pointeur ; rien sur ton bureau).
- **Plantage de Quickshell** (`fda1faf`) : clic droit sur Steam puis clic droit au même point pour fermer le menu = plantage à
  chaque fois (bogue de Qt 6.12 au coin du menu). Corrigé, puis le menu lui-même a disparu (ci-dessous).
- Passes 1 à 7 sur le menu copié de GTK (`fda1faf` … `b041843`) : clavier, sous-menus, rafraîchissement du menu à chaque
  ouverture (Steam n'était prévenu qu'à la première)… **Tangente reconnue** : beaucoup de cas sans rapport avec ton usage (tes
  seules applications : Steam ; Spotify, masqué tant qu'il est « Passive » ; NordVPN, masqué). Revue recentrée sur ton usage
  réel ensuite.
- **Revue centrée sur l'usage réel** (`f376093`) : clic gauche sur Steam sans effet (libayatana n'a pas d'Activate ; Waybar
  ouvrait le menu) ; menu de Steam fermé tout seul quand il le reconstruit ; focus volé au survol (jeu en plein écran) ; clic
  long sans effet.
- **Cartes des applications** (ta demande, `ae6c866` … `f6f7b71`) : le menu de Steam est une carte comme les autres
  (`AppMenuPanel.qml` : aperçu au survol, clic gauche ou droit, titre jaune, lignes des panneaux, séparateurs en traits de
  bordure — **à valider** —, largeur ajustée, centrée sous l'icône). L'ancien menu GTK et ses contournements sont supprimés
  (ta règle : pas de menu GTK, pas de rustine, Quickshell d'abord ; détour `busctl` pour ItemIsMenu retiré aussi).
- **Steam → son espace de travail** (ta demande) : après Store, Library, Community, Friends, Settings, Big Picture, SteamVR,
  sa fenêtre est affichée (pas pour un jeu récent ni « Exit Steam ») ; mesuré : 21 ms du clic au changement d'espace (1 s de
  trop à l'origine, supprimée) ; **pointeur laissé en place** (Sway : `mouse_warping` coupé pour ce seul focus, Deluge et les
  autres gardent le déplacement ; vérifié avec une sonde sur deux écrans, Steam en XWayland compris). Testé par toi : OK.
- **Surlignage des lignes rétabli dans toutes les cartes** (réseau, Wi-Fi, Bluetooth, disques, NordVPN, notifications,
  réglages) : un élément posé sur le cadre cachait le survol aux lignes.
- Revue finale (`f6f7b71`) : « Exit Steam » repéré comme dernière entrée (pas par son libellé anglais), clavier repris après
  une reconstruction du menu, largeur tirée de la mise en page des lignes. **Passe de confirmation : rien de sérieux** ;
  largeur arrondie au pixel, jeux récents repérés comme ce qui précède les trois groupes fixes de Steam (compte sans jeux
  récents : Store mène bien à l'espace 9). Arrêt de la boucle.
- Laissés : WhatsDesk (inventaire) perdrait l'Activate au clic gauche, il ne tourne plus (web app WhatsApp) ; une fenêtre
  Steam éphémère ouverte dans les 3 s après une entrée recevrait le focus ; une ligne « No matching node » par clic dans le
  journal (une des deux sélections app_id / classe ne trouve rien, attendu).
- **Pour le bloc 6** : calendrier épinglé fermé par Échap, pointeur sur l'horloge : la barre garde le clavier ;
  `CalendarPopup.popupHovered` réunit quatre survols inutilement. **Pour la phase 10** : `mouse_warping` rétabli à `output`
  (défaut de Sway, ta config ne le change pas) : à reprendre de `dotfiles/sway`.
- **À tester à la main** : survol d'une ligne dans tes cartes (surlignage) ; séparateurs de la carte Steam.

### Statistiques système : revue en boucle (2026-11-02, ta demande)

Trois passes, vérifiées sur un banc isolé (Sway headless, pointeur virtuel pour les vrais clics, sonde IPC temporaire jamais
committée, processus témoins : aucun de tes processus n'a reçu de signal).
- **Colonne CPU fausse** (`aa825c5`) : avec `objectProp`, `ScriptModel` garde l'ancien objet d'une ligne qui change de rang
  (reproduit sur un cas minimal, Quickshell 0.3.2) ; le modèle contient maintenant les PID, chaque ligne lit ses valeurs par PID.
  Tailscale a le même schéma, sans correction : une erreur éventuelle disparaît au relevé suivant.
- **Passe 1** (`2864d7b`) : un clic sur CPU, mémoire ou GPU referme enfin le panneau (fermé à l'appui, rouvert au relâchement ;
  reproduit) et l'ouvre sur l'écran du module ; vrais chiffres en 0,3 s au lieu de 0 % pendant 2,6 s ; égalités stables ; retour en
  haut ou sur le processus choisi ; sélection levée si la recherche le masque ; jauges de même longueur.
- **Passe 2** (`61005f2`) : choisir un autre processus garde l'ordre ; End et Force relèvent 300 ms après (parti : retiré ;
  survivant : reste choisi) ; valeurs du GPU séparées de `pmon` ; shell de relevé retiré de la liste.
- **Passe 3** : le relevé à 300 ms remet les minuteries à zéro (plus de mesure sur quelques millisecondes) ; zombies masqués ; GPU
  relevé après la liste, donc `nvidia-smi` n'y figure pas ; marge perdue des jauges de cœurs. Commentaire d'origine faux : `pmon`
  répond en 30 ms, pas en 1 s (chronométré), ce qui a retiré deux ajouts devenus inutiles. Arrêt de la boucle ; ces dernières
  corrections n'ont pas repassé de revue, seulement le banc.
- **Laissés (négligeables)** : débordement de 2 px pour un disque entre 1000 et 1024 GiB utilisés ; processus qui change de nom et
  sort du filtre sans perdre la sélection ; première ouverture de la session recomposée à l'arrivée des relevés ; texte d'une ligne
  sans marge dans le surlignage.
- **À tester à la main** : ouvrir et fermer le panneau en cliquant sur les trois modules, sur chacun de tes écrans ; longueur des
  barres RAM et swap (raccourcies par la largeur réservée au texte).

### Modules système de la barre : revue (2026-11-02, ta demande)

Défauts reproduits d'abord sur le banc (faux `nvidia-smi` et `checkupdates`, pointeur et clavier virtuels), puis re-testés corrigés.
- **Mises à jour** : un échec de `checkupdates` (réseau) remettait le compteur à 0 pour 2 h 23. Dernier compte gardé, nouvel essai
  dans 5 min (prouvé avec un intervalle raccourci sur le banc).
- **GPU** : un seul échec de `nvidia-smi` masquait le module jusqu'au redémarrage du shell (ta carte n'a aucun capteur du noyau).
  Il reste interrogé et le module revient ; le panneau de statistiques ne prend plus le message d'erreur pour un nom de carte.
- **Calendrier** : Échap ou fermeture, pointeur sur l'horloge : plus de retour en aperçu, la barre rend le clavier. Aperçu au bout
  de 150 ms (comme le tray), jamais par-dessus un panneau épinglé. 10 px de marge au bord de l'écran (`anchor.onAnchoring`).
  `popupHovered` réduit à un seul survol (fermeture automatique toujours correcte, vérifié).
- **Barre** : CPU réel 0,3 s après le démarrage (0 % pendant 5 s avant) ; icône montante du réseau à sa place (environ 2 px).
- **Limites connues, écrites dans `CalendarPopup.qml`** (pas d'API pour redonner le clavier à la barre) : après un clic dans le
  calendrier, Échap et ←/→ ne répondent plus (souris et délai restent) ; idem si on rouvre d'un clic sans avoir quitté l'horloge.
- **Non résolu** : avertissement `Bluez.qml[31:5]` (« Unable to assign [undefined] to bool », 2 fois au démarrage) : hypothèse du
  chaînage optionnel testée, fausse ; sans effet connu. `Tailscale.qml[172:9]` n'apparaît plus dans le journal actuel.
- **Banc** : `grim` sur tes vrais écrans bloque quand ils sont en veille (aucune image n'arrive) ; lire `power` dans
  `swaymsg -t get_outputs` avant. Pointeur virtuel : garder le client vivant, sinon le survol tombe à sa sortie.
- **À tester à la main** : Échap sur le calendrier pointeur sur l'horloge (le clavier revient à ta fenêtre) ; passage rapide sur
  l'horloge sans ouverture ; DP-1 et DP-3 : marge du calendrier au bord droit. Profils d'énergie : `power-profiles-daemon` n'est pas
  installé, boutons masqués normalement.

### OSD et widgets partagés : revue (2026-11-02, ta demande)

Vérifié sur banc (harnais avec vrais événements, deux écrans virtuels pour l'OSD). Banc sans PipeWire : le chemin avec un vrai
périphérique reste à tester à la main.
- **Boutons des panneaux** : une touche maintenue déclenchait le bouton en rafale (25 fois en 1,5 s, Mute basculait au hasard) : une
  seule action. Clic sur un bouton désactivé : n'active plus la ligne dessous.
- **Curseur de volume** : au-dessus de 100 % (réglé ailleurs), un cran vers le haut faisait retomber à 100 % ; ne bouge plus vers le
  haut, descend par pas de 5 (comme `Audio.step`).
- **Panneau audio** : bouton Mute / Unmute à largeur fixe (88 px) : le curseur ne bouge plus quand on coupe le son.
- **OSD** : plus d'annonce « micro actif, 0 % » sans périphérique ; reste sur son écran si le focus part pendant son affichage.
- Passe de confirmation du bloc 6 : rien de nouveau.
- **À tester à la main** : touches volume et micro (OSD) ; Mute dans le panneau audio ; molette à plus de 100 %.

### Scripts et ajouts récents : revue (2026-11-02, ta demande)

Scripts testés sur le banc (`takeover.sh` compris, garde-fou : abandon si un outil réel tourne, son `pgrep` vise tout l'utilisateur).
- **`dev.sh`** : répertoire courant = dossier personnel (les applications lancées depuis le shell démarraient dans le dépôt), variables
  du terminal retirées, verrou contre deux relances rapprochées (deux instances possibles, donc deux barres), échec de lecture de
  l'environnement systemd sans conséquence (arrêtait le script en silence). **Effet à la prochaine relance** de l'instance.
- **`takeover.sh`** : instance qui ne démarre pas : retour automatique à l'ancien bureau (prouvé avec une config cassée) ; Waybar
  n'est plus relancée en double au `restore` (`exec_always` de ta config s'en charge) ; Dunst bloqué tant que Quickshell a la main
  (`systemctl --user mask --runtime`, sans fichier de config touché, annulé par `restore`) : une notification pendant une relance ou
  après un plantage l'aurait réactivé. **Le blocage n'est pas testé** (il faudrait libérer le nom D-Bus de ta session), **et ne
  s'applique pas à la session en cours** : il prend effet au prochain `takeover.sh`.
- **Volume au-dessus de 100 %** : correction du bloc 7 incomplète, les curseurs de la barre et des réglages passaient par
  `Audio.setVolume`, qui plafonnait encore à 100 % ; corrigé (lecture et calcul seulement, banc sans PipeWire).
- **Touche maintenue** : même correction sur `PanelRow` et `PanelSwitch` (une ligne « Connect automatically » basculait en rafale).
  Relu, non rejoué pour ces deux éléments.
- **Sans défaut** : `PanelRow` relu sur ses 19 usages (lignes toujours cliquables), clic droit sur la cloche (lu), `EmptyState`,
  `shell.qml`, `shot.sh`, `crop.sh`, largeurs de `NetworkModule` (4000 débits tirés au sort, toujours 129 px).
- **Laissés** : `$mod+Ctrl+w` avec une config cassée : l'ancienne instance est tuée et l'erreur ne s'affiche nulle part (cas de
  développement) ; menu d'applications : après avoir effacé la recherche, pointeur déjà sorti, il se ferme au bout de 2 s sans touche.
- **Passes de confirmation** : blocs 6 et 7 relus ; les toutes dernières corrections ci-dessus n'ont pas repassé de revue.

## Phase 9 — Parité Hyprland : validée (2026-11-03 ; points 2 à 5 ci-dessous reportés)

Hyprland 0.57.0, Quickshell 0.3.2. Plan validé par toi : `~/.claude/plans/il-faut-peut-etre-que-imperative-flame.md`.

Tes décisions : **molette active partout** (écart à Waybar, qui la coupait sous Hyprland) ; banc lancé librement ; prise en main tôt.
Décidé par moi : **pas de `HyprlandFocusGrab`** (`OutsideClick` commun aux deux compositeurs, validé par de vrais clics).

Produit :
- `scripts/test-outputs.sh [sway|hyprland]` : mêmes 36 contrôles sur les deux. Hyprland imbriqué dans ta session (sous Nvidia, le mode headless n'alloue rien) : une fenêtre s'ouvre le temps du test. Nouveaux scénarios : fenêtre envoyée avec focus (`$mod+Ctrl+N`), aucun écran actif, écran focalisé débranché.
- `scripts/takeover.sh` sur les deux compositeurs. `restore` testé à l'aller-retour.
- `Compositor` : HDR et VRR Hyprland (`hardwareDetails`, `hl.monitor`, `misc.vrr`), reposés sur `configreloaded` ; `FALLBACK` et moniteur non relu ignorés ; branches « config classique » retirées.

Bogues trouvés et corrigés :
- **Vue perdue au rallumage d'un écran** (Hyprland) : Hyprland ramène les espaces avant la relecture des moniteurs, l'état transitoire était mémorisé, focus compris. Corrigé par `monitoradded` / `monitorremoved`.
- **Écran rallumé jamais vu** (Hyprland, 3 écrans rallumés coup sur coup, cas du réveil) : sans barre jusqu'à l'événement d'écran suivant. Corrigé par une relecture après la dernière d'une rafale. Relecture perdue si une autre est en cours : déduit, code de Quickshell non lu.
- Contre-épreuve de ces deux corrections, sur une copie : sans elles, 6 passages sur 6 échouent avec ces deux symptômes ; avec, 13 sur 13 à 36 OK.
- **`$mod+d` sans effet avant la première ouverture des réglages** (Sway aussi) : `Displays` n'était créé qu'à sa première lecture. Ajouté aux services de `shell.qml`.
- **udiskie en double après `restore` puis prise en main** (Sway aussi) : relancé par `python …`, il changeait de nom de processus. Commande enregistrée sans l'interpréteur.
- Dans le test : `hl.monitor` fusionne les champs, `disabled = true` restait posé et un scénario passait à tort ; changements d'écran appliqués après la réponse d'Hyprland : le test attend l'état réel ; **banc infidèle à ton bureau** : sans `no_warps`, le pointeur suivait chaque focus du placement et `follow_mouse` rendait le focus au dernier écran visé (échecs aléatoires). Le test a désormais `no_warps` et déplace le pointeur comme un vrai geste.

Soldés, renvois « phase 9 » du journal : conversion taille physique → logique et description (identiques à Sway) ; répartition et placement ; `moveworkspacev2` ; bouche-trou et focus ; moniteur non lu ; événement `urgent` (adresse sans `0x`, filtre `appId`) et focus : parcours lien → Chromium jetable sur banc, avec et sans IPC, autre application ; capture (fenêtres `hyprctl clients`, zone) ; `reload` : aucun replacement, `hyprland.start` non rejoué (donc ni nordvpn ni applications).

Vérifié sur banc seulement : répartition dynamique à 1, 2, 4 et 5 écrans (écrans virtuels sans description). Vérifié sur ta session : barres, répartition `DP-2=1-3, DP-1=4-6, DP-3=7-9`, VRR aller-retour et à travers `reload`, règle `desc:`, panneau de réglages, lanceur, capture, notification critique, prise en main.

Écarts acceptés : molette (ci-dessus) ; modules du tray et engrenage (tes décisions de phases 5 et 8).
Écart à trancher en phase 10 : fondu des couches hérité de tes animations `layers*` (`BACKLOG.md`).
Limite signalée : mémoire libérée réutilisée dans l'IPC Hyprland de Quickshell ou Qt, sans effet observé hors `junk:free` (`BACKLOG.md`).

Deuxième passe, sans toi (2026-11-02, ta demande) : Hyprland imbriqué réglé comme ta config, pointeur et clavier virtuels (`pywayland`, outil hors dépôt), application factice du tray.
- Validés par de vrais clics et touches : espaces des 3 barres et molette ; panneaux fermés par clic à côté, sur une barre, **sur un autre écran**, Échap, focus rendu (`HyprlandFocusGrab` inutile, écarté) ; lanceur (recherche, Entrée lance, Échap) ; calendrier (survol, épinglage) ; tray (gauche, droit, milieu, molette, clavier, entrée de menu) ; chemin de la carte Steam (espace masqué affiché, pointeur immobile) ; notifications (boutons d'action, clic corps et milieu, pause au survol, remplacement, critique, repli d'écran, cloche) ; capture (zone à la souris, fenêtre au clic) ; verrouillage sur tous les écrans, clavier capté, une tentative erronée refusée ; veille, inhibition « Keep Screen On », `hyprctl reload` écrans éteints ; `hl.dsp.exit`.
- **Bogue majeur corrigé : réveil des écrans.** `hl.dsp.dpms({ mode = … })` bascule au lieu d'appliquer (l'argument est `action`) : le mouvement de souris rallumait les écrans et le « on » de Quickshell les rééteignait. Ton `hypridle.conf` écrit aussi `mode` : piste pour le « bogue » que le délai de 3 s du Dell contournait. Avant et après : rallumage bloqué 6 s (délai du banc), puis 0,04 s.
- **Bogue corrigé : captures agrandies et floues en scale 1.5** (450 px sortis en 675) : `grabToImage` multiplie sa taille cible par l'échelle. Identique à `grim` sur banc, en scale 1.5 et 1. Sous Sway : même code, non vérifié (ce banc ne produit aucune capture).
- Curseur absent de l'image : validé sur ton écran réel (curseur matériel). Visible sur le banc (curseur logiciel) : cas d'une machine sans curseur matériel, `BACKLOG.md`.
- Non cliquée exprès : rangée Logout / Reboot / Power du panneau, le banc lancerait une vraie action.
- Trace : une tentative de mot de passe erronée dans `faillock` pour ton compte (effacée à ta prochaine connexion réussie).

Tes tests (2026-11-03) : HDR actif sur les LG, aller-retour bon, mais **terne par rapport à Sway** → blanc SDR passé de 80 (défaut d'Hyprland) à 203 nits : plus lumineux, validé par toi ; lien de web app : bon ; verrouillage, déverrouillage, polkit (`pkexec true`) : bons ; veille d'écran : bonne, **rallumage plus lent que sous Sway** → essai : `fadeDpms` coupé en direct (`hyprctl eval`, annulé par un `reload`) ; câble débranché et rebranché : espaces réorganisés ; veille du PC : non configurée chez toi, à voir sur le laptop.

Validé aussi par toi (2026-11-03) : carte Steam (entrée du tray, fenêtre et espace affichés).

Revue en boucle du code Hyprland (2026-11-03, ta demande, 9 passes : 2 à la main puis `/code-review high` sur les fichiers entiers ; chaque correction vérifiée sur Hyprland imbriqué, contre-épreuve sur l'ancien code ; `test-outputs.sh` 36/36 sous Hyprland et Sway). Arrêt à la passe 9 : plus que du négligeable ou de l'hypothétique.
- Capture : fenêtre de l'espace spécial ouvert (`$mod+H`) ; empilement réel (dialogue sur une fenêtre agrandie `$mod+TAB` : avant, toute la fenêtre agrandie était prise ; flottante et plein écran selon le focus ; flottantes qui se chevauchent) ; zone copiée au pixel près même à coordonnées fractionnaires en scale 1.5.
- HDR / VRR : arrêt du HDR = retour au mode d'avant (préréglage, 10 bits si ta config les donne comme sous Sway, blanc SDR) ; activés seulement, reposés après `reload`, y compris après une relance du shell ; arrêt aussi sur un LG éteint entre-temps ; état tenu en un seul endroit.
- `takeover.sh` : un outil qui se termine pendant la boucle ne peut plus l'arrêter à mi-course (Dunst bloqué, pas de barre).
- Laissés, négligeables pour ton usage : préréglages HDR autres que `hdr`, double appui sur `$mod+d` en moins de 0,5 s, refus partiel du HDR par Hyprland, fenêtres épinglées, échelles à largeur non entière, raccourcis de la prise en main remis par le `reload` du réveil (temporaire). Hors parité, dans `BACKLOG.md` : noms de capture à la seconde, VRAM de la découpe, `gdbus monitor` de la veille non relancé.

**Reste à vérifier (noté le 2026-11-03, ta demande) — points 2 à 5 reportés à plus tard (2026-11-03 : pas vérifiables maintenant, ne bloquent pas la phase 10) :**
1. ~~Rallumage après la veille d'écran~~ **validé par toi (2026-11-03)** : avec l'animation `fadeDpms` coupée en direct par moi (toujours coupée au réveil, vérifié avec `hyprctl animations`), le rallumage est bon. **Phase 10** : ajouter `hl.animation({ leaf = "fadeDpms", enabled = false })` à côté des autres animations (`lua/looknfeel.lua` aujourd'hui), sinon le `fade` dont elle hérite revient au prochain démarrage.
2. Prochaine session Sway (change de session, donc hors session de code) : une capture sur un LG (`Print`), nette et à la bonne taille (correctif d'échelle non vérifié sous Sway).
3. Notification Discord : la prochaine fois qu'une arrive d'elle-même, clic dessus → la web app Discord s'affiche, son espace avec. Même mécanisme que le lien de web app, déjà validé.
4. Prochaine ouverture de session Hyprland : les web apps Discord et WhatsApp démarrent et vont sur l'espace 5.
5. Laptop : veille du PC et réveil (non configurée sur ce desktop), plus la liste « Laptop » plus haut.

~~Attention, jusqu'à la phase 10 : `hyprctl reload` remet les raccourcis d'origine~~ : sans objet depuis la bascule (raccourcis dans `dotfiles/hypr`).

## Phase 10 — Bascule : faite, en attente de tes tests à la main (2026-11-03)

Sur `master` (ta règle), pas sur une branche dédiée comme le prévoyait `CLAUDE.md`.

Tes décisions (2026-11-03) : Dunst ne doit plus être utilisé du tout (masqué durablement, paquet gardé) ; `$mod+u` = dernier pays
utilisé ; fondu des panneaux gardé sous Hyprland (comme Rofi et Waybar) ; `$mod+N` et `$mod+Ctrl+N` par `qs ipc` (~45 ms de plus,
repli natif).

Décidé par moi :
- lancement par `scripts/desktop.sh` plutôt que par un service systemd (`ARCHITECTURE.md` § 11.2) ;
- fenêtre « config rechargée » gardée ;
- même jeu de raccourcis sur les deux compositeurs : touches média ajoutées sous Sway (elles existaient sous Hyprland), `$mod+Escape` et `$mod+d` ajoutés sous Hyprland (déjà utilisés en prise en main).

Fait :
- **Configs dans le dépôt** :
  - `dotfiles/sway/config` + `hosts/terrier.conf` ;
  - `dotfiles/hypr/hyprland.lua` + `lua/` + `hosts/terrier.lua` ;
  - reprises de tes configs en l'état, changements non commités du 2026-11-03 compris ;
  - liens `~/.config/sway` et `~/.config/hypr` vers le dépôt ;
  - anciennes configs dans `~/.config/sway.bak-2026-11-03/` et `~/.config/hypr.bak-2026-11-03/` ;
  - retour arrière : `docs/ROLLBACK.md`.
- **Partie machine** (`hosts/<hostname>`, choisie par `/etc/hostname`, absente = ignorée, vérifié pour les deux compositeurs) :
  - écrans par description ;
  - renvoi des espaces 7 et 8 vers l'écran central (par description) ;
  - `default_monitor` ;
  - sidewinder, OpenRGB, openrazer ;
  - montage `gio` de Sway.
- **Retirés** :
  - de l'autostart : Waybar, Dunst, Rofi, swaybg, swayidle et hypridle, polkit-gnome, nm-applet, blueman, udiskie ;
  - des raccourcis : hyprshot, grim/slurp, pactl/wpctl, brightnessctl, playerctl ;
  - `workspace N output …`, règles `persistent`, choix des espaces au démarrage ;
  - la ligne `nordvpn login --token …` de Sway (secret : jamais dans le dépôt ; ton compte reste connecté, comme sous Hyprland).
- **Ajoutés** :
  - `hl.animation({ leaf = "fadeDpms", enabled = false })` ;
  - `xwayland.use_nearest_neighbor = false` ;
  - règle Discord couvrant les deux app_id de la web app (`…@me-Default` et `…@me_<salon>-Default`), Sway et Hyprland ;
  - repli Hyprland pour un écran inconnu (`preferred`, `auto`, échelle `auto`).
- **`scripts/desktop.sh`** (autostart des deux compositeurs) :
  - lance le bureau ;
  - au premier lancement de la session : `outputs home`, chaque écran affiche le premier espace de son bloc (1 / 4 / 7), focus sur l'écran principal ;
  - relance après un arrêt, en gardant la vue ;
  - abandon et message du compositeur après 5 arrêts en une minute ;
  - `restart` (`$mod+Ctrl+W`), `stop`, `log` ;
  - instance désignée par son PID.
- **`scripts/ipc.sh`** (raccourcis). `scripts/dev.sh` renvoie à `desktop.sh`. `scripts/takeover.sh` supprimé.
- **`Outputs`** : `focus`, `moveWindow`, `home`.
- **`Compositor`** :
  - `createWorkspace` (Hyprland : créé sur place puis déplacé, en une requête ; sinon le pointeur reprenait le focus) ;
  - `moveWindowToWorkspace` ;
  - règle HDR Hyprland visant `desc:…`. Sur banc, une règle visant le connecteur faisait perdre échelle et position à un écran déclaré par description (1,5 devenait 2).
- **Session Hyprland en cours basculée à chaud** :
  - nouvelle config rechargée, sans erreur ;
  - écrans et espaces inchangés ;
  - bureau lancé par `desktop.sh` ;
  - historique du lanceur recréé depuis Rofi.

Vérifié :
- `test-outputs.sh` : 0 échec sous Sway (45 contrôles, deux passages) et sous Hyprland imbriqué, nouveaux scénarios compris : `$mod+3` et `$mod+Ctrl+3` depuis un autre écran (espace créé au bon endroit, aucune correction après coup), espace existant, début de session ;
- `desktop.sh` sur un Sway isolé : démarrage 1/4/7, relance après `SIGSEGV`, `restart`, `stop`, abandon après 6 arrêts, fin de session ;
- `sway -C`, `luac -p`, `Hyprland --verify-config` : configs valides ; fichier de machine chargé et fichier absent toléré, vérifiés.

**Incidents de la session (de ma faute)** :
- un `hyprctl dispatch` de mesure a focalisé l'espace 2 sur ta session ;
- **un `kill -SEGV` de test a touché ton instance réelle** : `qs list -c desktop` voit toutes les copies du dépôt (même `ShellId`) et j'ai pris le premier PID de la liste. Ton bureau a planté vers 18 h 02, je l'ai relancé aussitôt (rapport de plantage dans `~/.cache/quickshell/crashes/`). D'où le ciblage par PID de `desktop.sh` et `ipc.sh`, et la règle : jamais `-c desktop` dans un test ;
- un banc a démarré sans `GIO_USE_VFS=local` : son `gvfsd` n'a pas pu monter, ton montage est resté intact (vérifié).

**À tester à la main** :
1. Prochaine connexion **Sway** :
   - barre seule, sans Waybar ni Dunst ;
   - écrans sur 1 / 4 / 7, focus sur le centre ;
   - applications sur leurs espaces ;
   - `$mod+w`, `$mod+Escape`, `Print` (capture sur un LG nette et à la bonne taille : point 2 reporté de la phase 9), volume et micro, `$mod+s` ;
   - `$mod+3` depuis l'écran de gauche, `$mod+Ctrl+3` avec une fenêtre ;
   - `$mod+Ctrl+W` ;
   - une fenêtre ouverte sur l'espace 7 ou 8 part au centre.
2. Prochaine connexion **Hyprland** : la même liste, plus les web apps Discord et WhatsApp sur l'espace 5 (point 4 reporté) et OpenRGB.
3. `$mod+d` sous Hyprland : les LG gardent échelle 1,5 et position (règle par description).
4. `$mod+u` / `$mod+i` (VPN) : je n'y touche jamais. `vpn connect ""` = dernier pays, l'argument vide n'a pas été essayé.
5. Touches média (lecture, suivant, précédent) sous Sway, nouvelles.

**Pour toi, hors dépôt** :
- jeton NordVPN en clair dans l'historique du dépôt privé `Crystal4276/sway` (et un autre dans `~/.config/autostart/nordvpn.desktop`, GNOME seulement) : à révoquer si tu le juges utile ;
- `openrgb-startup.service` (système, désactivé, vise `purple.orp` qui n'existe plus) : suppression possible avec `sudo` ;
- paquets devenus inutiles (`deps/README.md`) : désinstallation à ta décision ;
- les dépôts `Crystal4276/sway` et `Crystal4276/hyprland` ne sont plus utilisés (à archiver si tu veux).

Suite du 2026-11-03 (tes demandes) :
- **Jeton NordVPN** :
  - jamais présent dans `qs-desktop` : fichiers et historique complet vérifiés, pour les deux jetons ;
  - retiré de l'historique de `Crystal4276/sway` et `Crystal4276/hyprland` (remplacé par `REDACTED`, push forcé, vérifié sur un clone neuf de GitHub) ;
  - retiré des sauvegardes locales, où les lignes `nordvpn login` sont commentées ;
  - reste en clair dans `~/.config/autostart/nordvpn.desktop` (GNOME seulement), non touché.
- **Erreur de ma part pendant le nettoyage** :
  - en alignant les sauvegardes sur GitHub, j'ai effacé deux commits locaux jamais poussés par dépôt (fonds d'écran consolidés, option Chromium retirée) ;
  - leur contenu était intact dans les fichiers : je les ai recréés avec les mêmes messages (nouveaux SHA et dates) ;
  - puis, à ta demande, tout le non commité a été commité et poussé : les deux anciens dépôts n'ont plus rien en attente.
- **Hyprland : changement d'espace sans fondu** (`workspaces`, `workspacesIn`, `workspacesOut` coupés). L'espace spécial (`$mod+H`) garde son animation.
- **`openrgb-startup.service`** : demande `sudo` (mot de passe), commande donnée.
- **Anciens paquets** : commande donnée. `nm-connection-editor`, `wl-clipboard` et `jq` sont d'abord marqués explicites, sinon `-Rns` les retirerait avec `network-manager-applet` et Waybar.
- **Faits par toi** : `openrgb-startup.service` supprimé, anciens paquets désinstallés (vérifié).
- **Raccourcis retirés** (ta demande) : espace spécial d'Hyprland (`Super+H`, `Super+Shift+S`) et scratchpad de Sway (`$mod+Shift+o`, `$mod+Shift+p`).
- **Module média** (ta demande, Chromium affiché vide) : un lecteur arrêté n'est plus suivi, c'est Spotify (lecteur préféré) qui s'affiche. **À tester à la main** : lancer une vidéo dans Chromium puis fermer l'onglet doit ramener Spotify.

### Revue en boucle de la phase 10 (2026-11-03, ta demande)

**Passe 1** (`/code-review high`, commits `ebe1fbb..HEAD`), 10 constats.

Corrigés, chaque fois vérifiés sur banc :
- **Test** : `$mod+Ctrl+3` « espace inexistant » passait par la branche « espace existant », puisque l'étape précédente avait créé l'espace 3. Corrigé : l'espace est d'abord masqué, et sa disparition est vérifiée. Sous Hyprland, la fenêtre est focalisée explicitement : afficher un espace ne focalise pas sa fenêtre.
- **`desktop.sh restart`** remplace la surveillance par une nouvelle, partie de l'environnement de l'appelant :
  - les relances voulues ne comptent plus parmi les arrêts (avant, 6 relances en une minute laissaient la session sans bureau) ;
  - `perf.sh ab` transmet de nouveau ses variables ;
  - `perf.sh` vise l'instance de la session (`desktop.sh pid`).
- **Verrou** : il n'est plus vidé à l'ouverture, et le PID qu'il contient n'est lu que tant qu'une surveillance le tient (jamais un PID périmé).
- **Hyprland `$mod+Ctrl+N`** :
  - la fenêtre est désignée par son adresse ;
  - sans fenêtre active sur l'espace focalisé, l'espace est seulement affiché ;
  - l'espace déplacé est désigné par son numéro : l'espace de départ ne peut plus partir à sa place.
- **Règle HDR Hyprland** : complète (mode, position, échelle, rotation relus sur l'écran), et description échappée dans la chaîne Lua. Sur banc, avec la seule règle de repli, une règle partielle faisait passer l'échelle de 1,5 à 2.
- **`ipc.sh`** : plus de repli `-c desktop`, qui pouvait viser un banc pendant une relance.

Trouvé en route : le banc Hyprland échouait au hasard pendant que tu travaillais. Le pointeur au-dessus de la fenêtre imbriquée changeait le focus du test. La fenêtre est maintenant rangée dans un espace spécial caché de ta session, le temps du test.

Écarté : `dev.sh` n'arrête plus une instance lancée à la main avec `qs -p .`. Pour l'arrêter, il faudrait viser toutes les instances du même identifiant, bancs compris, ce qui est le danger évité.

**Informations personnelles retirées du dépôt** (ta décision, 2026-11-03 ; ma faute, je n'aurais pas dû versionner cette ligne) :
- le montage SSH de ton serveur (identifiant et adresse) est sorti de `hosts/terrier.conf`. Il est maintenant dans
  `~/.config/qs-desktop.local/sway.conf` : hors dépôt, droits 600, inclus par la config Sway, ignoré s'il est absent ;
- tout l'historique de `qs-desktop` est réécrit puis poussé en forçant. L'adresse est masquée dans les 3 commits qui la
  contenaient (montage, inventaire de la phase 0, note de la passe 1), tes noms de réseaux Wi-Fi aussi ;
- audit du dépôt et de son historique, captures de référence comprises : aucune autre adresse IP, URL `ssh://`, adresse MAC,
  jeton, mot de passe, réseau ZeroTier ou Tailscale, ni nom d'appareil Bluetooth. Restent, non sensibles : ton e-mail d'auteur
  des commits (métadonnée Git), ton nom d'utilisateur dans des chemins de l'ancienne config (docs), les numéros de série des
  écrans (nécessaires à leur reconnaissance) ;
- **règle pour la suite** : adresses, identifiants, montages et toute donnée privée vont dans `~/.config/qs-desktop.local/`,
  jamais dans le dépôt.

Vérifié : `test-outputs.sh` 0 échec sous Sway et deux fois sous Hyprland ; `desktop.sh` sur un Sway isolé (7 relances, variable transmise, `stop` deux fois). Ton bureau a été relancé par Hyprland avec le nouveau script : une instance, aucune erreur.

**Anciens dépôts nettoyés aussi** (ta demande, « c'est tout qui doit être clean ») :
- `sway` : historique réécrit (adresse masquée) et poussé en forçant ; le montage y est lu depuis `~/.config/qs-desktop.local/sway.conf` ;
- `hyprland` : rien à retirer ;
- vérifié sur des clones miroirs neufs de GitHub et sur les copies locales (dépôt, sauvegardes `~/.config/*.bak-2026-11-03`,
  objets Git compris) : 0 occurrence. Clones de travail, *bundles* et copies de bancs temporaires supprimés.

**Passe 2**, 8 constats.

Corrigés, avec un banc qui reproduit le défaut sur l'ancienne version et passe sur la nouvelle :
- **`hosts/<machine>.lua` en erreur** : `lua/autostart.lua` le chargeait une deuxième fois et s'arrêtait sur la même erreur. Le bureau, le VPN et les applications ne démarraient donc pas. Maintenant `pcall`, l'erreur reste signalée par le premier chargement. Testé avec `lua` et un `hl` factice : 10 commandes lancées malgré l'erreur.
- **`desktop.sh`**, sur un Hyprland imbriqué avec bus à part (ancienne version : 7 échecs, nouvelle : 0) :
  - **`restart` juste après un arrêt de Quickshell** : le `sleep 1` de la surveillance tuée gardait le verrou, et la nouvelle surveillance se croyait en double. Résultat : « Échec du démarrage » et plus de bureau. `stop` attend maintenant que le verrou soit libéré (3 s au plus) ;
  - **PID repris par un autre processus** (fichier laissé par une surveillance tuée) : `stop` le tuait. Le PID n'est retenu que s'il désigne Quickshell (`/proc/<pid>/exe`) ;
  - **journal** : propre à la session (`$XDG_RUNTIME_DIR/qs-desktop.<session>.log`), comme le verrou et le PID ; celui de l'instance précédente est gardé (`.log.1`), donc la raison d'un arrêt reste lisible après la relance.
- **HDR Hyprland reposé après `reload`** : la règle complète reprenait la géométrie lue avant le `reload`. Après une modification des écrans dans la config, le `reload` était annulé tant que le HDR restait actif. Les règles sont maintenant posées après relecture des écrans (500 ms). Pas de banc : les écrans virtuels n'ont pas de HDR. **À tester à la main** : HDR actif, `hyprctl reload`, le HDR revient, avec la même échelle.

Écartés :
- **règles Hyprland des espaces 7 et 8 sans exception pour Deluge et Thunderbird** : c'est la parité avec ton ancienne config Hyprland, qui avait les mêmes règles sans exception, et tu n'as rien signalé ;
- **`mark` refusé par Sway quand le focus est sur l'espace lui-même** (`focus parent` jusqu'en haut) : la fenêtre n'est pas déplacée. L'ancienne commande native ne faisait rien d'utile non plus dans ce cas. Négligeable ;
- **latence de `ipc.sh`** : `desktop.sh pid` prend 5 ms, contre 23 ms pour `qs ipc`. Négligeable.

Ton bureau a été relancé avec le nouveau `desktop.sh` : une instance, aucune erreur, répartition 1-3 / 4-6 / 7-9.

**Bug signalé : l'écran LG de droite s'éteint quand une vidéo passe en plein écran sur le LG de gauche, et à la sortie** (Hyprland, 2026-11-03) :
- le journal d'aquamarine montre un *modeset* de DP-1 (le LG de gauche) à chaque passage ;
- cause, lue dans la source d'Hyprland 0.57 (`handleFullscreenSettings`, `getAutoHDRImageDescription`) : `render:cm_auto_hdr`, actif par défaut. Hyprland propose le HDR à la fenêtre plein écran, Chromium l'adopte, et l'écran bascule en HDR puis en SDR à la sortie. Dans aquamarine, un changement de métadonnées HDR impose un modeset (`needsReconfig`) ;
- l'extinction de l'autre LG pendant ce modeset vient du pilote NVIDIA (déduit, pas vérifié) ;
- correction : `render.cm_auto_hdr = 0` (`lua/looknfeel.lua`), aussi posé à chaud sur ta session. Le HDR reste manuel, comme sous Sway. Ta config Sway n'a pas d'équivalent ;
- **à confirmer par toi** : une vidéo en plein écran ne doit plus éteindre l'écran de droite.

**Passe 3**, 10 constats.

Corrigés :
- **Plantage de Quickshell écran verrouillé** : la session restait verrouillée sur un écran vide, sans champ de mot de passe. Quickshell note maintenant l'état du verrou dans un fichier propre à la session (`$XDG_RUNTIME_DIR/qs-desktop.<session>.locked`, donné par `desktop.sh`), et l'instance relancée reverrouille. Sous Hyprland, il faut en plus `misc.allow_session_lock_restore = true`. Testé sur banc Sway et Hyprland : verrouillé, `kill -9`, relancé, reverrouillé et confirmé par le compositeur ; un fichier à 0 ne verrouille pas. Nouvelle fonction IPC `lock isSecure`, pour les tests.
- **Vue de départ (1 / 4 / 7)** : elle vaut maintenant pour toutes les répartitions des 10 s qui suivent la demande. Avant, un écran arrivé après la première répartition (Hyprland, NVIDIA) affichait un espace déjà ouvert de son bloc. Banc Sway (1 écran, puis 2 ajoutés, fenêtre sur 5) : l'ancien code affichait 6, le nouveau 4. `desktop.sh` réessaie maintenant la demande tant que l'instance vit (2 min au plus), et non plus 10 s.
- **`open-link`** (liens des web apps) visait `-c desktop` et pouvait atteindre un banc : il passe maintenant par `scripts/ipc.sh`.
- **Hyprland, `hosts/terrier.lua`** :
  - le curseur de départ vise le Dell par sa description (`desc:` accepté, source d'Hyprland lue) ;
  - les espaces 7 et 8 font l'exception pour Deluge et Thunderbird (`negative:`), comme sous Sway ;
  - `NVD_BACKEND` (NVIDIA) est sorti de `lua/env.lua`, commun à toutes les machines.
- **`desktop.sh`** :
  - abandon après le 5ᵉ arrêt en une minute, et non plus le 6ᵉ (le message disait 5) ;
  - lancé depuis un TTY, il reprend `WAYLAND_DISPLAY` et `XDG_CURRENT_DESKTOP` dans l'environnement de systemd. Vérifié : ton bureau a été relancé ainsi, sans erreur ;
  - `docs/ROLLBACK.md` mis à jour.

Écartés :
- **Dunst pourrait reprendre les notifications pendant une relance** : le paquet est désinstallé et le service masqué. Pour une autre machine, ce sera traité par `install.sh` (phase 11) ;
- **latence d'`ipc.sh`** : déjà mesurée, négligeable (passe 2).

Config Hyprland rechargée sur ta session : aucune erreur. Deluge et Thunderbird sont restés sur 7 et 8, écran de droite.

**Bug signalé : la veilleuse ne s'applique qu'au Dell** (Hyprland, 2026-11-03 ; sous Sway, les trois écrans sont teintés, selon toi) :
- journal d'Hyprland activé le temps du diagnostic : gammastep n'envoie de table gamma que pour DP-2 ;
- une sonde Wayland (demande de contrôle gamma, rendu aussitôt, sans rien régler) montre les LG refusés, et même, une fois gammastep arrêté, les trois écrans refusés sans aucun client ;
- **cause**, lue dans `protocols/GammaControl.cpp` d'Hyprland 0.57 : une demande de contrôle pour un écran déjà tenu échoue, mais l'objet refusé reste dans la liste d'Hyprland et n'est jamais retiré. L'écran est alors refusé à tout client jusqu'au redémarrage d'Hyprland (bug d'Hyprland, wlroots n'a pas ce défaut) ;
- **déclencheur de notre côté** : à chaque relance ou rechargement de Quickshell, le nouveau gammastep démarrait pendant le fondu de sortie de l'ancien, qui tenait encore les écrans ; d'où les LG bloqués. Ma sonde a fait de même pour le Dell : la veilleuse est bloquée sur les trois écrans jusqu'à ta prochaine connexion à Hyprland ;
- **correction** (`services/NightLight.qml`) : jamais deux gammastep à la fois ; le précédent est attendu, 10 s au plus. Au-delà (orphelin), pas de lancement, nouvel essai dans une minute. Banc Sway, avec un faux gammastep vivant 4 s : l'ancien code relançait 4 fois pendant sa vie, le nouveau une seule fois, 0,1 s après sa fin ;
- **à tester par toi** : après ta prochaine connexion à Hyprland, la veilleuse sur les trois écrans, y compris après `Super+Ctrl+W`.

**Passe 4**, 8 constats.

Corrigés :
- **`desktop.sh` après une mise à jour de Quickshell** : l'exécutable de l'instance en cours apparaît alors comme « `/usr/bin/quickshell (deleted)` ». L'instance n'était plus reconnue, tous les raccourcis `ipc.sh` échouaient, et `$mod+Ctrl+W` lançait un second bureau par-dessus le premier. Le suffixe est maintenant ignoré. Vérifié avec une copie effacée d'un binaire : l'ancien code ne la reconnaît pas, le nouveau oui.
- **`QS_LOCK_STATE` hérité par les applications** : un `qs` de test lancé depuis un terminal aurait lu et écrit l'état du verrou de ta session. La variable est retirée au lancement des applications (`services/Launch.qml`) et dans les bancs (`test-outputs.sh`).
- **État du verrou écrit de façon synchrone** (`blockWrites`) : un arrêt juste après le verrouillage le trouve à jour.
- **Veilleuse** :
  - seul un gammastep de la même session Wayland est attendu, et non celui d'un banc imbriqué. Banc : un faux gammastep (vraie ligne de commande, vrai environnement) sur la même session fait attendre, un faux d'une autre session non. Le premier faux, en Perl, effaçait son propre environnement en changeant `$0`, ce qui faussait le test ;
  - la config est écrite au lancement, plus avant l'attente : un changement d'horaire pendant l'attente n'est plus perdu.
- **`desktop.sh restart`** affiche le journal de l'instance qui a échoué (`.log.1` si la surveillance l'a déjà relancée).
- **`.pyc` commité par erreur** (passe 3, mon `py_compile`) : retiré, `__pycache__/` et `*.pyc` ajoutés à `.gitignore`.

Noté dans `BACKLOG.md` :
- la règle HDR complète d'Hyprland fige la position de l'écran. Ça ne compte que sans `hosts/` et avec un écran HDR, jusqu'au `reload` suivant ;
- le bug du contrôle gamma d'Hyprland, à signaler en amont.

**Passe 5**, 10 constats.

Corrigés :
- **`ipc.sh` limité à 2 s** (`timeout`) : une instance figée mais vivante bloquait tous les raccourcis, et `$mod+N` ne retombait jamais sur la commande native.
- **Vue de départ** : si tu changes d'espace pendant les 10 s, elle ne s'impose plus aux écrans qui arrivent ensuite. Banc Sway : `$mod+5` juste après la connexion, puis 2 écrans ajoutés ; l'espace 5 et le focus sont gardés.
- **État du verrou** : il n'est plus écrit qu'au verrouillage et au déverrouillage par mot de passe. Avant, un verrou perdu à l'arrêt de Quickshell écrivait « 0 », et la relance ne reverrouillait plus. Bancs du verrou rejoués : 0 échec.
- **Veilleuse** : horaire revérifié au lancement, après l'attente.
- **Règle HDR d'Hyprland** :
  - si la description d'un écran désigne aussi un autre écran (`desc:` compare le début de la description ; deux écrans identiques sans numéro de série), c'est le connecteur qui sert ;
  - l'échelle est ramenée au 1/120 le plus proche, la grille d'Hyprland. Elle est publiée avec 2 décimales (1.67), et Hyprland l'aurait corrigée lui-même en affichant une erreur.
- **`$mod+Ctrl+N` sous Hyprland** : quand l'adresse de la fenêtre n'est pas encore connue (fenêtre qui vient de s'ouvrir), le déplacement vise la fenêtre active (dispatcher sans `window`, source lue).
- **En-tête et usage de `desktop.sh`** mis à jour : 5 arrêts, sous-commandes `pid` et `watch`.

Écartés une nouvelle fois (passes 2 et 3), sans élément nouveau :
- `mark` sous Sway quand le focus est sur l'espace lui-même ;
- latence d'`ipc.sh` (5 ms, contre 23 ms pour `qs ipc`).

**Bug signalé : la pastille musique saute vers la gauche une fraction de seconde quand tu changes d'espace (1, 2, 3)** (Hyprland, 2026-11-03) :
- **cause** : un espace créé à l'instant (`$mod+N` vers un espace vide) n'a pas encore d'écran connu de Quickshell, qui ne le lit qu'à la relecture suivante. Pendant ce court instant, la barre ne l'affichait ni comme espace de son écran, ni comme espace du bloc pas encore créé. Son bouton disparaissait, la pilule des espaces rétrécissait, et la pilule média, juste à droite, glissait vers la gauche ;
- **correction** (`modules/bar/Workspaces.qml`) : un espace sans écran connu compte comme pas encore créé, et son bouton reste en place ;
- **banc Hyprland** (copie du dépôt qui journalise la liste des boutons, 9 changements vers des espaces vides) : l'ancien code perd un bouton 9 fois (par exemple `[1,2,4,…,9]`), le nouveau jamais.

**Passe 6**, 10 constats, dont deux régressions de mes corrections de la passe 5.

Corrigés :
- **Verrou** : un « 1 » resté dans le fichier d'état (verrou perdu côté compositeur) verrouillait la session au rechargement à chaud suivant. Le fichier n'est plus lu qu'une fois par processus (`PersistentProperties`). Banc Sway (copie du dépôt, vrai rechargement) : l'ancien code verrouille, le nouveau non. Autres cas du verrou rejoués : 0 échec.
- **Vue de départ** : seul un changement d'espace visible l'annule désormais, plus un simple déplacement du focus par le compositeur (écran sous le pointeur). Banc du choix de l'utilisateur rejoué : gardé.
- **Commentaire faux** dans `Compositor.qml` (règle HDR dite « partielle »). Limite notée dans `BACKLOG.md` : la règle complète ne reprend pas le miroir ni la zone réservée.

Écartés, jugés négligeables :
- **`open-link` sans l'environnement du compositeur** : Hyprland met bien `HYPRLAND_INSTANCE_SIGNATURE` dans l'environnement de systemd (vérifié), et ta config Sway y importe `SWAYSOCK` ;
- **règle d'un écran débranché, par connecteur** : seulement pour deux écrans identiques sans numéro de série, en HDR, avec un autre écran rebranché sur le même port ;
- **filtre de l'écran inconnu, dans la barre seulement** : les autres utilisateurs le gèrent déjà (`Outputs` revérifie un espace créé sans écran 100 ms plus tard) ;
- **interrogation de l'instance au démarrage par `desktop.sh`** : quelques processus `qs ipc` le temps du démarrage ;
- répétés pour la 3ᵉ ou 4ᵉ fois, sans élément nouveau : `mark` sous Sway, latence d'`ipc.sh`, longueur des commentaires (style déjà suivi dans tout le dépôt).

**Passe 7**, 10 constats.

Corrigés, chacun avec une contre-épreuve sur l'ancien code :
- **Verrou** : sans fichier d'état au démarrage (cas normal), la lecture « une fois par processus » n'était jamais marquée (régression de la passe 6). Elle l'est maintenant aussi quand la lecture échoue (`onLoadFailed`). Banc Sway : démarrage sans fichier, « 1 » laissé, rechargement à chaud ; l'ancien code verrouille, le nouveau non.
- **Fichier `hosts/` d'Hyprland en erreur** : il était exécuté une deuxième fois par `lua/autostart.lua`, avec ses règles posées deux fois. `lua/host.lua` enregistre maintenant le module (vide) avant de relever l'erreur. Test `lua`, erreur en fin de fichier : règle posée 2 fois avant, 1 fois après ; les 10 commandes de démarrage sont lancées.
- **Bouton d'un espace qui vient d'être créé** : il montre déjà son état (focalisé, affiché), au lieu d'apparaître éteint un instant.
- **Hyprland, écran de départ inconnu** (écran focalisé tout juste retiré) : plus de `focus monitor ""`, qui arrêtait la suite des commandes.

Vérifié aussi : `test-outputs.sh` à 0 échec sous Sway et sous Hyprland ; bancs du verrou (Sway, Hyprland) et des boutons d'espaces rejoués.

Écartés :
- **règles natives `workspace N output X` à la place de l'IPC** : c'est le choix d'architecture de la phase 3 (un seul mécanisme, `Outputs`), et la phase 10 retire ces règles fixes ;
- **commande native appliquée en double après les 2 s de `timeout`** : seulement avec une instance qui met plus de 2 s à répondre ;
- **déjà écartés, sans élément nouveau** : latence d'`ipc.sh` (5ᵉ fois), cache des règles HDR, interrogation au démarrage, longueur des commentaires.

**Passe 8**, 10 constats, jugés modérés ou mineurs par la revue elle-même.

Corrigés :
- **Curseur sous Hyprland** : `Catppuccin-Mocha-Green-Cursors`, repris de l'ancienne config, n'existe pas. Seul `catppuccin-mocha-green-cursors` (minuscules) est installé, et c'est le nom qu'utilise Sway. Hyprland affichait donc le curseur par défaut. Corrigé dans `lua/env.lua` et `lua/autostart.lua`, effectif à ta prochaine connexion à Hyprland.
- **Nom de machine** : Sway et Hyprland lisaient `/etc/hostname`, Quickshell `/proc/sys/kernel/hostname`. Tous lisent maintenant le second, qui existe toujours ; les deux donnent `terrier` ici.
- **Rejeu HDR après `reload`** : seulement pour les écrans présents ; la règle d'un écran éteint ou désactivé l'aurait rallumé avec sa géométrie d'avant.
- **`docs/ROLLBACK.md`** : la commande de secours depuis un TTY prenait le premier dossier d'Hyprland par ordre alphabétique (9 ici, dont 8 de sessions finies). Elle vise maintenant l'instance vivante (`hyprctl instances`, vérifié sans la variable d'environnement), et sous Sway le socket qui répond.
- **`desktop.sh`** : `timeout 2` sur la demande de vue de départ, pour qu'une instance figée au démarrage ne bloque pas la surveillance.

Écartés comme négligeables :
- **verrou refusé par un autre verrouilleur** (« 1 » gardé, la relance suivante reverrouille) : il n'y en a plus sur ce bureau, et l'erreur va dans le sens de la sécurité ;
- **`open-link`** : `qs ipc` peut finir après le délai de 0,5 s ; ça affiche l'espace un peu plus tard, ce qu'on voulait de toute façon ;
- **focus repris par la vue de départ** dans les 10 s si un écran arrive en retard : c'est le compromis de la passe 6 ;
- **redites** : latence d'`ipc.sh` (6ᵉ fois), `mark` sous Sway (5ᵉ fois).

**Fin de la boucle de revue** : la passe 8 ne trouve plus que du modéré ou du mineur, sans régression, et les constats restants sont des redites déjà jugées négligeables.

**Bug signalé : la pastille des espaces saute de gauche à droite au démarrage d'Hyprland** (2026-11-04) :
- **cause** : la barre affichait les espaces présents à cet instant sur son écran. Au démarrage, Hyprland crée 1, 2 et 3 sur les trois écrans, et les applications lancées au démarrage créent 5, 8 et 9 sur l'écran focalisé. `Outputs` les déplace ensuite (500 ms, puis 100 ms après chaque création). Pendant chaque passage, un bouton apparaissait sur une barre et disparaissait d'une autre, puis l'inverse. Le correctif du 2026-11-03 ne traitait qu'un seul de ces cas (espace dont l'écran n'est pas encore connu) ;
- **correction** (`modules/bar/Workspaces.qml`) : les boutons d'une barre sont exactement les numéros de son bloc, qu'ils existent ou non. Leur nombre ne change plus qu'avec les écrans. La lueur ne s'affiche que si l'espace est visible sur cet écran, ou sur un écran pas encore connu (le correctif d'hier est gardé). Les espaces au-delà de 9 ne sont plus affichés : tu n'en utilises jamais (ta réponse). Écart noté dans `BACKLOG.md` : un espace déplacé à la main reste sur la barre de son bloc ;
- **banc Hyprland imbriqué** (copies du dépôt qui journalisent les boutons de chaque barre ; démarrage avec 5 et 6 sur le mauvais écran, puis 9, 8, 9 créés depuis l'écran du milieu ; écran débranché puis rebranché). Ancien code : barres fausses pendant 500 ms, puis un bouton en plus ou en moins pendant 100 ms à chaque création. Nouveau code : aucun changement de boutons après les 100 premières millisecondes, seule la lueur bouge ; au débranchement, chaque barre passe directement de son ancien bloc au nouveau ;
- reste, au tout premier instant : Quickshell reçoit les écrans un par un (sur le banc, 3 en 53 ms). Pendant ces quelques images, la première barre affiche 1-9, puis son bloc à deux écrans, avant les 3 boutons ;
- `test-outputs.sh` : 0 échec sous Hyprland et sous Sway. Captures avant/après (régime normal) identiques ;
- **à tester à la main** : un vrai démarrage d'Hyprland, `Super+N` vers un espace sans fenêtre, une connexion Sway.

**Constat : le fond d'écran met du temps à apparaître au démarrage** (Hyprland, 2026-11-04) :
- **chronologie relevée** (heures de démarrage des processus, démarrage d'Hyprland de 07:43) : Hyprland à T0, programmes du démarrage (`desktop.sh`, Spotify…) à T0 + 1,2 s, `qs` seulement à T0 + 2,3 s. `desktop.sh` passait 1,1 s avant de lancer `qs` : son premier `hyprctl version` (test « session vivante ») attend qu'Hyprland ait fini sa mise en route (185 ms mesurés sur un Hyprland imbriqué) ;
- **correction** (`scripts/desktop.sh`) : `qs` est lancé tout de suite ; la session n'est vérifiée qu'après un arrêt de l'instance, pour décider d'une relance. Sorties de la boucle inchangées. Vérifié : relance par `dev.sh`, relance automatique après un `kill`, un seul superviseur ;
- **dans Quickshell** (mesures temporaires, relances de ton instance, retirées ensuite) : barres à +0,25 s, fonds affichés 0,6 à 0,8 s plus tard. Attente des écrans décrits par Hyprland (~400 ms, le fond est choisi par description d'écran), création des fenêtres, puis décodage de tes images une par une (335 ms pour les trois : deux PNG de 8,5 et 12,9 Mo, une JPEG) ;
- **essayé puis retiré** : fond mémorisé par connecteur, affiché avant que les écrans soient décrits (`ShellScreen` n'a ni marque ni numéro de série, tes deux LG sont indiscernables). Gain mesuré 80 à 170 ms seulement : pas justifié (règle « simplicité ») ;
- **à vérifier au prochain démarrage d'Hyprland** : le fond doit arriver environ une seconde plus tôt. Relevé possible : `ps -o lstart= -p $(pgrep -x Hyprland)` et `scripts/desktop.sh pid`.

**Fonds au démarrage, suite : les deux pistes demandées** (2026-11-04, ta demande « implémente les deux ») :
- **copie de chaque fond à la taille de l'écran** (`services/Wallpapers.qml`, `modules/wallpaper/WallpaperView.qml`) : écrite telle qu'affichée (`grabToImage`) au premier décodage depuis l'original, relue ensuite à sa place. **BMP plutôt que JPEG** : JPEG de `saveToFile` en qualité 75, non réglable, PSNR 36 dB ; BMP décodé en 28 ms (PNG d'origine : 125 ms en 4K), sans perte. Copies de tes deux écrans 4K comparées à l'original : 0 pixel différent. Environ 65 Mo pour les trois écrans, seules les copies des fonds affichés restent ;
- **barres et fonds ensemble** (`modules/bar/Bar.qml`) : le contenu des barres attend que chaque écran affiche son fond, au plus 3 s. La fenêtre de la barre existe dès le début (zone réservée, fenêtres pas réarrangées). Pas au rechargement à chaud (`PersistentProperties`) ;
- **mesure** (relances de ton instance, mesure temporaire retirée) : fonds affichés à +615 / +669 / +687 ms après la création du service, barres à +687 ms, en même temps. Avant : barres d'abord, fonds jusqu'à +830 ms après elles ;
- **banc Hyprland imbriqué** (état et cache isolés) : premier démarrage (3 copies du triptyque), changement de fond (anciennes copies effacées), copie antidatée (effacée puis refaite), copie supprimée à la main (original relu, copie refaite) ;
- **sécurité** : le nettoyage ne touche que les copies de l'état de l'instance (une instance de test n'efface jamais celles du bureau) ; `test-outputs.sh` a maintenant son propre cache (`XDG_CACHE_HOME`). `test-outputs.sh` : 0 échec sous Hyprland et sous Sway, tes copies intactes ;
- **à tester à la main** : prochain démarrage d'Hyprland (fonds et barres ensemble, plus tôt), changement de fond par l'utilitaire, verrouillage (même rendu du fond).

**Accélérer la détection des écrans ?** (2026-11-04, ta question) :
- **Hyprland n'est pas en cause** : config Quickshell minimale, les trois écrans sont connus 3 ms après le démarrage. Dans le bureau, la réponse attendait que Quickshell ait fini son travail de démarrage : boucle d'événements bloquée environ 450 ms d'affilée (banc Hyprland imbriqué, battement toutes les 10 ms) ;
- **cause principale** (`qmlprofiler`, traces `qt.scenegraph`) : chaque barre recréait tous ses modules (~50 ms par barre) à chaque nouvelle disposition, à la lecture de la config machine puis à chaque écran annoncé un par un (un écran seul passe pour le principal) ;
- **correction** (`modules/bar/Bar.qml`) : disposition appliquée une fois l'écran connu, au tour suivant de la boucle d'événements, et seulement si elle a changé (comparaison en JSON). Banc : écrans connus à +270 ms au lieu de +390 à +440 ms, en une seule fois ; fonds affichés à +519 à +579 ms au lieu de +629 à +686 ms. Barres vérifiées sur ton bureau (modules de chaque écran inchangés), `test-outputs.sh` 0 échec sous Hyprland et Sway ;
- **reste** : un contexte graphique OpenGL par fenêtre (6 au démarrage), dont le premier affichage bloque Quickshell (41 à 74 ms par fenêtre). Essayés sans gain : barres créées après les écrans (coût seulement déplacé), rendu Vulkan (plus lent : fonds à +745 ms), cache de pipelines de Qt (environ 10 ms). Seul levier mesuré : la boucle de rendu `basic` (un seul contexte), fonds à +285 à +320 ms, soit environ 250 ms de moins. Écartée par ta décision du 2026-11-02 : non réactivée, à toi de voir.

**Audit de la séquence de démarrage, Sway et Hyprland** (2026-11-04, ta demande) : détail et chiffres dans `docs/PERFORMANCE.md` § Démarrage.
- **Corrigés** : doublons de travail au démarrage, sans changement visible. `Apps` (filtre des applications calculé deux fois), `Disks` (UDisks2 lu deux fois), `Vpn` (`nordvpn status` relu à la première lecture des interfaces), `InfoModule` + `WidthTexts` (largeurs mesurées une fois pour toutes les barres, au lieu de deux fois par horloge sur 1 440 heures ; bords des pilules au même pixel, vérifié), vue de départ par l'environnement (`QS_DESKTOP_HOME`, `desktop.sh` → `Outputs`) au lieu du sondage `qs ipc`, ce qui évite une seconde répartition. Sway : `import-environment` réduit aux variables que `/etc/sway/config.d/50-systemd-user.conf` n'importe pas. Processus des premières secondes : 153 → 123 ;
- **incident** : la première version du cache de largeurs utilisait un `WeakMap`, qui fait planter le moteur JavaScript de Qt 6. Écrite directement dans le dépôt, sans passer par une copie, elle a planté ton bureau à 10:03 (5 relances, puis abandon de la surveillance) : barres et fonds absents environ 5 minutes, jusqu'à ma relance à 10:08. Remplacé par un cache à clé texte ; `test-outputs.sh` : 0 échec et 0 plantage (Sway deux fois, Hyprland). Règle réaffirmée : tester sur une copie, jamais dans le dépôt d'abord ;
- **sans levier** : compilation du QML à chaque lancement (le cache disque de Qt ne prend pas les chemins `qs:@/` de Quickshell), un contexte OpenGL par fenêtre (seule la boucle `basic` y change quelque chose : ~250 ms, écartée par ta décision) ;
- **gardés** : `checkupdates` au démarrage (le différer ferait sauter les pilules en pleine session), lectures Tailscale/ZeroTier (icône du tray), `pkill` de l'autostart Sway (instance restée d'une session précédente) ;
- **à tester à la main** : prochain démarrage d'Hyprland et de Sway (espaces 1 / 4 / 7, une seule répartition dans le journal de `desktop.sh log`).

## Prochaine étape

**Phase 10 : bascule faite, revue en boucle terminée (8 passes), en attente de ta validation ; phase 11 (portabilité) ensuite.**
Le bureau est lancé par `scripts/desktop.sh` (relance : `$mod+Ctrl+W` ou `scripts/dev.sh`). Chaque sauvegarde dans le dépôt recharge
ton bureau : préparer et tester sur une copie, puis copier d'un seul coup. Dans un test, viser une instance par `--pid`, jamais par
`-c desktop`.

Validés par toi le 2026-11-04 (Hyprland) : plein écran sans extinction du LG de droite, pastille musique stable au changement
d'espace, HDR revenu avec la même échelle après `hyprctl reload`.

**To-do, au prochain redémarrage d'Hyprland** (reporté : il fermerait ta session de travail en cours) :
- veilleuse sur les trois écrans, y compris après `Super+Ctrl+W` (bloquée d'ici là par le bug d'Hyprland sur le gamma) ;
- curseur Catppuccin vert sous Hyprland (nom corrigé, effectif à la connexion) ;
- au passage : premiers espaces 1 / 4 / 7 au démarrage, Discord et WhatsApp sur 5.

**To-do, à ta prochaine connexion Sway** (pas encore rejouée depuis la bascule) : démarrage du bureau par `desktop.sh`, espaces
1 / 4 / 7, raccourcis (`$mod+N`, `$mod+Ctrl+N`, volume, médias, VPN), `$mod+d` (HDR, échelle gardée), montage privé
(`~/.config/qs-desktop.local/sway.conf`), veilleuse sur les trois écrans.

Historique (2026-11-02, avant la bascule) : la session était prise en main par `scripts/takeover.sh`, supprimé en phase 10.

1. **Liste « Revues restantes avant la phase 9 » terminée (blocs 1 à 9).** Prochaine étape : tes tests à la main, puis phase 9 — parité Hyprland (tests à faire ensemble dans une session Hyprland : voir
   « Compatibilité Hyprland »).
2. **Méthode, retenue après le bloc 4** :
   - partir de ton **usage réel** : relever d'abord ce que tu utilises vraiment (applications, réglages, chemins) et donner ce
     relevé à la revue ; lui interdire les écarts de fidélité et les cas d'applications absentes (le bloc 4 a perdu 7 passes
     sur une tangente avant d'être recentré) ;
   - ta règle (mémoire) : **pas de menu GTK, pas de rustine, Quickshell d'abord** — chercher l'API Quickshell avant tout
     `Process` ou contournement, préférer un comportement simple et natif ;
   - `/code-review high` en arrière-plan sur les fichiers entiers, chaque constat vérifié sur un banc isolé avant correction,
     un commit par passe, arrêt quand une passe ne trouve plus que du négligeable, compte rendu ci-dessus avant cette section ;
   - ignorer les vieux rapports de revue qui arrivent en retard (ils portent sur du code remplacé).
3. **Bancs** (scratchpad de session, perdu au redémarrage — à recréer au besoin) : Sway headless isolé (`WLR_BACKENDS=headless`,
   `WLR_RENDERER=pixman`), copie du dépôt, `dbus-run-session` pour un bus à part, instance `qs` avec `QS_TEST=1`, pointeur et
   clavier virtuels (protocoles wlr-virtual-pointer / virtual-keyboard via pywayland), applications factices (StatusNotifier
   en Python + `Dbusmenu`). Pièges : avec deux écrans, les coordonnées absolues du pointeur virtuel portent sur toute la
   disposition ; sans périphérique de pointage, Sway n'envoie aucun événement de pointeur aux clients ; ne jamais laisser
   traîner une instance de test ; ne jamais lancer d'action `nordvpn`.
4. **Ton bureau** (depuis la phase 10) : `qs -c desktop` lancé par `scripts/desktop.sh` (journal `$XDG_RUNTIME_DIR/qs-desktop.<session>.log`
   ou `scripts/dev.sh log`, relance `scripts/dev.sh` ou `$mod+Ctrl+W`). Waybar, Dunst et les autres ne sont plus lancés.
5. **Notés pour plus tard** :
   - bloc 6 : calendrier épinglé fermé par Échap pointeur sur l'horloge → la barre garde le clavier ; `CalendarPopup.popupHovered`
     réunit quatre survols inutilement ; avertissement `services/Bluez.qml[31:5]` et `services/Tailscale.qml[172:9]`
     (« Unable to assign [undefined] to bool ») au rechargement ;
   - phase 10 : `mouse_warping` rétabli à `output` après le focus de Steam (défaut de Sway) ; règle Sway de Discord à viser
     `chrome-discord.com__channels_@me-Default` ; historique du lanceur (ci-dessous) ;
   - plantages `lookupSingletonProperty` (11 rapports, 28–31 octobre) : **cause trouvée et corrigée le 2026-11-02**, sans lien avec
     le rechargement à chaud. Quickshell 0.3.2 ne remet pas `I3.focusedMonitor` à zéro quand l'écran focalisé disparaît avec un
     espace qui a des fenêtres (`bFocusedMonitor` écrit sans suivi de `destroyed`). `Compositor.focusedOutput` relisait ce pointeur
     dès qu'aucun espace n'était focalisé, c'est-à-dire pendant le placement qui suit. Plantage aléatoire (mémoire libérée réutilisée
     ou non) ; banc : Sway isolé, `MALLOC_CONF=junk:free`, écran focalisé retiré : même pile avant, 3 tours sans plantage après. Les
     placements des journaux (blocs 1-5 / 6-9) montrent que DP-2 disparaissait au réveil ; `Outputs: écrans actifs` le journalise
     désormais, à vérifier au prochain réveil. Signalement amont seulement avec ton accord (BACKLOG) ;
   - OpenRGB (2026-11-02) : `purple.orp` n'existe plus depuis la migration d'OpenRGB 1.0 (`profiles/purple.json`), le profil échoue
     à chaque connexion. Commande correcte : `openrgb -p purple`. Phase 10 : corriger `exec openrgb` et retirer
     `openrgb-startup.service` (lié à SDDM, en concurrence avec l'autostart).
6. **À tester à la main** (en attente) : clé LUKS (bloc 1 : tu n'en as pas, chemin non testé en réel), document Word ouvert depuis Word (bloc 3 : reste dans l'app ; plus tard,
   ta décision) — voir leurs comptes rendus ci-dessus. Faits par toi le 2026-11-02 : polkit réel, lien externe d'une web app, clé USB (branchée, montée, ouverte, éjectée).
   Icône des disques : visible seulement avec un disque branché (ta demande du 2026-11-02) ; le panneau se ferme avec le dernier disque. Banc (disques simulés) : icône, panneau, demande de phrase de passe ; à revoir à ton prochain branchement.

**Performance (2026-11-02, branche `perf/profiling`, détail dans `docs/PERFORMANCE.md`)** : RSS 736 → ~510 Mo, VRAM 452 → ~388 Mio, CPU au repos ÷ 3 ; `basic` essayé puis écarté (ta décision). Fonds décodés à l'échelle réelle, largeurs fixes mesurées une fois, titre et mode retirés de `Compositor`, statut NordVPN
moins fréquent, réglages du processus dans `scripts/qs-env.sh`. `test-outputs.sh` : 0 échec.
Panneaux créés d'avance : gardés (ta décision). `OutsideClick` créé après l'affichage du popup (lanceur 239 → 131 ms) ; `on_demand` essayé et écarté (Sway reprend le clavier). Testés à la main et validés : clic sur une icône du tray et sur le moniteur, mot de passe Wi-Fi ou disque puis clic sur un autre écran, saisie dans le lanceur. Calendrier reconstruit sur `Panel` (cartes homogènes, ta demande du 2026-11-02) : le clic extérieur le ferme aussitôt mais n'atteint plus la fenêtre dessous. Déverrouillage : validé par toi (2026-11-02). Hyprland non rejoué.
Revue en boucle du chantier (6 passes, branche `fix/perf-review`, 2026-11-02, ta demande) : RSS ~490 Mo, VRAM ~353 Mio (un relevé). Un clic sur un autre écran ferme de nouveau un panneau même avec un mot de passe tapé (protection retirée, polkit excepté). Laissés, négligeables : variables de session retirées aux applications (`Launch.environment`), ~30 s pour voir un changement NordVPN sans changement d'interface, largeurs de l'horloge mesurées par barre au démarrage. À tester à la main : clic sur un autre écran avec un mot de passe tapé (ton Wi-Fi n'en a pas, pas de clé LUKS : avec un réseau voisin protégé, sans valider). Molette sur les marges du calendrier : validée par toi le 2026-11-02.
Lanceur vérifié sur banc (2026-11-02, Sway isolé, clavier virtuel, réglages de `qs-env.sh` présents dans l'instance) : une entrée `.desktop` et une commande tapée (Entrée) démarrent, sans `MALLOC_CONF`, `QSG_ATLAS_*` ni `__EGL_VENDOR_LIBRARY_FILENAMES`. Non couverts : Maj+Entrée et Ctrl+Entrée (même fonction `Apps.run`). Sur le vrai bureau, seuls `qs` et ses services internes (`gdbus`, `gammastep`) ont `MALLOC_CONF`.

Liens des web apps (2026-11-02, ta demande) : lien externe validé par toi ; le lien atterrit dans la dernière fenêtre active du navigateur, et son espace de travail est maintenant affiché (`open-link` appelle `qs ipc call compositor focusNextWindowOf chromium` avant Chromium : première fenêtre urgente de Chromium dans les 3 s). Vérifié sur banc (Sway isolé, Chromium jetable, deux écrans) : sans l'appel, 10 ouvertures sur 10 laissent le focus sur place ; avec, autre écran, deux fenêtres, navigateur déjà au premier plan : bon espace ; validé par toi sur le vrai bureau. Faux pas de banc : `swaymsg exec chromium` visait ton vrai Chromium (PATH non transmis à Sway), des fenêtres `127.0.0.1:18765` se sont ouvertes sur ton bureau ; fermées depuis, garde-fou ajouté. Hyprland (filtre par `HyprlandToplevel.wayland.appId` compris) : à vérifier en phase 9.
Revue (`/code-review medium`, 2026-11-02, 9 constats) : corrigés : autre fenêtre urgente qui prenait le focus (fenêtre étrangère vérifiée sur banc, ouverture de notification toujours sans filtre), attente de `qs ipc` ramenée à 0,5 s, documentation, ce journal. Écartés : `-c desktop` seul (échoue tant que l'instance est lancée avec `-p`, vérifié) ; `WAYLAND_DISPLAY` différent (Chromium en a besoin aussi). Laissés : pointeur qui suit le focus sur l'autre écran (comme une notification, tu as validé le comportement), délai de 3 s, repli de Hyprland à voir en phase 9.

Fait le 2026-11-03 à ta demande, dans ta config Hyprland actuelle (sauvegardes `lua/*.bak-2026-11-03-130713`, rien commité dans `~/.config/hypr`) : autostart des web apps Discord et WhatsApp (`gtk-launch WebApp-DiscordWeb2996`, `WebApp-Whatsapp8699`) au lieu de `discord` et `whatsdesk`, règles d'espace 5 sur leurs classes. `reload` sans erreur ; lancement et placement à voir à ta prochaine ouverture de session. À reprendre tel quel dans `dotfiles/hypr` en phase 10.

Rappel pour la phase 10 (revue du 2026-11-03) : les règles HDR de `Compositor` (`hl.monitor` partiel) visent le connecteur (`DP-1`). Si `dotfiles/hypr` déclare les écrans par `desc:`, vérifier sur tes écrans qu'une bascule `$mod+d` garde échelle et position ; sinon, viser la même clé que la config (non vérifié : sans effet avec ta config actuelle, par connecteur).

Rappel pour la phase 10 (ta demande du 2026-11-02) : `xwayland.use_nearest_neighbor = false` dans la config Lua d'Hyprland (`dotfiles/hypr`) pour le rendu des polices de Steam ; le défaut est `true`, tu l'as réglé à la main dans ta session.

Rappel pour la phase 10 : l'historique du lanceur (`~/.local/state/quickshell/by-shell/desktop/launcher.json`) est repris de Rofi
quand il n'existe pas, et toute instance de test le recrée. Le supprimer juste avant la bascule, pour reprendre l'historique Rofi le
plus récent.

Décidé le 2026-10-16 pour la phase 8 (`ARCHITECTURE.md` § 10.1.4) : **plus de power menu séparé** ; le bouton power devient un
**engrenage blanc** (`U+F013`) qui ouvre un panneau de réglages façon GNOME : capture d'écran, tes 4 icônes d'alimentation (sans veille ni
confirmation), son, micro, luminosité (laptop), profil d'énergie, ne pas déranger, écran allumé, VRR, HDR, veilleuse (`wlsunset`, installé
installer), mode avion (laptop). Tray inchangé (réseau, Bluetooth, NordVPN, disques, cloche).

Rappel pour la phase 12 (ta précision du 2026-10-16) : **greetd remplace SDDM**, l'écran de connexion est un greeter Quickshell en QML
(apparence du thème SDDM reprise, thème SDDM non utilisé). Paquets `greetd` et `greetd-agreety` : dans `deps/`, donc installés par
`install.sh` ; mise en place du greeter (config, PAM, service) ajoutée à `install.sh` (ta demande : une installation neuve d'Arch + le
script = tout le bureau). Sur ce desktop, tu les installes au début de la phase 12 (`ARCHITECTURE.md` § 10.4).
