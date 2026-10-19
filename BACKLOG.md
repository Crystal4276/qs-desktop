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
- Panneau NordVPN : focus direct dans la recherche à l'ouverture (taper sans cliquer).
- Notifications (phase 6) : raccourcis clavier pour le centre et « ne pas déranger » (IPC à ajouter) ; historique et « ne pas déranger »
  conservés après un redémarrage de Quickshell (en mémoire aujourd'hui, comme Dunst) ; menu pour choisir parmi plusieurs liens d'une
  notification (Dunst passait par `dmenu`, absent) ; couleurs par notification (`fgcolor`, `bgcolor`… : ignorées).
- **Animations** (ta demande du 2026-10-16) : aucune dans la première version (parité) ; à ajouter ensuite, au fur et à mesure
  (ouverture des panneaux, menus et notifications, changement d'espace de travail…), avec `EasingCurve` et les animations de Qt Quick.
- Partage d'écran : choix de l'écran par une fenêtre Quickshell au lieu de `slurp` (`chooser_cmd` de `xdg-desktop-portal-wlr`).
- **Vue des fenêtres** (accepté le 2026-10-16, après la première version) : aperçus en direct de toutes les fenêtres (`Toplevel` +
  `ScreencopyView`), clic pour y aller, ouverte par un raccourci.

- NordVPN (`services/Vpn.qml`) : son lanceur de commandes (busy / run / error) date de la phase 5 ; le passer sur
  `services/CliRunner.qml`, qui gère en plus une commande qui ne démarre pas (sinon `busy` resterait vrai pour la session).
  Relevé par la revue du 2026-10-19 ; non fait sans test, pour ne pas toucher à ta connexion VPN.
