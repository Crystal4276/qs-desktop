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
- **Deuxième passe** : vraie touche de volume / micro une fois les raccourcis branchés (phase 10) ; connexion limitée (Wi-Fi d'hôtel avec
  portail, ou câble sans Internet) ; sur le laptop : OSD de luminosité et alerte de batterie à 30 % et 15 %.
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

## Prochaine étape

Nouvelle passe de recherche (ta règle : tant qu'on trouve des choses, pas de phase 7), puis phase 7 (lanceur).

Rappel pour la phase 12 (ta précision du 2026-10-16) : **greetd remplace SDDM**, l'écran de connexion est un greeter Quickshell en QML
(apparence du thème SDDM reprise, thème SDDM non utilisé). Paquets `greetd` et `greetd-agreety` : dans `deps/`, donc installés par
`install.sh` ; mise en place du greeter (config, PAM, service) ajoutée à `install.sh` (ta demande : une installation neuve d'Arch + le
script = tout le bureau). Sur ce desktop, tu les installes au début de la phase 12 (`ARCHITECTURE.md` § 10.4).
