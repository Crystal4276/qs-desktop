# Journal d'avancement

État courant seulement. Historique figé : phases 0 à 10 dans `docs/archive/PROGRESS.md`, maintenance du 2026-11-05 au 2026-11-09
et phases 11-12 dans `docs/archive/PROGRESS-11-12.md` (à n'ouvrir qu'en cas de besoin).

## Machines

- **`terrier`** (desktop, référence) : Arch, i9-9900K, RTX 2080 (pilote propriétaire) ; trois écrans : DP-1 (LG 27GN950, gauche,
  scale 1.5), DP-2 (Dell AW3418DW, centre, principal), DP-3 (LG 27GN950, droite, scale 1.5) ; espaces 1-3 / 4-6 / 7-9.
- **Laptop** (à venir) : Arch fraîchement installé, puis `install.sh` ; le développement (affinage de l'interface) reprendra depuis lui.
- Versions (2026-11-09) : Quickshell 0.3.2, Sway 1.12, Hyprland 0.57 (**config Lua** : pas de `hyprctl keyword`, `dispatch` en
  syntaxe Lua).

## Phases

| Phase | Contenu | État |
|---|---|---|
| 0 – 9 | Audit → parité Hyprland | faites (2026-10-15 → 2026-11-03) |
| 10 | Bascule (configs dans `dotfiles/`, lancement par `scripts/desktop.sh` ; retour arrière : `docs/ROLLBACK.md`) | faite (2026-11-03) |
| 11 | Écran de connexion greetd + greeter Quickshell | faite : en service sur `terrier`, connexion avec trousseau déverrouillé (2026-11-08) |
| 12 | Portabilité | faite sauf les **tests sur le vrai laptop** (ci-dessous) |

Ensuite (pas de phase 13) : maintenance et idées de `BACKLOG.md`, une à la fois, avec ton accord.

## Phase 12 — ce qui existe

- `install.sh` (`README.md`) : paquets officiels d'abord (`[multilib]` activé, `paru-bin` seule construction AUR ; Claude Code,
  NordVPN, Plex, RustDesk seulement documentés), paquets selon la carte (`deps/gpu.txt`), profil optionnel jeux, liens des configs,
  thème Catppuccin (archives officielles vérifiées, `deps/themes.txt`), réglages (dconf, applications par défaut, web apps, Chromium
  et web apps en thème GTK, Deluge sans icône de tray), fonds d'écran clonés, config machine, étape système (greeter, sonde
  réseau, `scripts/system-setup.sh` : Samba, services, groupes). `--dry-run`, `--uninstall`, idempotent.
- Choix retenus avec toi : GNOME Terminal + fastfetch (thème neofetch repris), dossiers Papirus lavande, pas de btop (moniteur
  Quickshell), `power-profiles-daemon` seulement sur laptop, fond par défaut `simple/wallhaven-j37lop.png`, Qt en Kvantum Catppuccin,
  toutes les applications sur le thème GTK. Pas d'autres distributions pour l'instant (`BACKLOG.md`).
- Tests : `python3 scripts/test-install.py` (dossier personnel jetable : simulation, installation, idempotence, retrait) : 0 échec.
  Trois VM Arch vierges (image officielle « basic » du 2026-11-01, disque overlay, `~/.cache/qs-desktop-vm`, gardé pour d'autres
  essais) : installation complète, second passage sans changement, greetd → Sway, thème, fonds, `--uninstall`. Détail : archive.
- Revue de code de la phase 12, passe 1 (2026-11-09, après ton essai réel : questions invisibles d'`install.sh`, corrigées) :
  10 constats corrigés — fichier machine non committé absent de la copie du greeter (session par défaut fausse sur NVIDIA),
  `--uninstall` qui supprimait `hosts/<machine>.json`, configs liées par stow (sauvegarde du lien au lieu du contenu), multilib
  sans confirmation et bloquant, thème Chromium jamais défait (seule la clé est maintenant restaurée), test bloqué sur un
  terminal, dépôt cloné à l'emplacement du lien, saut de ligne final perdu, `git pull` pouvant demander un mot de passe,
  `--help`. Tests ajoutés ; contre-épreuve : 4 échecs sur l'ancien code, 0 sur le nouveau.
- Passe 2 : 10 constats corrigés — fichier Sway machine non trouvé hors du dépôt (correctif de la passe 1), profil jeux sans
  multilib (désormais retiré avec message), retrait qui supprimait un vrai dossier ayant remplacé un lien, anciennes valeurs dconf
  notées avant toute écriture, fichier illisible / python-gobject absent / `.bashrc` disparu sans arrêt, curseur du greeter copié
  avec l'étape du greeter, **Samba sans accès invité** (laptop sur Wi-Fi public), multilib gardé au retrait, `deps/` ; en plus,
  `USER` absent (lancement hors session) géré. Essais jetables : Latin-1, lien remplacé, `.bashrc` supprimé, sans `USER` : OK.
- Dépôts `qs-desktop` et `wallpapers` **publics** (audit de l'historique sans secret ; adresse e-mail des commits gardée).

## Reprise sur le laptop

1. Installer Arch (archinstall : nom de machine **fixe**, NetworkManager, pilote graphique), puis :
   `sudo pacman -S --needed git && git clone https://github.com/Crystal4276/qs-desktop.git ~/qs-desktop && cd ~/qs-desktop && ./install.sh`.
2. Committer le `hosts/<laptop>.json` créé par `install.sh` ; ajouter si besoin `dotfiles/sway/hosts/<laptop>.conf` et
   `dotfiles/hypr/hosts/<laptop>.lua` (échelle de l'écran interne, disposition du clavier).
3. Points propres au laptop, à régler à ce moment-là :
   - **barre principale sur un écran étroit** : en VM à 1280 px, la pilule volume + curseur chevauche la pilule CPU / mémoire ;
   - **GPU hybride Intel + NVIDIA** : `sway` exige `--unsupported-gpu` ; `sway-vulkan.desktop` n'est installé que si NVIDIA est la seule
     carte → choisir la session dans `greeter.defaultSession` de la config machine ;
   - **disposition du clavier** : aucune réglée dans le dépôt (`us`) ; si le laptop en règle une, la mettre aussi dans le Sway de
     l'écran de connexion (`dotfiles/greetd/sway.conf` ou fichier machine inclus par `scripts/greeter.sh`).
4. Le banc d'essai et les règles de `docs/DEVELOPMENT.md` s'appliquent aussi sur le laptop (le bureau tourne depuis le dépôt).

## À tester à la main

**Laptop** : laptop seul, + écrans externes, capot fermé, écran interne éteint, branchement à chaud avec fenêtres ouvertes ;
batterie (alertes 30 % et 15 %), rétroéclairage et OSD de luminosité, profils d'énergie, mode avion, Wi-Fi (mot de passe, portail
captif réel), modules masqués selon le matériel, GPU Intel / AMD réels, verrouillage avant la veille et réveil, menu et lanceur sur
un petit écran (`Brightness`, `BatteryModule`, `Backlight` jamais revus sur du vrai matériel).

**`terrier`, écran de connexion** : démarrage à froid du premier coup (pilote NVIDIA hors initramfs : `journalctl -b -u greetd`) ;
connexion Sway (Vulkan + NVIDIA) ; session « Windows 10 (X11) » ; mauvais mot de passe ; dernière session retenue ; éteindre /
redémarrer / veille depuis l'écran de connexion et le verrouillage ; retour arrière vers SDDM essayé une fois (`docs/ROLLBACK.md`).

**`terrier`, prochaine connexion Sway** : `desktop.sh` sans Waybar ni Dunst ; écrans sur 1 / 4 / 7 ; applications sur leurs espaces ;
raccourcis (`$mod+w`, `$mod+Escape`, `$mod+s`, `$mod+Ctrl+W`, volume, micro, média, `$mod+u` / `$mod+i`, `$mod+3` depuis la gauche,
`$mod+Ctrl+3`) ; `$mod+d` (HDR) ; `Print` net sur un LG ; montage privé ; veilleuse ; terminal avec fastfetch.

**`terrier`, Hyprland** : veilleuse après `$mod+Ctrl+W` ; curseur vert dès la première image ; espaces 1 / 4 / 7 ; web apps sur 5 ;
OpenRGB dès l'écran de connexion ; Spotify sur l'écran de gauche sans clic ; bordures au changement d'espace ; `Super+←/→`.

**Quand l'occasion se présente** : vrais clics de liens depuis Thunderbird / Deluge / Steam et les web apps (écran principal) ;
notification Discord → web app ; vidéo Chromium puis onglet fermé → retour sur Spotify ; vidéo > 5 min sans veille, pause > 5 min ;
appairage Bluetooth (code, PIN) ; clé USB LUKS ; mise à jour réelle depuis le module ; portail captif réel ; colonne VRAM d'un jeu,
« Force quit » ; bascule Applications / Processus du moniteur au clic physique ; VRR à l'œil (`BACKLOG.md`) ; calendrier : Échap,
marge au bord droit sur DP-1 / DP-3.

## Décisions en attente

- Signalement amont du bogue `I3.focusedMonitor` de Quickshell (`docs/DEVELOPMENT.md`, pièges) : seulement avec ton accord.
- Hors dépôt : jeton NordVPN en clair dans `~/.config/autostart/nordvpn.desktop` (GNOME seulement) ; anciens dépôts
  `Crystal4276/sway` et `Crystal4276/hyprland` à archiver si tu veux.

## Connu, non résolu

- Écran de connexion : « Received unexpected greetd response » dans le journal après un mauvais mot de passe : sans effet
  (`DEVELOPMENT.md`, pièges).
- Avertissement `services/Bluez.qml[31:5]` « Unable to assign [undefined] to bool » au démarrage : sans effet connu.
- Calendrier : après un clic dedans, Échap et ←/→ ne répondent plus (pas d'API pour rendre le clavier à la barre).
- Audio seul sous Hyprland : Chromium garde un inhibiteur de veille Wayland natif (pas contourné).
- NetworkManager prend le nom d'hôte du DHCP quand la machine n'a pas de nom fixe (`install.sh` le signale).

## Prochaine étape

Installer le laptop avec `install.sh` (« Reprise sur le laptop » ci-dessus), faire ses tests, puis le rapport de fin de phase 12 avec
captures. Ensuite : affinage de l'interface depuis le laptop.
