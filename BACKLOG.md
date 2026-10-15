# Backlog — améliorations hors parité

Idées notées pendant le travail. Rien ici n'est implémenté sans accord.

- Titre de la fenêtre active / mode Sway dans la barre (absents de la Waybar actuelle ; décision Q4 : parité d'abord).
- Activer le VRR (`adaptive_sync on` / `vrr = 1`) dans les règles d'écran, si le test de phase 3 est concluant.
- **Événements Thunderbird dans la fenêtre calendrier** (lecture seule de `calendar-data/cache.sqlite` / `local.sqlite` ; 3 CalDAV, 2 Owl, 1 local). Voir ARCHITECTURE § 8.3.
- Réévaluer Kanshi si un jour le même écran doit être placé différemment selon les autres écrans présents (plusieurs docks).
- Confirmation avant Reboot / Shutdown dans le power menu.
- Seuil critique de température GPU réellement appliqué (l'option `critical-threshold` de Waybar est sans effet sur un `custom/*`).
- Raccourcis `XF86AudioPlay/Next/Prev` sous Sway (existants sous Hyprland seulement).
- Passer DP-1 / DP-3 en 144 Hz (piste notée dans `~/.config/hypr/lua/layout.lua`).
- Thème d'icônes Qt (`qt6ct` : breeze) différent du thème GTK (Papirus-Dark) : à harmoniser ?
