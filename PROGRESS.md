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
| 11 | Écran de connexion (greetd + greeter Quickshell au design du verrouillage) | **en cours** : code, fichiers système et docs faits et testés sur banc (2026-11-04) ; mise en place système et vraie connexion en attente de ton accord |
| 12 | Portabilité (`install.sh`, `deps/`, laptop) | à faire |

Retour arrière de la bascule : `docs/ROLLBACK.md`.

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

**Écran de connexion** (phase 11, après `scripts/greeter-setup.sh install`, puis `enable` et redémarrage) :
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

**Phase 11 — écran de connexion** : fait jusqu'à la mise en place système (`ARCHITECTURE.md` § 9). Reste, avec ton accord :
`scripts/greeter-setup.sh install` (sudo ; `--dry-run` pour voir), essai réel, `enable`, redémarrage, tests ci-dessus. Verrouillage :
rangée éteindre / redémarrer / veille déjà en place sur le bureau.
