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
| 1. Paquets | active le dépôt `[multilib]`, installe `deps/arch-pacman.txt` (le bureau) et `deps/apps.txt` (applications de base), les paquets de la carte graphique (`deps/gpu.txt`), `brightnessctl` sur un laptop ; propose le profil jeux (`deps/games.txt`) ; construit `paru-bin`, seul paquet AUR |
| 2. Configs du compte | liens vers le dépôt : `~/.config/quickshell/desktop`, `sway`, `hypr`, `fastfetch`, `mpv`, `starship.toml`, `chromium-flags.conf`, règle WirePlumber ; bloc ajouté à `~/.bashrc` (le reste n'est pas touché) |
| 3. Thème | archives officielles Catppuccin (`deps/themes.txt`, empreintes vérifiées) : GTK 3/4, curseur, Kvantum (Qt), dossiers Papirus lavande, Geany ; mêmes polices et curseur partout |
| 4. Réglages | GSettings (`dotfiles/dconf/`), applications par défaut (`dotfiles/mime/defaults.list`), web apps, liens HTTP vers Chromium |
| 5. Config machine | crée `hosts/<machine>.json` s'il manque (à committer) |
| 6. Système (sudo) | écran de connexion greetd, sonde des portails captifs, Samba, services (réseau, Bluetooth, énergie, VM), groupes, thème Qt du système |

Tout fichier existant est sauvegardé avant d'être remplacé (`<fichier>.bak-<date>` à côté de l'original ; fichiers système dans
`/var/lib/qs-desktop/`).

Options : `--with jeux` / `--without jeux`, `--no-packages`, `--no-system`, `--yes` (aucune question), `--uninstall`
(retire liens et copies, remet les sauvegardes et les réglages d'origine, étapes système comprises ; les paquets restent).

Autre distribution qu'Arch : pas encore prévue (paquets à installer soi-même d'après les listes Arch de `deps/`, puis
`./install.sh --no-packages`).

## À faire soi-même ensuite

- Mot de passe Samba (demandé par Windows pour les partages avec les VM) : `sudo smbpasswd -a $USER`. Partager un dossier :
  clic droit dans Nemo → Partager.
- Web apps (WhatsApp, Discord, Word, Excel, PowerPoint, Notion) : se connecter une fois dans chacune.
- Thème des applications qui le rangent dans leur profil : Obsidian et Thunderbird (choisir Catppuccin Mocha dans leurs
  réglages), Chromium suit le thème GTK (réglé par `install.sh` : thème GTK du profil principal).
- Fonds d'écran : `install.sh` propose de cloner le dépôt `Crystal4276/wallpapers` dans `~/Pictures/Wallpapers` (HTTPS, sans
  compte GitHub) et le met à jour aux passages suivants. Fond par défaut : `simple/wallhaven-j37lop.png` (celui de l'écran
  central de terrier, `hosts/default.json`) ; autre choix : utilitaire de fonds d'écran du bureau.
- Logiciels absents des dépôts officiels, avec `paru` (installé par `install.sh`) :

| Logiciel | Commande | Remarque |
|---|---|---|
| Claude Code | `paru -S claude-code` | |
| NordVPN | `paru -S nordvpn-bin`, puis `sudo systemctl enable --now nordvpnd`, `sudo usermod -aG nordvpn $USER`, `nordvpn login` | module de la barre masqué sans lui |
| Plex Media Server | `paru -S plex-media-server`, puis `sudo systemctl enable --now plexmediaserver` | |
| RustDesk | `paru -S rustdesk-bin` | |

## Réglages propres à une machine

Ce qui ne se détecte pas va dans des fichiers par machine (nom : `cat /etc/hostname`), absents = valeurs par défaut :
`hosts/<machine>.json` (barre, écran principal, écran de connexion : `docs/ARCHITECTURE.md` § 4),
`dotfiles/sway/hosts/<machine>.conf`, `dotfiles/hypr/hosts/<machine>.lua` (écrans, matériel),
`dotfiles/mpv/hosts/<machine>.conf`, `dotfiles/chromium/hosts/<machine>.conf` (décodage vidéo),
`dotfiles/dconf/hosts/<machine>.ini`. Données privées (adresses, montages) : `~/.config/qs-desktop.local/`, jamais dans le dépôt.

## Documentation

`docs/ARCHITECTURE.md` (fonctionnement), `docs/THEME.md` (charte), `docs/DEVELOPMENT.md` (développer sans casser son bureau),
`docs/ROLLBACK.md` (revenir en arrière), `deps/README.md` (dépendances par module), `PROGRESS.md`, `BACKLOG.md`.
