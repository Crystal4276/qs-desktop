# qs-desktop

Bureau Quickshell (barre, notifications, lanceur, menus, verrouillage, écran de connexion) pour Sway et Hyprland, avec les
configurations des compositeurs et des applications de tous les jours. Thème Catppuccin Mocha, accent green.

## Installer sur une nouvelle machine

Prérequis : Arch Linux installé (archinstall convient : noyau, pilote graphique, NetworkManager, zram), un compte utilisateur
membre de `wheel` (sudo), une connexion Internet.

```sh
sudo pacman -S --needed git
git clone https://github.com/Crystal4276/qs-desktop.git ~/qs-desktop
cd ~/qs-desktop
./install.sh --dry-run     # voir tout ce qui sera fait, sans rien modifier
./install.sh               # installer : deux questions au plus (profil de la machine, étapes système)
```

Puis se déconnecter : l'écran de connexion greetd apparaît au prochain démarrage ; choisir Sway ou Hyprland.

`install.sh` est idempotent : le relancer ne refait que ce qui manque ou a changé (après un `git pull`, par exemple).

| Étape | Ce qui est fait |
|---|---|
| Avant les paquets | profil de la machine (question 1) ; étapes système acceptées (question 2) : Reflector installe d'abord ce seul paquet avec les miroirs existants s'il manque, classe jusqu'à 20 miroirs HTTPS mondiaux synchronisés depuis moins de 12 h par débit, puis active le renouvellement hebdomadaire (`reflector.timer`) |
| 1. Paquets | installe `deps/arch-pacman.txt` (le bureau) et `deps/apps.txt` (applications de base), les paquets du profil (`deps/games.txt` avec le dépôt `[multilib]`, ou `deps/work.txt`), ceux de la carte graphique (`deps/gpu.txt`), `brightnessctl` sur un laptop ; construit `paru-bin`, seul paquet AUR ; installe Claude Code |
| 2. Configs du compte | liens vers le dépôt : `~/.config/quickshell/desktop`, `sway`, `hypr`, `fastfetch`, `mpv`, `starship.toml`, `chromium-flags.conf`, règle WirePlumber ; bloc ajouté à `~/.bashrc` (le reste n'est pas touché) ; identité Git si elle manque, prise du compte GitHub de `gh` (sinon rappel : `gh auth login`, puis relancer) |
| 3. Thème | archives officielles Catppuccin (`deps/themes.txt`, empreintes vérifiées) : GTK 3/4, curseur, Kvantum (Qt), dossiers Papirus lavande, Geany ; mêmes polices et curseur partout |
| 4. Réglages | GSettings (`dotfiles/dconf/`), applications par défaut (`dotfiles/mime/defaults.list`), web apps, liens HTTP vers Chromium ; profils Chromium (navigateur et web apps) en thème GTK, barre de titre du système (sans boutons réduire / agrandir / fermer) |
| Fonds, DigitalMicrograph | clone les fonds d'écran ; profil travail : clone `Crystal4276/GMSFreeAnalysis17` (privé : `gh auth login` ou clé SSH) dans `~/GMSFreeAnalysis17` |
| 5. Config machine | crée `hosts/<machine>.json` s'il manque, avec le profil (à committer) |
| 6. Système (sudo / authentification polkit) | compteurs GPU Intel (CAP_PERFMON ciblé et hook de mise à jour), écran de connexion greetd, profil travail : écran de démarrage Plymouth Core Lab (initramfs, `splash`, image de secours sans Plymouth pour une UKI : `docs/PLYMOUTH.md`, retour : `docs/ROLLBACK.md`), garde de GRUB pour les UKI (`10_linux` désactivé après chaque mise à jour de `grub`), sonde des portails captifs, Samba, services (réseau, Bluetooth, énergie, VM), groupes, thème Qt du système, extensions de Chromium (`dotfiles/chromium/extensions.txt`, installées depuis le Chrome Web Store au démarrage du navigateur ; pas dans les web apps) |

Tout fichier existant est sauvegardé avant d'être remplacé (`<fichier>.bak-<date>` à côté de l'original ; fichiers système dans
`/var/lib/qs-desktop/`).

Les étapes système (sudo) sont acceptées ou refusées d'un bloc, après la liste affichée ; « non » vaut `--no-system`. Parmi elles,
l'accès **pacman sans mot de passe pour tous les membres de `wheel`**.
Paru se lance normalement, en utilisateur : ses appels sudo à pacman bénéficient de la même règle.
Le fichier `/etc/sudoers.d/90-qs-desktop-pacman` est validé par `visudo`, appartient à root et a le mode `0440`.
Les autres commandes sudo gardent leur authentification habituelle. Activation seule :
`./scripts/system-setup.sh pacman-sudo` (authentification administrateur initiale nécessaire).
`--no-system` ignore ce réglage ; `--no-packages` le permet ; le retrait système restaure l'état précédent.

Options : `--profil jeux|travail`, `--no-packages`, `--no-system`, `--yes` (aucune question : étapes système faites, profil de
`hosts/<machine>.json`, sinon travail), `--uninstall`
(retire liens et copies, remet les sauvegardes et les réglages d'origine, étapes système comprises ; les paquets restent).

Reflector est réservé à Arch Linux. `--no-system` ignore cette étape ; `--no-packages` peut configurer un Reflector déjà présent.
Un échec conserve les miroirs précédents et laisse continuer l'installation ; le récapitulatif invite à relancer le script.
Les relances ne retestent pas les miroirs après une initialisation réussie, sauf changement de configuration ou liste absente.
Le timer renouvelle uniquement les miroirs, sans installer de mises à jour. Pour vérifier : `systemctl list-timers reflector.timer`
et `journalctl -u reflector.service`. Le retrait système restaure la configuration, la liste initiale et l'état antérieur du timer.

Autre distribution qu'Arch : pas encore prévue (paquets à installer soi-même d'après les listes Arch de `deps/`, puis
`./install.sh --no-packages`).

## À faire soi-même ensuite

- Mot de passe Samba (VM et accès par ZeroTier) : `sudo smbpasswd -a $USER`, dans un terminal, une fois par machine. Partager un dossier :
  clic droit dans Nemo → Partager.
- Web apps (WhatsApp, Discord, Word, Excel, PowerPoint, Notion) : se connecter une fois dans chacune.
- Thème d'Obsidian (rangé dans son profil) : choisir Catppuccin Mocha dans ses réglages. Chromium suit le thème GTK (réglé
  par `install.sh` dans chaque profil) ; Thunderbird reçoit Catppuccin Mocha Green par l'étape système (politique
  `/etc/thunderbird/policies`, tout profil, même neuf ; désactivable dans ses modules, réinstallé au démarrage tant que la
  politique est là).
- nightTab (page Nouvel onglet de Chromium) : ses réglages (favoris, couleurs, icônes, horloge) sont importés par `install.sh`
  depuis `dotfiles/chromium/nighttab.json` (Chromium fermé et extension installée, sinon rappelé à la fin : relancer
  `install.sh`). Réimportés seulement quand ce fichier change. Après un changement sur une machine : nouvel onglet → roue
  dentée → Data → Export data, puis remplacer le fichier du dépôt.
- Stylus (styles des sites, Catppuccin surtout) : ses styles sont importés de la même façon depuis `dotfiles/chromium/stylus.json`
  (sauvegarde de Stylus ; styles déjà là remplacés, autres gardés ; mis à jour ensuite par Stylus lui-même). Après un
  changement : icône de Stylus → Gérer → Exporter, puis remplacer le fichier du dépôt.
- Dossiers du compte : Applications, Desktop, Documents, Downloads, Music, Pictures, Videos ; Modèles, Public et Projets
  désactivés (`~/.config/user-dirs.dirs`), retirés s'ils sont vides.
- Fonds d'écran : `install.sh` propose de cloner le dépôt `Crystal4276/wallpapers` dans `~/Pictures/Wallpapers` (HTTPS, sans
  compte GitHub, dernière version seulement, progression affichée) et le met à jour aux passages suivants. Fond par défaut : `simple/wallhaven-j37lop.png` (celui de l'écran
  central de terrier, `hosts/default.json`) ; autre choix : utilitaire de fonds d'écran du bureau.
- Claude Code : installé par `install.sh` avec le script officiel (`https://claude.ai/install.sh`, dans `~/.local/bin`,
  ajouté au PATH des terminaux ; mises à jour faites par Claude Code), sauf s'il est déjà là. Codex vient des dépôts
  (`openai-codex`). Barres d'état des deux (modèle, contexte, limites 5 h et semaine) réglées comme sur `terrier` :
  `dotfiles/claude/statusline-command.sh` (lié dans `~/.claude`, déclaré dans `settings.json`) et `[tui] status_line` de
  `~/.codex/config.toml` ; le reste de ces fichiers est gardé. Connexion : `claude`, `codex`.
- Logiciels absents des dépôts officiels, avec `paru` (installé par `install.sh`) :

| Logiciel | Commande | Remarque |
|---|---|---|
| NordVPN | `paru -S nordvpn-bin`, puis `sudo systemctl enable --now nordvpnd`, `sudo usermod -aG nordvpn $USER`, `nordvpn login` | module de la barre masqué sans lui |
| Plex Media Server | `paru -S plex-media-server`, puis `sudo systemctl enable --now plexmediaserver` | |
| RustDesk | `paru -S rustdesk-bin` | |

## Réglages propres à une machine

Ce qui ne se détecte pas va dans des fichiers par machine (nom : `cat /etc/hostname`), absents = valeurs par défaut :
`hosts/<machine>.json` (barre, écran principal, écran de connexion : `docs/ARCHITECTURE.md` § 4),
`dotfiles/sway/hosts/<machine>.conf`, `dotfiles/hypr/hosts/<machine>.lua` (écrans, matériel),
`dotfiles/mpv/hosts/<machine>.conf`, `dotfiles/chromium/hosts/<machine>.conf` (décodage vidéo),
`dotfiles/dconf/hosts/<machine>.ini`. Données privées (adresses, montages) : `~/.config/qs-desktop.local/`, jamais dans le dépôt.

Les réglages conservés directement dans le BIOS sont documentés dans les notes de `hosts/` lorsqu'elles existent.

## Documentation

`docs/ARCHITECTURE.md` (fonctionnement), `docs/THEME.md` (charte), `docs/DEVELOPMENT.md` (développer sans casser son bureau),
`docs/ROLLBACK.md` (revenir en arrière), `deps/README.md` (dépendances par module), `PROGRESS.md`, `BACKLOG.md`.

Sur Intel, les paquets GPU incluent `intel-gpu-tools`. La charge 3D de la barre et les moteurs du moniteur utilisent ses
compteurs matériels. L'étape système demande l'autorisation ciblée `CAP_PERFMON` pour ce collecteur, conservée après les
mises à jour du paquet. `--no-system` laisse les droits actuels ; `--uninstall` avec retrait système les restaure.

Pour ajouter Windows 11 au menu et au launcher, déclarer `"windows11": {"uri": "qemu:///system", "domain": "win11"}`
dans `hosts/<machine>.json`, puis relancer `install.sh`. Les règles machine du laptop ouvrent la console de virt-manager en
mosaïque sur l’espace du profil (6 en travail, 5 en jeux), sans changer l’espace courant. Fermer sa fenêtre laisse Windows fonctionner.

## Provisioning ZeroTier

Les deux profils installent ZeroTier, les clients SMB/SFTP et iperf3 depuis les dépôts officiels.
Le Network ID est fourni par `hosts/zerotier-network`, versionné : un nouveau clone puis
`./install.sh` suffisent pour demander automatiquement la jonction, en acceptant les étapes système.
Cet identifiant n'est ni une clé ni un jeton ; chaque machine génère sa propre identité.
Pour changer le réseau commun, modifier ce fichier. Pour remplacer le réseau sur une seule installation,
créer `hosts/zerotier-network.local` (prioritaire, ignoré par Git), avec seulement le Network ID
sur une ligne (16 chiffres hexadécimaux). Aucun accès au desktop n'est nécessaire.
L'ancien réseau n'est pas quitté automatiquement lors d'un changement d'ID.

L'étape système active ZeroTier et conserve l'adhésion dans son répertoire natif.
Une nouvelle adhésion refuse DNS, routes publiques et route Internet par défaut.
Les adhésions préexistantes sont conservées. Autoriser le Node ID affiché dans les membres du réseau
sur ZeroTier Central ; service actif et requête de jonction ne prouvent pas la connectivité.
Sans autorisation ou réseau disponible, l'installateur affiche un rappel et conserve la configuration.
`--no-system` ignore le provisioning ; `--no-packages` nécessite un ZeroTier déjà installé.
Le retrait du bureau conserve actuellement les adhésions et le service ZeroTier.
Les ajouts n'activent ni sshd, ni Avahi, ni serveur iperf3.

### Partages Samba par ZeroTier

L'étape système configure les partages personnels et Nemo sur les interfaces locales, les ponts
libvirt (`virbr*`) et ZeroTier (`zt*`) uniquement. Aucune adresse de machine n'est codée en dur.
Les interfaces Wi-Fi et Ethernet ne servent pas SMB.
Un complément systemd attend l'adresse ZeroTier au démarrage de Samba (30 s maximum),
et propage les arrêts et redémarrages du service ZeroTier à Samba. Les changements d'adresse
sur une interface déjà connue sont suivis nativement par Samba sous Linux.
Si un nouveau réseau reste sans autorisation au-delà de ce délai, relancer la commande `samba`
après autorisation dans Central : une écoute manquante déclenche alors le redémarrage nécessaire.
L'accès exige le compte Samba de la machine distante ; `[homes]` limite chaque dossier à son propriétaire.
Si UFW est déjà actif, TCP 445 est autorisé uniquement sur les interfaces ZeroTier (`zt+`).
L'installateur n'installe ni n'active UFW ; un autre pare-feu doit autoriser ce même accès.

Sur chaque machine, créer le compte avec `sudo smbpasswd -a $USER` dans un terminal s'il manque.
Les comptes et mots de passe existants sont conservés. Dans Nemo, saisir
`smb://<IP ZeroTier distante>/<compte distant>` (Ctrl+L), puis les identifiants Samba distants.
Le mot de passe Samba est indépendant de l'authentification SSH.

Pour appliquer uniquement ces réglages depuis un clone à jour, sans relancer l'installation complète :
`scripts/system-setup.sh samba` dans un terminal (`--dry-run samba` pour simuler).
La commande ciblée accepte aussi `pkexec /chemin/vers/scripts/system-setup.sh samba`.
`install.sh --no-system` les ignore. Le retrait système restaure la configuration sauvegardée,
réapplique celle-ci au service actif et retire uniquement la règle UFW ajoutée par cette installation.

Validation réelle Arch en VM : installation, relances, redémarrage et panne réseau vérifiés.
Autorisation Central non accordée : aucune IP privée ni connectivité de bout en bout validées.
Détails : [rapport de validation](docs/ZEROTIER-VALIDATION.md).
