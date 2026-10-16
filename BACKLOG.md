# Backlog — améliorations hors parité

Idées notées pendant le travail. Rien ici n'est implémenté sans accord.

- Titre de la fenêtre active / mode Sway dans la barre (absents de la Waybar actuelle ; décision Q4 : parité d'abord).
- Activer le VRR (`adaptive_sync on` / `vrr = 1`) dans les règles d'écran : accepté par Sway + Nvidia sur les 3 écrans (phase 3) ; reste à juger l'effet à l'œil.
- **Événements Thunderbird dans la fenêtre calendrier** (lecture seule de `calendar-data/cache.sqlite` / `local.sqlite` ; 3 CalDAV, 2 Owl, 1 local). Voir ARCHITECTURE § 8.3.
- Réévaluer Kanshi si un jour le même écran doit être placé différemment selon les autres écrans présents (plusieurs docks).
- Confirmation avant Reboot / Shutdown dans le power menu.
- **Power menu → panneau de réglages rapides façon GNOME** (idée du 2026-10-15, à discuter au début de la phase 8) : verrouiller, déconnexion,
  redémarrer, éteindre, plus éventuellement volume, réseau, Bluetooth, NordVPN… Les menus réseau, Bluetooth et VPN de la phase 5 seront
  écrits comme des panneaux autonomes, pour pouvoir y être intégrés sans réécriture.
- Seuil critique de température GPU réellement appliqué (l'option `critical-threshold` de Waybar est sans effet sur un `custom/*`).
- Raccourcis `XF86AudioPlay/Next/Prev` sous Sway (existants sous Hyprland seulement).
- Passer DP-1 / DP-3 en 144 Hz (piste notée dans `~/.config/hypr/lua/layout.lua`).
- Thème d'icônes Qt (`qt6ct` : breeze) différent du thème GTK (Papirus-Dark) : à harmoniser ?
- Informations des anciens tooltips Waybar (non repris, décision du 2026-10-16) : swap, nom de la sortie audio, titre complet du morceau —
  à placer dans la fenêtre de statistiques (phase 8b) ou un futur panneau audio.
- Panneaux natifs (phase 5), fonctions des applets non reprises : nm-applet (« Enable Networking » global, connexions VPN de NetworkManager,
  réseau Wi-Fi caché, création d'un point d'accès, fenêtre d'informations), blueman (envoi de fichiers, gestion des adaptateurs),
  udiskie (« Mount disc image », interrupteurs montage automatique / notifications), NordVPN (réglages, compte).
- Panneau NordVPN : focus direct dans la recherche à l'ouverture (taper sans cliquer).
- Notifications (phase 6) : raccourcis clavier pour le centre et « ne pas déranger » (IPC à ajouter) ; historique et « ne pas déranger »
  conservés après un redémarrage de Quickshell (en mémoire aujourd'hui, comme Dunst) ; menu pour choisir parmi plusieurs liens d'une
  notification (Dunst passait par `dmenu`, absent) ; couleurs par notification (`fgcolor`, `bgcolor`… : ignorées).
