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
./install.sh               # installer (questions avant chaque étape système)
```

Puis se déconnecter : l'écran de connexion greetd apparaît au prochain démarrage ; choisir Sway ou Hyprland.

`install.sh` est idempotent : le relancer ne refait que ce qui manque ou a changé (après un `git pull`, par exemple).

| Étape | Ce qui est fait |
|---|---|
| Avant les paquets | propose Reflector : installe d'abord ce seul paquet avec les miroirs existants s'il manque, classe jusqu'à 20 miroirs HTTPS mondiaux synchronisés depuis moins de 12 h par débit, puis active le renouvellement hebdomadaire (`reflector.timer`) |
| 1. Paquets | active le dépôt `[multilib]`, installe `deps/arch-pacman.txt` (le bureau) et `deps/apps.txt` (applications de base), les paquets de la carte graphique (`deps/gpu.txt`), `brightnessctl` sur un laptop ; propose le profil jeux (`deps/games.txt`) ; construit `paru-bin`, seul paquet AUR |
| 2. Configs du compte | liens vers le dépôt : `~/.config/quickshell/desktop`, `sway`, `hypr`, `fastfetch`, `mpv`, `starship.toml`, `chromium-flags.conf`, règle WirePlumber ; bloc ajouté à `~/.bashrc` (le reste n'est pas touché) |
| 3. Thème | archives officielles Catppuccin (`deps/themes.txt`, empreintes vérifiées) : GTK 3/4, curseur, Kvantum (Qt), dossiers Papirus lavande, Geany ; mêmes polices et curseur partout |
| 4. Réglages | GSettings (`dotfiles/dconf/`), applications par défaut (`dotfiles/mime/defaults.list`), web apps, liens HTTP vers Chromium ; profils Chromium (navigateur et web apps) en thème GTK, barre de titre du système (sans boutons réduire / agrandir / fermer) |
| 5. Config machine | crée `hosts/<machine>.json` s'il manque (à committer) |
| 6. Système (sudo / authentification polkit) | compteurs GPU Intel (CAP_PERFMON ciblé et hook de mise à jour), écran de connexion greetd, sonde des portails captifs, Samba, services (réseau, Bluetooth, énergie, VM), groupes, thème Qt du système, extensions de Chromium (`dotfiles/chromium/extensions.txt`, installées depuis le Chrome Web Store au démarrage du navigateur ; pas dans les web apps) |

Tout fichier existant est sauvegardé avant d'être remplacé (`<fichier>.bak-<date>` à côté de l'original ; fichiers système dans
`/var/lib/qs-desktop/`).

Avant les paquets, une question propose l'accès **pacman sans mot de passe pour tous les membres de `wheel`**.
Paru se lance normalement, en utilisateur : ses appels sudo à pacman bénéficient de la même règle.
Le fichier `/etc/sudoers.d/90-qs-desktop-pacman` est validé par `visudo`, appartient à root et a le mode `0440`.
Les autres commandes sudo gardent leur authentification habituelle. Activation seule :
`./scripts/system-setup.sh pacman-sudo` (authentification administrateur initiale nécessaire).
`--no-system` ignore ce réglage ; `--no-packages` le permet ; le retrait système restaure l'état précédent.

Options : `--with jeux` / `--without jeux`, `--no-packages`, `--no-system`, `--yes` (aucune question), `--uninstall`
(retire liens et copies, remet les sauvegardes et les réglages d'origine, étapes système comprises ; les paquets restent).

Reflector est réservé à Arch Linux. `--no-system` ignore cette étape ; `--no-packages` peut configurer un Reflector déjà présent.
Un échec conserve les miroirs précédents et laisse continuer l'installation ; le récapitulatif invite à relancer le script.
Les relances ne retestent pas les miroirs après une initialisation réussie, sauf changement de configuration ou liste absente.
Le timer renouvelle uniquement les miroirs, sans installer de mises à jour. Pour vérifier : `systemctl list-timers reflector.timer`
et `journalctl -u reflector.service`. Le retrait système restaure la configuration, la liste initiale et l'état antérieur du timer.

Autre distribution qu'Arch : pas encore prévue (paquets à installer soi-même d'après les listes Arch de `deps/`, puis
`./install.sh --no-packages`).

## À faire soi-même ensuite

- Mot de passe Samba (demandé par Windows pour les partages avec les VM) : `sudo smbpasswd -a $USER`. Partager un dossier :
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
