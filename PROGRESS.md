# Journal d'avancement

## Environnement

- Machine : `terrier` — Arch, i9-9900K, RTX 2080 (nvidia-utils 615.78)
- **Quickshell 0.3.2** (paquet Arch `quickshell 0.3.2-1`)
- Sway 1.12, Hyprland 0.56.2 (**config Lua** : `hyprctl keyword` indisponible, `dispatch` en syntaxe Lua)
- Écrans : DP-1 (LG 27GN950, gauche), DP-2 (Dell AW3418DW, centre, principal), DP-3 (LG 27GN950, droite)

## Phase 0 — Audit : faite, en attente de validation (2026-10-15)

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

## Prochaine étape

Phase 1 (squelette), après validation.
