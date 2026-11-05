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
- curseur Catppuccin vert (nom corrigé, effectif à la connexion) ;
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
