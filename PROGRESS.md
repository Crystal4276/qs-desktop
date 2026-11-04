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

## À tester à la main

**Écran de connexion** (phase 11, après `scripts/greeter-setup.sh install`, puis `enable` et redémarrage) :
- l'écran s'affiche sur les trois écrans, champ sur le Dell, fond = le tien flouté (exporté par le bureau dans `/var/lib/qs-desktop/crystal/`) ;
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
- curseur Catppuccin vert (nom corrigé, effectif à la connexion) ;
- espaces 1 / 4 / 7 au démarrage ; web apps Discord et WhatsApp sur l'espace 5 ; OpenRGB.

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
