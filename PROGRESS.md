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

Retour du 2026-10-16 : phase validée ; tests reportés (voir « Tests différés »).

## Tests différés

- **Débranchement physique d'un câble** sur le desktop (phase 3) : à faire avec toi plus tard.
- **Laptop** (phase 3, puis modules batterie / luminosité de la phase 4) : quand il sera installé — laptop seul, laptop + écrans externes,
  capot fermé (`bindswitch lid:on/off`), écran interne éteint, branchement à chaud avec fenêtres ouvertes.

## Phase 4 — Modules système de la barre : faite, en attente de validation (2026-10-16)

Produit :
- Services : `Audio` (Pipewire : volume, muet, sortie suivante à 60 % + notification — remplace `audio-toggle.sh`), `Media` (Mpris, lecteur
  choisi par `mediaPlayer`, troncature `Artiste - Titre` copiée de Waybar 0.15), `Cava` (`cava` en sortie brute, `config/cava.conf`,
  ne tourne que si un module l'affiche), `SystemStats` (`/proc/stat`, `/proc/meminfo`), `Gpu` (NVIDIA `nvidia-smi`, AMD / Intel hwmon,
  carte `boot_vga`), `Network` (interface de la route par défaut, `/proc/net/dev`), `Updates` (`checkupdates` toutes les 8600 s, mise à jour
  dans un terminal puis recomptage), `Battery` (UPower), `Brightness` (sysfs + `brightnessctl`).
- Modules : bouton Arch (survol ; n'ouvre rien avant la phase 8), mpris, cava, volume, curseur, mises à jour, GPU, CPU, mémoire, réseau,
  bouton power (n'ouvre rien avant la phase 8), batterie et rétroéclairage (laptop) ; `RichLabel` (une ligne, une police par segment),
  `InfoModule` (modules texte), `WheelSteps` (molette par crans de 120, aussi pour les espaces de travail).
- **Calendrier** (`CalendarPopup.qml`) : survol = aperçu, clic = épinglé (flèches, molette, ←/→, titre = mois en cours ; Échap ou clic ailleurs
  ferme, via une couche transparente sur chaque écran). Style : `THEME.md` § 3 « Calendrier », valeurs reprises de la charte.
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
- Sous Sway, un `PopupWindow` avec `grabFocus` n'est pas fermé par un clic extérieur et bloque le clic sur l'horloge → couche de fermeture.
- `swaymsg seat - cursor press button4` envoie un pas de molette de 1 (un cran réel vaut 120) : tests faits avec 60 pressions = 1 cran.

Vérifié (Sway, écrans réels, Waybar masquée le temps des captures puis rétablie) :
- Rendu comparé à Waybar sur les trois écrans : mêmes modules, couleurs, polices, positions ; pilules à +1 / +2 px sur DP-2 (anticrénelage,
  comme l'horloge en phase 2) ; pilule média à 1 px ; DP-1 / DP-3 identiques à l'œil (bordure un peu plus nette que le rendu GTK ×2 réduit).
- Volume : molette ±5 % sur l'icône et le curseur (plafond 100 %), clic gauche muet / rétabli, clic sur le rail (10 %, 84 %), clic milieu
  (sortie suivante, volume 60 %, notification), clic droit pavucontrol (icône et curseur) ; paliers d'icône à 32/33 et 65/66 %, icône muette.
- Clics GPU / CPU / mémoire / mises à jour : commandes `nvtop`, `btop`, `btop`, `bash -c <mise à jour>` reçues par un terminal factice
  (copie de test du dépôt) ; recomptage après la mise à jour.
- Molette sur les espaces de travail : précédent / suivant avec bouclage, un cran = un espace.
- Calendrier : aperçu au survol, fermeture en quittant l'horloge, épinglage, cran haut / bas, flèches, titre, fermeture par clic sur l'horloge
  (sans réouverture immédiate de l'aperçu), sur DP-2 et sur un autre écran.
- Session isolée : cava alimenté par un signal de test (barres 4–5, masqué au silence) ; GPU AMD simulé (capteur `edge`, 52 °C), Intel sans capteur
  et aucune carte → module masqué ; rétroéclairage simulé (42 %) ; batterie absente → masquée ; écran secondaire : pilule volume présente.
- `test-outputs.sh` : 0 échec.

Écarts restants :
- tray absent (phase 5) : le bouton power est seul dans sa pilule, sans padding gauche (comme dans Waybar, où le tray le précède) ;
- silence de cava : décidé sur les barres à zéro (Waybar : échantillons d'entrée nuls) — différence seulement pour un son très faible ;
- réseau : interface de la route par défaut (`bridge0` ici) au lieu de `eno2` écrit en dur ; débits quasi identiques (même lien physique) ;
  sans route par défaut, le module se masque (Waybar affichait un texte « déconnecté ») ;
- avertissements Qt `QWaylandTextInputv3::disableSurface` à la fermeture du calendrier épinglé : sans effet.

À tester à la main :
- molette réelle (souris et pavé tactile) sur le volume, le curseur, les espaces, le calendrier épinglé ;
- clics mpris (gauche lecture / pause, milieu précédent, droit suivant) et molette mpris — non testés pour ne pas lancer ta musique ;
- Échap et ←/→ dans le calendrier épinglé (pas d'outil d'injection clavier installé) ;
- clic sur les mises à jour avec `paru -Syu` réel ; glisser le curseur de volume ;
- laptop (tests différés) : batterie, rétroéclairage (`brightnessctl`), modules masqués selon le matériel ; GPU AMD / Intel réels.

État laissé : Waybar et Dunst actifs, aucune instance `qs`, volume 0,46 non muet, notification de test retirée de l'historique Dunst.

## Prochaine étape

Phase 5 (tray, réseau, Bluetooth, disques, NordVPN), après validation.
