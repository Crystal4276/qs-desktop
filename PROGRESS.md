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
  - En attente de ta réponse : correction d'`install.sh` sans `python3` (Arch minimal) ; ensuite étape 3 (thème complet :
    phrase de passe, sortie, plusieurs écrans).
