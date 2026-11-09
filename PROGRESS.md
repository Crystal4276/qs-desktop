# Journal d'avancement

État courant seulement. Historique figé : phases 0 à 10 dans `docs/archive/PROGRESS.md`, maintenance du 2026-11-05 au 2026-11-09
et phases 11-12 dans `docs/archive/PROGRESS-11-12.md` (à n'ouvrir qu'en cas de besoin).

## Machines

- **`terrier`** (desktop, référence) : Arch, i9-9900K, RTX 2080 (pilote propriétaire) ; trois écrans : DP-1 (LG 27GN950, gauche,
  scale 1.5), DP-2 (Dell AW3418DW, centre, principal), DP-3 (LG 27GN950, droite, scale 1.5) ; espaces 1-3 / 4-6 / 7-9.
- **`corelabs-laptop`** : Arch installé avec `install.sh` ; développement repris sur le laptop, session Hyprland 0.57.1. Dalle
  interne 1920×1200 à 60 Hz (CSO 0x1471), échelle 1 explicite sous Sway et Hyprland.
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
- Passe 3 : `pciutils` installé en premier puis cartes lues par `lspci` (ton choix), NetworkManager seul gestionnaire de réseau
  (un autre actif est remplacé, remis au retrait), Geany ouvert respecté, `EDITOR="geany -i"` (attend la fermeture), retrait qui
  garde à côté (`<fichier>.uninstall-<date>`) tout réglage modifié par une application depuis l'installation, archives du thème
  ni téléchargées ni extraites si déjà en place, applications par défaut lues en une fois, pas d'attente libvirt aux relances ni
  d'appel libvirt en simulation, `deps/` complété. Contre-épreuve : l'ancien code perd le réglage modifié.
- Passe 4 : iwd aussi désactivé au profit de NetworkManager (services désactivés, paquets gardés), sortie de `virsh` lue en
  anglais (idempotence en français), copie gardée au retrait aussi à travers un lien stow, retrait sans session utilisateur,
  script système en échec signalé sans arrêter la suite, `pacman -Syu` avant `pciutils`, rien pour Chromium s'il est absent,
  `wallpapersDir` de la config machine respecté, code commun factorisé (profils des web apps, sauvegarde avant écriture),
  archive Geany seulement si besoin.
- Passe 5 : second `--uninstall` non bloqué, chemins non ASCII / `&` / `|` des web apps corrects, Samba limité à la machine
  et au réseau des VM (`hosts allow`), bascule vers NetworkManager seulement au redémarrage (connexion jamais coupée),
  `paru` non bloquant, dconf : clé modifiée depuis gardée au retrait, dossier Images comme `Places.qml`, simulation sans
  téléchargement. Suite : 0 échec.
- Passe 6 + tes retours de VM : NetworkManager réglé sur iwd (archinstall « iwd backend ») → iwd gardé, retrait système qui
  continue après un échec, dconf injoignable non bloquant, lien stow vers un fichier absent gardé au retrait, simulation qui annonce
  le bon dossier Images, un seul `pacman -Syu`. **Chromium** : thème GTK vérifié en VM ; seul le profil réellement ouvert (verrou
  `SingletonLock`) bloque, et tout réglage remis à plus tard est rappelé à la fin (« Pas encore fait »). **Gammastep Indicator**
  masqué du lanceur (inutile : la barre lance gammastep). **Écran de connexion** : fond de la config machine dès le premier
  démarrage (avant, uni jusqu'à la première session). Ghostty : absent de `deps/`. Kvantum gardé (ton choix).
- Passes 7 à 9 : liens Chromium, config machine illisible, dossier Papirus inattendu, `pciutils`… ne bloquent plus la suite ;
  `/etc/environment` sans saut de ligne final ; réseau libvirt relu une seule fois (idempotence) ; dossier Images désactivé ;
  **Deluge** : identifiant `deluge.desktop` (torrents et liens magnet ; sur `terrier`, `~/.config/mimeapps.list` pointe encore
  vers l'ancien nom absent) ; dossier de thème ou curseur remplacé par le tien mis de côté, jamais supprimé ; NetworkManager
  absent → aucun autre gestionnaire désactivé. VM vierge : installation, 2e passage **0 changement**, greeter avec fond dès le
  1er démarrage, Chromium « Thème : GTK ». Passe 9 : restes négligeables (laissés : triptyque de `terrier` retiré à ta demande,
  `.bashrc` vide laissé si absent avant, Python lancé plusieurs fois). **Série de revues close.** Reste : nouvel essai dans ta VM.
- Dépôts `qs-desktop` et `wallpapers` **publics** (audit de l'historique sans secret ; adresse e-mail des commits gardée).
- Tes retours de VM (2026-11-09, Chromium) :
  - **Boutons réduire / agrandir / fermer** : ils venaient du cadre dessiné par Chromium (`browser.custom_chrome_frame`, réglé
    sur `false` sur `terrier`). `install.sh` règle « barre de titre et bordures du système » dans le profil principal **et**
    les web apps (ton choix) ; vérifié sur banc et en VM, thème GTK conservé.
  - **Extensions** : les 9 de ton profil, DOTLAN ESI Radar exclue (`dotfiles/chromium/extensions.txt`). Étape système
    (question dédiée) : `/usr/share/chromium/extensions/<id>.json`, installation depuis le Chrome Web Store au démarrage,
    activées sans question, retirables. Ce dossier vaut pour tous les profils, donc les web apps les refusent par leur
    profil (`extensions.external_uninstalls`). VM : 9 extensions dans le navigateur, 0 dans les 6 web apps ; `--uninstall`
    → désinstallées au lancement suivant.
  - **nightTab** : réglages sauvegardés dans `dotfiles/chromium/nighttab.json` (favoris publics, recherche résiduelle
    vidée) ; import en un clic (ton choix), rappelé en fin d'`install.sh`. Import vérifié en VM : page identique.
  - **Thème GTK au 1er lancement** (« GTK coché, rendu standard ») : **non reproduit**. Banc Sway et environnement Hyprland,
    boîte « conditions d'utilisation » acceptée, puis VM vierge par ton parcours exact (greetd → Hyprland → Super+A → Accept) :
    Catppuccin dès la première fenêtre (barre `#313244` / `#181825`). Profil de ta VM lu sur disque : rien d'anormal (fichier
    final après ta correction). À revoir au prochain essai : capture + `chrome://settings/appearance` si ça se reproduit.
  - Tests : `test-install.py` 0 échec (nouveaux contrôles : barre de titre, refus des extensions dans les web apps, refus
    existant gardé et remis) ; VM : installation code 0, 2ᵉ passage sans changement Chromium, retrait.

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

## Affinage laptop — échelle (2026-11-09)

- Diagnostic : Hyprland choisissait automatiquement une échelle de 1.5 sur la dalle 1920×1200, soit seulement 1280×800 logiques.
  Le centre de `terrier` était à 1 (les deux LG 4K à 1.5). Choix validé : échelle 1 pour le bureau et toutes les applications.
- Configurations machine Sway et Hyprland ajoutées : dalle identifiée par description, mode préféré conservé, écrans externes
  inchangés. Sway utilise le fabricant EDID avec virgule et `Unknown` pour la série absente ; Hyprland retire cette virgule.
  Le fichier Sway des sorties est aussi repris par `scripts/greeter.sh` à la prochaine mise à jour de sa copie système ; aucune
  modification système effectuée ici.
- Validations : syntaxe Lua, `Hyprland --verify-config` et `sway --validate` OK (inclusion machine Sway vérifiée dans le log).
  `test-outputs.sh sway` et `test-outputs.sh hyprland` sur copie isolée : **0 échec** chacun ; bancs arrêtés.
- Session réelle : rechargement Hyprland appliqué, 1920×1200 logiques à l’échelle 1, aucune erreur de configuration ; même
  instance Quickshell vivante. Capture avant/après (`.shots/laptop-scale-before.png`, `laptop-scale-after.png`) : barre sans
  chevauchement, volume et curseur de nouveau visibles. Contrôle visuel du panneau de réglages à l’échelle 1.
- Reste à vérifier à la main : rendu dans une vraie session Sway (description de sortie et échelle), persistance après reconnexion.

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

Poursuivre les tests réels du laptop installé (« À tester à la main »), notamment le rendu Sway à l’échelle 1 et la persistance
après reconnexion, puis terminer le rapport de phase 12. Affinage de l’interface en cours depuis le laptop.
