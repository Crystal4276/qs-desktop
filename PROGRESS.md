# Journal d'avancement

## Environnement

- Machine : `terrier` — Arch, i9-9900K, RTX 2080 (nvidia-utils 615.78)
- **Quickshell 0.3.2** (paquet Arch `quickshell 0.3.2-1`)
- Sway 1.12, Hyprland 0.56.2 (**config Lua** : `hyprctl keyword` indisponible, `dispatch` en syntaxe Lua)
- Écrans : DP-1 (LG 27GN950, gauche), DP-2 (Dell AW3418DW, centre, principal), DP-3 (LG 27GN950, droite)

## Phase 0 — Audit : faite, en attente de validation (2026-10-15)

Produit :
- `docs/INVENTORY.md` — Waybar (3 barres, tous les modules), Dunst, Rofi, nwg-menu, tray, raccourcis, autostart, sorties, attribution des espaces, secrets repérés
- `docs/THEME.md` — palette Catppuccin Mocha + couleurs Rofi, polices, géométrie mesurée de la barre (pilules 55 px, marges 10 px, rayon 16 px), notifications, lanceur, power menu, nwg-menu
- `docs/SCRIPTS.md` — 9 scripts/commandes actifs, 11 scripts morts, hors périmètre
- `docs/ARCHITECTURE.md` — proposition : Kanshi pour les sorties, `services/Outputs.qml` pour la répartition, règle « principal d'abord », format `hosts/*.json`, **8 questions ouvertes (Q1–Q8)**
- `docs/reference/` — 10 captures (barres, lanceur, power menu, nwg-menu, notifications)
- `deps/` — première version (pacman, AUR, optionnel, correspondances Fedora/Debian non vérifiées)
- `BACKLOG.md`

Constats importants :
- L'attribution 3 écrans n'est pas gauche → droite (1-3 au centre) → règle proposée « écran principal d'abord ».
- Hyprland en config Lua invalide les commandes `hyprctl keyword` / `dispatch moveworkspacetomonitor` prévues dans `CLAUDE.md`.
- La Waybar actuelle n'affiche ni titre de fenêtre ni mode Sway (prévus en phase 2) → Q4.
- Jetons NordVPN en clair dans les configs Sway/Hyprland/autostart → Q7.

État laissé : Waybar et Dunst actifs et inchangés, aucun écran virtuel, aucune instance `qs`, 3 notifications de test retirées de l'historique Dunst.

## Prochaine étape

Réponses à Q1–Q8 (`docs/ARCHITECTURE.md` § 8), puis phase 1 (squelette).
