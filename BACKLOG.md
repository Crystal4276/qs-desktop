# Backlog — améliorations hors parité

Idées notées pendant le travail. Rien ici n'est implémenté sans accord.

- Titre de la fenêtre active / mode Sway dans la barre (absents de la Waybar actuelle ; décision Q4 : parité d'abord).
- Activer le VRR (`adaptive_sync on` / `vrr = 1`) dans les règles d'écran : accepté par Sway + Nvidia sur les 3 écrans (phase 3) ; reste à juger l'effet à l'œil.
- **Événements Thunderbird dans la fenêtre calendrier** (lecture seule de `calendar-data/cache.sqlite` / `local.sqlite` ; 3 CalDAV, 2 Owl, 1 local). Voir ARCHITECTURE § 8.3.
- Réévaluer Kanshi si un jour le même écran doit être placé différemment selon les autres écrans présents (plusieurs docks).
- Confirmation avant Reboot / Shutdown (écartée pour la phase 8, le 2026-10-16 : comme Rofi).
- ~~Power menu → panneau de réglages façon GNOME~~ : **décidé le 2026-10-16, fait en phase 8** (`ARCHITECTURE.md` § 10.1.4). Commandes
  `qs ipc` pour le HDR et le VRR aussi (`$mod+d`).
- Seuil critique de température GPU réellement appliqué (l'option `critical-threshold` de Waybar est sans effet sur un `custom/*`).
- Raccourcis `XF86AudioPlay/Next/Prev` sous Sway (existants sous Hyprland seulement).
- Passer DP-1 / DP-3 en 144 Hz (piste notée dans `~/.config/hypr/lua/layout.lua`).
- Thème d'icônes Qt (`qt6ct` : breeze) différent du thème GTK (Papirus-Dark) : à harmoniser ?
- Informations des anciens tooltips Waybar (non repris, décision du 2026-10-16) : swap, nom de la sortie audio, titre complet du morceau —
  à placer dans la fenêtre de statistiques (phase 8b) ou le panneau audio (nom de la sortie : fait).
- Panneaux natifs (phase 5), fonctions des applets non reprises : nm-applet (« Enable Networking » global, connexions VPN de NetworkManager,
  réseau Wi-Fi caché, création d'un point d'accès, fenêtre d'informations), blueman (envoi de fichiers, gestion des adaptateurs),
  udiskie (« Mount disc image », interrupteurs montage automatique / notifications), NordVPN (réglages, compte).
- Notifications (phase 6) : raccourcis clavier pour le centre et « ne pas déranger » (IPC à ajouter) ; historique et « ne pas déranger »
  conservés après un redémarrage de Quickshell (en mémoire aujourd'hui, comme Dunst) ; menu pour choisir parmi plusieurs liens d'une
  notification (Dunst passait par `dmenu`, absent) ; couleurs par notification (`fgcolor`, `bgcolor`… : ignorées).
- **Animations** (ta demande du 2026-10-16) : aucune dans la première version (parité) ; à ajouter ensuite, au fur et à mesure
  (ouverture des panneaux, menus et notifications, changement d'espace de travail…), avec `EasingCurve` et les animations de Qt Quick.
- Partage d'écran : choix de l'écran par une fenêtre Quickshell au lieu de `slurp` (`chooser_cmd` de `xdg-desktop-portal-wlr`).
- **Vue des fenêtres** (accepté le 2026-10-16, après la première version) : aperçus en direct de toutes les fenêtres (`Toplevel` +
  `ScreencopyView`), clic pour y aller, ouverte par un raccourci.

- Panneau NordVPN : recherche par ville (« amsterdam ») ; demanderait les villes des ~150 pays (`nordvpn cities` pour chacun).
- **Effet verre façon iOS** (ta idée du 2026-10-21) : panneaux, menu et lanceur semi-transparents sur le fond d'écran flouté. Sur un
  panneau opaque, un surlignage translucide ne se distingue pas d'un gris uni : il faut un fond flouté derrière. Sway ne floute pas
  (SwayFX ou Hyprland oui, seulement pour l'ensemble de la fenêtre) ; Quickshell peut l'imiter en floutant le fond d'écran qu'il dessine
  lui-même (`MultiEffect`) sous chaque panneau — les fenêtres derrière n'apparaîtraient pas. Valeurs de transparence à choisir ensemble.
- Disques : déverrouiller VeraCrypt (TCRYPT) et BitLocker (revue du 2026-10-27). `udisksctl` ne lit une phrase de passe qu'au
  terminal ; passée en fichier de clé (`--key-file`), elle ne vaut que pour LUKS. Il faudrait appeler `Encrypted.Unlock` sans
  mettre la phrase dans la ligne de commande (petit programme qui la lit sur l'entrée standard).
- Disques : images disque en boucle créées par un autre utilisateur (root : Waydroid, VM) gérées et montées comme les tiennes,
  comme le fait udiskie ; les limiter à `Loop.SetupByUID` = ton uid serait plus sûr (revue du 2026-10-27).
- Plantage `QQmlDelegateModel::_q_itemsMoved` (3 sur banc le 2026-11-02, à 07 h 24, 07 h 29 et 07 h 39, Qt 6.12.0-4 ; aucun sur ton
  instance) : déplacement de lignes d'un `ScriptModel`, modèle non identifié. Non reproduit avec la fenêtre de statistiques ouverte
  80 s sous charge. À reprendre si un rapport apparaît dans `~/.cache/quickshell/crashes/`.
- Écrans : `I3.focusedMonitor` périmé quand l'écran focalisé disparaît (contourné dans `Compositor.qml`) : à signaler à Quickshell
  (amont, avec ton accord). `bFocusedMonitor` est écrit sans suivre `destroyed`, le garde de `setFocusedMonitor` n'est jamais posé.
- Polkit : agent perdu si polkitd redémarre (`systemctl restart polkit`, plantage) : Quickshell se croit toujours enregistré,
  comme polkit-gnome. Surveiller le propriétaire de `org.freedesktop.PolicyKit1` (`gdbus monitor --system`) et recréer l'agent
  (revue du 2026-10-27 ; non testable sans `sudo`).
- Polkit : signaler à Quickshell (amont, avec ton accord) la file d'attente inopérante de `PolkitAgentImpl` (0.3.2 et `master` :
  une demande remplace celle en cours ; `finishAuthenticationRequest` agit sur la demande active, pas sur celle qui finit) et
  l'absence de nouvel essai d'enregistrement. Contournement en place : ARCHITECTURE § 10.1.9.
- Web apps : un lien envoyé au navigateur est aussi demandé par la web app (l'onglet a déjà lancé la requête quand
  l'extension le ferme ; même fermé aussitôt, la requête part sur une connexion déjà ouverte). Un lien à usage unique (connexion
  par e-mail, réinitialisation) peut donc être consommé par la web app. Seule parade : intercepter le clic dans la page (script
  de contenu, `window.open` remplacé) avant l'ouverture de l'onglet ; plus invasif, risque de casser les apps (revue du
  2026-10-28).
- Performance : `perf` refuse tout événement sur cette machine (profil CPU natif non obtenu) ; pente mémoire sur plusieurs heures à relever ; coût mémoire du verrouillage sur le vrai GPU (`docs/PERFORMANCE.md`).
- Hyprland : signaler à Quickshell (amont, avec ton accord) une utilisation de mémoire libérée à chaque réponse de requête. Une config réduite à `Hyprland.refreshMonitors()` plante sous `MALLOC_CONF=junk:free` (pile : `QAbstractSocketPrivate::canReadNotification` → `QIODevice::channelReadyRead`), 26 requêtes sans plantage sinon. Source de Quickshell non lue : socket détruit pendant son `readyRead`, hypothèse. Conséquence : `junk:free` inutilisable pour tester sous Hyprland (0.3.2, Qt 6.12).
- Hyprland, phase 10 : les couches Quickshell héritent de tes animations `layers*` (panneau encore invisible 50 ms après l'ouverture, fondu). Décidé en phase 10 (2026-11-03, ta réponse) : fondu gardé, comme Rofi et Waybar sous Hyprland.
- Capture sous Hyprland avec un curseur logiciel (écrans virtuels, peut-être une VM ou certains laptops) : le curseur figure dans l'image, `paintCursor: false` ne suffit pas. À traiter si cela se présente ; tes écrans ont un curseur matériel, sans ce défaut.
- Capture (revue du 2026-11-03, hors parité Hyprland) : deux captures dans la même seconde portent le même nom, la seconde écrase la première (nom à la seconde, repris du script de la touche Impr.) ; la découpe (`ShaderEffectSource`) de l'outil est rendue sur chaque écran tant qu'il est ouvert, environ 85 Mo de VRAM pour rien sur deux écrans sur trois (la créer à la demande dans `onCaptureRequested`).
- Veille du système (revue du 2026-11-03, laptop surtout) : le `gdbus monitor` de `services/Idle.qml` (verrouillage avant la veille, `hyprctl reload` au réveil sous Hyprland) n'est pas relancé s'il s'arrête (redémarrage de dbus-broker ou de logind après une mise à jour) ; rien n'est journalisé. Le relancer à sa sortie.
