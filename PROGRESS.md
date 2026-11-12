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

- `install.sh` (`README.md`) : paquets officiels d'abord (`[multilib]` activé, `paru-bin` seule construction AUR ; Claude Code
  par son script officiel ; NordVPN, Plex, RustDesk seulement documentés), paquets selon la carte (`deps/gpu.txt`), profil optionnel jeux, liens des configs,
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

## Affinage laptop — rétroéclairage du clavier (2026-11-09)

- Choix corrigé et appliqué : **toujours allumé sur secteur, extinction après 30 secondes sans activité sur batterie**.
- Réglages natifs du BIOS, relus après écriture avec authentification administrateur ; détails et retour arrière dans
  `hosts/laptop-bios.md` (sans identifiant ni modèle matériel). Pas de changement QML ni de service ajouté.
- Le BIOS signale un redémarrage nécessaire. Reste : redémarrer, attendre plus de 30 s sans activité sur
  secteur, puis débrancher et vérifier l'extinction à 30 s sur batterie, le rallumage à la frappe et au rebranchement.

## Maintenance — Reflector (2026-11-09)

- `install.sh` propose Reflector avant les paquets du bureau (Arch Linux uniquement). S'il manque, amorçage par
  `pacman -S --needed reflector` avec les miroirs existants, puis installation habituelle avec mise à jour complète.
- Sélection mondiale : HTTPS, synchronisation < 12 h, vingt candidats au maximum classés par débit ; initialisation immédiate
  via le service du paquet, puis `reflector.timer` hebdomadaire. Aucun pays fixé, aucune mise à jour de paquets automatique.
- Configuration, liste initiale et changements d'activation/activité du timer sauvegardés pour le retrait système. Échec :
  dernière liste conservée, suite de l'installation et rappel final ; nouvelle tentative au passage suivant. Une initialisation
  réussie n'est pas rejouée si la configuration et la liste sont présentes. Options de simulation et d'exclusion respectées.
- Validations : `python3 scripts/test-reflector.py` OK (commandes factices, quatre états initiaux du timer, fichiers absents,
  échecs réseau/liste vide, reprise après une ancienne réussite, amorçage, options, idempotence et retrait) ;
  `python3 scripts/test-install.py` **0 échec** ; syntaxe Bash et `git diff --check` OK. Source officielle Reflector 2023 vérifiée :
  sélection vide rejetée avant toute écriture, timer hebdomadaire persistant. Test de sélection vide exécuté hors réseau sur
  ce code officiel : fichier d'origine conservé.
- Reste : validation réelle du service et du timer dans une VM Arch (image de test et accès KVM absents de cet environnement).
  Aucun paquet installé ni réglage système modifié sur la machine de travail.
- Activation ultérieure sur le laptop, à ta demande : `reflector` installé, configuration et liste initiales sauvegardées,
  premier passage réel réussi (`Result=success`, `ExecMainStatus=0`, environ 59 s). Liste mondiale HTTPS générée ; trois
  candidats ont dépassé le délai du test de débit, sans empêcher le résultat. `reflector.timer` activé et actif ; prochaine
  exécution le 2026-11-16 vers 02:01 +03. Service ponctuel arrêté normalement entre les passages, déclenché par le timer.

## Maintenance — pacman et paru sans mot de passe (2026-11-09)

- Choix validé : tous les membres de `wheel`. `install.sh` propose la règle avant Reflector et les paquets ; commande seule :
  `scripts/system-setup.sh pacman-sudo`. Paru reste lancé en utilisateur, ses appels sudo à pacman bénéficient de la règle.
- `/etc/sudoers.d/90-qs-desktop-pacman` : `%wheel ALL=(root) NOPASSWD: /usr/bin/pacman`, root:root, mode 0440.
  Inclusion du dossier et configuration existante vérifiées ; fichier préparé et validé avec `visudo`, remplacement atomique,
  restauration en cas d'échec dans la même transaction root. Registre système existant : sauvegarde et retrait.
- Options respectées : simulation sans sudo ni écriture ; `--no-system` exclut le réglage, `--no-packages` le permet,
  `--yes` accepte la question. Les autres commandes sudo gardent leur authentification.
- Tests : `python3 scripts/test-sudo-pacman.py` OK (état absent/existant, validation, retour arrière, inclusion absente ou erronée,
  lien refusé, permissions, idempotence, options, refus, ordre et retrait) ; `test-reflector.py` OK après isolation de la détection
  du paquet (le vrai Reflector installé ne doit pas contourner le faux amorçage). Syntaxe Bash et `git diff --check` OK.
- `test-install.py` : un échec préexistant, reproduit avec `install.sh` de HEAD avant cette modification : le nouveau
  `update-desktop-database` laisse `.local/share/applications/intent.cache` au retrait. Les autres contrôles passent.
- Activation réelle demandée et faite sur le laptop avec authentification initiale dans un terminal : `visudo -c` OK,
  propriétaire et mode relus (`root:root 440`). `sudo -k -n /usr/bin/pacman --version` réussit sans cache ;
  `sudo -k -n /usr/bin/true` exige toujours un mot de passe. Aucun paquet installé ou mis à jour. Bureau vivant (PID 4614).

## Affinage laptop — barre adaptative (2026-11-09)

- Musique : budget en pixels par écran, partagé entre artiste et titre, avec ellipses ; anciennes limites Waybar supprimées.
  Les marges et écarts de 10 px sont réservés avant le texte, y compris à l’apparition des mises à jour et d’icônes du tray.
- Petites largeurs : texte musical réduit, date masquée si nécessaire (heure gardée), puis statistiques GPU / CPU / mémoire.
  Le volume, son curseur et les commandes du lecteur restent visibles ; retour automatique au profil complet.
- Configuration par défaut : luminosité et batterie déplacées avant le tray dans la dernière pilule ; couleurs peach / teal.
  Batterie toujours rouge à ≤ 30 % hors charge. Alertes existantes conservées : normale à 30 %, critique à 15 % ;
  les urgences critiques passent le mode « Ne pas déranger » (`Notifs.silent`).
- Validations sur copie isolée : `test-bar.py` passe (70 scénarios à 1280, 1480, 1600, 1920 et 3440 px, lecture/pause,
  Unicode, champs absents, mises à jour 0/999, croissance du tray, matériel absent), sans avertissement QML.
  `test-battery.py` passe (couleurs, seuils, urgence, déduplication et réarmement) avec source et commande simulées.
- Captures du banc comparées à la charte ; fichiers appliqués ensemble. Session réelle Sway à 1920×1200 : rechargement réussi, puis démarrage
  propre pour reprendre la disposition complète (PID 49124 vivant, icônes luminosité / batterie visibles). Capture : `.shots/bar-responsive-after.png`. Bancs arrêtés.
- Reste : appréciation visuelle et vrais clics/molette sur la musique, le volume, le calendrier et le tray ; vrais seuils de
  batterie et nouvelle largeur sur écran externe. Aucune action réelle VPN ou batterie pendant les essais.

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
- Spotify annonce sa pause ~260 ms après la commande (fixe, fondu interne ; lecture et Chromium : ~10 ms) : la pastille attend
  l'état réel. Laissé tel quel (ton choix du 2026-11-10, pas d'affichage anticipé).
- NetworkManager prend le nom d'hôte du DHCP quand la machine n'a pas de nom fixe (`install.sh` le signale).

## Prochaine étape

Poursuivre les tests réels du laptop installé (« À tester à la main »), notamment le rendu Sway à l’échelle 1 et la persistance
après reconnexion, puis terminer le rapport de phase 12. Affinage de l’interface en cours depuis le laptop.

## Maintenance — métriques GPU Intel (2026-11-09)

- Diagnostic réel : Intel Arrow Lake-U / i915 détecté ; pas de hwmon GPU ni de `gpu_busy_percent`.
  Accès aux compteurs perf globaux refusé (`perf_event_paranoid=2`). Choix : aucune estimation ni modification des droits ;
  barre masquée lorsque la charge est indisponible, sans remplacement par une fréquence.
- `Gpu.cardPath` découple la carte de son capteur. Moniteur : fréquence réelle Intel (0 MHz valide au repos), mesures sysfs
  disponibles aussi pour AMD sans température, mémoire résidente DRM par processus et application. Identité PID + démarrage,
  filtre PCI, clients dédupliqués dans une application. Mémoire Intel partagée signalée ; aucun total physique déduit.
  NVIDIA garde `nvidia-smi`. Relevés uniquement panneau ouvert ; valeurs périmées effacées à la fermeture ou en cas d'échec.
- Validations : `test-gpu.py` (7 cas), `test-monitor.py` (9 réussis, intégration Chromium optionnelle non lancée),
  `test-gpu-qml.py` (Intel sans température, AMD sans température, NVIDIA simulés : détection, barre, moniteur, fermeture,
  déduplication), `test-bar.py` (70 scénarios) : OK. Bancs Sway isolés, aucun avertissement QML au démarrage ; message IPC
  de déconnexion à l'arrêt de Quickshell seulement. Captures comparées à la charte.
- Laptop : lecture réelle de 18 clients DRM, puis moniteur ouvert et capturé (`.shots/gpu-monitor-after.png`) : fréquence
  800 MHz et mémoire GPU des applications visibles ; fermeture et focus initial restaurés. Même bureau vivant (PID 49124),
  pas d'erreur QML ; avertissements Qt textinput déjà présents avant le changement. Aucun paquet installé, aucun droit modifié.
- Reste à vérifier à la main : tri par mémoire GPU et passage Applications / Processes selon ton usage ; AMD et NVIDIA réels
  à revalider sur les machines correspondantes. Bancs arrêtés.

## Maintenance — coût des relevés GPU (2026-11-09)

- À ta remarque sur les performances : mesures réelles sur trois passages, environ 140–163 ms CPU par collecte avant
  optimisation (~6 % d'un cœur à 2,6 s). Filtrage des descripteurs par nœud `/dev/dri` avant toute lecture fdinfo,
  parcours `os.scandir` : 84–100 ms CPU par passage, mêmes 18 clients retrouvés.
- Intel : relevés espacés à environ 10 s (premier relevé immédiat à l'ouverture, délai réinitialisé à la fermeture).
  Coût moyen du collecteur GPU ramené à environ 0,9 % d'un cœur lorsque le panneau reste ouvert ; aucun relevé périodique
  GPU panneau fermé sur ce laptop. Les autres relevés du moniteur et le rythme NVIDIA / AMD sont inchangés.
- Tests : `test-gpu.py` (8 cas, dont absence de lecture des fdinfo non GPU), `test-gpu-qml.py` (Intel / AMD / NVIDIA,
  espacement Intel et réarmement à la fermeture) : OK. Même rendu ; bancs arrêtés.

## Maintenance — fréquence réactive et charge Intel absente (2026-11-09)

- Clarification : la charge GPU Intel n'a pas été implémentée ; la masquer dans le moniteur rendait ce manque ambigu.
  La carte indique maintenant « Load unavailable » lorsqu'aucune charge n'est mesurée.
- Fréquence : lecture native `FileView` chaque seconde panneau ouvert, distincte de la collecte mémoire (~10 s).
  Aucun nouveau processus ni parcours `/proc` pour cette lecture ; 0 MHz reste valide lorsque le GT est au repos.
- Test QML modifié : le fichier de fréquence simulé passe de 0 à 1300 MHz entre deux relevés mémoire ; le moniteur
  doit suivre le changement avant 10 s. Intel / AMD / NVIDIA simulés : OK, sans avertissement QML de démarrage.
- Charge réelle : `intel-gpu-tools` 2.6-1 disponible dans Extra, absent du laptop ; `perf_event_paranoid=2`.
  Installation et autorisation ciblée du collecteur encore soumises à ton accord. Aucun changement système effectué.
- Session réelle : après rechargement, IPC Quickshell bloqué (« Not ready to accept queries yet ») malgré le processus vivant.
  Relance contrôlée par `desktop.sh restart` : IPC et ouverture du moniteur rétablis, nouveau PID 55946.
  Capture `.shots/gpu-monitor-clock-fix.png`, fermeture et focus restaurés ; aucun avertissement QML au démarrage,
  seulement les anciennes icônes NordVPN manquantes. Lecture directe sysfs au repos : 0 MHz réel, 1200 MHz demandé
  (fréquences distinctes, aucune substitution). Bancs arrêtés.

## Maintenance — vraie charge Intel et installation portable (2026-11-09)

- Autorisation donnée : installer l'outil Intel et lui donner le droit ciblé si le coût reste faible ; installer aussi ce paquet
  automatiquement sur les futures machines Intel. `intel-gpu-tools` 2.6-1 installé (dépendances libprocps, peg, xorg-xrandr).
  `CAP_PERFMON` accordé uniquement à `/usr/bin/intel_gpu_top` ; Quickshell reste utilisateur, `perf_event_paranoid=2` conservé.
- Un seul collecteur natif persistant à 5 s : barre = compteur matériel Render/3D ; moniteur = 3D, Copy, Video, Video+,
  Compute, fréquence réelle moyenne `avg`, consommation GPU et mémoire déclarée par processus/application. Le flux est
  partagé ; aucun parcours Python Intel supplémentaire avec les PMU valides. Première mesure d'initialisation ignorée ;
  reprise après échec, expiration des données figées, repli lecture sysfs sans inventer de charge. Pas de température GPU exposée.
- Coût réel : outil seul à 1 s 2,22 % d'un cœur, à 2,6 s 1,21 %, à 5 s 0,60 %. Intégré au bureau à 5 s : 0,40 % sur 20 s.
  Module QML isolé + collecteur sur 20 s : 0,15 + 0,40 = **0,55 % d'un cœur**. Collecteur actif même panneau fermé pour la barre.
- `deps/gpu.txt` : intel-gpu-tools + libcap sélectionnés pour Intel seulement. `install.sh` demande l'autorisation PMU à
  l'étape système (`system-setup.sh intel-gpu`). `intel-gpu-setup.sh` : transaction polkit, sauvegarde de l'ancien droit et du
  hook éventuel, idempotence, simulation, retour arrière sur échec et retrait. Hook pacman root:root 644 installé pour
  réappliquer le droit après les mises à jour du paquet ; état d'origine sans capacité enregistré dans `/var/lib/qs-desktop/intel-gpu`.
- Tests : `test-intel-gpu-setup.py` (sélection du paquet + étape système, droits précédents, échec, restauration, simulation,
  idempotence), `test-gpu-qml.py` (Intel refusé et PMU valide, flux JSON fragmenté/échappé, première mesure, vrais zéros,
  champs absents, partage barre/moniteur, AMD, NVIDIA), `test-gpu.py`, `test-monitor.py`, `test-sudo-pacman.py`,
  `test-reflector.py`, `test-bar.py` (70 scénarios) : OK. Syntaxe Bash et diff sans erreur. Intégration Chromium optionnelle non lancée.
- Session réelle : charge 3D variable (notamment 2,8 % puis 1,8 %), consommation 0,1 W, fréquence moyenne 29 puis 43 MHz,
  mémoire GPU des applications affichée. Captures `.shots/intel-gpu-monitor.png` et `.shots/intel-gpu-bar.png`, charte vérifiée.
  Démarrage propre, IPC et moniteur fonctionnels, panneau refermé et focus restauré ; bureau vivant PID 71676.
  Avertissements préexistants : icônes NordVPN et Qt textinput ; aucune action VPN. Bancs et sondes de mesure arrêtés.
- Reste : charge vidéo/jeu et autres machines Intel à vérifier à l'usage, mise à jour réelle du paquet (hook testé sur données
  simulées, pas de réinstallation imposée). NVIDIA et AMD validés ici par simulation.

## Revue du moniteur et de la collecte GPU — passe 1 (2026-11-09)

- Deux défauts reproduits avant correction sur copie isolée : cache mémoire Intel indexé seulement par PID, réattribué à
  un nouveau processus réutilisant le PID ; retrait des droits Intel qui écrasait un changement administrateur postérieur.
- Correction : une trame Intel fraîche associe les clients aux identités PID + démarrage connues du moniteur ; les relevés
  de processus suivants ne réattribuent plus cette mémoire à un PID recyclé. Réinitialisation à la fermeture et perte du flux.
  Le retrait conserve une capacité modifiée depuis l'installation et retire normalement notre hook inchangé.
- Contre-épreuves : nouveaux scénarios de `test-gpu-qml.py` et `test-intel-gpu-setup.py` échouent sur le code précédent,
  passent après correction. Intel avec/sans PMU, AMD, NVIDIA, `test-monitor.py` et `test-gpu.py` : OK.
  Aucun droit réel ni fichier système modifié par cette revue ; tests d'installation sur faux outils et fichiers jetables.

## Revue du moniteur — passe 2, clôture (2026-11-09)

- Nouvelle lecture du moniteur, UI, regroupement/arrêt des processus, collecte Intel/NVIDIA/AMD, décodeur et mise en place
  des droits : aucun autre défaut significatif trouvé. Pas de refonte ou de correction cosmétique ajoutée.
- Banc QML existant `scripts/tests/monitor/shell.qml` : vues Applications / Processes, sommes, tri, sélection figée,
  bascule, animation, réouverture et comptage des utilisateurs/relevés : OK. Test supplémentaire sur copie : collecteur Intel
  qui publie des valeurs puis échoue ; barre masquée, données PMU et cache invalidés, repli sysfs fonctionnel : OK.
- `test-gpu-qml.py` (Intel avec/sans PMU, PID réutilisé, AMD, NVIDIA), `test-monitor.py`, `test-gpu.py`,
  `test-intel-gpu-setup.py`, `test-sudo-pacman.py`, syntaxe Bash et `git diff --check` : OK ; intégration Chromium optionnelle non lancée.
- Série arrêtée à cette passe conformément à ta demande. Limite des validations : AMD/NVIDIA simulés, Intel réel ;
  pas de mise à jour réelle de paquet ni de changement des droits système pendant la revue.
- Contrôle final réel : moniteur ouvert 6 s, mémoire des applications et mesures GPU visibles, capture
  `.shots/monitor-review-after.png` comparée au rendu précédent ; panneau refermé et focus initial restauré.
  Bureau vivant PID 76660, un seul collecteur Intel, aucun banc restant ; droits GPU inchangés.

## Retours laptop — Nemo, Thunderbird, nightTab (2026-11-10)

- **Icônes de Nemo bleues** (Vidéos, et toutes au zoom) : deux défauts de la surcouche Papirus d'`install.sh`. Papirus sert
  `folder-videos` par une chaîne de liens (→ `folder-video` → `folder-blue-video`) que la surcouche ne suivait pas ; et les
  tailles 96 / 128 du zoom (liens `96x96/places → 48x48`) n'y étaient pas, donc GTK prenait les dossiers bleus du système.
  Corrigé : chaînes suivies, liens de tailles repris tels quels (Papirus et Papirus-Dark), noms explicitement bleus
  (`folder-blue-*`) laissés bleus. Révision dans la marque du thème : la surcouche est refaite sur les machines déjà installées.
  Comparaison réelle (recherche GTK simulée) avec le Papirus de `terrier` : **0 différence sur 1 186** couples icône × taille
  (419 avec l'ancien code).
- **Dossiers du Home** (ton choix : `Applications` au pluriel) : Modèles, Public et Projets désactivés dans
  `user-dirs.dirs` (« $HOME/ », plus recréés à la connexion), retirés s'ils sont vides, gardés avec un message sinon ;
  `~/Applications` créé. `--uninstall` remet `user-dirs.dirs` et recrée les dossiers vides retirés.
- **Thunderbird** (ton choix : politique système) : thème officiel `mocha-green.xpi` (commit figé, SHA-256 dans
  `deps/themes.txt` ; même thème que sur `terrier`, une couleur `lwt_frame` en plus) copié dans
  `/usr/local/share/catppuccin-thunderbird/`, installé par `ExtensionSettings` dans `/etc/thunderbird/policies/policies.json`
  (`normal_installed` : actif, désactivable). Une politique existante à toi n'est jamais écrasée. Thunderbird 159 range ses
  profils dans `~/.config/thunderbird` (`terrier` : encore `~/.thunderbird`).
- **nightTab** : `dotfiles/chromium/nighttab.json` était **identique** à ta page de `terrier` (11 favoris, thème, icônes ; seule
  la recherche en cours vidée) : rien d'oublié, l'import était manuel. Ton choix : import automatique,
  `scripts/nighttab-import.py` (Chromium sans fenêtre piloté par `--remote-debugging-pipe`, écriture de la clé `nightTab`,
  rechargement, relecture). Une fois par version du fichier ; Chromium ouvert ou extension absente : rappel en fin d'installation.
- Tests : `test-install.py` 0 échec (Papirus d'origine en miniature résolu comme GTK, mise à niveau d'une ancienne surcouche,
  Home déjà habité) ; contre-épreuve sur l'ancien `install.sh` : 4 échecs. `test-thunderbird-theme.py` OK (installation,
  idempotence, nouvelle version, politique existante, retrait). Import nightTab sur un profil jetable : page identique.
- **VM Arch vierge** : installation code 0 ; Home = Applications, Desktop, Documents, Downloads, Music, Pictures, Videos ;
  nightTab importé dans le profil **neuf** (extension installée depuis le Web Store pendant l'import), page vérifiée dans
  Chromium ; Thunderbird : thème Catppuccin actif dans un profil neuf (`extensions.json`, `activeThemeID`) ; Nemo : dossiers
  lavande au zoom normal et maximal, Vidéos compris. Second passage sans changement (hors `sudo pacman`, refusé à cause de
  `/etc/sudoers.d/arch` mal réglé dans l'image de test, sans rapport). `--uninstall` : politique, copie et `user-dirs.dirs` retirés.
- **Sur le laptop** : `git pull`, fermer Chromium, `./install.sh` (accepter l'étape « Thème Catppuccin de Thunderbird ») ;
  puis vérifier Nemo (zoom), Thunderbird au prochain lancement, nouvel onglet de Chromium.
- **Nemo, « Ouvrir dans un terminal » sans effet** (laptop et VM) : Nemo lance le terminal de la clé Cinnamon
  `org.cinnamon.desktop.default-applications.terminal exec`, dont le défaut (`cinnamon-desktop` 6.8) est `velocitty`, absent.
  Sur `terrier`, la clé valait `gnome-terminal` par un reste de l'ancienne session Cinnamon. Corrigé : `exec='gnome-terminal'`,
  `exec-arg='--'` dans `dotfiles/dconf/desktop.ini` (gardé au retrait comme les autres clés). `test-install.py` : 0 échec,
  contrôle ajouté ; dconf isolé : `velocitty` → `gnome-terminal`. **À tester** : `git pull`, `./install.sh`, puis Nemo →
  clic droit dans un dossier → « Ouvrir dans un terminal » (GNOME Terminal dans ce dossier).

## Pastille musique — régression de largeur (2026-11-10)

- Cause : `a7a55f2` (barre adaptative) donnait à la musique **toute** la place restante (aucun plafond : titre long étiré jusqu'aux
  mises à jour sur l'ultrawide), et `elideWidth: Math.floor(…)` abrégeait un artiste qui tenait (« R… - Hi Ren »).
- Corrigé (`Mpris.qml`, `Theme.bar`) — tes choix : texte plafonné à **600 px** (`mediaTextMaxWidth`) ; écart restant
  **< 50 px** (`mediaSnapGap`) → la pilule se cale sur l'écart normal de 10 px. Artiste / titre entiers quand ils tiennent ;
  artiste réduit à « … » retiré, le titre prend la place.
- Tests : `test-bar.py` complété (texte ≤ 600 px, « Ren - Hi Ren » entier dès 1920 px, écart = 10 px ou ≥ 50 px, pas de
  « … - ») ; passe sur copie de 1480 à 3440 px, sans avertissement QML. Captures du banc à 1480 / 1600 / 1920 / 3440 vérifiées ;
  bureau réel rechargé sans erreur (Hyprland, PID 498448), `.shots/media-pill-after.png`.
- **Connu** : sur `terrier`, `test-bar.py` échoue **déjà avant ce correctif** à 1280 px (modules fixes 1278 px pour 1260
  disponibles) et sur le niveau attendu à 1480 px : le tray réel de cette machine fait 155 px (plus d'icônes que sur le laptop
  où le test a été écrit). Le test dépend donc du tray de la machine ; à décider (tray figé dans le test, ou niveau de repli en plus).
- Ta demande : sans place pour le texte, la pastille ne montre que l'**icône du lecteur** (Spotify, Chromium…), le haut-parleur et
  le curseur ; l'icône de pause n'apparaît qu'avec le texte. Testé sur le banc (pause et lecture, 1480 → 3440 px) ; bureau réel
  rechargé sans erreur, `.shots/media-pill-iconsonly.png`.
- À tester à la main sur le laptop : titres longs, apparition des mises à jour, tray qui grandit (écart toujours 10 px ou ≥ 50 px).

## Installation — Claude Code, barres d'état, fonds d'écran (2026-11-10)

- **Claude Code** : `install.sh` (étape 1, après paru) propose le script officiel `https://claude.ai/install.sh`, téléchargé en
  entier puis lancé (binaire dans `~/.local/bin`) ; rien si `claude` existe déjà (paquet AUR sur `terrier`). `~/.local/bin`
  ajouté au PATH des terminaux (`dotfiles/bash/qs-desktop.bash`). Codex : déjà installé par `deps/apps.txt` (`openai-codex`).
- **Barres d'état** reprises de `terrier` (étape 4) : `dotfiles/claude/statusline-command.sh` (ton script, jq) lié dans
  `~/.claude/`, clé `statusLine` fusionnée dans `~/.claude/settings.json` (mise en forme et autres clés gardées) ; Codex :
  `[tui] status_line` de `~/.codex/config.toml` (7 éléments natifs). Seules ces clés sont remises au retrait. Fusion JSON
  commune à Chromium et Claude Code (`json_merge`, `json_write`). Sur `terrier` : réglages déjà identiques, seul le script
  devient un lien vers le dépôt (ancien fichier en `.bak-<date>`).
- **Fonds d'écran** : clonage avec la progression de git (objets, Mo, débit) et `--depth 1` depuis GitHub (dernière version :
  pas les images retirées de l'historique). Dépôt `wallpapers` : `simple/wallhaven-dpqjwj-3440.jpg` et `-3440.png` retirés
  (`31d9a7b`), gardé `wallhaven-dpqjwj.jpg` (3840×2160). Sur `terrier`, le choix « tous les écrans » pointait vers l'un d'eux :
  sans effet (chaque écran a son propre fond ; sinon repli sur le fond de la config machine).
- Tests : `test-install.py` complété (réglages existants gardés, script de barre d'état lancé sur un JSON d'exemple, Codex lu
  par `tomllib`, retrait à l'identique) : 0 échec ; simulation sur `terrier` sans changement inattendu ; clone réel vérifié.
- Vus au passage, **non retirés** (à ta décision) : `panorama/336375.jpg` = `52RY9Px.jpeg` (Voie lactée, 5760×1080, fichiers
  presque identiques), `simple/nathan-anderson-…-unsplash.jpg` (7010×2955) = `photo-1475738198235-….jpeg` (3476×1465, ciel
  étoilé), `panorama/andrii-ganzevych-…-unsplash.jpg` (10591×3555) ≈ `photo-1536919641626-….jpeg` (3456×1160, lac turquoise,
  autre étalonnage).
- **À tester sur le laptop** : `git pull`, `./install.sh` → question Claude Code (si absent), `claude` dans un nouveau terminal,
  barres d'état de `claude` et `codex` ; fonds : `rm -rf ~/Pictures/Wallpapers` n'est **pas** nécessaire (`git pull` retire les
  deux doublons).

## Profils jeux / travail et install.sh consolidé (2026-11-10)

- **Profil de la machine** : clé `profile` de `hosts/<machine>.json` (`jeux` | `travail` ; défaut `travail` dans
  `default.json`, `terrier` en `jeux`), lue par `scripts/profile.sh` pour Sway (`include profiles/<profil>.conf`), Hyprland
  (`lua/profile.lua` → `profiles/<profil>.lua`) et `install.sh` ; `Settings.profile` côté Quickshell.
- **jeux** : règles et démarrage de Steam, de ses jeux (EVE, gamescope, Megabonk) et de Deluge déplacés tels quels dans
  `dotfiles/{sway,hypr}/profiles/jeux.*` ; paquets `deps/games.txt` (Deluge y passe depuis `apps.txt`), `[multilib]`.
- **travail** : espace 5 libre, Discord-WhatsApp sur 6, Spotify sur 7, DigitalMicrograph sur 9, aucun démarrage automatique ;
  glyphes 5 `nf-md-circle_double` (U+F0E95) et 9 `nf-md-microscope` (U+F0654). Espaces de Discord-WhatsApp et de Spotify fournis
  par le profil (`$ws_chat` / `$ws_music` sous Sway, `workspaces` sous Hyprland), règles communes ; paquets `deps/work.txt`
  (winetricks, wine-mono, wine-gecko, cabextract, icoutils, potrace) ; `install.sh` clone `Crystal4276/GMSFreeAnalysis17` dans
  `~/GMSFreeAnalysis17` (gh ou SSH) et rappelle à la fin de lancer son `scripts/install-all.sh` avec le kit Gatan.
- **install.sh, deux questions au plus** : profil (seulement si la config machine n'en a pas ; `--profil jeux|travail` remplace
  `--with/--without jeux` ; écrit dans `hosts/<machine>.json`, mise en forme gardée) ; étapes système d'un bloc, liste affichée
  (« non » = `--no-system`). Claude Code et fonds d'écran sans question. Clonage commun (`sync_repo`, fonds + DM).
- Vérifié : `Hyprland --verify-config` et `sway -C` pour les deux profils (fichier de profil réellement chargé) ; banc Sway
  headless : barre jeux identique, barre travail (double cercle en 7, microscope en 9), aucun nouvel avertissement ; bureau réel
  (Hyprland) rechargé sans erreur, Deluge / Steam toujours sur 7 / 9 ; `test-install.py` : 0 échec (passage travail ajouté) ;
  simulations `--profil jeux` / `--profil travail` sur `terrier`.
- **Laptop** : `corelabs-laptop` n'a pas de `hosts/*.json` dans le dépôt : au `git pull`, il passe en **travail** (plus de Steam ni
  Deluge au démarrage, glyphes 7 / 9 changés). `./install.sh` y demandera le profil et créera le fichier (à committer).
- **DigitalMicrograph, vérifié sur la VM `qs-desktop-test`** (agent invité QEMU, Sway headless à part, greeter intact, VM
  rééteinte) : app_id `digitalmicrograph.exe` avec le pilote Wayland de Wine, classe X11 `digitalmicrograph.exe` (instance
  idem) avec `GMS_WAYLAND=0` ; dans les deux cas, fenêtre sur l'espace 9, focus resté sur 1. Règles réduites à ce nom exact.
- Vérifié pour les deux profils : numéros 5 / 6 (jeux) et 6 / 7 (travail) réellement appliqués sous Sway (`sway -C -d`) et
  Hyprland (sonde dans `--verify-config`) ; barre travail sur banc : double cercle, Discord, Spotify, enveloppe, microscope.
- **À tester à la main (laptop)** : Hyprland avec DM (même nom attendu) ; `./install.sh` → deux questions, clone de
  GMSFreeAnalysis17, rappel d'installation ; Discord / WhatsApp sur 6 et Spotify sur 7 au démarrage.

## Maintenance — démarrage Spotify (2026-11-10)

- Cause : les deux autostarts appelaient `spotify`, alors que l'installation du laptop fournit `spotify-launcher`.
  Script commun `scripts/spotify-launch.sh` : client direct prioritaire, sinon lanceur officiel ; erreur explicite si aucun
  n'est présent. Arguments et code de sortie transmis ; temporisations et espaces des profils conservés.
- À ta demande : lancement standard pour ton abonnement, sans bibliothèque préchargée ; anciennes références retirées
  des deux configurations et de l'inventaire archivé. Aucun paquet ni bibliothèque supplémentaire à retirer sur le laptop.
- Vérifié sur copie isolée : quatre cas de disponibilité des commandes, arguments et codes de sortie ; syntaxes Bash/Lua ;
  `sway -C` headless et `Hyprland --verify-config` pour jeux et travail : OK, sans erreur de configuration.
- Configurations actives liées aux fichiers corrigés ; bureau réel Hyprland vivant (PID 1894).
- À tester à la main : nouvelle connexion Sway puis Hyprland, Spotify ouvert sur l'espace musique (6 en jeux, 7 en travail).

## Laptop — verrouillage à l’inactivité (2026-11-10)

- Choix validé : verrouiller après inactivité des écrans **et** avant suspension du système, sur secteur comme sur batterie.
  Délai conservé à 300 s. `idle.lockOnIdle` : null par défaut (machine avec batterie), true/false pour un choix explicite.
- `Idle` attend la confirmation du compositeur avant extinction ; activité pendant l’attente → extinction annulée, verrouillage
  conservé. Verrou refusé → écrans allumés. Inhibitions vidéo, Wayland/D-Bus et « Keep Screen On » respectées.
  `idle state` expose `lockOnIdle`. Mécanisme logind avant suspension conservé.
- Validations sur copie : `test-idle-lock.py` passe (IdleMonitor, WlSessionLock et DPMS réels sur Sway headless ; mouvement du
  pointeur pendant l’attente, confirmation tardive, refus, session déjà verrouillée, laptop/desktop, choix explicites, inhibitions
  et délai nul) ; `test-sleep.py` et `test-idle-inhibit.py` passent. Pas de nouvelle erreur QML au démarrage complet.
- `test-bar.py` échoue sur son assertion de largeur musicale à 3440 px (580,98 px mesurés, > 590 attendus) ;
  échec identique reproduit sur le code d’origine, sans rapport avec ce changement. Avertissements connus de portail Qt
  et icônes NordVPN au démarrage complet ; aucune action VPN effectuée.
- À vérifier à la main : attendre 5 minutes sans inhibition, réveiller et saisir le mot de passe ; capot → suspension → réveil,
  en vraie session Sway et Hyprland. Aucune suspension ni authentification réelle pendant les essais.
- Application groupée au dépôt : rechargement réussi sur la session Hyprland réelle ; IPC répond, `lockOnIdle=true`,
  `lockBeforeSleep=true`, délai 300 s et pont D-Bus prêt. Aucun nouvel avertissement QML au rechargement ; bancs arrêtés.


## Fonds Core Lab — profil travail (2026-11-10)

- Cause : le dépôt local des fonds était déjà à jour, mais le service ignorait le nouveau dossier `corelab/`.
- Onglet **Core Lab** réservé au profil travail : neuf designs regroupés (28 résolutions chacun dans le dépôt des images),
  bibliothèque Images / Panoramas / Triptychs conservée. Aucun fond imposé à l'activation.
- Choix mémorisé par design (`kind: corelab`, chemin `corelab/<design>`), global ou par écran. Chaque écran prend sa résolution
  physique, échelle comprise ; sinon rapport le plus proche, plus petite taille suffisante ou plus grande disponible.
  Résolution réévaluée à chaud ; caches sur le fichier résolu. Profil jeux : repli habituel, choix Core Lab conservé.
- `test-wallpapers.py` sur Sway isolé : neuf vignettes, sélection globale / par écran, 1920×1200, ultrawide, 4K à 1,5,
  arrondi fractionnaire, variante et dossier absents, caches des choix, persistance après relance et changement de profil : OK.
  Démarrages complets sans avertissement QML ; avertissements connus du portail, icônes et PipeWire sans serveur sur le banc.
- Contrôle visuel avec les vraies images : `.shots/corelab-picker-bench.png`. Application groupée, même bureau réel vivant
  (PID 1882), IPC : neuf designs, 40 images et 43 panoramas inchangés, fond actuel conservé. Sélecteur ouvert puis refermé,
  capture des neuf vignettes `.shots/corelab-picker-live.png` ; pas de nouvelle erreur QML au rechargement (avertissements textinput Qt déjà présents).
- Reste à vérifier à la main : clic dans Core Lab / Entrée sur le laptop, nouvel écran externe avec des dimensions différentes.
  Aucun paquet installé, aucune action VPN ; bancs arrêtés.

## DigitalMicrograph — halo Hyprland (2026-11-10)

- Règle commune aux profils jeux / travail pour la classe exacte `digitalmicrograph.exe` : `no_blur=true`,
  `no_shadow=true`. Classe documentée pour Wine Wayland natif et XWayland ; placement sur l’espace 9 conservé.
- Validé sur copie temporaire : syntaxe Lua et `Hyprland --verify-config` pour les deux profils (`config ok`).
  Le validateur émet aussi un diagnostic de socket IPC, sans erreur de parsing.
- Configuration réelle rechargée : aucune erreur Hyprland, même instance Quickshell vivante (PID 1882).
- Reste à vérifier à la main : absence du halo au changement de focus, au redimensionnement et à l’ouverture des dialogues
  GMS, en Wayland puis XWayland. Aucun changement de Wine, du lanceur ou des effets des autres applications.


## Barre — couleurs des espaces de travail (2026-11-10)

- Neuf couleurs Catppuccin Mocha, par position dans chaque barre : green, teal, sapphire, blue, lavender, mauve, pink, peach, red.
  Chaque écran reprend les N premières couleurs pour ses N espaces, sans interpolation ; les espaces vides restent en surface1.
  Couleur au survol et halo de l’espace affiché conservés ; indice borné pendant le retrait des boutons.
- Vérification ciblée du vrai composant sur copie isolée : 169 contrôles passent, deux profils, blocs de 0/1/2/3/4/5/9 espaces,
  réduction puis restauration, redémarrage de la palette sur le second écran, espaces visibles et vides. Captures du banc vérifiées.
- `test-outputs.sh sway` : 0 échec ; Hyprland : 0 échec au second passage. Premier passage Hyprland : une commande
  pendant l’extinction séquentielle des trois écrans, assertion « aucun écran actif » en échec ; comparaison au code
  d’origine : 0 échec. Écart intermittent à surveiller dans le banc, aucun changement des services de placement.
- Démarrages complets : aucun avertissement QML du composant ; avertissements habituels du portail et des icônes
  NordVPN, plus PipeWire absent sur Sway isolé. Aucune action VPN ni système effectuée.
- Application groupée : même instance réelle Hyprland vivante (PID 1882), IPC : espaces 1–9 sur la dalle interne,
  rechargement sans avertissement. Capture contrôlée : `.shots/workspace-colors-after.png` ; neuf couleurs du banc :
  `.shots/workspace-colors-nine-bench.png`. Tous les bancs arrêtés, aucun écran virtuel restant.
- À vérifier à la main : appréciation des couleurs, survol et halo, vrai branchement d’un écran externe.

- Ajustement demandé : rouge en dernière position, pêche en huitième pour conserver neuf teintes distinctes.
  169 contrôles ciblés sur copie isolée passent ; capture `.shots/workspace-colors-red-bench.png`. Même instance réelle
  vivante (PID 1882), IPC prêt après rechargement, capture `.shots/workspace-colors-red-after.png` contrôlée ; banc arrêté.
  Un avertissement `Notifs.qml:42` (`scheduled`, undefined → bool) au rechargement, hors du composant modifié.


## Sélecteur Core Lab — latence et caches (2026-11-10)

- Branche exceptionnelle `fix/wallpaper-corelab-latency`, worktree isolé depuis `a698fb3` : master et le bureau réel préservés.
- Cause reproduite sur Hyprland : recalcul des empreintes de toute la bibliothèque à chaque ouverture, malgré les PNG
  en cache ; le coût augmente après accumulation d'appels Qt.md5. Préchargement de 4 000 appels : clic retardé de 1 043 ms.
- Empreintes mémorisées par version de fichier ; modèle conservé si identique, écritures en cours préservées et écritures
  pendant un scan fusionnées. Noms de caches, choix enregistrés et sélection de résolution inchangés.
- Banc Hyprland corrigé : dix clics pris en compte en 1–2 ms, images prêtes en 31–52 ms ; pixels contrôlés par captures PPM.
  Mesures et limites dans docs/PERFORMANCE.md. Tests Sway et Hyprland : caches stables, modification / ajout / suppression,
  suppression du cache, écriture pendant un scan, changement de dossier, persistance, profils et résolutions.
  Contre-épreuve sur l’ancien service : le test détecte 65 empreintes recalculées au premier scan inchangé du jeu de données.
- Aucun paquet ni réglage système modifié, aucune action VPN. Validation réelle du correctif à faire après intégration
  par l'autre session : aucune copie dans master et aucun rechargement du bureau réel effectués ici.


## Onglets Images / Core Lab — réutilisation des grilles (2026-11-10)

- Suite sur `fix/wallpaper-corelab-latency`, worktree isolé : master et la session réelle conservés.
- SourceSize validée avant chargement ; une grille par onglet visité garde ses cellules, sa sélection clavier et son
  défilement. Pas de préchargement des variantes ; pas de cache Qt conditionnel ni de processus de maintenance.
- Vignettes isolées par dossier, captures à taille logique, jobs annulables par identité, récupération après cache
  absent/corrompu. Ancien cache plat régénéré une fois ; aucun choix enregistré ni cache écran migré.
- Mesure du code final sur Hyprland : cent bascules, zéro cellule recréée et zéro lecture supplémentaire après les deux
  premières visites ; huit vrais clics, pixels corrects vers 31–33 ms (capture incluse). Détails dans PERFORMANCE.md.
- Tests : Sway et Hyprland, profils/persistance/résolutions et invalidations ; callbacks obsolètes, fermeture pendant
  une capture, corruption du cache et dimensions physiques aux échelles 1 / 1,25 / 1,5 / 2.
- Aucun paquet ni réglage système modifié, aucune action VPN. À apprécier après intégration : navigation clavier,
  défilement par onglet et première régénération du cache sur la vraie session ; rien appliqué à master ici.


## Déploiement réel du sélecteur (2026-11-10)

- À ta demande : les deux correctifs de `fix/wallpaper-corelab-latency` intégrés à master par avance rapide
  jusqu’à `d43a53d`. Aucun changement suivi en attente ; fichier machine non suivi conservé.
- Rechargement groupé, même instance réelle PID 1882 : `Configuration Loaded`, IPC répond, aucune erreur QML
  ni boucle de liaison depuis le rechargement. Avertissements textinput Qt préexistants conservés.
- Sélecteur ouvert et contrôlé visuellement après la première régénération du cache : neuf designs Core Lab,
  fond `02b-degrade-vert-bleu` et choix enregistrés inchangés. Capture `.shots/corelab-tabs-deployed-ready.png`.
  Sélecteur refermé, aucun changement d’écran ni action VPN.

## Plymouth « Core Lab » — profil travail (en cours, 2026-11-10)

- Spécification et design validé versés : `docs/PLYMOUTH.md`, référence `assets/plymouth/reference/assemblage.html`, logos
  `assets/plymouth/source/`. Étapes 1 à 5 de la spec, arrêt pour validation après chacune.
- Décisions : tout le travail système en **VM** (Arch par archinstall, UEFI, **GRUB** comme le laptop, racine LUKS), jamais sur
  `terrier` (profil jeux) ; ISO officielle et paquets dans la VM acceptés. Laptop seulement à l'étape 5, avec ton accord.
- VM chiffrée prête (`docs/DEVELOPMENT.md`, « VM chiffrée ») : archinstall 4.5, GRUB, LUKS, `install.sh --profil travail` passé.
- **Étape 1, audit (VM, Plymouth 26.134.222)** — en attente de validation :
  - Démarrage : `HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)`,
    GRUB `loglevel=3 quiet` + `cryptdevice=UUID=…:root`. Le hook `encrypt` passe par `plymouth ask-for-password
    --command="cryptsetup open …"` quand Plymouth tourne : Plymouth relance lui-même la demande après un refus. Invite :
    « A password is required to access the root volume » (pas celle de systemd-cryptsetup de la référence).
  - API `script` présente : rappels Refresh, BootProgress, RootMounted, KeyboardInput, UpdateStatus, DisplayNormal, DisplayPassword,
    DisplayQuestion, DisplayPrompt, DisplayHotplug, ValidateInput, DisplayMessage, HideMessage, Quit, SystemUpdate ; `SetRefreshRate`,
    `GetCapslockState`, `GetMode` ; `Image.Rotate/Scale/Crop/Tile/Text` ; `Sprite.SetX/Y/Z/Opacity` ; `Window.GetWidth/GetHeight/GetX/GetY`.
    **Ni rotation ni échelle de sprite** : rotation et échelle = nouvelles images (`Image.Rotate` / `Image.Scale`).
  - Polices : l'initramfs ne reçoit que la police `Font=` du thème (+ gras) ; `Font=Inter` → `/usr/share/fonts/inter/Inter.ttc`
    (paquet `inter-font`), rendue par `label-freetype` : le texte variable en Inter est possible.
  - HiDPI : `DeviceScale` (plymouthd.conf) et `PLYMOUTH_FORCE_SCALE` existent ; à mesurer en 4K (image agrandie ×2 sinon).
  - Signaux : déverrouillage → `RootMounted` (le hook tardif `update-root-fs` ne passe qu'après ouverture du volume) ; sortie →
    `Quit` arrive trop tard pour animer : il faut un signal avant (`plymouth update --status=…` depuis une unité à nous), puis
    `plymouth quit --retain-splash`. greetd est `After=plymouth-quit-wait.service` ; `plymouth-quit.service` (multi-user) quitte sans
    garder l'image : à ordonner après notre unité.
  - Risques : anneaux = 13 à 15 images (56 Mo en 1920×1200, 118 Mo en 3440×1440, 185 Mo en 4K en RGBA) et composition
    logicielle plein écran pendant leur apparition ; sortie ajoutée au démarrage : fin de cycle + 0,95 s (jusqu'à 3,35 s).
  - Hors Plymouth : `install.sh` muet (code 127) sans `python3` sur un Arch minimal.
- **Étape 2, images et coût (2026-11-10)** — en attente de validation. Décisions : sortie après la fin du cycle ; fichiers du
  zip gardés dans le dépôt ; animation au moindre coût, même en 4K.
  - Moteur : Plymouth n'a aucun rendu accéléré ; `two-step` ne joue que des suites d'images figées (pas d'intro, pas de
    calques) ; le plugin `script` ne redessine que les rectangles des sprites modifiés. D'où : **anneaux découpés en 16 arcs**
    (petites PNG, points entiers, échelle 0,94 → 1 par rapprochement des arcs), demi-anneaux tournés par `Image.Rotate`,
    bande et filet en sprites fixes.
  - `scripts/plymouth-assets.py build` : un jeu d'images par échelle (1,0 / 1,2 / 1,5 / 1,8), 240 arcs par jeu, textes et
    champ par Chromium (CSS et polices de la référence), courbes précalculées ; bloc de données dans
    `dotfiles/plymouth/qs-corelab/qs-corelab.script` (prototype : intro + rotation + modes de mesure). 1,6 Mo, reproductible
    (deux passages identiques). Un seul jeu 4K réduit à 1920×1200 doublerait l'écart (texte épaissi, points amincis).
  - `check` (planche de contrôle, `.shots/plymouth/`) : écart moyen 0,10 à 0,28 sur 255, 0,09 à 0,23 % de pixels > 32 aux trois
    tailles. Écarts acceptés : Chromium place les points un peu irrégulièrement (≤ 1 px selon le quadrant ; ici espacement
    exact), texte du nom au demi-pixel près. Le texte de la demande (variable) n'est pas dans les images.
  - VM, vrai rendu Plymouth en 4K : identique à l'émulation (écart nul), donc à la référence comme ci-dessus.
  - Coût mesuré (VM, i9-9900K, CPU de `plymouthd`) : intro au pire moment 8,7 ms par image en 4K ; rotation 6,6 ms (4K),
    4,8 ms (1920×1200) ; repos 1,2 ms ; mémoire 57 Mo (1920×1200) à 111 Mo (4K). Budget 20 ms par image (50/s) : le laptop
    peut être 2,3 fois plus lent sans ralentir l'animation. 8 arcs : plus de mémoire (192 Mo) ; 32 : pas de gain.
  - Pièges notés (`DEVELOPMENT.md`) : littéraux hexadécimaux = analyse bloquée, écran noir ; pas d'exposant ; `splash`
    nécessaire même hors démarrage (`--kernel-command-line`). Pas de HiDPI appliqué en VM ; à vérifier sur le laptop.
- **Validation de l'étape 2** (tes retours) : choix techniques acceptés ; ajout de 1920×1080 et 2560×1440.
  - Jeu s = 0,9 ajouté (1920×1080 sans réduction) ; 2560×1440 = jeu s = 1,2 comme 3440×1440. `check` sur cinq tailles :
    écart moyen 0,10 à 0,38 sur 255, 0,09 à 0,34 % de pixels > 32 (un seul jeu 4K réduit : 2 à 3 fois plus). Thème 1,8 Mo.
  - `install.sh` sur un Arch minimal sans `python3` : profil lu sans Python (sous `set -e`, l'échec dans `$(…)` arrêtait
    tout, code 127, sans message). Test ajouté (`PATH` sans python) : échoue sur l'ancien code, passe sur le nouveau.
    Au passage, échec déjà présent corrigé : `intent.cache` (desktop-file-utils 0.29) noté et retiré au retrait.
    `test-install.py` : 0 échec. Vérifié en vrai sur un Arch minimal chiffré neuf (sans python) : code 0, python installé
    à l'étape 1 ; second passage : seul le clonage de DigitalMicrograph (dépôt privé, injoignable depuis la VM) est retenté.
  - Second passage, sudoers : « + » affiché à tort avant « = … à jour » ; l'annonce est maintenant faite par l'étape root
    après la comparaison (vérifié en VM : à jour « = », absent « + », simulation « + »).
  - Suite : étape 3 (thème complet : phrase de passe, sortie, plusieurs écrans).
- **Étape 3, thème complet (2026-11-10)** — en attente de validation. `dotfiles/plymouth/qs-corelab/qs-corelab.script` : intro →
  phrase de passe (repos, saisie, Verr. Maj., « Unlocking… » pulsé, refus) → rotation → sortie à la fin du cycle → crust ;
  arrêt et redémarrage : crust seul ; écrans branchés à chaud : scène reconstruite.
  - VM, hors démarrage (`preview.sh`), comparé à la référence figée avec la même invite : 0,15 à 0,25 % de pixels > 32 sur l'écran
    entier, en 1920×1200, 3440×1440 et 4K ; après la sortie, 100 % crust. Captures : `.shots/plymouth/step3-*`.
  - VM, vrai démarrage chiffré (initramfs) : intro, champ après l'intro, mauvaise phrase (« Unlocking… » pendant tout le calcul
    d'argon2, 5 à 8 s en VM) puis « Wrong passphrase », bonne phrase → fondu et rotation (`RootMounted`).
  - Coût du thème complet (4K) : 37 % d'un cœur au pire moment de l'intro, 30 % en rotation (7,4 et 6 ms par image).
  - **Écart imposé par Plymouth** : tous les écrans voient la même scène (une toile commune) ; échelle retenue : celle du plus
    petit écran (`.shots/plymouth/step3-two-screens.png`, 1920×1200 + 1280×800). À confirmer.
  - **Passage au greeter** (pour l'étape 4) : `quit --retain-splash` seul → écran noir ~1,2 s ; `plymouth deactivate` garde le
    crust jusqu'au greeter (vérifié). Restent : l'ordre de greetd (`After=plymouth-quit-wait`) et ~0,75 s de noir du compositeur
    du greeter avant son premier dessin. L'unité de sortie attendra 3,4 s fixes après la demande (le script ne peut pas
    signaler la fin de son animation).
  - Pièges ajoutés (`DEVELOPMENT.md`) : sans sprite, pas d'affichage ; écrans centrés sur une toile ; `global.` dans les fonctions.
- **Validation de l'étape 3** (tes retours) : écran de référence 1440p (un écran : le sien ; plusieurs : le 1440p, sinon le
  plus proche de 1440) ; pas de `swaybg` : le noir du greeter (~1,1 s) est accepté.
- **Étape 4, installation (2026-11-10)** — en attente de validation. `scripts/plymouth-setup.sh install|uninstall|status` ;
  `install.sh` : profil travail → installé (paquet `plymouth` dans `deps/work.txt`), profil jeux → retiré s'il était là,
  `--uninstall` → retiré. Surcharges `plymouth-quit-wait` (sortie du thème, 3,4 s, `plymouth deactivate`) et `plymouth-quit`
  (après greetd, `quit --retain-splash`). Docs : `ROLLBACK.md` (section Plymouth, secours depuis GRUB), `ARCHITECTURE.md` § 9.1,
  `README.md`, `PLYMOUTH.md`.
  - VM (Arch archinstall, GRUB, LUKS, `install.sh` réel) : installation code 0 ; second passage sans changement côté Plymouth ;
    démarrage complet enregistré : thème à 7,2 s, phrase de passe, rotation, sortie à la fin du cycle, ~1,3 s de noir du Sway du
    greeter, greeter. Bascule en jeux et `--uninstall` : `mkinitcpio.conf`, `/etc/default/grub`, `plymouthd.conf` identiques aux
    originaux (sommes de contrôle), initramfs revenu à sa taille exacte ; redémarrage : demande texte habituelle.
  - Secours vérifié en VM : GRUB `e`, `splash` retiré → phrase de passe en mode texte, démarrage et greetd normaux
    (`plymouth.enable=0` est sans effet avec le hook de l'initramfs).
  - Initramfs : +4,4 Mo (Inter Regular seule ; `Inter.ttc` aurait ajouté 13 Mo). archinstall ne crée pas d'image `fallback`.
  - `test-install.py` : simulation système travail (étape Plymouth prévue) et jeux (rien) ; 0 échec. Sur `terrier` (jeux), rien
    de Plymouth n'est installé.
  - Ton essai dans Virtual Manager (VM `qs-plymouth-corelab`, disque de l'étape 4) : rendu jugé « pas mal » ; trop long après
    Entrée. Cause : dérivation de clé LUKS d'archinstall (~10 s par essai, bonne ou mauvaise phrase), pas Plymouth.
  - Tes choix : dérivation à **5 s** ; pendant la vérification, champ masqué et **rotation** ; refus → champ aussitôt de
    retour (« Wrong passphrase »), rotation arrêtée à la fin de son tour ; bonne phrase → rotation jusqu'à la fin du démarrage,
    puis fermeture. Fait (thème, « Unlocking… » retiré). VM : disque passé à 5 s (5,4 s mesurés, en-tête sauvegardé dans
    `/root/luks-header-before-5s.img` de la VM), démarrage enregistré : champ masqué et rotation à l'Entrée, refus 5,2 s
    plus tard, rotation jusqu'à la fermeture, greeter. La VM est rendue à Virtual Manager (éteinte).
  - Ton retour : deux tours au lieu de trois après une bonne phrase. Fait : dérivation de la VM à **2,5 s** (signal de sortie
    ~1,7 s après le déverrouillage) → deux tours puis la fermeture, vérifié. Trouvé au passage : l'affichage de la VM plafonne
    à ~41 images/s (le thème en supposait 50 : animation 20 % trop lente) ; temps désormais calé sur l'horloge de démarrage
    quand elle tourne (figée par plymouthd de la demande au déverrouillage), cadence demandée 60 images/s.
  - Étape 5 (laptop, avec ton accord) : mesurer les images/s réelles et le délai déverrouillage → signal de sortie, puis
    dérivation LUKS ≈ (4,8 − délai − 0,5) s (au lieu des 5 s prévues) (`luksHeaderBackup`, puis `luksConvertKey --pbkdf argon2id
    --iter-time 5000`) ; `./install.sh` (ou `scripts/plymouth-setup.sh install`), redémarrage ; à tester à la main :
    démarrage à froid, mauvaise phrase, Verr. Maj., écran externe branché au démarrage (dont le 1440p), arrêt et redémarrage
    (écran crust), échelle HiDPI éventuelle de Plymouth sur la dalle interne.
  - Revue de code (2026-11-10, trois passages jusqu'à ne plus trouver que du négligeable). Corrigé dans `plymouth-setup.sh` :
    - une reconstruction interrompue est reprise au passage suivant, grâce à une marque `rebuild` posée avant le premier
      changement (mkinitcpio, grub-mkconfig ou sudo en échec) ;
    - HOOKS sur plusieurs lignes refusé d'emblée, sauf si le hook a été ajouté à la main ;
    - GRUB exigé dans `/boot/grub`, vérifié par sudo quand l'ESP est illisible (dmask=0077 d'archinstall : sans cela,
      le laptop aurait été refusé à tort) ;
    - machine non prise en charge : code 3, signalé une fois par `install.sh`, sans « relancer » ;
    - retrait possible même sans `plymouth-set-default-theme`.

    Dans le thème : un statut systemd pendant la vérification (cas `sd-encrypt`) n'efface plus un refus.

    Côté test, `test-install` lance `plymouth-setup.sh --dry-run` depuis le dépôt.

    Tout est vérifié dans une couche jetable de la VM : échec de mkinitcpio puis reprise, `/etc/default/grub` non modifiable
    puis reprise, retrait sans l'outil, HOOKS sur plusieurs lignes, puis redémarrage avec refus, déverrouillage, greeter et
    départ de plymouthd. Laissé de côté, jugé négligeable :
    - les cinq jeux d'images dans l'initramfs ;
    - les couleurs recopiées de la spec ;
    - deux passages de Chromium dans `plymouth-assets.py` ;
    - quelques formes de HOOKS improbables.

- Synchronisation du déploiement : commits Plymouth / installation publiés par l’autre session conservés par fusion ;
  seul conflit dans le journal résolu en gardant les deux ajouts. Aucun installateur ni réglage système exécuté.

## Écran de connexion — fond de la session Hyprland (2026-11-10)

- Constat (laptop, profil travail) : fond changé, déconnexion, l'écran de connexion garde le fond par défaut.
- Cause : le bureau exporte le fond de chaque écran sous `md5(description).jpg` ; l'écran de connexion tourne sous Sway, la
  session du laptop sous Hyprland, et la description de la dalle diffère : Sway `China Star Optoelectronics Technology Co., Ltd
  0x1471 Unknown` (pas de numéro de série dans l'EDID), Hyprland sans « Unknown » (virgules retirées de ses propres descriptions).
  Fichier introuvable → `default.jpg`. `terrier` non touché (numéros de série, aucune virgule : même chaîne partout).
- Correctif : `Compositor.describe`, même description sous les deux compositeurs (sans « Unknown » ni virgules). Descriptions
  de `terrier` inchangées (vérifiées sous Hyprland, choix par écran retrouvés) ; `test-outputs.sh sway` : 0 échec ; bureau rechargé
  sans erreur. Doc : `ARCHITECTURE.md` § 3.1, § 7.11 (le greeter ne prend plus le fond d'un autre écran depuis la phase 12).
- **À tester sur le laptop** : `git pull`, `./install.sh` en acceptant l'étape système (met à jour la copie du dépôt lue par
  l'écran de connexion, `/usr/local/share/qs-desktop`) ; dans la session Hyprland, changer de fond, attendre 3 s, se déconnecter :
  l'écran de connexion doit l'afficher. Idem sous Sway. Un éventuel choix **par écran** fait sur le laptop sous l'ancienne
  description est à refaire une fois (choix global conservé).

## Stylus — styles de `terrier` installés par `install.sh` (2026-11-10)

- Constat (laptop) : Stylus installé par l'étape système, mais aucun style.
- Sauvegarde des styles de `terrier` (copie de ses données, Chromium sans fenêtre, même export que Gérer → Exporter) :
  `dotfiles/chromium/stylus.json` (3 Mo) : **139 styles**, 137 Catppuccin (mis à jour ensuite par Stylus, `updateUrl`), dont
  YouTube, Wikipedia, Shinigami Eyes en Mocha/vert, Claude et ChatGPT en vert, et tes deux styles Focalboard (`localhost:7000`,
  l'un désactivé). Réglages de Stylus : tous par défaut, non importés. Rien de personnel (adresses, jetons) dans le fichier.
- Import : `scripts/nighttab-import.py` devient `scripts/extension-import.py nighttab|stylus` (même Chromium sans fenêtre) ;
  Stylus par son propre import (celui du glisser-déposer d'une sauvegarde sur Gérer), puis relecture style par style (nom,
  actif, options). `install.sh` : étape « nightTab et Stylus », une fois par version de chaque fichier, rappel en fin
  d'installation si Chromium est ouvert ou l'extension pas encore là.
- Tests (profils jetables, Stylus 2.4.17 de `terrier`) : profil neuf → 139 styles relus, CSS compilé identique à `terrier`
  (seule différence : l'ancienne section d'en-tête, commentaire seul, de 3 styles) ; relance → 0 changement ; styles modifiés
  (couleur, désactivé) → remis comme le dépôt ; extension absente → code 3 ; nightTab refait par le nouveau script : 11 favoris.
  `test-install.py` : 0 échec.
- **À tester sur le laptop** : `git pull`, **fermer Chromium**, `./install.sh` → « = Stylus : 139 styles relus » ; puis un site
  (GitHub, YouTube) en Catppuccin.

## Stylus — import bloqué par Bitwarden (2026-11-11)

- Constat (laptop) : « ! Stylus : pas de rapport d'import après 120 s », puis une trace Python (Chromium sans fenêtre ne se
  fermait pas). Reproduit sur `terrier` avec une copie du profil réel.
- Cause : sans fenêtre, l'agent utilisateur de Chromium est `HeadlessChrome/…` ; Bitwarden se croit alors sous Safari et lève
  une exception en boucle (`browser.runtime.sendNativeMessage is not a function`, 1,2 million de lignes en 25 s). Le processus
  principal de Chromium sature (130 % de CPU, mémoire jusqu'à 3 Go) et ne répond plus au protocole de débogage. Bitwarden
  isolé par désactivation tour à tour des extensions (copie du profil).
- Correctif (`scripts/extension-import.py`) : Chromium sans fenêtre lancé avec l'agent utilisateur de Chromium avec fenêtre
  (version tirée de `chromium --version`) ; fermeture sûre : Browser.close, puis SIGTERM, puis SIGKILL sur tout le groupe de
  processus, sans plus jamais lever d'exception.
- Tests (copies jetables) : profil réel de `terrier` → Stylus 139 styles relus en 7 s, nightTab 11 favoris, relance 1 s ;
  profil neuf (extensions téléchargées au démarrage) → Stylus 10 s, nightTab 9 s ; processus qui ignore SIGTERM → tué en 55 s,
  rien ne traîne.
- `test-install.py` lançait le vrai Chromium dans le dossier jetable (extensions déclarées dans `/usr/share/chromium/extensions`
  sur `terrier`) : profil complet écrit, 2 à 3 échecs. Désormais un `chromium` factice (import raté exprès, retenté à chaque
  passage, hors du test « sans changement ») ; l'import réel se teste sur une copie de profil. `test-install.py` : 0 échec.
- Laptop (2026-11-11) : `./install.sh` → « = Stylus : 139 styles relus (139 dans le profil) ». **Reste à vérifier à l'œil** :
  un site (GitHub, YouTube) en Catppuccin dans Chromium.

## Plymouth — mises à jour du noyau et démarrage UKI du laptop (2026-11-11)

- Question : une mise à jour du noyau défait-elle l'écran de démarrage ? Enquête (lecture seule, laptop) :
  - **Non, rien à ajouter pour le noyau.** Le hook pacman de mkinitcpio (`90-mkinitcpio-install.hook`) refait les images à
    chaque mise à jour de `linux`/`linux-lts`, `plymouth`, systemd, cryptsetup, firmwares, avec nos réglages (fichiers gardés
    par pacman ou à aucun paquet). Preuve : `pacman.log` 2026-11-10 13:42, les deux images refaites avec `[plymouth]`.
  - **Mais le laptop démarre en GRUB + UKI** (archinstall : `15_uki`, `10_linux` en 644, presets `default_uki=`, pas
    d'image `fallback`), la VM de l'étape 4 en GRUB classique. Conséquences avec l'ancienne version du script : `splash` et
    `grub-mkconfig` sans effet (le `splash` venait déjà de `/etc/kernel/cmdline`) ; procédure de secours de `ROLLBACK.md`
    inapplicable (pas de ligne `linux`) ; aucun démarrage sans Plymouth possible hors clé USB.
  - **Piège trouvé** : le paquet `grub` livre `10_linux` exécutable ; sa prochaine mise à jour le réactive, et un
    `grub-mkconfig` mettrait en tête du menu « Arch Linux, with Linux linux-lts » avec le seul microcode pour initrd :
    entrée par défaut incapable d'ouvrir LUKS. Reproduit en VM.
  - Noyau `linux` 7.2.15 : il a démarré normalement le 2026-11-10 (15 h 01 → 19 h 50) ; aucun démarrage raté n'est
    journalisé (échec avant l'ouverture du disque). Ton constat : écran noir, sans demande de phrase de passe. Cause non
    déterminée (affichage de l'initramfs : KMS Intel ou Plymouth, alors avec `spinner`).
- Correctifs (tes choix : image de secours par noyau, hook de garde) :
  - `scripts/plymouth-setup.sh` : mode **UKI** détecté (preset `default_uki=`) : GRUB non touché ; `splash` garanti par
    `/etc/cmdline.d/qs-corelab.conf` s'il manque ; **image de secours sans Plymouth** par noyau (preset `rescue`,
    `-S plymouth`, `<image>~rescue.efi`, titre « Arch Linux (<noyau> rescue, no splash) ») ; reprise : le `splash` ajouté
    dans GRUB le 2026-11-11 est défait sans `grub-mkconfig`. Mode GRUB classique inchangé. `status` affiche le mode.
  - `dotfiles/pacman/hooks/90-qs-grub-uki.hook`, posé par `system-setup.sh install` sur une machine GRUB + UKI : remet
    `10_linux` en non exécutable après chaque mise à jour de `grub`. Retiré par `--uninstall`.
  - Docs : `ROLLBACK.md` (deux modes, entrée de secours, mises à jour), `PLYMOUTH.md`, `ARCHITECTURE.md` § 9.1, `README.md`,
    `DEVELOPMENT.md` (« VM UKI »).
- Vérifié dans une VM chiffrée construite au format du laptop (fichiers du laptop, `~/.cache/qs-desktop-vm/uki/`) :
  - état du laptop reproduit (ancienne version appliquée) ; démarrage : logo Arch de systemd-stub, puis thème Core Lab et champ ;
  - nouvelle version : reprise, images de secours construites (33 Mo chacune ; ESP 20 % sur 1 Go), second passage sans
    changement ; contenu vérifié (`objcopy` + `lsinitcpio`) : Plymouth dans l'image normale, absent du secours ;
  - menu GRUB : « Arch Linux » (linux-lts), « Arch Linux (linux-lts rescue, no splash) », « Arch Linux » (linux),
    « … (linux rescue, no splash) » ; première entrée = LTS normal, thème affiché ; secours : phrase de passe en texte,
    démarrage complet (`running`, aucune unité en échec) ;
  - mise à jour simulée du noyau (`pacman -S linux`) : image normale et de secours refaites ;
  - mise à jour simulée de `grub` : sans le hook, `10_linux` réactivé et entrées défectueuses générées ; avec, `10_linux`
    reste en 644 et `grub-mkconfig` n'en génère aucune ;
  - retrait : presets, `/etc/kernel/cmdline` et `/etc/default/grub` identiques aux originaux (sommes de contrôle), images de
    secours et hook retirés, menu d'origine, thème `spinner` ; cas sans `splash` : fichier `cmdline.d` ajouté puis retiré.
  - `test-install.py` : 0 échec.
- **Appliqué au laptop** (2026-11-11 20 h 10, ton accord ; mot de passe sudo saisi dans une fenêtre zenity, faute de
  terminal) : `plymouth-setup.sh install` → presets `linux` et `linux-lts` avec le preset `rescue`, quatre images (ESP à
  25 %), `splash` retiré de `/etc/default/grub`, état `previous-theme=spinner` + deux `rescue=` ; `system-setup.sh install` →
  `/etc/pacman.d/hooks/90-qs-grub-uki.hook`. Codes 0 ; nouveau passage `--dry-run` : aucun changement. Pas encore redémarré.
- **À tester à la main sur le laptop**, ensuite :
  1. menu GRUB : quatre entrées dans l'ordre ci-dessus ; démarrage normal → thème Core Lab, phrase de passe, greeter ;
  2. entrée « linux-lts rescue » → phrase de passe en texte, puis greeter ;
  3. diagnostic du noyau `linux` : entrée « linux rescue » ; la phrase en texte apparaît → c'était Plymouth avec ce noyau ;
     écran noir → affichage du noyau 7.2.15 (pilote Intel), indépendant de nos réglages ; dans ce cas, taper la phrase à
     l'aveugle puis Entrée ; selon le résultat : rester sur le LTS, ou correctif ciblé proposé avant d'agir ;
  4. à la prochaine vraie mise à jour du noyau : `pacman.log` montre les presets `default` et `rescue` refaits.
- Logo Arch avant Plymouth : il venait de systemd-stub (section `.splash` des UKI, `--splash` mis par archinstall dans
  `default_options`). Retiré (ton choix) par `plymouth-setup.sh` en mode UKI : option enlevée des presets, BMP noté
  (`stub-splash=`), remis par `uninstall`. VM : plus de section `.splash` ; démarrage filmé (0,3 s) : menu GRUB, noir bref,
  thème, aucune image du logo ; second passage sans changement ; retrait → presets identiques aux originaux.
  Appliqué au laptop (2026-11-11, code 0, quatre images refaites ; nouveau passage : aucun changement).

## Windows 11 — entrée native et console sur l’espace 5 (2026-11-11)

- Entrée « Windows 11 » commune au menu et au launcher, catégorie Administration ; logo bleu SVG de Wikimedia embarqué
  avec sa provenance. Configuration `windows11` (`uri`, `domain`) dans le fichier machine ; installateur sans appel libvirt,
  simulation, second passage sans changement, sauvegarde et retrait par le registre existant. Dépendances documentées.
- Clic : démarrage de la VM éteinte, sinon connexion à la VM active, puis Virt Viewer en fenêtre ; verrou anti-double clic,
  erreurs notifiées, fermeture de la console sans arrêt de Windows. Aucun paquet installé.
- Laptop : `win11` sur `qemu:///system`. Règles machine Sway / Hyprland : espace 5, mosaïque, espace courant conservé.
  Identité GTK dédiée `qs-windows11` (`--name`, `--class`) : placement dès l’ouverture, sans attendre le titre du domaine
  et sans déplacer les autres VM.
- Retour du premier essai réel : accès direct au socket SPICE refusé ; corrigé avec `virt-viewer --attach`, qui utilise
  libvirt pour ouvrir l’affichage. Permissions et définition de la VM inchangées.
- Validations : `test-windows11.py` OK (états, erreurs, double clic, jetons, installation conditionnelle, simulation,
  sauvegarde, espaces dans les chemins et idempotence) ; `test-install.py` 0 échec, retrait inclus ; tests des espaces
  Sway et Hyprland : 0 échec chacun. Banc GTK avec l’identité finale : espace 5, non flottant, focus courant conservé,
  autre VM inchangée sous les deux compositeurs. Sonde Quickshell isolée : entrée présente dans les listes du menu et
  de recherche du launcher, image SVG chargée. Syntaxe Bash et `git diff --check` OK.
- Déployé sur le laptop : entrée installée seule, règles Hyprland rechargées sans erreur. VM réellement démarrée,
  console `qs-windows11`, espace 5, `floating=false`, espace 1 conservé. Capture `.shots/windows11-workspace5.png`.
  Windows laissé actif sur 5 ; bureau réel PID 1910 vivant, bancs arrêtés.
- À vérifier à la main : confort d’utilisation de Windows et lancement dans une vraie session Sway (placement déjà validé
  sur banc, aucun changement de session imposé).

## Windows 11 — proportions de l’icône et espacement (2026-11-11)

- Tes captures : texte trop proche du logo dans le launcher et logo disproportionné dans le menu.
- Launcher : écart icône → texte porté de 4 à 10 px, repris du thème des panneaux et du menu ; appliqué à toutes les
  lignes. Seule `itemTextMargin` change ; espacement de l’en-tête conservé.
- SVG Windows : marge transparente intégrée au viewBox ; dessin centré sur les deux tiers du cadre (32 px dans un
  emplacement de 48 px, 16 px dans celui de 24 px), comparable aux marges des icônes Papirus. Provenance complétée.
- Copie du bureau, démarrage complet sur Sway isolé, contrôle visuel des deux composants :
  `.shots/launcher-icon-spacing.png`, `.shots/menu-windows11-padding.png`. Aucun avertissement QML ; restent les
  avertissements externes du banc (portails privés, rendu logiciel et icône de tray NordVPN absente). Aucune action VPN.
- Seuls le thème et le SVG validés appliqués au bureau réel ; textes de recherche et défilement forcés du banc non repris.

## Launcher — icônes plus grandes (2026-11-11)

- Ton retour : les icônes du launcher paraissent trop petites face au texte. Emplacements agrandis de 24 à 32 px
  (`Theme.launcher.itemIconSize`, taille déjà utilisée par la charte), écart horizontal de 10 px conservé. Menu inchangé.
- Démarrage complet sur copie et Sway isolé, liste de plusieurs applications contrôlée visuellement :
  `.shots/launcher-icon-spacing.png`. Aucun nouvel avertissement QML ; mêmes avertissements externes de banc.
- Thème appliqué seul au bureau réel ; banc arrêté.

## Pastille musique — texte qui débordait (2026-11-11)

- Ta capture : « Deftones - Around the Fur » en entier sous le haut-parleur, l'icône Spotify sur la pilule des espaces ;
  le repli « icônes seules » ne se déclenchait pas.
- Cause (reproduite sur banc) : `artistWidth` et `titleWidth` appelaient `metrics.advanceWidth()` dans une liaison. À la
  création, avant que la police de la barre soit appliquée au `FontMetrics`, elles mesuraient dans la police par défaut
  (« Deftones » 67 px au lieu de ~110). Un appel de fonction ne dépendant pas de la police, elles n'étaient plus réévaluées
  avant le morceau suivant. D'où un budget faux dès que le lecteur est présent au démarrage ou au rechargement. Le banc
  changeait toujours de morceau par IPC : il ne le voyait pas.
- Corrigé (`Mpris.qml`) : une seule mesure, `advance()`, qui lit `metrics.font` (réévaluée quand la police arrive).
  **Contrôle sur le rendu**, comme demandé : le libellé complet est rendu hors écran (`candidate`) ; s'il sortirait de la
  pilule, le texte est retiré (icônes seules). Ton choix : en icônes seules, l'**icône de pause** reste affichée en pause
  (largeur minimale = icône du lecteur + pause).
- Ton choix ensuite : **priorité à l'artiste**. Texte entier s'il tient ; sinon le titre est retiré et l'artiste reste seul
  (le titre seul s'il n'y a pas d'artiste), abrégé s'il le faut ; plus de partage artiste / titre ni de « … - … ». Remplace
  la règle du 2026-11-10 (« artiste réduit à « … » retiré, le titre prend la place »). Trois mesures en moins dans `Mpris.qml`.
  Banc : « Deftones » à 1920 et 1500 px, « D… » à 1280 px en lecture, icônes seules en pause ; `test-bar.py` vérifie la
  règle dans tous les cas (l'ancienne version échoue : « Ru… - oo… »). Bureau réel rechargé sans erreur, capture
  `.shots/media-pill-artist.png` (« Slipknot - Prosthetics » entier, il tenait).
- Mal compris, corrigé : retirer tout le titre décollait la pilule de sa voisine. Ta règle : **artiste entier, titre abrégé
  dans la place restante** (« Deftones - Arou… ») ; titre retiré seulement si même une lettre ne tient pas, puis artiste
  abrégé. La pilule remplit de nouveau la place et se cale à 10 px. Banc : 1920, 1500 et 1280 px (« D… » en lecture,
  icônes seules en pause) ; `test-bar.py` vérifie la règle (la version « artiste seul » échoue). Bureau réel rechargé sans
  erreur : « La Rumeur - Le coffre-fort… », calé à 10 px (`.shots/media-pill-title.png`).
- Ton choix : artiste seul abrégé à moins de **3 lettres** (`Theme.bar.mediaMinLetters`, « D… ») → icônes seules. Le titre
  abrégé après l'artiste entier garde sa règle (une lettre suffit : la pilule reste calée). Banc à 1280 px : icônes seules
  en lecture, pilule à ~70 px de sa voisine (au-delà de `mediaSnapGap`, pas de calage) ; `test-bar.py` vérifie le
  minimum (balayage serré de 1250 à 1350 px ; l'ancienne version échoue sur « D… »). Bureau réel : « Orbital - Dwr Budr »
  entier. **Au rechargement**, Quickshell a planté une fois (segfault Qt dans `QQuickImageBase::loadPixmap` sur une mise à
  jour D-Bus, 6 s après) et s'est relancé seul ; rapport `~/.cache/quickshell/crashes/2h1s0mcot/`. À surveiller.
- Tests : `test-bar.py` contrôle dans tous les cas que le libellé rendu tient dans le module. S'y ajoutent le cas
  « lecteur présent au démarrage, place changée sans changer de morceau », « Deftones - Around the Fur » et 2 segments
  sans texte en pause. Contre-épreuve : l'ancien `Mpris.qml` échoue dès le démarrage (libellé de 435 px dans 388).
  Seuil « texte proche du plafond » à 3440 px ramené de 590 à 550 px : il échouait déjà sur le laptop avant ce
  correctif (581 px, chaque moitié abrégée peut perdre un « W » d'environ 26 px). Passe sur copie, sans avertissement QML.
- Captures du banc (avant / après, 1920, 1500 et 1280 px, lecture et pause) vérifiées. Bureau réel rechargé sans erreur
  (PID 1910).
- Même schéma vu ailleurs, non corrigé (hors sujet) : `VolumeLine.qml:50` (largeur du bouton « Unmute », texte constant
  mesuré par `FontMetrics.advanceWidth()` dans une liaison) ; `InfoModule.qml:83` (`tightBoundingRect`, avec un repli sur
  `implicitWidth`, sans effet visible connu).
- À tester à la main : pastille au démarrage avec Spotify déjà lancé, en lecture et en pause, sur le laptop.

## Espace 5 — glyphe Windows 11 (2026-11-11)

- Profil travail : double cercle remplacé par le logo Windows 11 à quatre carrés (`nf-dev-windows11`, U+E8E5), présent
  dans la police embarquée Symbols Nerd Font Mono. Taille 34 px, couleurs, survol et halo conservés ; profil jeux inchangé.
- Copie isolée : démarrage complet, rendu contrôlé à vide et actif (captures `.shots/workspace5-windows11-empty.png`
  et `workspace5-windows11-active.png`). Aucun avertissement QML ; avertissements externes du banc (portails, rendu logiciel,
  PipeWire inaccessible sur le runtime isolé et icône NordVPN absente). Aucune action VPN.
- Tests des espaces Sway et Hyprland : **0 échec** chacun. Thème appliqué seul au bureau réel, rechargement sans erreur,
  même instance vivante (PID 1909), espace 1 conservé et bancs arrêtés. Capture `.shots/workspace5-windows11.png`.

## Profil travail — ordre des espaces (2026-11-11)

- Espaces 1–4 conservés ; nouvel ordre : **5 Microscopie (DigitalMicrograph), 6 Windows, 7 Thunderbird, 8 Discord-WhatsApp,
  9 Spotify**. Glyphes et règles Sway / Hyprland alignés. Thunderbird et Windows prennent désormais leur espace dans le
  profil, comme Discord et Spotify ; anciens placements du profil jeux conservés (mail 8, Windows 5).
- Copie isolée : barre contrôlée visuellement, démarrage complet sans avertissement QML (mêmes avertissements externes
  portails / rendu logiciel / PipeWire isolé / icône NordVPN). Capture `.shots/workspaces-work-order-bench.png`.
  Tests des espaces Sway et Hyprland : **0 échec** chacun. Aucun appel VPN ni lancement d’application réelle sur les bancs.
- Placement testé avec fenêtres GTK factices sur Sway pour les deux profils (Discord X11, webapps Discord/WhatsApp,
  Spotify X11, Thunderbird, Windows, DigitalMicrograph) ; focus conservé. Chargement profil + règles communes + règles machine
  Hyprland vérifié pour les deux profils, syntaxe Lua et `Hyprland --verify-config` OK.
- Bureau réel : Hyprland rechargé sans erreur ; fenêtres ouvertes de Thunderbird, Discord, WhatsApp et Spotify déplacées
  sur 7 / 8 / 8 / 9. Sondes GTK DigitalMicrograph et Windows sur 5 / 6, en mosaïque, puis fermées. Espace courant 1 conservé,
  Quickshell PID 1909 vivant, bancs arrêtés. Capture `.shots/workspaces-work-order.png`. Aucun changement de session imposé.

## Laptop — fermeture du capot (2026-11-11 → 2026-11-12)

- Cahier des charges (ton choix) : capot fermé sans écran externe → veille, sur secteur comme batterie ; avec un externe (USB-C,
  dock, HDMI) → dalle éteinte, session sur les externes ; retrait du dernier externe capot fermé → veille.
- **Version native** (ta décision, après une première version de Codex : pont Python UPower/logind, `Lid.qml`, lecture des
  sorties, règles de restauration, ~600 lignes avec tests, 32 Mo de Python en permanence, et 4 défauts réels trouvés en revue,
  dont des règles perdues à chaque rechargement à chaud) :
  - veille : logind par défaut (`/etc/systemd/logind.conf` inchangé) ; verrouillage avant veille : `Idle.qml`, inchangé ;
  - dalle : `bindswitch --reload` Sway et `hl.bind("switch:on|off:Lid Switch")` Hyprland dans les fichiers machine du laptop,
    comme prévu dès le départ par `ARCHITECTURE.md` § 3.1 ; Hyprland relit aussi l'état du capot au chargement (`/proc`, pour le
    `hyprctl reload` du réveil) ;
  - pas de quirk libinput : un capot est réputé fiable par défaut depuis libinput 1.21 (doc officielle : « Very few devices
    need this, if in doubt do not set ») ; l'état initial du capot arrive donc au compositeur. Un quirk ajouté le 2026-11-12 sur
    une hypothèse périmée (la mienne et celle d'une revue) a été retiré le même jour. Journal du 2026-11-09 (logind seul) :
    fermetures et ouvertures cohérentes, aucun événement fantôme ;
  - seul code : un `systemd-inhibit --what=handle-lid-switch` dans `Idle.qml` (8 lignes), laptop seulement, tant qu'un écran
    `DP`/`HDMI`/`DVI`/`VGA` est actif. Raison mesurée ici : écran en veille DPMS → connecteur `disabled` dans sysfs, donc
    logind ne verrait plus l'externe.
- Validé : `Hyprland --verify-config`, `sway --validate` (commandes liées avec la description entre guillemets), liaisons
  chargées par ta session Hyprland (`hyprctl binds`), vérification jetable de l'inhibiteur (externe, virtuels exclus, veille
  DPMS, dalle éteinte, retrait, reprise après arrêt, rien sans batterie), `test-sleep.py` OK, `test-outputs.sh sway` 0 échec,
  `test-install.py` 0 échec (contrôle du quirk ajouté), banc Sway sans avertissement. `test-idle-lock.py` échoue sur un
  avertissement de portail, **déjà avant** ce travail (environnement). `libinput-tools` installé le temps de cette vérification
  puis désinstallé avec ses dépendances (ton choix : aucun paquet inutile ; hors `deps/`).
- Revues de la version native (3 passes) : virtuels comptés comme externes, liste blanche des connecteurs, `Battery.available`,
  état initial du capot (quirk) : corrigés. Acceptés : écran qui coupe sa connexion en veille profonde ou KVM basculé =
  débranchement (comme la version Codex) ; relance de Quickshell écrans éteints capot fermé → veille ; dalle éteinte même sans
  externe (plan § 3.1, `Outputs.qml` gère « aucun écran ») ; rechargement Sway capot fermé branché : la dalle clignote.
- Vu dans le journal du 2026-11-09 : capot fermé 19 min, le laptop s'est **réveillé seul 6 fois** (s2idle), environ 27 s à
  chaque fois avant que logind ne le rendorme (sa revérification du capot fermé marche). Cause non cherchée : `BACKLOG.md`.
- Règles : `CLAUDE.md` règle 6 « Natif d'abord, code minimal » (proposer avant de s'écarter d'une solution documentée ou
  d'ajouter un processus, un script ou un protocole maison) ; la revue en boucle juge aussi l'altitude (`DEVELOPMENT.md`).
- Test du 2026-11-12, 07:40 (Hyprland, sans externe) : veille déclenchée par logind à la fermeture ; réveil spontané 11 s plus
  tard capot fermé, rendormi par logind ~27 s après (`BACKLOG.md`) ; réveil normal à l'ouverture. Liaisons de capot chargées,
  plus de pont. Avertissements Quickshell du passage à zéro écran (`FALLBACK`, layershell) sans effet visible.
- Test du 2026-11-12, 07:44 (Hyprland, Dell AW3418DW en HDMI) : capot fermé 54 s, **pas de veille**, verrou « External display
  active » tenu ; dalle rallumée à l'ouverture. Cas écrans éteints par la veille vérifié sur la session (extinction de 2 s) :
  connecteur HDMI `disabled` dans sysfs (logind seul croirait l'externe débranché), verrou toujours tenu.
- **Fait** sous Hyprland : fermer sans externe (veille, verrouillage confirmé en 1 s) ; fermer avec HDMI (pas de veille, verrou
  tenu même écrans éteints) ; rouvrir (dalle rallumée, échelle 1) ; débrancher le HDMI capot fermé (veille dans la seconde,
  07:50:59, tenue 78 s sans réveil spontané).
- **À faire** (à la main) :
  1. sous Hyprland, avec le HDMI : ouvrir la session capot fermé puis ouvrir le capot (dalle rallumée) ; réveil capot fermé
     avec l'écran branché (dalle reste éteinte) ; les essais sur batterie ;
  2. sous Sway : les mêmes cas ;
  3. USB-C et dock : pas de matériel pour l'instant (à refaire après achat) ;
  4. l'écran de connexion reprend les liaisons Sway à la prochaine mise à jour de sa copie système (`install.sh`, étape système).

## Windows 11 — timer CPU et partage Samba de Codex retirés (2026-11-12)

- Origine : projet séparé `~/Win11` (Codex, 10-11 novembre, non versionné), hors de ce dépôt. Ce dépôt ne fait pour les VM
  que `libvirtd` activé et le réseau `default` démarré au boot (`scripts/system-setup.sh`).
- **Timer `win11-cpu` retiré** (ton accord) : `win11-cpu.{service,timer}`, hook `/etc/libvirt/hooks/qemu.d/90-win11-cpu`,
  `/usr/local/libexec/win11-cpu`, `/run/win11-cpu`. Il servait au profil `target` (vCPU sur 0-7, hôte limité à 8-13), écarté
  par les mesures de Codex (plus lent) au profit de `comparison` sans restriction : il tournait toutes les 15 s pour rien
  (1828 passages le 12 avant 8 h 30). Aucune restriction CPU active au retrait ; VM `win11`, réseau `default` et libvirtd intacts.
  `~/Win11/scripts/win11ctl prepare` le réinstallerait.
- **Samba : un seul mécanisme, celui du dépôt** (ton choix) : partage `[Win11Exchange]` de Codex retiré
  (`/etc/samba/win11.conf`, comptes Samba et Linux `win11share`, `/srv/samba/win11-exchange` qui ne contenait que ses
  scripts et un fichier de test). Il était déjà inactif : `install.sh` relancé le 11 à 18:35 avait remis `smb.conf` du dépôt,
  sans sa ligne `include`. Restent `[homes]` et les partages Nemo (clic droit → Partager) ; partage de test créé puis retiré
  sans root : OK. Règle `ufw` de Codex (TCP 445 depuis 192.168.122.2) et réservation DHCP `win11` → 192.168.122.2 gardées.
- Compte Samba `chikhs` créé par toi. VM démarrée par `virsh`, commandes Windows par l'agent invité (SYSTEM) : ancien
  lecteur `L:` → `Win11Exchange` / `win11share` retiré dans ta session (tâche planifiée unique, supprimée), aucun identifiant
  enregistré pour 192.168.122.1. Port 445 joignable dans les deux sens ; pare-feu Windows : SMB entrant depuis 192.168.122.1
  seulement. Partage Windows `Win11Exchange` (`C:\Win11Exchange`, `chikhs` en modification) gardé pour Windows → laptop.
- Windows → laptop : **fait par toi** (`\\192.168.122.1\`, compte Samba `chikhs`).
- Laptop → Windows : **abandonné, un seul sens suffit** (ton choix). Ton compte Windows est sans mot de passe ; Nemo ne peut
  pas s'y connecter même avec `LimitBlankPasswordUse=0` : gvfs force le cache d'identifiants de `libsmbclient`
  (`GENSEC_FEATURE_NTLM_CCACHE`), où un mot de passe vide veut dire « identifiants en cache » → « Invalid argument »
  (reproduit avec `smbclient --use-krb5-ccache`, qui passe sans cette option). `LimitBlankPasswordUse` remis à `1`, partage
  Windows `Win11Exchange` retiré, `C:\Win11Exchange` supprimé (seul le fichier de test de Codex). Échanges dans les deux
  sens par les partages du laptop. Règles du pare-feu Windows pour SMB entrant (Codex) laissées pour l'audit.
- Prochaine étape demandée : **audit de la configuration de la VM** faite par Codex (domaine, réseau, `ufw`, réglages Windows).

## Windows 11 — console de virt-manager au lieu de Virt Viewer (2026-11-12)

- Demande : la barre de Virt Viewer en plein écran gênait en haut de Windows ; la console de virt-manager suffit.
- `scripts/windows11-launch.sh` : VM démarrée si éteinte, puis `virt-manager --connect URI --show-domain-console DOMAINE`.
  Instance unique : un nouveau clic réaffiche la même console. Verrou rendu avant la console (sinon un virt-manager resté
  ouvert bloquerait les clics suivants) ; il évite toujours un double démarrage.
- Règles machine : virt-manager n'a pas d'identité par fenêtre (`app_id` / classe `virt-manager` pour toutes) → console
  reconnue par son titre `win11 on QEMU/KVM`, présent dès l'ouverture (`initialTitle`) ; le préfixe « Press … to release
  pointer. » d'une capture arrive après. Sous Sway, le `move position center` de la règle flottante commune ramenait la
  fenêtre sur l'espace visible : `for_window` la renvoie sur `$ws_windows` après coup.
- Bancs (fausse fenêtre GTK `virt-manager`) : Sway headless et Hyprland imbriqué → console sur l'espace Windows, en
  mosaïque, même après changement de titre ; gestionnaire et console d'une autre VM flottants sur l'espace courant ; focus
  conservé. `sway --validate`, `Hyprland --verify-config` (contre-épreuve : erreur volontaire détectée dans le fichier machine
  de la copie). `test-windows11.py` réécrit (contre-épreuve : échoue sur l'ancien lanceur), `test-install.py` 0 échec.
- Réel (Hyprland, profil travail) : config rechargée sans erreur ; lanceur → VM démarrée, console sur l'espace **6** (espace
  Windows du profil travail, confirmé par toi), `floating=false`, espace 2 conservé. VM ensuite éteinte (arrêt normal par
  l'agent invité, l'ACPI ignoré juste après le démarrage), comme avant l'essai.
- Incident de test : une première contre-épreuve sans faux `virt-viewer` a lancé le vrai pendant ~1 min (VM éteinte : il
  attendait), arrêté. Refaite avec un faux en tête du `PATH`.
- `virt-viewer` retiré de `deps/apps.txt` (plus utilisé) et désinstallé du laptop à ta demande (`pacman -Rns` : avec
  `libgovirt` et `librest`, ses seules dépendances propres ; virt-manager n'en dépend pas).
- À vérifier à la main : plein écran de virt-manager (barre du haut) ; même lancement sous Sway.

## Projet `~/Win11` (Codex) mis à jour (2026-11-12)

- Ton choix : doc et code tout de suite. Sauvegarde des sources d'avant dans le scratchpad de la session ; publié sur le
  dépôt privé `Crystal4276/win11-kvm-arch` par son `publish-github.sh` (`1e82a46`). Ce commit publie aussi le travail de
  Codex du 11 au soir jamais poussé (`compare-power.py`, `console-trial.py`, leurs tests et docs).
- Retiré : profil `target` et bail CPU (`cpu-lease.py`, hook, timer, `set-profile`, `restore-host`, banc `compare-cpu.py` /
  `summarize-cpu.py`, contrôle de topologie), partage `Win11Exchange` (hôte : `setup_samba`, `set-samba-password.py` ;
  Windows : partage, compte et règles SMB de `Setup-Win11.ps1`, `Connect-LinuxShare.ps1`), `Remove-RdpPreparation.ps1`
  (exécuté, aurait échoué sans le partage), sous-commande `viewer` de `console-trial.py` (virt-viewer). `prepare` n'exige
  plus `gvfs-smb`, `wimlib`, `smbclient`, `turbostat`, `virt-viewer` ; ses règles UFW (dont TCP 445 VM → partages de
  qs-desktop) gardées, sautées sans UFW actif.
- `rollback` ne restaure plus que `/etc/win11/config.json` : il aurait remis la `smb.conf` d'avant Codex par-dessus celle de
  qs-desktop (test ajouté, qui échoue sur l'ancien code). README, AGENTS.md (à ne pas réintroduire), docs mis à jour.
- Tests du projet : 29 OK ; XML de `render` valide (`virt-xml-validate`). Pas de PowerShell sur l'hôte : scripts Windows
  modifiés par retrait de blocs seulement, encodage d'origine gardé ; non exécutés.
- Incident de test : la contre-épreuve sur l'ancien code a lancé un vrai `systemctl disable --now win11-cpu.timer` (unité
  absente) → demande polkit sur ton écran vers 09:29, sans effet. Contre-épreuves de code système : commandes simulées.
- Pour l'audit : `Restore-Win11.ps1` à passer dans la VM (règles SMB Win11-* et config serveur SMB de l'ancien Setup) ;
  paquets installés pour Codex et plus utilisés (`gvfs-smb`, `wimlib`, `turbostat` ; `7zip`, `virt-firmware` seulement pour
  `prepare`) ; `swtpm` (TPM de Windows 11) absent de `deps/` ; état root `/var/lib/win11-setup` (sauvegardes, `files.json`).

## Audit de la VM Windows 11 (2026-11-12)

Lecture seule (hôte, root par pkexec, Windows par QGA ; VM démarrée puis éteinte). Rien n'est changé ; décisions en attente.

- **SSD du laptop (cause probable des plantages)** : 7 `nvme … timeout, completion polled` (E/S bloquée 30 s) du 9 au 11,
  dont 2 avant la création de la VM. KIOXIA EG6 derrière Intel VMD (`10000:e1:00.0`) : interruptions perdues, cas connu
  (bugzilla 217871, 219220 ; erratum MTL016). Les écrans bleus Windows du 11 (`0x1E`, E/S `0xc0000185`) collent avec ce
  défaut, sans preuve. Correctif usuel : BIOS, « SATA/NVMe Operation » RAID On → AHCI/NVMe. Vérifié : les 4 UKI contiennent
  `nvme`, fstab par UUID, pas de Windows natif sur le disque. Action à faire par toi dans le BIOS.
- **Sain** : `qemu-img check` sans erreur ; aucun hook libvirt, règle polkit ou sudoers de Codex ; `qemu.conf` d'origine ;
  UFW = les 4 règles `win11-managed`. Windows : activé, Secure Boot et TPM, Defender actif sans exclusion, Windows Update de
  nouveau fonctionnel, TRIM, heure juste, RDP fermé, profil réseau Public, aucun plantage depuis le 11 à 14 h 34. Split
  locks : 0 en 60 s au repos (sonde kprobe temporaire).
- **Reliquats Codex dans Windows** : règles `Win11-Host-SMB`, `Win11-SMB-BlockOthers`, `Win11-NetBIOS-BlockOthers` (445
  ouvert au laptop alors que Windows ne partage plus rien) ; tâche `Win11Setup-VioGpuResizeAtLogon` et service `VioGpuSrv`
  (carte virtio, inutiles avec QXL) ; `SoftwareDistribution.win11-backup-*` (1,9 Gio) ; `C:\ProgramData\Win11Setup` (6,5 Mo).
- **Chiffrement Windows** : BitLocker automatique « Protection Off », sans protecteur (clé en clair). À décider :
  déchiffrer et bloquer l'activation automatique (le laptop est déjà en LUKS ; une activation lierait la clé au TPM émulé).
- **QXL (ton choix du 11, réglages par défaut)** : 64 Mio ram/vram, `vgamem` 16 Mio (assez pour 1920 × 1200, pas pour
  un écran 4K). Pistes à essayer : compression d'images et flux vidéo SPICE désactivés (connexion locale), `vgamem` 64 Mio.
  Le projet Win11 génère encore `virtio` : `prepare` annulerait QXL.
- **Ménage hôte** : copie de disque du 11 avant maintenance (44 Gio, état de crash) ; ISO Windows en double (9 Gio dans
  `~/Win11` et `/var/lib/libvirt/boot`), encore branchée en CD ; sauvegardes obsolètes de `/var/lib/win11-setup` ;
  règle UFW 67/udp IPv6 sans objet ; paquets `gvfs-smb`, `wimlib`, `turbostat` ; `swtpm` à ajouter à `deps/apps.txt`.
