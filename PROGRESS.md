# Journal d'avancement

État courant seulement. L'historique détaillé des phases 0 à 10 est dans `docs/archive/PROGRESS.md` (à n'ouvrir qu'en cas de besoin).

## Environnement

- Machine : `terrier` — Arch, i9-9900K, RTX 2080 (nvidia-utils 615.78)
- **Quickshell 0.3.2** (paquet Arch `quickshell 0.3.2-1`)
- Sway 1.12, Hyprland 0.57.0 (**config Lua** : `hyprctl keyword` indisponible, `dispatch` en syntaxe Lua)
- Écrans : DP-1 (LG 27GN950, gauche, scale 1.5), DP-2 (Dell AW3418DW, centre, principal), DP-3 (LG 27GN950, droite, scale 1.5) ;
  espaces DP-2 = 1-3, DP-1 = 4-6, DP-3 = 7-9

## Phases

| Phase | Contenu | État |
|---|---|---|
| 0 | Audit | faite (2026-10-15) |
| 1 | Squelette | faite (2026-10-15) |
| 2 | Espaces de travail, horloge | faite (2026-10-15) |
| 3 | Écrans dynamiques | faite (2026-10-16) |
| 4 | Modules système de la barre | faite (2026-10-16) |
| 5 | Tray, réseau, Bluetooth, disques, NordVPN | faite (2026-10-16) |
| 6 | Notifications | faite (2026-10-16) |
| 7 | Lanceur | faite (2026-10-16) |
| 8 | Menus, panneau de réglages, menu d'applications, scripts | faite (2026-10-17) |
| 8b | Fond d'écran, verrouillage, veille, polkit, capture, statistiques | faite (2026-10-19) |
| 9 | Parité Hyprland | faite (2026-11-03) |
| 10 | Bascule (configs dans `dotfiles/`, lancement par `scripts/desktop.sh`) | faite (2026-11-03), revues et audit du démarrage le 2026-11-04 ; en attente de tes tests de connexion ci-dessous |
| 11 | Écran de connexion (greetd + greeter Quickshell au design du verrouillage) | faite : mise en place système (greetd activé, SDDM désactivé) ; vraie connexion Hyprland par greetd avec trousseau déverrouillé constatée le 2026-11-08 |
| 12 | Portabilité (`install.sh`, `deps/`, laptop) | **en cours** (plan validé le 2026-11-09, voir ci-dessous) |

Retour arrière de la bascule : `docs/ROLLBACK.md`.

## Phase 12 — portabilité (en cours, 2026-11-09)

- `deps/` : `arch-pacman.txt` (bureau), `apps.txt` (applications de base retenues avec toi), `games.txt` (profil jeux,
  jamais automatique), `gpu.txt` (VA-API, `nvidia-smi`, Vulkan 32 bits selon la carte), `themes.txt` (archives Catppuccin
  officielles, empreintes SHA-256). Polices d'icônes par paquets officiels. Aucun AUR sauf `paru-bin`.
- Dotfiles des applications : fastfetch (reprise fidèle du thème neofetch : seuls écarts, ligne DE/WM désormais détectée et nom
  complet du CPU), starship, mpv et options Chromium en partie commune + machine (`hosts/terrier.conf` = réglages Nvidia
  actuels, défaut `hwdec=auto-safe`), dconf (GTK, Nemo, Celluloid, profil GNOME Terminal Catppuccin Mocha officiel), applications
  par défaut, bloc `~/.bashrc`, Viewnior, `smb.conf` (partages utilisateur pour les VM).
- `install.sh` : `--dry-run`, `--uninstall`, `--with/--without jeux`, `--no-packages`, `--no-system`, `--yes` ; registre et
  sauvegardes `<x>.bak-<date>` ; étapes système via `greeter-setup.sh`, `network-setup.sh` et le nouveau `system-setup.sh`
  (multilib, Samba, services, groupes, `QT_QPA_PLATFORMTHEME`, curseur pour le greeter dans `/usr/local/share/icons`).
  Thème : GTK 3/4, curseur, Kvantum, dossiers Papirus verts en surcouche dans le compte (aucun fichier de `/usr/share` touché),
  btop, Geany ; Qt passe de KvArcDark + breeze à Kvantum Catppuccin + Papirus-Dark + Inter. `README.md` d'installation.
- Tests : `python3 scripts/test-install.py` (dossier personnel jetable, bus privé) : simulation sans écriture, installation,
  second passage sans aucun changement, retrait qui remet dossier personnel et dconf à l'identique : **0 échec**.
  GitHub a renvoyé des 504 sur l'archive du curseur pendant les essais : délais curl ajoutés, une archive indisponible
  n'arrête plus le reste ; l'archive vérifiée du matin a servi au dernier passage.
- `install.sh --dry-run` sur ce desktop : 5 paquets à installer (`power-profiles-daemon`, `adobe-source-code-pro-fonts`,
  `noto-fonts-cjk`, `fastfetch`, `spotify-launcher`) et les changements visibles listés ci-dessous. **Rien n'est appliqué
  ici** tant que tu ne l'as pas validé.
- VM : image officielle Arch « basic » du 2026-11-01 (empreinte vérifiée) dans `~/.cache/qs-desktop-vm`, disque overlay,
  QEMU lancé en utilisateur (libvirt et ton ancienne image non touchés). Simulation complète sans écriture : OK.
  Installation réelle `--yes --without jeux` : 747 paquets, `paru-bin` construit, thème, réglages, greetd, Samba, services ;
  reprise après un 504 GitHub en relançant ; passages suivants : **0 changement**. Redémarrage : écran de connexion greetd
  affiché, vraie connexion Sway au clavier, bureau complet (barre, tray, espaces) ; Nemo (GTK) et qt6ct (Qt/Kvantum)
  homogènes, dossiers verts. `--uninstall --yes` : liens, thème, bloc `.bashrc`, dconf, `pacman.conf`, `/etc/environment`,
  groupes, services remis ; greeter fini au redémarrage suivant (prévu). Corrigés en route : `--noconfirm` avec `--yes`,
  ordre services → sonde réseau, copie du greeter et sonde sautées si à jour, simulation sur machine nue.
  Constats VM : NetworkManager prend le nom d'hôte du DHCP de QEMU (fichier `hosts/` à ce nom) ; premier lancement de
  Chromium (conditions d'utilisation) et de Spotify par l'autostart.
- Changements visibles à valider avant l'application sur ce desktop : dossiers Papirus lavande → verts ; palette GNOME
  Terminal ancienne Catppuccin → Mocha officielle ; thèmes btop / Geany à jour (cadres de btop un peu différents) ; Qt en
  Catppuccin ; `smb.conf` sans la section imprimantes ; lanceurs des web apps ouverts sur leur accueil (`deps/README.md`).

## Maintenance — workspace Spotify sur le mauvais écran au démarrage (2026-11-08)

- Incident capturé après logout/relogin : Spotify bien sur 6, mais workspace 6 rattaché au centre ; répartition calculée correcte
  (4–6 à gauche). Aucun déplacement du 6 dans les traces de placement initiales ; redécouvert nativement au premier clic.
- Course Quickshell 0.3.2 reproduite sur sockets privés : création du 6 pendant la lecture initiale, puis réponse antérieure
  sans le 6 qui le retire du modèle. Les rafraîchissements ordinaires ne recréent pas les espaces absents. Même test avec
  l'ancien code : échec attendu (aucun déplacement du 6) ; code corrigé : un seul déplacement vers la gauche.
- Avant placement Hyprland, lecture directe bornée de ses espaces ; complète seulement les données natives absentes/incomplètes.
  Événement structurel pendant une lecture : réponse invalidée puis relue. Créations conservées pendant la stabilisation et
  la vérification. Trois tentatives au plus sur échec IPC ; pas de scrutation au repos ni de délai ajouté aux applications.
- Test persistant `python3 scripts/test-workspace-startup.py` : course initiale, réponse retardée, deux échecs puis succès,
  échec permanent borné, destruction pendant la lecture, créations simultanées et déplacement manuel conservé : OK.
- Suites `test-outputs.sh sway` / `hyprland` sur copie figée : 0 échec (22 / 23 placements), focus et vues conservés.
  Premiers passages invalidés par un rechargement de la copie pendant le test, puis entièrement relancés sur copie figée.
  Démarrages complets des deux backends : OK, avertissements habituels des portails/bus privés et PipeWire privé absent seulement.
- Activation réelle : rechargement réussi, PID bureau 464800 conservé ; Spotify PID 464781 inchangé, 6 → DP-1, centre → 1.
  Bascules 6/1 validées ; trois barres et trois fonds, aucune instance/banc restant. Capture `.shots/spotify-workspace6-left.png`.
  Aucun réglage système ni action VPN. Dépendances déjà présentes (`hyprctl`, `timeout`) documentées.
- Reste à confirmer : prochaine vraie connexion/reconnexion, sans devoir cliquer sur 6 pour corriger son écran.

## Maintenance — ouvertures par origine Deluge / Thunderbird / Steam (2026-11-08)

- Besoin corrigé : tout contenu ouvert par ces trois applications doit afficher sa destination sur l'écran principal,
  vidéos, documents et dossiers compris ; la règle ne dépend ni de Chromium, ni d'une extension, ni du workspace source.
  Les lancements manuels restent sur leur espace. Les propres fenêtres des trois applications gardent leurs affectations.
- `open-origin.py`, processus géré par `Compositor`, suit les lancements GIO et les demandes natives GApplication/GTK CommandLine,
  FileManager1, portails et MPRIS ; les fenêtres des enfants directs sont suivies aussi. PID + identité noyau vérifiés ;
  contexte éphémère en mémoire, aucun chemin/URI journalisé ou persisté. Fenêtre cible affichée sur `Outputs.primary`,
  lecteur déjà ouvert compris. Pas de scrutation périodique au repos ; suivi seulement pendant une ouverture.
- Correction du transfert visible signalé avec Celluloid : sous Hyprland, `lua/openorigin.lua` s'exécute dans le traitement
  natif de mapping (`window.open`), avant que le compositeur reprenne le rendu. Destination connue via l'identité PID/démarrage
  publiée dans le runtime, ou ascendance native ; aucune correction asynchrone des nouvelles fenêtres. Animation de transfert
  neutralisée pendant 100 ms puis réglages configurés restaurés. Lecteur réutilisé : placement dès la demande d'ouverture,
  sans attendre le changement de titre. Les règles de workspace explicites sont conservées si leur écran est déjà le principal.
- Contrôle sur banc Hyprland, animations activées : callback de vérification exécuté dans le même mapping après la règle ;
  nouvelle fenêtre GTK, vrai Celluloid et enfant Steam déjà sur CENTER. Pas de déplacement tardif servant de filet de sécurité.
  Sway conserve le suivi IPC après création : destination vérifiée, mais pas de garantie avant premier rendu sur ce backend.
- HTTP depuis ces sources : préférence précédente conservée (fenêtre Chromium centrale réutilisée, sinon nouvelle fenêtre).
  Le lanceur vérifie désormais l'origine auprès du suivi ; les autres sources ne sont pas redirigées. Hôte des web apps
  revenu à son mécanisme de focus précédent. Aucune nouvelle association de fichiers ni changement de lecteur par défaut.
- Tests de politique (13 cas) : publication avant mapping Hyprland, lecteur existant déplacé dès la demande, origines et PID, nouvelle fenêtre et lecteur existant, documents arbitraires, fenêtre manuelle,
  réutilisation de PID, requêtes expirées et non-persistance des URI. Tests de routage navigateur et installation : 9 cas ; transmission Chromium : 4 cas.
- Bus privés et vrais lecteurs : trois origines contrôlées, vidéo/document/autre contenu, même fichier ouvert manuellement,
  lecteur réutilisé ; Sway et Hyprland. Vrai `deluge.common.open_file` → `xdg-open` → Celluloid avec vidéo locale de test,
  puis Celluloid déjà ouvert sur le secondaire : validés sur Hyprland. Enfant Steam lancé directement, sans GIO : validé.
  Tous les groupes de test arrêtés ; aucun mail, torrent, jeu ou document utilisateur ouvert/modifié, aucune action VPN.
- Activation réelle : hook Hyprland rechargé sans erreur, suivi PID enfant du bureau ; écran principal validé contre les sorties
  actives pour ne jamais conserver un diagnostic IPC de démarrage comme nom d'écran. Test d'une fenêtre factice issue de Deluge
  depuis 7 → écran principal ; Chromium rapide manuel sur 7 et 8 → leurs espaces. Fenêtres de test fermées, focus, espaces visibles
  et pointeur restaurés ; bureau PID 7098 conservé. Répartition des écrans : Sway et Hyprland, 0 échec.
- Reste à confirmer à la main : vrais clics depuis les trois applications, lecteurs habituels et prochaine connexion Sway.

## Maintenance — Chromium rapide rétabli après correction (2026-11-08)

- Lanceur SingletonSocket d'Omarchy rétabli pour Super+A / Super+C et le lanceur Quickshell ; entrée desktop surchargée sans
  argument comprise. Transmission native avec ACK ; repli sur Chromium normal si profil/flags incompatibles, socket absent
  ou socat indisponible. Aucun préchargement, décodage vidéo matériel conservé.
- Dernière série isolée, règle d'origine et hook natif actifs, ordre ABBA, 8 échauffements + 24 mesures par méthode : médiane
  104,1 → 74,9 ms, gain 29,2 ms (28,0 %). Seuil convenu 15 ms / 10 % de nouveau atteint. Mesure jusqu'au mapping, pas au pixel.
- Vérification combinée : 6/7/8 manuels correctement conservés avec le lanceur rapide ; vrais liens HTTP locaux depuis une
  origine Thunderbird contrôlée → fenêtre centrale créée puis réutilisée ; vrai Celluloid nouveau/réutilisé et enfant Steam.
- Démarrage complet Quickshell des deux compositeurs : OK, avertissements habituels du bus privé seulement.

## Maintenance — liens externes au centre, lancements manuels libres (2026-11-08)

- Intention clarifiée : les liens HTTP/HTTPS depuis Thunderbird, Deluge, Steam et les autres applications doivent afficher
  une fenêtre Chromium sur l'écran principal ; réutiliser une fenêtre centrale existante, sinon en créer une. Un lancement
  manuel doit rester sur son workspace, y compris 6/7/8. Le cas 1 est éclairci : fenêtres masquées par le plein écran.
- Anciennes règles globales de renvoi de 7/8 retirées des fichiers machine Sway et Hyprland. Aucun changement des raccourcis
  manuels ni de `file-open-focus`. `Outputs` expose son écran principal via l'IPC en lecture seule `primaryName`.
- `scripts/browser-link.py` traite seulement les URL HTTP/HTTPS : fenêtre du profil principal déjà sur l'écran principal
  choisie selon le focus, activation puis transmission native ; sinon nouvelle fenêtre. Les fenêtres des autres écrans et
  les profils isolés ne sont pas déplacés. Sans URL ou avec un fichier local : lancement Chromium normal. Repli natif si le
  bureau ne répond pas ; pas de réémission après livraison, liens sérialisés pour éviter les créations simultanées.
- `browser-links-setup.py` génère la surcharge utilisateur `chromium.desktop` depuis le paquet : seule l'Exec principale
  change, identité MIME, traductions et actions conservées. Installation idempotente sans sudo, simulation et retrait ;
  sauvegarde d'une ancienne surcharge native, refus de commande personnalisée ou d'édition ultérieure. Aucun paquet ajouté.
  L'hôte natif des web apps utilise le même chemin après nettoyage de son environnement. Procédure dans `deps/README.md`.
- Tests persistants de sélection/réutilisation, création, fichiers locaux, repli, ordre Sway, installation répétée,
  simulation, restauration et préservation des éditions : OK. Bancs Chromium réels sur pages HTTP locales, profils jetables :
  création/réutilisation centrale, ouvertures manuelles 6/7/8, aucun déplacement des fenêtres manuelles, navigateur arrêté : OK
  sous Hyprland ; création/réutilisation, fenêtre manuelle sur l'autre écran et navigateur arrêté : OK sous Sway headless.
- Démarrages complets Quickshell et nouvelle requête IPC : OK sur les deux compositeurs (avertissements habituels du bus privé
  uniquement). `scripts/test-outputs.sh sway` et `hyprland` : 0 échec, état du banc restauré et groupes arrêtés.
- Lecture et lancement du vrai fichier desktop par GIO, avec commandes factices : sans URL → natif, URL → routage, chemin
  avec espaces et caractères URL spéciaux préservés, aucune livraison en double : OK.
- Activation réelle : surcharge utilisateur installée et validée, associations HTTP/HTTPS conservées sur `chromium.desktop`,
  écran principal IPC = DP-2 ; configuration Hyprland rechargée sans erreur, bureau PID 7098 conservé.
  Fenêtres manuelles vérifiées sur 6 et 7 ; contrôle 8 rendu non ambigu par un titre unique et un lancement atomique : fenêtre
  sur 8, écran de droite, pointeur au bon endroit. Fenêtres de test fermées, espaces/focus/pointeur initiaux restaurés.
- Reste à confirmer à la main : vrais clics de liens Thunderbird / Deluge / Steam et des web apps, et prochaine connexion Sway.
  Une application configurée pour appeler directement un binaire de navigateur contourne le lanceur desktop.

## Maintenance — diagnostic du placement Chromium (2026-11-08)

- Attribution initiale à l'optimisation trop rapide : le mauvais placement depuis 7/8 se reproduit avec la commande native,
  optimisation déjà retirée. Aucun lien causal établi entre le lanceur rapide et ces symptômes.
- Source confirmée : `ws7-to-center` / `ws8-to-center` dans `dotfiles/hypr/hosts/terrier.lua`, introduites le 2026-11-03
  (`2ee959d`). Toute nouvelle fenêtre sur 7/8 est envoyée sur le moniteur central sauf Deluge/Thunderbird respectivement ;
  elle rejoint son espace actuellement visible (1 pendant les essais). Ce comportement correspond à l'ancienne configuration.
- Contre-épreuve sur trois écrans jetables, pointeur placé sur l'écran demandé : sans ces règles, ouvertures natives sur 1/7/8
  correctement placées ; avec elles, 7/8 → 1. Même résultat avec `file-open-focus` activée, désactivée, puis réactivée.
  Le commit `19b33de` (focus des applications à l'ouverture de fichiers) n'est donc pas nécessaire au problème reproduit.
  Le plus récent `b30f990` change seulement l'animation de la couleur des bordures.
- Tests autorisés sur la session réelle : `chromium` et `chromium --new-window about:blank` depuis 1/7/8, avec pointeur au
  centre du bon écran. Résultats identiques : 1 → 1, 7 → 1, 8 → 1. Puis deux fenêtres vides sur 1, la première en plein écran :
  la seconde est créée sur 1 mais reste derrière la première ; `misc.on_focus_under_fullscreen = 0` conserve le plein écran.
  Un mauvais placement depuis 1, hors plein écran, n'a pas été reproduit.
- Fenêtres de test identifiées puis fermées, état initial des espaces/focus/pointeur restauré ; aucun profil ni fenêtre
  utilisateur déplacé ou fermé, aucun réglage de profil modifié, aucune action VPN. Tous les bancs arrêtés, bureau PID 7098 vivant. Pas de changement des règles actives.
- Décision demandée : conserver le renvoi de Chromium depuis 7/8 ou l'exclure de ces deux règles. L'optimisation reste retirée.

## Maintenance — lancement Chromium : retour au lancement natif (2026-11-08)

- Optimisation Omarchy déployée puis retirée après ton signalement : demandes depuis les workspaces 1, 7 et 8 apparemment sans
  résultat. Inspection réelle : de nombreuses fenêtres Chromium sur le workspace 1, qui contient une fenêtre plein écran.
  Tu confirmes ensuite un problème de placement sur un autre workspace : la demande atteint Chromium ; aucun plantage établi.
- Rétablissement des appels `chromium` d'origine pour Super+A / Super+C sous Sway et Hyprland et de `Apps.launch` natif.
  Lanceur expérimental, test dédié et dépendance optionnelle `socat` retirés. Aucune fenêtre réelle fermée ou déplacée,
  aucun profil modifié, aucun changement de décodage vidéo ni préchargement.
- Résultats de performance conservés dans `docs/PERFORMANCE.md` avec mention du retrait : le gain global de 22,4 ms ne valide
  pas la gestion des workspaces. Les tests précédents, sur un seul workspace, ne permettaient pas d'établir la cause du symptôme.
- Retour arrière appliqué : raccourcis Hyprland rechargés sans erreur, QML rechargé avec succès, bureau PID 7098 conservé ;
  trois barres et trois fonds vérifiés. Les fichiers de lancement sont identiques à ceux d’avant l’optimisation.
- Avant toute nouvelle tentative : contre-épreuve native/directe sur plusieurs workspaces et écrans avec plein écran,
  contrôle de l'activation et du placement. Aucune nouvelle optimisation en place.

## Maintenance — diagnostic Thunderbird après reconnexion (2026-11-08)

- **Suivi obligatoire (BACKLOG.md)** : résoudre le vrai blocage, puis retirer les scripts de diagnostic / tests dédiés,
  le branchement Hyprland et les références actives. Instrumentation **temporaire**, à exclure de l'installateur final ;
  contrôle requis avant finalisation de la phase 12. Le correctif reste à établir et à valider.

- Blocage utilisateur **non reproduit** sur quatre essais à profil vide (deux Sway headless, deux Hyprland imbriqués) :
  arrêt normal en environ 1,2 s. Logind actif : `KillUserProcesses=false`, ancienne session abandonnée avec Deluge ;
  aucun ancien Thunderbird au moment de l'inspection. Sorties du Thunderbird réel vers `/dev/null`, aucun rapport de plantage.
  Une instance restée verrouillée après logout est une hypothèse, pas une cause interne démontrée.
- À ta demande, instrumentation ciblée : Hyprland garde son délai de 4 s puis lance `thunderbird-diagnostic.py run`.
  Capture préalable des processus du même UID, identité noyau, cgroups / sessions logind, affichages, threads et verrous ;
  sorties et code de sortie conservés. Aucun arrêt ni relancement automatique d'une instance existante ; Sway inchangé.
- Captures privées sous `$XDG_STATE_HOME/qs-desktop/thunderbird-diagnostic` (repli `~/.local/state`) : dossiers 700, fichiers 600,
  cinq derniers enregistrements par type, plus les anciens encore actifs. Arguments, comptes et mails non lus / non copiés dans
  les métadonnées. Les sorties applicatives peuvent contenir des informations privées : contrôler avant partage.
  Diagnostic indisponible : lancement normal préservé. Python et loginctl déjà présents, dépendances documentées.
- Sept tests persistants passants : sorties / code / arguments, permissions et rotation, journal actif conservé,
  repli sans diagnostic, erreur d'écriture des métadonnées, processus survivant **simulé** avec vrai verrou, logind absent.
  Vrai Thunderbird jetable sous Hyprland et bus privé : fenêtre ouverte après délai, capture manuelle, fermeture du compositeur,
  sortie 0 et message de fermeture propre capturés. Aucun mail réel lu, aucune action VPN, tous les groupes de test arrêtés.
  Syntaxe Lua et callback autostart testés sans exécuter ses commandes ; chemin avec espaces / apostrophe vérifié.
- Après intégration : aucune erreur de configuration Hyprland, bureau PID 7098 et Thunderbird PID 7091 vivants ;
  une seule instance Hyprland et aucun banc restant. Aucun fichier QML ni configuration système modifié.
- Activation automatique à la **prochaine connexion Hyprland**. Lors du prochain blocage, avant de tuer Thunderbird :
  `python3 ~/.config/quickshell/desktop/scripts/thunderbird-diagnostic.py snapshot` ; conserver le dossier affiché.
  Reste : capture d'un vrai incident pour identifier l'instance qui détient le verrou et la raison de sa survie.

## Maintenance — bordures au changement de workspace Hyprland (2026-11-08)

- Diagnostic reproduit : le focus arrive immédiatement, mais la couleur de bordure interpole depuis son état inactif.
  Comparaison visuelle A/B sur banc : désactiver l'animation `border` donne directement la couleur active.
- Selon ton choix : animation `border` désactivée pour toutes les prises de focus, y compris au survol. Focus mémorisé,
  focus au survol, autres animations et configuration Sway conservés ; aucun changement QML ni dépendance ajoutée.
- Copie isolée : syntaxe Lua et configuration complète valides ; restauration du focus mémorisé vérifiée. Les nouvelles
  captures imbriquées ont bloqué (screencopy) et le survol simulé n'a pas conclu ; captures A/B du diagnostic conservées
  dans `/tmp/hf-knk6nh5j/`. Reste à confirmer à la main : bascules de workspace et vrai survol entre deux fenêtres.
- Application réelle : configuration rechargée sans erreur, animation `border` effectivement désactivée ; bureau PID 7098
  vivant, trois barres et trois fonds présents, une seule instance Hyprland et tous les bancs arrêtés. Aucun changement VPN.

## Maintenance — corrections ciblées de robustesse (2026-11-08)

- Retrait du greeter : suppression globale de `/var/lib/qs-desktop` remplacée par le nettoyage de son propre état/cache et de
  ses registres après restauration. Sauvegardes réseau/OpenRGB, verrou réseau, fonds utilisateur et fichiers étrangers conservés.
  Service greetd actif : nettoyage différé comme avant ; sauvegarde manquante : registre et ancien gestionnaire conservés.
- Veille : inhibition libérée à la confirmation du verrouillage, sans échéance QML de 2 s ; logind garde son plafond
  `InhibitDelayMaxSec`. Écoute des événements et inhibiteur relancés après 5 s s’ils s’arrêtent alors qu’ils sont attendus ;
  libération volontaire respectée même après une relance, réarmement au réveil. Aucun nouveau service ou paquet.
- Tests persistants : `python scripts/test-greeter-cleanup.py` et `python scripts/test-sleep.py`, fichiers temporaires,
  bus privé et commandes système factices. Confirmation retardée, veille/réveil simulés, arrêt des deux processus,
  reprise puis nouvelle libération volontaire : OK. Les deux tests échouent sur l’ancien code pour les défauts attendus.
  Suite existante `test-idle-inhibit.py` : OK. Démarrages complets sur copie Sway headless / Hyprland imbriqué : OK,
  avertissements habituels des entrées desktop / portails et PipeWire absent du runtime privé seulement.
- Application réelle : rechargement réussi, PID 7098 conservé, trois barres et trois fonds présents ; avertissements Bluez
  déjà connus uniquement. Tous les bancs arrêtés.
- Aucune suspension, authentification, action NordVPN ni modification de configuration système. Greeter non installé/activé.
  Reste à vérifier à la main sur laptop : vraie suspension/réveil avec verrouillage (phase 12) ; vraie connexion greeter (phase 11).

## Maintenance — moniteur en fenêtre classique (2026-11-06)

- À ta demande, MonitorPanel passe de la surcouche OverlayPopup à une FloatingWindow native. Même contenu et dimensions,
  centrée dans la zone utile de l’écran de la barre cliquée ou de l’écran focalisé pour le raccourci. Coins et bordures gérés
  par Sway/Hyprland : cadre QML rectangulaire sans bordure, aucune règle de décoration imposée au compositeur.
- Ouverture ciblée via Compositor (PID courant + titre, puis identifiant natif), flottement/centrage/focus ; recentrage après
  chargement des cartes et changement de taille sans reprise de focus. Échap et bouton de barre conservés ; clic extérieur
  laisse la fenêtre ouverte. Pas d’inscription parmi les popups ni de surfaces d’interception. Fermeture au verrouillage.
- Compteur de relevés rendu idempotent : Hyprland émet parfois plusieurs visibleChanged avec la même valeur. Tests QML
  persistants couvrant ces notifications répétées, fermeture et retour du compteur à zéro ; recherche, tri et animation : OK.
- Bancs sur copie : démarrages complets Sway headless et Hyprland imbriqué sans erreur du changement. Fenêtre reconnue flottante
  et focalisée ; deux fermetures/réouvertures via l’action native de Super+Q, fenêtre jetable derrière et processus Quickshell
  conservés, relevés arrêtés : OK sur les deux. Ouverture depuis un second écran virtuel alors que le premier est focalisé : OK
  sous Sway. Fixture et script persistants scripts/tests/monitor/window-{shell.qml,check.py}, réservés à QS_TEST=1.
- Application réelle : bureau rechargé, PID 1753 vivant ; Hyprland confirme une fenêtre native flottante et focalisée,
  1100x912 logiques. Fermeture ciblée du seul moniteur puis focus initial restauré. Captures vérifiées :
  `.shots/monitor-floating-sway.png` (coins carrés, bordure du compositeur) et `.shots/monitor-floating-hyprland.png`
  (coins et bordure Hyprland). Tous les bancs arrêtés.
- Avertissements connus des entrées desktop, portails et textinput du banc seulement. Aucun processus utilisateur arrêté,
  aucune action NordVPN. Reste à vérifier à la main : vrais clics et Super+Q sur les écrans habituels, déplacement par le raccourci
  du compositeur. Les tests automatisés emploient exactement l’action du raccourci, pas un événement de touche physique.

## Maintenance — moniteur applications et couleurs (2026-11-06)

- Jauges CPU teal, mémoire green, GPU sky, disques blue ; une seule teinte par carte, valeurs de Theme.
- Vue Applications à chaque ouverture, y compris les applications identifiables en arrière-plan ; ressources additionnées,
  nombre de processus. Bascule compacte à gauche de la recherche, pastille verte et icônes application / processeur,
  navigation clavier ; les grands onglets de la première proposition ont été remplacés selon ta demande.
- Identité desktop + arguments / profils Chromium et PID des fenêtres (Hyprland natif, IPC Sway). Instances regroupées,
  applications indépendantes séparées dans l’arbre, orphelins suivis. Chromium, Discord et WhatsApp distincts, y compris
  leurs rapports de plantage ; Steam et Terminal identifiés via leurs fenêtres. Hôte partagé : arrêt groupé désactivé.
- Arrêt avec confirmation, SIGTERM / SIGKILL ; instances confirmées conservées, nouveaux descendants inclus, nouvelles
  instances indépendantes exclues. UID et starttime contrôlés avec pidfd ; erreurs visibles. API stop(pid, force) conservée.
- Tests sur copie : 10 tests Python passants, dont trois vrais Chromium headless à profils temporaires : TERM navigateur,
  KILL première webapp, seconde webapp toujours vivante ; aucun membre des groupes arrêtés encore vivant. Tests QML sur
  Sway headless et Hyprland imbriqué : sommes, tri, gel de sélection, bascule, disparition et ouverture par défaut : OK.
  Démarrages complets sans nouvel avertissement du changement ; avertissements connus desktop entries / portails du banc.
  Capture du toggle compact vérifiée sur Sway. Aucune application réelle arrêtée, aucune action NordVPN.
- Application réelle rechargée : PID 1753 vivant, trois barres et trois fonds présents. Panneau ouvert puis refermé sans
  erreur du changement ; capture recadrée `.shots/monitor-applications-panel.png`. Tous les bancs arrêtés.
- Ajustement demandé ensuite : bascule déplacée avant le champ de recherche, à gauche, pour fixer sa position lorsque les
  actions de sélection apparaissent. Rendu et tests QML sur copie Sway headless : OK ; bureau réel rechargé et vivant.
- Comportement du toggle ajusté : une seule zone de clic sur toute la pilule, clic à gauche/droite ou sur les marges →
  inversion systématique de la vue ; un seul arrêt de tabulation, Entrée/Espace et action d’accessibilité. Pastille coulissante,
  transition OutCubic de 250 ms reprise du thème ; retour à Applications à l’ouverture sans animation parasite.
  Tests du vrai gestionnaire de clic (clics répétés) sous Sway/Hyprland : OK ; position intermédiaire et finale de l’animation
  vérifiées par minuteries QML sur Sway. Aucune application arrêtée, aucune action NordVPN.
- Finition demandée : infobulle supprimée ; glyphes Applications/Processes centrés sur leur dessin réel (tightBoundingRect),
  pour corriger le décalage optique de l’icône CPU. Deux positions inspectées sur captures du banc Sway ; tests QML existants,
  y compris clic global et animation, passants. Aucun changement de comportement ni arrêt d’application.
- Palette ajustée à ta demande : GPU bleu ciel (`sky`), disques bleu (`blue`), CPU/mémoire conservés. Jauges uniformes par carte.
  Capture et démarrage complet sur copie Sway vérifiés, tests QML passants ; thème réel rechargé.
- Reste à vérifier à la main : clic physique sur la bascule et confirmations, confort de lecture sur les écrans habituels.

## Maintenance — portails captifs Wi-Fi (2026-11-06)

- Audit : la détection native et le libellé existaient ; aucune ouverture de portail. Reprise du principe d'Omarchy : sonde
  NetworkManager, bouton explicite, adresse HTTP fixe et nouvelle vérification pendant l'identification. Navigateur par défaut
  retenu avec toi ; configuration système alignée pour la portabilité, activation après validation des fichiers préparés.
- Carte : bouton « Open Captive Portal » seulement pour le réseau Wi-Fi connecté concerné. Le panneau libère son clavier avant
  `Launch.exec(["xdg-open", …])`. Aucun lancement automatique, aucun changement VPN. Le service ignore les résultats périmés si
  les sondes sont désactivées ; vérifie à la connexion / ouverture épinglée et toutes les 10 s pendant portail / accès limité,
  même panneau fermé, une seule minuterie pour toutes les barres. Internet rétabli ou radio coupée : minuterie arrêtée.
- Configuration versionnée : `dotfiles/NetworkManager/conf.d/90-qs-desktop-connectivity.conf`, même adresse HTTP que la carte,
  `response=` vide (204). `scripts/network-setup.sh` : simulation, installation idempotente, sauvegarde/restauration et relecture
  `nmcli general reload conf` seulement ; mode `--root` sans sudo ni effet système pour les tests. Documentation et dépendances
  mises à jour dans `docs/NETWORK.md` et `deps/` ; reprise prévue par `install.sh` en phase 12. Aucun paquet installé.
- Tests persistants `scripts/test-network.py` : simulation sans écriture, répétition, sauvegarde initiale conservée, permissions,
  restauration avec/sans ancien fichier, conservation des éditions locales, sauvegarde incomplète et égalité des URI : OK.
  Code QML courant sur copies, backend et lancements factices : portail / complet / limité, clic via le vrai gestionnaire de
  `WifiPanel`, commande navigateur, vérifications panneau fermé, sondes désactivées, radio coupée, route Ethernet, reconnexion,
  aperçu / panneau épinglé et plusieurs panneaux : OK sous Sway headless et Hyprland imbriqué. Minuterie accélérée dans la copie
  de test seulement. Le clic physique et les touches du bouton restent à vérifier à la main.
- Démarrage complet de la copie sous les deux compositeurs : aucune erreur QML du changement. Avertissements habituels des
  portails / entrées desktop et PipeWire indisponible dans le runtime privé. Capture de carte vérifiée sous Sway :
  `.shots/wifi-captive-portal.png`. Capture Hyprland non concluante (échec du screencopy imbriqué) ; tests fonctionnels passants.
  Syntaxe Bash/Python et `git diff --check` : OK. Bancs arrêtés ; application réelle rechargée sans erreur, PID 1753 vivant,
  trois barres et trois fonds présents. Aucune action NordVPN.
- Activation système autorisée puis effectuée (2026-11-06) : `scripts/network-setup.sh install`, authentification sudo dans un
  terminal local. Fichier installé identique au dépôt, root:root / 644 ; aucun ancien fichier à sauvegarder, registre de retour
  arrière présent. Relecture de configuration réussie, URI effective `http://ping.omacom.io/nm-check.txt`, sondes activées ;
  `nmcli networking connectivity check` → `full`. Bureau réel PID 1753 toujours vivant ; aucun redémarrage réseau ni action VPN.
- **Reste :** essai sur un vrai réseau d'hôtel / aéroport : ouverture du formulaire, clic physique / clavier, validation, retour
  automatique à « Connected » et navigation.

### Revue des portails captifs — passe 1 (2026-11-06)

- **P2 — sauvegarde écrasée par deux installations simultanées** : deux scripts peuvent tous deux constater l'absence du
  registre, notamment pendant la première authentification sudo. Le second sauvegarde alors le fichier déjà installé à la
  place de l'original. Reproduit avec de vrais fichiers temporaires et un ordonnancement contrôlé ; le nouveau test échoue
  sur l'ancien script. Revue high des fichiers entiers : même constat, aucun autre P1/P2 étayé.
- Correction : verrou `flock` stable hors du registre, acquis avant de l'inspecter et conservé pendant toute installation ou
  désinstallation. Deux tests persistants contrôlent la concurrence avec et sans ancien fichier. Nettoyage des tests par groupe
  de processus, y compris après échec. Dépendances et procédure documentées.
- Vérifications sur copie : suite système et QML complète, démarrage complet Sway headless, syntaxe Bash et diff : OK.
  Aucun changement de rendu ni de fichier QML de production ; avertissements du banc privé connus seulement. Aucun appel sudo,
  rechargement réseau ou changement VPN pendant cette revue. Correction appliquée au dépôt ; configuration système active conservée.

### Revue des portails captifs — passe 2 et arrêt (2026-11-06)

- Nouvelle revue high de tous les fichiers complets et de leurs appelants, après correction : aucun P1/P2 restant étayé.
  Relecture du bouton, des transitions réseau, du lancement du navigateur, des échecs, du verrou et du retour arrière.
- Complément sur fichiers temporaires : 24 opérations concurrentes mêlant installation et désinstallation, puis retour arrière
  final ; contenu et permissions d'origine conservés. Les tests persistants système et QML ainsi que le démarrage complet de
  la passe 1 restent passants. Aucun fichier QML de production modifié par les revues.
- Arrêt de la série après cette passe sans problème significatif. Aucun changement de configuration système, aucune action
  NordVPN ; seul le script du dépôt et ses tests ont été corrigés. Le test sur un véritable portail reste à faire.

## Maintenance — veille pendant les vidéos Chromium (2026-11-05)

- Diagnostic : règles Chromium plein écran / Picture-in-Picture présentes seulement sous Sway ; aucun service
  `org.freedesktop.ScreenSaver` depuis le remplacement de hypridle. Hyprland réel : Chromium plein écran visible,
  `inhibitingIdle: false`. Banc Sway avant correction : inhibition plein écran effective même sans lecture.
- Choix retenu : suivre la lecture vidéo, en fenêtre, plein écran et Picture-in-Picture, libérer en pause / à la fin.
  Service Python/Gio `scripts/idle-inhibit.py`, protocole D-Bus standard, cookies par appelant et libération à la déconnexion.
  Aucun propriétaire D-Bus remplacé. Socket privé vers `Idle.qml` ; compteur positif → suivi désactivé, libération → nouveau délai.
  Règles Chromium de Sway retirées ; règles Firefox / jeux et inhibiteurs Wayland conservés.
- Cycle de vie : service porté par `desktop.sh`, indépendant du moteur QML ; rechargement et relance automatique de Quickshell
  conservent les cookies. Service relancé après plantage (5 tentatives au plus), arrêté avec sa surveillance. Déconnexion du pont :
  aucun blocage persistant de veille. Une relance complète manuelle ou un plantage du service perd les cookies existants :
  pause/reprise de la vidéo nécessaire. Dépendances Python / PyGObject déclarées, déjà présentes ; aucune installation.
- Tests sur copies et bus privés : contrat D-Bus (plusieurs cookies, propriété des cookies, déconnexion, rejeu à la connexion,
  collision de nom, chemin historique, nettoyage) ; superviseur factice (plantage du service, relance, TERM, sortie normale) : OK.
  Bureaux complets Sway headless / Hyprland imbriqué, Chromium jetable + vidéos locales : lecture en fenêtre / plein écran / PiP,
  pause, fin, fermeture, rechargement QML et reconnexion du pont : OK. Délai de test 3 s, aucun délai réel modifié.
  Les bancs ont produit les avertissements connus des entrées desktop, PipeWire absent du runtime privé et portails privés,
  ainsi que les avertissements de déconnexion volontaire du pont. Pas d'erreur QML du correctif.
- Limite distincte observée : audio seul sous Hyprland, compteur D-Bus nul mais Chromium 156 maintient un inhibiteur Wayland
  (`inhibitingIdle: true`). Aucun contournement qui ignorerait les inhibiteurs natifs. Sway autorise la veille avec l'audio du banc.
- Application réelle : relance sans erreur, bureau PID 62470 vivant ; `idle state` : pont prêt, délai 300 s conservé.
  Demande D-Bus de contrôle sur la vraie session : compteur 1 et suivi désactivé, puis déconnexion → compteur 0 et suivi actif.
  Trois barres et trois fonds vérifiés dans les couches ; capture `.shots/idle-fix.png`. Une seule instance Hyprland,
  aucune instance de banc restante. Tests de syntaxe Python / Bash et `git diff --check` : OK.
  Complément Hyprland : lecture toujours inhibée avec une autre application ouverte au premier plan : OK.
  Le test d'une surface Wayland synthétique n'a pas activé l'inhibiteur attendu : contrôle non concluant, aucun changement
  de cette logique existante ; bouton « garder l'écran allumé » et manette restent à vérifier à la main.
- Reste à tester à la main : lecture de plus de 5 minutes (y compris sans focus), pause de plus de 5 minutes,
  Picture-in-Picture, bouton « garder l’écran allumé », manette et nouvelle connexion Sway. Aucune action NordVPN ni suspension réelle pendant les tests.

### Revue de code de la veille — passe 1 (2026-11-05)

- **P1 — arrêt du pont bloquant la relance du bureau** : reproduit avec le service figé (SIGSTOP), un faux Quickshell et un bus
  privé. L'attente sans limite conservait le verrou du superviseur ; `restart` supprimait l'ancien shell mais ne pouvait pas
  lancer le nouveau. Correction : TERM, attente bornée à 1 s, KILL si nécessaire, puis nettoyage. Même test : relance réussie.
- **P2 — nom D-Bus publié avant ses méthodes** : pause d'ordonnancement simulée avant l'enregistrement ; demande immédiate →
  `UnknownMethod` sur l'ancien code. Enregistrement des deux chemins et du suivi des appelants avant `RequestName` : test passant.
- Tests persistants étendus : disponibilité immédiate, conservation des cookies pendant une relance automatique du shell,
  relance du pont après SIGKILL, arrêt du pont figé et réutilisation du verrou. Contrat initial, syntaxe Python / Bash et diff : OK.
  Préparation et tests sur copie ; application au service réel différée à la fin des passes de revue.

### Revue de code de la veille — passe 2 (2026-11-05)

- **P2 — cookie ancien libérant une nouvelle vidéo après un plantage du pont** : même appelant D-Bus conservé, première
  vidéo → cookie 1 ; pont tué, nouvelle vidéo → cookie 1 aussi ; libération de l'ancienne vidéo → compteur 0 à tort.
  Reproduit avant correction. Cookies uint32 non nuls aléatoires, unicité contrôlée parmi les demandes actives : test passant,
  sans réutilisation systématique après relance. Le nouveau test échoue sur le code de la passe 1.
- Contrôles complémentaires : 250 reconnexions de frontend, 250 déconnexions d'appelants et 30 appelants simultanés : compteur
  final nul, descripteurs stables (10 → 10). Aucune fuite ni cookie restant observé. Tests persistants des deux passes : OK.
  Sway complet sur copie avec Chromium jetable : fenêtre, perte de focus, plein écran, pause, fin, PiP et rechargement : OK.

### Revue de code de la veille — passe 3 et validation finale (2026-11-05)

- Relecture des fichiers complets après les deux corrections : aucun autre constat significatif. Vérifications des erreurs de
  démarrage, bornes des cookies uint32, ownership / déconnexions, reconnexion du frontend, garde PID et nettoyage du superviseur.
- Suite persistante complète : OK, dont contre-épreuves des trois bugs sur les versions précédentes. Syntaxe Python / Bash,
  `git diff --check` : OK. Bancs complets Sway et Hyprland avec Chromium local jetable : lecture en fenêtre, autre application
  au premier plan, plein écran, pause, fin, Picture-in-Picture, rechargement QML et reconnexion du pont : OK.
  Audio seul : aucune demande d'inhibition D-Bus ajoutée ; réserve sur l'inhibiteur natif Hyprland ci-dessus conservée.
- Application réelle des deux passes après une seule relance : aucune erreur de démarrage, PID 71424 vivant, délai 300 s conservé,
  pont prêt. Demande de contrôle acquise puis libérée : compteur 1 / suivi désactivé, puis 0 / suivi actif. Trois barres et trois
  fonds présents dans les couches, capture `.shots/idle-review.png` et bandeau `.shots/idle-review-bars.png` vérifiés.
  Aucune instance de banc restante ; une seule instance Hyprland. Aucune action NordVPN ni suspension réelle.
- Restent les tests manuels de durée réelle / nouvelle connexion / manette listés plus haut. Si une vidéo était déjà en lecture
  pendant la relance complète, pause/reprise pour renouveler sa demande D-Bus.

## Maintenance — curseur homogène (2026-11-05)

- Cause du flash rose violacé : `XCURSOR_THEME` vert, mais `HYPRCURSOR_THEME` absent. La bibliothèque Hyprcursor prend alors le
  premier thème disponible (ici `catppuccin-mocha-mauve-cursors`), avant le `hyprctl setcursor` vert de l'autostart.
- `HYPRCURSOR_THEME` vert ajouté à `dotfiles/hypr/lua/env.lua`, taille 48 conservée. Autostart et réglages Sway/greeter déjà verts
  conservés. Selon ton choix « tout le compte » : GTK 2/3, XSettings et héritage du thème utilisateur `default` alignés sur le
  vert, taille 48 ; GTK 4, dconf et Xresources déjà conformes. Autres préférences et fichiers système inchangés.
- Sauvegardes des quatre fichiers utilisateur modifiés : suffixe `.bak-20261105-220039`, à côté de chaque original. Procédure
  reproductible pour la phase 12 dans `deps/README.md` ; pas de nouveau paquet, pas de suppression des anciens thèmes.
- Vérification : syntaxe Lua et `Hyprland --verify-config` sur copie valides ; banc Hyprland imbriqué A/B, bus et runtime privés,
  sans autostart ni `setcursor` : ancien fichier → mauve, nouveau → vert dès l'initialisation, aucune erreur de configuration.
  Bancs arrêtés ; avertissements DRM/logind de la tentative de backend et XKB seulement. Le premier essai du banc avait un chemin
  de socket trop long et un bind de test incorrect : corrigés avant le passage A/B concluant.
- GTK 3/4 : thème et taille effectifs vérifiés sous Wayland et XWayland ; XCursor `default` et vert : pixels et hotspot identiques
  en taille 48. Clients Qt Wayland/X11 : variables XCursor vert/48 vérifiées ; pas de validation visuelle dans les applications.
  Avertissement accessibilité GTK du test uniquement. Seconde application des modifications utilisateur : aucun changement.
  Après application : bureau réel PID 14536 vivant, une seule instance Hyprland, aucune erreur de configuration.
- Reste à tester à la main : nouvelle connexion Hyprland sans flash rose/mauve et survol des applications usuelles (GTK/Qt/X11),
  puis connexion Sway. Aucune déconnexion de la session réelle n'a été provoquée, aucune action NordVPN.

## Maintenance — OpenRGB (2026-11-05)

- `openrgb -p purple` trouve bien le profil JSON ; le problème est son contenu migré : clavier Ornata à 6 modes au lieu des
  9 actuels, carte mère à 12 au lieu de 7. OpenRGB ignore alors le mode mais peut appliquer les couleurs noires en mode Direct.
  Les chemins `hidraw` variables ne sont pas la cause (ignorés par la correspondance).
- Profil régénéré depuis les six contrôleurs réels, effets choisis par nom, vitesses et luminosités conservées. Copie utilisateur
  remplacée après sauvegarde `purple.json.before-qs-20261105-211451`. **Éclairage rétabli, confirmé par toi.**
- Serveur temporaire testé, puis relancé sans options de couleur : `service_startup_profile: purple` chargé automatiquement après
  détection en ~2 s. Instances temporaires arrêtées ; aucune action sur NordVPN ni sur le compositeur.
- Mise en place : `scripts/openrgb-setup.sh`, surcharge du service du paquet, procédure et retour arrière dans `docs/OPENRGB.md`.
  Tests isolés : simulation sans écriture, validation avant écriture, installation répétée, activation séparée, refus d'un service
  actif, restauration fichiers/état d'activation initial : OK. `bash -n`, `systemd-analyze verify`, `git diff --check` : OK.
  Configurations : `luac -p`, `sway -C`, `Hyprland --verify-config` : valides, sans lancement des autostarts.
- Installation système faite par toi après accord sudo. Service du paquet activé et en marche, surcharge chargée, une seule instance
  matérielle (root), écoute `127.0.0.1:6742`, profil chargé en 1,8 s après lancement. Autostarts OpenRGB Sway/Hyprland retirés.
  Lecture SDK sans détection : les six contrôleurs sont bien en `Spectrum Cycle` (RAM, clavier, souris) / `Color Cycle` (carte mère).
  Bureau réel vivant (PID 1673). Reste à tester à la main : démarrage à froid (éclairage dès l'écran de connexion), puis connexions,
  déconnexions et reconnexions Sway et Hyprland, sans extinction des LED. Le démarrage réel à froid n'a pas été simulé.

## Maintenance — focus à l’ouverture de fichiers Hyprland (2026-11-05)

- Cause confirmée sur Hyprland 0.57.1 : `misc.focus_on_activate = false` refuse le focus demandé par les applications ;
  la règle Sway qui affiche l’espace 7 pour « Add Torrents » manquait sous Hyprland. Les trois options de focus de Deluge
  sont déjà activées ; aucun changement de sa configuration utilisateur.
- Selon ton choix : exception native `focus_on_activate` pour les classes exactes `deluge`, `geany`, `chromium` seulement.
  Règle du dialogue `Add Torrents.*` vers `7` sans `silent`, après la règle générale `7 silent`. Les web apps Chromium ne
  correspondent pas ; le réglage global, le curseur sans déplacement automatique et les affectations de démarrage sont conservés.
- Vérification sur copie : `luac -p`, `Hyprland --verify-config` valides ; bancs de répartition Sway et Hyprland : **0 échec**.
  Banc de focus imbriqué à deux écrans, chargé avec les vrais fichiers input/windowrules : l’ancien code reproduit le dialogue
  non focalisé ; correctif validé à la création et réouverture du dialogue GTK Wayland, espace 7 masqué sur l’autre écran.
  Requêtes XWayland : les trois classes sélectionnées affichent leur espace et leur fenêtre ; application témoin et web app
  Discord ignorées. Démarrage Deluge silencieux conservé, aucune erreur de configuration. Avertissements GTK/accessibilité et
  XKB du banc seulement. Sway headless : sa règle existante affiche bien l’espace 7 et focalise le dialogue dans l’arbre.
- Application réelle : configuration rechargée sans erreur ; ouverture d’un `.torrent` factice dans le vrai Deluge → dialogue
  actif sur l’espace 7, curseur immobile. Dialogue fermé **sans ajout de torrent ni téléchargement** ; espaces affichés et focus
  initiaux restaurés. Bureau réel vivant (PID 14536), instances de banc arrêtées.
- Reste à vérifier à la main : ouvertures depuis le navigateur/gestionnaire de fichiers (torrent, texte Geany, lien Chromium),
  clics de notifications et liens des web apps, puis nouvelle connexion. Les requêtes des trois applications peuvent donner le
  focus même sans ouverture de fichier ; un jeton Wayland invalide ou absent reste refusé par le compositeur (le dialogue Deluge
  est couvert par sa règle dédiée).

## Maintenance — déplacements entre écrans Hyprland (2026-11-05)

- Cause : `$mod+←` / `$mod+→` utilisaient `-1` / `+1`, qui parcourent la liste interne des écrans. Dans la session observée :
  DP-1, DP-3, DP-2, malgré les positions correctes 0 / 6000 / 2560. Les positions par numéro de série sont déjà déterministes.
- Correction : voisins géométriques `hl.get_monitor("l")` / `hl.get_monitor("r")`, déplacement avec suivi du focus ; sans voisin ou
  fenêtre active, aucune action. Aucun bouclage aux extrémités ; répartition des espaces et réglages des écrans conservés.
- Vérification sur copie : `luac -p`, `Hyprland --verify-config` : configuration valide ; `scripts/test-outputs.sh sway` et
  `hyprland` : **0 échec** chacun. Complément temporaire au banc Hyprland 0.57.1 : chargement de `lua/binds` seul (sans autostart),
  capture et exécution des vrais callbacks ; ordre physique inversé par rapport à la création, déplacements dans les deux sens,
  extrémités, espace vide, écran unique et désactivation/réactivation : **0 échec**, aucune fenêtre perdue, aucune erreur de config.
- Application réelle : rechargement sans erreur de configuration, géométrie des trois écrans identique avant/après ; bureau vivant
  (PID 1673), bancs arrêtés.
- Reste à vérifier à la main : touches physiques Super+← / Super+→ et nouvelle connexion Hyprland.

## Greeter — champ interactif et sessions (2026-11-05)

- Greeter et verrouillage : bordure verte pulsée au survol (cycle 1,2 s du thème), fixe après clic ou frappe ; clic ailleurs,
  changement de compte ou nouvel affichage : retour au repos. Le clic reste facultatif ; l'erreur rouge est prioritaire.
- Sessions regroupées par bureau connu, sans toucher aux paquets ni aux fichiers système : ici Sway Vulkan + NVIDIA, GNOME,
  Hyprland standard, Qtile Wayland, Openbox et Windows 10. Priorité XDG et métadonnées conservées, variante absente : repli dans
  sa famille ; bureaux inconnus conservés. Un ancien choix mémorisé est réassocié à sa variante retenue.
- Vérification sur copie : `qmllint` sans avertissement ; banc Sway headless + QtTest : **29 assertions**, saisie sans clic,
  survol, clic hors champ et sélecteur, erreur, changement de compte, six sessions réelles, ancien choix Qtile X11, variantes
  absentes, session inconnue, priorité XDG, entrées masquées / sans commande. Démarrage complet du greeter et capture : OK,
  aucune erreur QML ; avertissements des portails du bus isolé seulement. Aucune authentification ni action système réelle.
  Après application : bureau réel PID 1673 vivant, trois barres et trois fonds présents, captures des barres vérifiées ;
  seul l’avertissement Bluez connu au rechargement. Banc et instances de test arrêtés.
- Reste à valider à la main : rythme de la pulsation sur le vrai verrouillage et le greeter après actualisation de sa copie système
  (`scripts/greeter-setup.sh install`, sudo soumis à accord). Cette actualisation système n'a pas été exécutée.

## À tester à la main

**Écran de connexion** (phase 11 en place ; connexion Hyprland et trousseau validés par le journal du 2026-11-08) :
- l'écran s'affiche sur les trois écrans, champ sur le Dell, fond = le tien flouté (exporté par le bureau dans `/var/lib/qs-desktop/crystal/`) ;
- au démarrage à froid, l'écran de connexion apparaît du premier coup (pilote Nvidia hors initramfs : si greetd démarre avant lui, Sway
  partirait sans `--unsupported-gpu` ; à voir dans `journalctl -b -u greetd`) ;
- connexion Sway (Vulkan + NVIDIA) puis Hyprland : la session démarre comme avec SDDM (barres, autostarts, `desktop.sh`) ;
- trousseau déverrouillé : Chromium et `secret-tool search` sans demande de mot de passe ;
- session « Windows 10 (X11) » (`startx`, `/bin/vm`) ; déconnexion → retour à l'écran de connexion ;
- mauvais mot de passe (message, champ rouge), dernière session retenue au démarrage suivant ;
- éteindre / redémarrer / veille depuis l'écran de connexion **et** depuis le verrouillage (panneau de réglages → verrouiller, puis la lune) ;
- retour arrière vers SDDM essayé une fois (`docs/ROLLBACK.md`).

**Prochaine connexion Sway** (pas rejouée depuis la bascule) :
- démarrage par `desktop.sh`, sans Waybar ni Dunst ; écrans sur 1 / 4 / 7, focus au centre ; une seule répartition dans `scripts/dev.sh log` ;
- applications sur leurs espaces ; une fenêtre ouverte sur l'espace 7 ou 8 part au centre ;
- `$mod+w`, `$mod+Escape`, `$mod+s`, `$mod+Ctrl+W`, volume et micro, touches média (nouvelles sous Sway), `$mod+u` / `$mod+i` (VPN : `vpn connect ""` = dernier pays, jamais essayé) ;
- `$mod+3` depuis l'écran de gauche, `$mod+Ctrl+3` avec une fenêtre ;
- `$mod+d` : HDR, échelle gardée ; `Print` sur un LG : capture nette et à la bonne taille (correctif d'échelle non vérifié sous Sway) ;
- montage privé (`~/.config/qs-desktop.local/sway.conf`) ; veilleuse sur les trois écrans.

**Prochain redémarrage d'Hyprland** :
- veilleuse sur les trois écrans, y compris après `$mod+Ctrl+W` (bloquée d'ici là par un bogue d'Hyprland sur le gamma) ;
- curseur Catppuccin vert dès la première image, sans flash rose/mauve (voir maintenance du curseur ci-dessus) ;
- espaces 1 / 4 / 7 au démarrage ; web apps Discord et WhatsApp sur l'espace 5 ; OpenRGB (service système, voir maintenance ci-dessus).

**Quand l'occasion se présente** :
- notification Discord : clic → la web app Discord et son espace s'affichent ;
- module média : vidéo dans Chromium puis onglet fermé → retour sur Spotify ;
- Bluetooth : appairage d'un nouvel appareil (code, PIN), y compris en fermant le panneau juste après la confirmation ;
- clé USB chiffrée (LUKS) : déverrouiller, verrouiller, éjecter ; clic sur un autre écran avec une phrase de passe tapée ;
- mise à jour réelle depuis le module (confirmer, le compteur disparaît) ; connexion limitée (portail captif, câble sans Internet) ;
- statistiques : colonne VRAM d'un jeu, « Force quit » sur une application figée ;
- profils d'énergie, une fois `power-profiles-daemon` installé ;
- VRR : juger l'effet à l'œil avant de l'activer (`BACKLOG.md`) ;
- calendrier : Échap pointeur sur l'horloge (le clavier revient à la fenêtre) ; marge au bord droit sur DP-1 et DP-3.

**Laptop** (phase 12) : laptop seul, + écrans externes, capot fermé, écran interne éteint, branchement à chaud avec fenêtres ouvertes ;
batterie (alertes 30 % et 15 %), rétroéclairage et OSD de luminosité, mode avion, Wi-Fi (mot de passe, portail captif), modules masqués
selon le matériel, GPU AMD / Intel réels, verrouillage avant la mise en veille et réveil, menu et lanceur sur un petit écran ;
`Brightness`, `BatteryModule`, `Backlight` jamais revus sur du vrai matériel.
Écran de connexion sur un laptop hybride Intel + Nvidia (pilote propriétaire) : `sway` refuse de démarrer sans `--unsupported-gpu`,
`sway-vulkan.desktop` n'est installé que si Nvidia est la seule carte : session Sway à prévoir (config machine `greeter.defaultSession`).
Disposition du clavier : aucune n'est réglée dans le dépôt (`us` par défaut, comme ici) ; si le laptop en règle une (`input * xkb_layout …`),
la mettre aussi dans le Sway de l'écran de connexion (`dotfiles/greetd/sway.conf` ou un fichier machine inclus par `scripts/greeter.sh`),
sinon le mot de passe y serait tapé avec une autre disposition.

## Décisions en attente

- **Fonds d'écran** (pour la phase 12) : images versionnées dans un dépôt séparé (`wallpapers`) cloné par `install.sh` dans
  `~/Pictures/Wallpapers` (recommandé) ; fonds animés gardés ou non (`qt6-multimedia`, fichiers non versionnés) ; suppression du cache
  `~/.cache/swww` (11 Go, swww n'est plus utilisé) ; 6 icônes et 3 images portrait exclues. Détail : `docs/archive/WALLPAPERS.md`.
- Signalement amont du bogue `I3.focusedMonitor` de Quickshell (`docs/DEVELOPMENT.md`, pièges) : seulement avec ton accord.
- Hors dépôt : jeton NordVPN en clair dans `~/.config/autostart/nordvpn.desktop` (GNOME seulement) ; anciens dépôts
  `Crystal4276/sway` et `Crystal4276/hyprland` à archiver si tu veux.

## Connu, non résolu

- Écran de connexion : après un mauvais mot de passe, le journal de Quickshell montre « Received unexpected greetd response » (Quickshell
  0.3 annule lui-même la session et ne s'attend pas à la réponse de greetd) : sans effet (`DEVELOPMENT.md`, pièges).

- Avertissement `services/Bluez.qml[31:5]` « Unable to assign [undefined] to bool » au démarrage : sans effet connu.
- Calendrier : après un clic dans le calendrier, Échap et ←/→ ne répondent plus (pas d'API pour rendre le clavier à la barre ;
  limite écrite dans `CalendarPopup.qml`).

## Prochaine étape

**Phase 12 — portabilité**, plan validé le 2026-11-09 (`~/.claude/plans/…dragonfly.md`, résumé ici) :
- paquets officiels d'abord, aucun paquet AUR installé par `install.sh` sauf `paru-bin` (à ta demande) ; `[multilib]` activé par
  `install.sh` (Wine, Steam) ; Claude Code, NordVPN, Plex, RustDesk seulement documentés ;
- base : bureau + applications retenues (`deps/apps.txt`), multimédia minimal (Celluloid, miniatures, VA-API selon le GPU),
  virtualisation et Samba (partage VM ↔ hôte) ; profil optionnel « jeux » (Steam, gamescope, Lutris, GameMode) ;
- thème Catppuccin Mocha green homogène GTK + Qt (Kvantum), archives officielles Catppuccin téléchargées et vérifiées ;
- fastfetch reprenant le thème neofetch actuel ; GNOME Terminal conservé ;
- tests dans une VM Arch neuve (overlay de l'image « basic »), puis `--dry-run` sur ce desktop.
