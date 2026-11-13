# Dépendances

Règle (2026-11-09) : **dépôts officiels d'abord**. `install.sh` n'installe aucun paquet AUR, sauf `paru-bin` qu'il construit
lui-même ; ce qui n'existe qu'en AUR (NordVPN, Plex, RustDesk) est seulement documenté dans `README.md`. Claude Code, absent
des dépôts, est installé par son script officiel (`https://claude.ai/install.sh`, dans `~/.local/bin`), avec confirmation.

- `arch-pacman.txt` : le bureau (dépôts officiels Arch).
- `reflector` (dans `arch-pacman.txt`) : amorcé avant les paquets du bureau avec confirmation système ; sélection mondiale HTTPS,
  synchronisation < 12 h, vingt candidats classés par débit ; service et timer hebdomadaire du paquet. Configuration via
  `scripts/system-setup.sh [--dry-run] reflector`, sauvegardes et retrait dans le même registre système.
- `apps.txt` : applications de base, toujours installées (terminal, fichiers, navigateur, mail, documents, création,
  multimédia minimal, Wine, virtualisation, Samba).
- `games.txt` : profil « jeux » (Steam, gamescope, Lutris, GameMode, Deluge) ; Steam vient du dépôt `multilib`, activé par `install.sh`.
- `work.txt` : profil « travail » (paquets de DigitalMicrograph sous Wine ; son dépôt privé `GMSFreeAnalysis17` est cloné par
  `install.sh`, son installation se lance à la main). Profil de la machine : clé `profile` de `hosts/<machine>.json`
  (`scripts/profile.sh`), demandé par `install.sh` s'il manque, ou `--profil jeux|travail`.
- `gpu.txt` : paquets selon la carte graphique détectée (VA-API, `nvidia-smi`, Vulkan 32 bits des jeux).
- `themes.txt` : thème Catppuccin (GTK, curseur, Kvantum, dossiers Papirus, Geany) : archives officielles, empreintes SHA-256.
- `optional.txt` : selon le matériel ou les modules utilisés.
- Fichiers fournis par le dépôt lui-même (polices, images, feuilles de style) : colonne « Fichiers du dépôt » ci-dessous.

Règle : chaque composant ajouté au dépôt met à jour **dans le même commit** la table « Par module » et les listes de paquets.
`install.sh` (phase 12) vérifiera, pour chaque ligne, que la commande, la police ou le service est réellement présent après installation.

## Par module

RGB (optionnel) : `openrgb` fournit le service système et les règles matérielles ; `python` valide et prépare les réglages dans
`scripts/openrgb-setup.sh`. Mise en place, migration du profil et retour arrière : [OPENRGB.md](../docs/OPENRGB.md).

Chaque commande a été rattachée à son paquet sur cette machine avec `pacman -Qo`.

« Natif » = fait par Quickshell lui-même, sans programme externe. Le paquet `quickshell` installe déjà Qt 6, `qt6-svg`,
`qt6-wayland` et `libpipewire`. Les modules Quickshell utilisés (`I3`, `Hyprland`, `Services.Pipewire`, `.Mpris`, `.SystemTray`,
`.Notifications`, `.UPower`) sont tous inclus dans ce paquet.

### Barre

| Module | Comment il obtient ses données | Paquets requis | Optionnel (module masqué / clic inactif si absent) | Polices | Fichiers du dépôt |
|---|---|---|---|---|---|
| Barre (toutes) | layer-shell Wayland | `quickshell`, `sway` ou `hyprland` | — | — | — |
| Bouton Arch | natif (ouvre le menu d'applications maison) | — | — | — | `assets/arch_linux_icon_green.svg`, `arch_linux_icon_mantle.svg` |
| Espaces de travail | natif (`Quickshell.I3` / `Quickshell.Hyprland`) | — | — | Symbols Nerd Font Mono | — |
| Média (mpris) | natif (`Services.Mpris`, D-Bus) | — | un lecteur MPRIS (Spotify via `spotify-launcher` ou le paquet AUR `spotify`, n'est pas une dépendance du bureau) ; choix du lecteur à la molette natif (plus de `playerctl`) | Inter, Font Awesome 7 Brands, FontAwesome 4.7 | — |
| Volume (icône + curseur) | natif (`Services.Pipewire`) | `pipewire`, `wireplumber` (services utilisateur actifs), `rtkit` (priorité temps réel) | `pavucontrol` (réglages avancés du panneau audio ; `pipewire-pulse`) | Symbols Nerd Font Mono | — |
| Sortie audio suivante (ex-`audio-toggle.sh`) | natif (`Services.Pipewire`) + `notify-send` | `libnotify` | — | — | — |
| Mises à jour | `checkupdates` | `pacman-contrib`, **`fakeroot`** (`checkupdates` échoue sans lui ; non déclaré par `pacman-contrib`) | `paru` ou `yay` (clic) ; terminal | Inter, Hack Nerd Font | — |
| GPU | NVIDIA : `nvidia-smi` ; AMD : sysfs (natif) ; Intel : `intel_gpu_top` (PMU, un seul processus à 5 s) | — | `nvidia-utils` (NVIDIA) ; `intel-gpu-tools`, `libcap` (Intel), `polkit` pour accorder CAP_PERFMON ; module masqué sans charge lisible | Inter, Hack Nerd Font | — |
| CPU | natif (`/proc/stat`) | — | — | Inter, Hack Nerd Font | — |
| Mémoire | natif (`/proc/meminfo`) | — | — | Inter, Hack Nerd Font | — |
| Panneau de statistiques (clic CPU / mémoire / GPU, remplace btop et nvtop) | natif (`/proc`, `/sys`) | `procps-ng` (`ps`), `util-linux` (`kill`), `coreutils` (`df`), `python` (`gpu-stats.py` : sysfs et mémoire DRM fdinfo) ; NVIDIA : `nvidia-smi` ; Intel : flux `intel_gpu_top` partagé avec la barre | — | Inter, Hack Nerd Font | — |
| Horloge + fenêtre calendrier | natif (Qt) | `tzdata` (système) | — | Inter, Hack Nerd Font, Font Awesome 7 Free | — |
| Réseau (débit) | natif (`/proc/net/dev`, `/proc/net/route`) | — | — | Inter, Hack Nerd Font | — |
| Tray | natif (`Services.SystemTray` ; Quickshell fait aussi le rôle de « watcher ») | — | — | Inter (menus) | — |
| Engrenage → panneau de réglages (remplace le power menu) | natif (`Pipewire`, `UPower`, `PowerProfiles`, `IdleInhibitor`, IPC du compositeur pour HDR / VRR) | `systemd` (redémarrer, éteindre), `gammastep` (veilleuse), `util-linux` (`rfkill`, mode avion), capture et verrouiller : natifs (phase 8b, voir plus bas) | `power-profiles-daemon` (3 boutons masqués sans lui) ; `brightnessctl` (luminosité, laptop) | Inter, Symbols Nerd Font Mono | `assets/{lock,logout,restart,shutdown}.svg` |
| Bouton Arch → menu d'applications (remplace nwg-menu) | natif (`DesktopEntries`) | `xdg-user-dirs` (dossiers), `xdg-utils` (ouvrir dossiers et fichiers) ; boutons de session comme le panneau de réglages | — | Inter, Symbols Nerd Font Mono | `assets/{lock,logout,restart,shutdown}.svg`, icônes Papirus-Dark |
| Batterie (laptop) | natif (`Services.UPower`) | — | `upower` (service système) | Symbols Nerd Font Mono (icônes v3 `U+F0079`…) | — |
| Luminosité (laptop) | `/sys/class/backlight` | — | `brightnessctl` (écriture sans root) | Symbols Nerd Font Mono | — |

Rendu de tous les SVG : `qt6-svg` (installé avec `quickshell`).
Thème d'icônes des applications (tray, lanceur, menu d'applications, notifications) : `papirus-icon-theme` (`Papirus-Dark`).

### Autres composants

| Composant | Paquets requis | Optionnel | Polices | Fichiers du dépôt |
|---|---|---|---|---|
| Notifications | — (natif) | `libnotify` (tests `notify-send`) | Inter | — |
| Lanceur | — (natif, `DesktopEntries`) | terminal pour les applis `Terminal=true` | Inter, Symbols Nerd Font Mono | — |
| Comptes en ligne (application) | `gnome-online-accounts-gtk` (interface autonome, `deps/apps.txt` ; installe `gnome-online-accounts`) | — | — | — |
| Menu d'applications (modèle Cinnamon, remplace nwg-menu) | — (natif, `DesktopEntries`) ; `xdg-user-dirs` (dossiers), `xdg-utils` (ouvrir dossiers et fichiers) | — | Inter, Symbols Nerd Font Mono | icônes de session `assets/*.svg` |
| Verrouillage | — (natif, `WlSessionLock` + `PamContext`, `pam` installé avec `quickshell`) ; `systemd` (éteindre, redémarrer, veille) | — | Inter | `assets/{shutdown,restart,suspend}.svg` |
| Écran de connexion (greetd, `ARCHITECTURE.md` § 9) | `greetd` (natif, `Services.Greetd`), `sway` (compositeur du greeter), `git` + `tar` (copie système par `scripts/greeter-setup.sh`), `sudo` (mise en place) | `greetd-agreety` (secours console) ; `xorg-xinit` + `xorg-server` (sessions X11, par `startx`) ; `gnome-keyring` (trousseau déverrouillé par PAM) | Inter, Symbols Nerd Font Mono | `greeter.qml`, `dotfiles/greetd/`, `scripts/greeter*.sh` |
| Fond d'écran + utilitaire | — (natif) | `xdg-user-dirs` (dossier Images) ; dépôt privé des fonds cloné dans `~/Pictures/Wallpapers` | Inter, Symbols Nerd Font Mono | — |
| Veille des écrans | natif (`IdleMonitor` + commande DPMS au compositeur) ; `python`, `python-gobject` (service D-Bus ScreenSaver) ; `systemd` (`systemd-inhibit`), `glib2` (`gdbus` : mise en veille du système) | — | — | — |
| Agent polkit | — (natif, `PolkitAgent` ; `polkit` installé avec `quickshell`) | — | Inter | — |
| Réseau (tray) | `networkmanager` (natif, `Networking` ; `nmcli` pour les détails filaires), `wl-clipboard` (copies) | `nm-connection-editor` pour l'édition des connexions ; onglets `tailscale` (actions : `tailscale set --operator=$USER`) et `zerotier-one` (jeton copié dans `~/.zeroTierOneAuthToken`), masqués si absents | icônes Papirus-Dark (`nm-*`, `network-vpn`, `zerotier-gui`, `computer`, `smartphone`) | — |
| Wi-Fi (tray) | `networkmanager` (natif ; `nmcli` pour bande, canal, débit, adresse), `wireless-regdb` (base réglementaire signée ; dépendance `iw`), `xdg-utils` (portail captif dans le navigateur par défaut) | — | glyphe dessiné (géométrie Papirus) | — |
| Bluetooth (tray) | `bluez` (natif, `Bluetooth`), `bluez-utils` (agent d'appairage) | — | icônes Papirus-Dark (`blueman-tray*`) | — |
| Disques amovibles (tray) | `udisks2`, `glib2` (`gdbus`), `systemd` (`busctl`), `xdg-utils` (ouvrir), `libnotify` (notifications), `util-linux` (`setpriv`) | — | icônes Papirus-Dark | — |
| NordVPN (tray) | — | `nordvpn-bin` (AUR) + service `nordvpnd` + compte connecté (sinon module masqué) ; icônes `nordvpn-tray-*` du paquet | — | historique des pays : `~/.local/state/quickshell/by-shell/desktop/vpn.json` |
| Outil de capture | natif (`ScreencopyView`) ; `wl-clipboard` (presse-papiers), `xdg-user-dirs` (dossier Images) | — | Inter, Symbols Nerd Font Mono | — |
| Événements Thunderbird (backlog) | `sqlite` | — | — | — |

Le [module temps réel de PipeWire](https://docs.pipewire.org/page_module_rt.html) utilise RTKit par D-Bus lorsque les limites
de la session ne permettent pas d'obtenir directement une priorité temps réel. Le paquet `rtkit` fournit ce service natif.
`wireless-regdb` fournit la base Wi-Fi signée `regulatory.db` et sa signature ; `iw`, installé comme dépendance, permet
notamment de consulter le domaine réglementaire. Ces paquets communs sont repris par les deux profils d'`install.sh`.

### Hors barre (configs compositeur)

Thème GTK, curseur, Kvantum : archives Catppuccin (`deps/themes.txt`). Tout le reste (fond, veille, verrouillage, polkit, applets réseau/Bluetooth/disques, captures) est fait par
Quickshell : `swaybg`, `swayidle`, `hypridle`, `swaylock`, `polkit-gnome`, `blueman`, `udiskie`, `hyprshot`, `waybar`, `dunst`, `rofi`
ne sont pas des dépendances (Dunst, s'il est installé, doit être masqué : `systemctl --user mask dunst.service`).
Les applications personnelles lancées au démarrage (Steam, Spotify, Thunderbird, NordVPN…) ne sont **pas** des dépendances du bureau.

| Script | Rôle | Commandes |
|---|---|---|
| `scripts/desktop.sh [restart\|stop\|log]` | lance le bureau depuis l'autostart de Sway / Hyprland, le relance s'il s'arrête | `qs`, `flock`, `setsid` (`util-linux`), `swaymsg` / `swaynag` (`sway`), `hyprctl` |
| Vérification des espaces Hyprland | complète le modèle natif lors d’une course au démarrage | `hyprctl` (`hyprland`), `timeout` (`coreutils`, déjà requis) |
| `scripts/spotify-launch.sh [arguments…]` | lancement commun de Spotify sous Sway / Hyprland, priorité au client direct | `spotify` (AUR) ou `spotify-launcher` (dépôts officiels, `deps/apps.txt`) |
| `scripts/ipc.sh <cible> <fonction> …` | `qs ipc call` vers le bureau de la session (raccourcis) | `qs` |
| `scripts/greeter.sh [shell]` | écran de connexion : Sway minimal puis Quickshell (lancé par greetd) | `sway`, `swaymsg`, `qs` |
| `scripts/greeter-session.sh` | session choisie : shell de connexion puis `Exec` ; X11 par `startx` | `sh`, `startx` (`xorg-xinit`, sessions X11) |
| `scripts/greeter-setup.sh [--dry-run] install\|enable\|uninstall` | mise en place système de l'écran de connexion | `sudo`, `git`, `tar`, `install` / `cmp` (`coreutils`, `diffutils`), `systemctl`, `getent`, `setfacl` (`acl`, paquet de base) |

| `install.sh [--dry-run] [--profil jeux|travail] [--no-packages] [--no-system] [--yes] [--uninstall]` | installation complète d'une machine (README.md) ; registre et sauvegardes dans `~/.local/state/qs-desktop/install` | `pacman`, `sudo`, `git` + `makepkg` (`base-devel` : paru-bin), `lspci` (`pciutils`), `curl`, `sha256sum`, `tar`, `unzip`, `python` (+ `python-gobject` : `scripts/dconf-keys.py`), `dconf`, `xdg-mime` (`xdg-utils`), `update-desktop-database` (`desktop-file-utils`), `gtk-update-icon-cache` (`gtk3`), `fc-list` |
| `scripts/system-setup.sh [--dry-run] pacman-sudo\|multilib\|install\|uninstall` | sudo pacman sans mot de passe pour wheel, `[multilib]`, Samba (`dotfiles/samba/smb.conf`, partages utilisateur), `QT_QPA_PLATFORMTHEME`, groupes, services, réseau des VM, curseur de l'écran de connexion (`/usr/local/share/icons`) | `sudo` + `visudo` (paquet `sudo`), `sed`, `install`, `cmp`, `usermod` / `gpasswd` / `groupadd` (`shadow`), `systemctl`, `virsh` (`libvirt`) |
| `scripts/test-install.py` | étapes du compte d'`install.sh` dans un dossier personnel jetable : simulation, installation, idempotence, retrait | `dbus-run-session` (`dbus`), `dconf` |

Portails captifs : `scripts/network-setup.sh [--dry-run] install|uninstall` (`sudo`, `nmcli`, `coreutils`, `diffutils`, `flock` de `util-linux`).
Configuration et sauvegarde système, à reprendre par `install.sh` en phase 12 : [NETWORK.md](../docs/NETWORK.md).

### Spotify en Wayland natif

Si `spotify-launcher` est installé, `install.sh` lie `dotfiles/spotify/spotify-launcher.conf` dans le dossier de configuration
du compte. Ce réglage cible Sway et Hyprland : backend Wayland, décorations Wayland et `DISPLAY` vidé par le lanceur pour son
client seulement. L'accélération graphique reste active. Il s'applique aux lancements par le menu et par l'autostart ; une
instance déjà ouverte garde ses réglages jusqu'à sa fermeture. Le client alternatif `spotify` (AUR) garde sa configuration.

Configuration native du lanceur : [source spotify-launcher](https://github.com/kpcyrd/spotify-launcher/blob/main/src/config.rs).
Un fichier préexistant est sauvegardé par le mécanisme habituel d'installation ; le retrait restaure l'original ou retire
le lien créé. Pour revenir à X11, retirer uniquement le lien `spotify-launcher.conf` pointant vers ce dépôt et remettre
l'éventuelle sauvegarde d'origine avant le prochain lancement. Les données du compte Spotify restent dans leur profil.

### Web apps et « ne pas déranger »

Web apps du dépôt : WhatsApp, Discord, Word, Excel, PowerPoint, Notion, Copilot (`dotfiles/webapps/applications/`).

| Composant | Comment | Paquets requis | Fichiers du dépôt |
|---|---|---|---|
| Sons coupés pendant « ne pas déranger » | natif (`Services.Pipewire`, `services/Audio.qml`) ; flux repérés par `application.id` (web apps) ou binaire (application Discord) | `wireplumber` | règle `dotfiles/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf` ; liste `doNotDisturb.muteApps` de `hosts/<machine>.json` |
| Web apps WhatsApp et Discord | `chromium --app` dans un profil isolé ; `PULSE_PROP_OVERRIDE=application.id=…` dans le lanceur (coupure de nuit) | `chromium` | modèles de lanceurs `dotfiles/webapps/applications/*.desktop` |
| Web apps Word, Excel, PowerPoint, Notion, Copilot | `chromium --app` dans un profil isolé (pas de coupure de nuit : pas de sons de notification) | `chromium` | modèles de lanceurs `dotfiles/webapps/applications/*.desktop` |
| Extensions du navigateur | extensions externes : `/usr/share/chromium/extensions/<id>.json` (étape système), installées depuis le Chrome Web Store au démarrage ; refusées dans les profils des web apps (`extensions.external_uninstalls`) ; réglages de nightTab importés par `install.sh` (Chromium sans fenêtre, `scripts/nighttab-import.py`) | `chromium`, `python`, accès au Chrome Web Store | `dotfiles/chromium/extensions.txt`, `external-extension.json`, `nighttab.json` |
| Thème de Thunderbird | Catppuccin Mocha Green (`deps/themes.txt`, `.xpi` vérifié) installé par une politique `ExtensionSettings` (`/etc/thunderbird/policies/policies.json`, étape système, `scripts/system-setup.sh thunderbird-theme`) | `thunderbird` (`deps/apps.txt`) | — |
| Lancement Chromium à chaud | transmission au navigateur existant ; repli natif | `socat` (optionnel) | `scripts/chromium-launch.sh`, raccourcis et lanceur |
| Contenu ouvert depuis Deluge / Thunderbird / Steam | origine du lancement → fenêtre de destination sur l'écran principal, lecteur déjà ouvert compris | `python`, `python-gobject`, `quickshell`, `swaymsg` ou `hyprctl` | `scripts/open-origin.py` ; HTTP Chromium : `browser-link.py` + surcharge desktop |

`webapp-manager` n'est **pas** une dépendance : les lanceurs de ces web apps viennent du dépôt. Ne pas les modifier avec
lui (il réécrit la ligne `Exec` et ferait sauter `PULSE_PROP_OVERRIDE` et `--load-extension`) ; modifier le modèle du dépôt.

### Outils de développement

`grim`, `imagemagick` (captures et recadrage), `jq` (tests), `libnotify` (tests de notifications), `zenity` (fenêtres de test de `scripts/test-outputs.sh`).

| Script | Rôle | Commandes |
|---|---|---|
| `scripts/dev.sh [stop\|log]` | relance le bureau (`scripts/desktop.sh restart`) et affiche les erreurs | `qs` |
| `scripts/shot.sh <nom> [sortie\|géométrie]` | capture dans `.shots/` (ignoré par git) | `grim` |
| `scripts/crop.sh <image> <géométrie> [sortie]` | recadre une capture | `magick` (`imagemagick`) |
| `scripts/test-outputs.sh [sway\|hyprland] [-v]` | teste la répartition des espaces (et `$mod+N`, `$mod+Ctrl+N`, début de session) dans une session isolée | `sway` ou `hyprland`, `jq`, `zenity`, `qs` |
| `scripts/plymouth-assets.py build\|check` | images et bloc de données du thème Plymouth (`docs/PLYMOUTH.md`) ; planche de contrôle contre la référence. Jamais lancé par `install.sh` (PNG committés) | `python-cairo`, `python-numpy`, `python-pillow`, `chromium` (+ réseau : DM Sans et Inter de Google Fonts, comme la référence) |

## Prérequis système d'un nouveau PC (au-delà des paquets)

Ce que `install.sh` (phase 12) devra installer, activer ou vérifier — relevé sur cette machine.

| Élément | Pourquoi | Sur cette machine | Action sur un nouveau PC |
|---|---|---|---|
| Service `NetworkManager` | module réseau (`Quickshell.Networking`) | activé | `systemctl enable --now NetworkManager` (demande `sudo` : à confirmer) |
| Service `bluetooth` | module Bluetooth | activé | `systemctl enable --now bluetooth` (`sudo`) ; module masqué si absent |
| `upower`, `udisks2` | batterie, disques | activés à la demande par D-Bus | rien |
| `polkit` | agent polkit natif, montage des disques sans mot de passe | actif (statique) | rien |
| Services utilisateur `pipewire.socket`, `pipewire-pulse.socket`, `wireplumber` | audio | activés | `systemctl --user enable --now …` |
| Service `rtkit-daemon` | priorité temps réel des threads audio | activation native par D-Bus | paquet `rtkit` ; activation à la demande |
| Fichier PAM du verrouillage | `WlSessionLock` + `PamContext` vérifient le mot de passe | configuration `login` de `/etc/pam.d` (présente partout) | rien : un fichier propre au dépôt ne marche pas (`include` se résout dans son propre dossier) ; rien n'est écrit dans `/etc` |
| Polices d'icônes (Symbols Nerd Font Mono, Hack Nerd Font, Font Awesome 7 Free / Brands, FontAwesome 4.7) | icônes de la barre (`THEME.md` § 2) | paquets (`ttf-nerd-fonts-symbols-mono`, `ttf-hack-nerd`, `otf-font-awesome`, `awesome-terminal-fonts`) | paquets officiels (`deps/arch-pacman.txt`) ; Quickshell charge en plus ses copies de `assets/fonts/` (`FontLoader`) |
| Images `assets/*.svg` | bouton Arch, icônes de session | dans le dépôt | rien (`THEME.md` § 12) |
| Lien `~/.config/quickshell/desktop` → dépôt | lancement par `qs -c desktop` | existe | créé par `install.sh` |
| Thème d'icônes `Papirus-Dark` | icônes d'applications | paquet | paquet + `//@ pragma IconTheme Papirus-Dark` dans `shell.qml` (indispensable : le thème `breeze` de qt6ct n'est pas installé ici, `ARCHITECTURE.md` § 8.1) |
| Curseur, thème GTK, Kvantum, dossiers Papirus | apparence des applications | paquets AUR (ancienne installation) | archives Catppuccin de `deps/themes.txt` dans le compte + réglages GTK / Qt / dconf, par `install.sh` (étape 3) |
| Dépôt `wallpapers` | fonds d'écran | `~/Pictures/Wallpapers` | cloné par `install.sh` (dépôt public, HTTPS, `--depth 1`, progression affichée) ; facultatif |
| Commande de session Sway sur Nvidia | `WLR_RENDERER=vulkan sway --unsupported-gpu` | fichier `/usr/share/wayland-sessions/sway-vulkan.desktop` créé à la main pour SDDM | versionné (`dotfiles/greetd/sway-vulkan.desktop`), installé dans `/usr/local/share/wayland-sessions/` par `scripts/greeter-setup.sh` si Nvidia est la seule carte graphique (laptop hybride : phase 12) ; le Sway du greeter le détecte seul (`scripts/greeter.sh`) |
| Gestionnaire de connexion | greetd + greeter Quickshell (phase 11, `ARCHITECTURE.md` § 9) | SDDM activé (`sddm.service`), PAM `/etc/pam.d/sddm` avec `pam_gnome_keyring.so` | paquets `greetd` (+ `greetd-agreety`), puis `scripts/greeter-setup.sh install` (copie dans `/usr/local/share/qs-desktop`, `/etc/greetd/config.toml`, `/etc/pam.d/greetd` avec le trousseau, `/etc/pam.d/greetd-greeter`, `/var/lib/qs-desktop/`) et `enable` (ancien gestionnaire désactivé) — `sudo`, avec ton accord |
| `QT_QPA_PLATFORMTHEME=qt6ct` | thème des applications Qt (Kvantum `KvArcDark`, icônes `breeze`) | dans `/etc/environment` | à reproduire (fichier système, `sudo`) ; Quickshell en hérite (`ARCHITECTURE.md` § 8.1) |
| Réglages dconf | apparence des applications GTK | dconf | `gsettings set org.gnome.desktop.interface …` par `install.sh` (liste ci-dessous) |
| Polices CJK | titres et notifications en japonais/chinois/coréen | polices MS copiées à la main | `noto-fonts-cjk` (repli du bureau) |
| Polices Microsoft (optionnel) | documents Word, repli CJK | `/usr/share/fonts/MS_Fonts` (363 Mo) | dépôt privé `Crystal4276/fonts-ms`, cloné à la demande dans `~/.local/share/fonts/fonts-ms` + `fc-cache -f` (clé SSH GitHub nécessaire) |
| Règle WirePlumber « ne pas déranger » | les flux coupés la nuit ne sont pas retenus par WirePlumber (sinon coupés le lendemain) | copiée dans `~/.config/wireplumber/wireplumber.conf.d/` | lien vers `dotfiles/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf`, puis `systemctl --user restart wireplumber` ; voir « Web apps » ci-dessous |
| Web apps (WhatsApp, Discord, Word, Excel, PowerPoint, Notion, Copilot) | lanceurs, coupure de nuit (WhatsApp, Discord), liens vers le navigateur | créées avec `webapp-manager`, puis lanceurs modifiés à la main | générées par `install.sh` depuis `dotfiles/webapps/` : voir « Web apps » ci-dessous |
| Utilisateur dans le groupe `video` ou règles udev | `brightnessctl` sans `sudo` (laptop) | sans objet (pas de rétroéclairage) | fourni par le paquet `brightnessctl` (règles udev) ; à vérifier sur le laptop |

Réglages dconf de cette machine (`org.gnome.desktop.interface`) : `gtk-theme` `catppuccin-mocha-green-standard+default`,
`icon-theme` `Papirus-Dark`, `font-name` `Inter Light 12`, `document-font-name` `Inter Light 13`, `monospace-font-name`
`Source Code Pro 12`, `text-scaling-factor` `1.25`, `color-scheme` `prefer-dark`, `cursor-theme` `catppuccin-mocha-green-cursors`,
`cursor-size` `48`, `clock-format` `24h`.

### Curseur : mise en cohérence du compte

Thème commun : `catppuccin-mocha-green-cursors`, taille `48` (`docs/THEME.md`). Le paquet fournit les formats XCursor et
Hyprcursor. Hyprland doit fixer **les deux** variables `XCURSOR_THEME` et `HYPRCURSOR_THEME` dans `lua/env.lua`, ainsi que leurs
tailles : sans `HYPRCURSOR_THEME`, Hyprcursor prend le premier thème installé qu'il trouve (ici le mauve), avant que le
`hyprctl setcursor` de l'autostart impose le vert. Sway et le greeter fixent déjà le thème avec `seat … xcursor_theme`.

Procédure à reprendre par `install.sh` (phase 12), sans remplacer les autres préférences d'apparence : sauvegarder chaque fichier
modifié avec un suffixe `.bak-<date>`, puis mettre à jour uniquement les clés suivantes (ajouter les clés absentes) :

| Réglage utilisateur | Clés et valeurs |
|---|---|
| `~/.config/gtk-3.0/settings.ini` et `~/.config/gtk-4.0/settings.ini`, section `[Settings]` | `gtk-cursor-theme-name=catppuccin-mocha-green-cursors`, `gtk-cursor-theme-size=48` |
| `~/.gtkrc-2.0` | `gtk-cursor-theme-name="catppuccin-mocha-green-cursors"`, `gtk-cursor-theme-size=48` |
| `~/.config/xsettingsd/xsettingsd.conf` | `Gtk/CursorThemeName "catppuccin-mocha-green-cursors"`, `Gtk/CursorThemeSize 48` |
| `~/.icons/default/index.theme`, section `[Icon Theme]` | `Inherits=catppuccin-mocha-green-cursors`, `Size=48` |
| `org.gnome.desktop.interface` (GSettings) | `cursor-theme` : `catppuccin-mocha-green-cursors` ; `cursor-size` : `48` |
| `~/.Xresources` | `Xcursor.theme: catppuccin-mocha-green-cursors`, `Xcursor.size: 48` |

Ne pas modifier les fichiers déjà conformes. Les exports de nwg-look doivent garder ce même thème ; les anciens thèmes et les
fichiers système n'ont pas besoin d'être supprimés ou changés. Une nouvelle connexion valide le thème initial du compositeur ;
les applications déjà ouvertes peuvent garder leur curseur jusqu'à leur prochain lancement.

Autres constats pour un nouveau PC :
- trousseau `gnome-keyring` déverrouillé par PAM à la connexion (greetd : `dotfiles/greetd/pam-greetd`) ;
- `logind` par défaut (bouton power = extinction ; capot = mise en veille, sauf écran externe actif : verrou `handle-lid-switch`
  d'`Idle.qml`) ; dalle éteinte capot fermé par le compositeur (`dotfiles/*/hosts/<laptop>`) ;
- polices de repli : `noto-fonts-cjk` (japonais, chinois, coréen ; ici les polices Microsoft le font), `noto-fonts-emoji` ;
- partage d'écran sous Sway : `xdg-desktop-portal-wlr` choisit l'écran avec `slurp` ;
- **secrets jamais versionnés** : jetons (NordVPN…), adresses de montage (`gio mount ssh://…`) → `~/.config/qs-desktop.local/`.

Commandes dont `install.sh` vérifiera la présence après installation :
`qs`, `checkupdates`, `fakeroot`, `bluetoothctl`, `udisksctl`, `gdbus`, `busctl`, `grim`, `slurp`, `wl-copy`, `pavucontrol`
(+ optionnels : `nvidia-smi`, `brightnessctl`, `paru`/`yay`, `nm-connection-editor`, `chromium` pour les web apps).

### Web apps : ce que fait `install.sh`

Tout en une fois, idempotent : un fichier généré identique à l'existant n'est pas réécrit ; sinon, sauvegarde
`<fichier>.bak-<date>` avant de le remplacer, seulement si aucune sauvegarde n'existe encore (l'original de l'utilisateur, pas
une sortie d'`install.sh`). `--uninstall` : copies générées (lanceurs, manifestes de l'hôte) retirées, sauvegardes remises
s'il y en a. `WEBAPPS` = dossier
`dotfiles/webapps` du dépôt (chemin absolu), `PROFILES` = `~/.local/share/ice/profiles` (dossier de `webapp-manager`, gardé :
les profils et sessions déjà connectées de cette machine sont repris tels quels).

1. Paquets : `chromium` (`deps/optional.txt`), `python` (`deps/arch-pacman.txt`), `wireplumber`, `papirus-icon-theme` (icônes `whatsapp`, `discord`,
   `notion`, `solstice-microsoft-365-{word,excel,powerpoint}`). Copilot utilise son icône officielle embarquée
   (`dotfiles/webapps/icons/copilot.png`, source documentée à côté), sans paquet supplémentaire.
2. Règle WirePlumber, seulement si `doNotDisturb.muteApps` de la machine n'est pas vide (sinon elle ne sert à rien et les web
   apps perdent la mémoire de leur volume) : lien `~/.config/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf` →
   `dotfiles/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf`, puis `systemctl --user restart wireplumber` si le lien
   vient d'être créé ou changé (le redémarrage coupe le son un instant).
3. Pour chaque modèle `dotfiles/webapps/applications/<lanceur>.desktop` : remplacer `@PROFILES@` et `@WEBAPPS@`, écrire le
   résultat dans `~/.local/share/applications/<lanceur>.desktop` (copie, pas lien : les chemins y sont développés), puis
   `update-desktop-database ~/.local/share/applications` s'il existe. Chemin avec espace : argument entier entre guillemets
   dans `Exec` (`"--load-extension=…"`) ; chemin contenant `"`, `` ` ``, `$`, `\` ou `%` : refusé avec un message (deux
   niveaux d'échappement dans `Exec`, pas la peine pour un cas improbable).
4. Pour chaque profil (`Whatsapp8699`, `DiscordWeb2996`, `Word9053`, `Excel7169`, `Powerpoint0904`, `Notion5106`, `Copilot`, lus dans
   `--user-data-dir` des modèles) : créer
   `PROFILES/<profil>/NativeMessagingHosts/` et y écrire `qs_desktop.open_link.json` depuis `dotfiles/webapps/qs_desktop.open_link.json`
   (`@WEBAPPS@` remplacé, échappé pour JSON : Chromium exige un chemin absolu). Vérifier que `dotfiles/webapps/open-link`
   est exécutable.
5. `hosts/<machine>.json` : `doNotDisturb.muteApps` contient `whatsapp` et `discord` (ex. `hosts/terrier.json`) ; la config
   par défaut d'une nouvelle machine laisse la liste vide.
6. Message de fin : relancer les web apps si elles tournent ; nouvelle machine : se connecter une fois dans chacune (WhatsApp
   par QR code, Discord, compte Microsoft 365, Notion).

Contrôle après installation : `pw-dump` montre `application.id` `whatsapp` / `discord` sur les clients des web apps lancées ; un
lien cliqué dans une web app s'ouvre dans le navigateur principal.

Sur cette machine, `install.sh` remplacera les lanceurs actuels par les modèles : mêmes options, mais chaque app s'ouvrira sur
son accueil (Discord : `https://discord.com/channels/@me` ; Word, Excel, PowerPoint : `https://www.office.com/launch/<app>` ;
Notion : `https://www.notion.so/`). Les lanceurs actuels ouvrent une conversation, des documents SharePoint ou une page
précis, laissés hors du dépôt (adresses personnelles).

Sous Wayland, Chromium ignore `--class` : l'app_id d'une web app vient de son adresse de départ (`StartupWMClass` des
modèles : app_id relevé avec ces adresses). Changer l'adresse d'un modèle change son app_id, donc les règles d'espace des
configs compositeur (Discord : `…@me-Default` et `…@me_<salon>-Default`, espace 5).

## Contenu ouvert depuis Deluge, Thunderbird et Steam

La règle dépend de l'application d'origine, pas du workspace, du type de fichier ou du navigateur. Sous Hyprland,
`dotfiles/hypr/lua/openorigin.lua` décide le placement dans le mapping natif, avant le rendu ; aucune animation de transfert
entre écrans. Les lecteurs déjà ouverts sont placés dès la demande. Sous Sway, le suivi passe par les événements IPC après
création : la destination est la même, mais le placement avant premier rendu n'est pas garanti. Le processus
`scripts/open-origin.py`, tenu par `Compositor`, suit les ouvertures natives GIO/D-Bus et les nouvelles fenêtres de programmes
lancés directement par ces applications. Une vidéo, un document, un dossier ou une autre fenêtre de destination est envoyé
sur l'écran principal, y compris lorsque le lecteur est déjà lancé. Les propres fenêtres de Deluge/Thunderbird/Steam gardent
leurs affectations ; les lancements manuels et les autres applications ne déclenchent pas cette politique.

Les URI et chemins ne sont ni journalisés ni enregistrés : le contexte de requête reste brièvement en mémoire ; PID et date
de création du processus contrôlés. Le signal GIO de lancement, les méthodes d'ouverture GApplication, `CommandLine` des
applications GTK, FileManager1 et les ouvertures via portail/MPRIS sont pris en charge. Le suivi utilise `python-gobject`
(déjà requis pour l'inhibition vidéo), `swaymsg`/`hyprctl` selon le compositeur et l'IPC Quickshell `outputs primaryName`.
Il n'effectue aucune action réseau et ne modifie aucune association de fichiers ou réglage de lecteur.

Pour le cas particulier des liens HTTP/HTTPS venant de ces sources, ton choix est conservé : réutiliser une fenêtre Chromium
sur l'écran principal, sinon en créer une. `browser-link.py` vérifie l'origine auprès du suivi de session ; les autres sources,
les fichiers locaux et le lancement sans URL passent par Chromium natif. Les liens des web apps conservent leur ancien chemin
de focus. Les anciennes règles globales de renvoi des workspaces 7/8 sont retirées.

La surcharge utilisateur Chromium s'installe sans sudo par `python3 scripts/browser-links-setup.py install` (simulation :
`--dry-run install`). Seule l'Exec principale du fichier `chromium.desktop` du paquet est remplacée ; identité, traductions,
actions et associations MIME conservées. Installation idempotente, retrait par `uninstall`, sauvegarde d'une ancienne surcharge
native dans `$XDG_STATE_HOME/qs-desktop/browser-links` (repli `~/.local/state`, dossier 700). Les commandes personnalisées et les
éditions ultérieures sont préservées. Ce script sera repris par `install.sh` en phase 12.

### Charge matérielle Intel

`install.sh` sélectionne `intel-gpu-tools` et `libcap` uniquement si Intel est détecté (`deps/gpu.txt`). L'étape système
propose `scripts/system-setup.sh intel-gpu` : `pkexec` authentifie une transaction qui donne `cap_perfmon=ep` au seul
`/usr/bin/intel_gpu_top`, sans changer `kernel.perf_event_paranoid` ni lancer Quickshell comme root. Le hook
`/etc/pacman.d/hooks/90-qs-intel-gpu.hook` réapplique ce droit après une mise à jour du paquet. L'ancien droit et un éventuel
hook préexistant sont sauvegardés dans `/var/lib/qs-desktop/intel-gpu`, restaurés au retrait système ; une capacité modifiée par l’administrateur depuis l’installation est conservée. Simulation et idempotence
respectées. Sans autorisation, température/fréquence/mémoire accessibles restent disponibles ; aucune charge n'est inventée.

### Windows 11

`windows11` dans `hosts/<machine>.json` (`uri`, `domain`) active une entrée native commune au menu et au lanceur.
`scripts/windows11-launch.sh URI DOMAINE` utilise `virsh` (libvirt), `virt-manager` (sa console), `flock` (util-linux) et
`notify-send` (libnotify). La console seule se ferme ; la VM continue. Sur le laptop, les règles machine Sway et Hyprland
reconnaissent la console par son titre (`win11 on QEMU/KVM`) et la placent sur l’espace du profil (6 en travail, 5 en jeux),
en mosaïque sans changer l’espace courant ; les autres fenêtres de virt-manager restent flottantes. Logo : `assets/windows11-source.md`.

### Provisioning ZeroTier et clients de partage

`scripts/system-setup.sh samba` configure `[homes]` et les usershares Nemo, valide avec `testparm`
et utilise `pdbedit` pour signaler un compte manquant (outils du paquet `samba`). Interfaces dynamiques
natives de Samba sous Linux : loopback, `virbr*`, `zt*` (changements d'adresse sur interface connue),
plus celles de `dotfiles/samba/hosts/<machine>.conf` (`/etc/samba/smb.host.conf`).
Drop-in systemd : ordre et propagation des arrêts/redémarrages de ZeroTier ; attente bornée via
`samba-wait-zerotier.sh` (`bash`, `ip` d'`iproute2`, `awk` de `gawk`, `sleep` de `coreutils`).
UFW, optionnel et jamais installé ici,
reçoit seulement une règle TCP 445 sur `zt+` s'il est actif ; elle est suivie par le registre système.
Le compte Samba se crée dans un terminal ; aucun mot de passe n'est stocké dans le dépôt.
`python3 scripts/test-samba.py` teste la configuration et le provisioning isolés sans privilèges.
`pkexec unshare --net python3 scripts/test-samba-network.py` teste le vrai Samba dans un espace
réseau jetable (`unshare` de `util-linux`, `ip` et `smbd`) : attente d'une interface retardée,
accès libvirt, retour d'adresse ZeroTier et refus d'une interface physique. Refuse le réseau réel.

`zerotier-one`, `smbclient`, `openssh`, `iperf3` sont déclarés dans `apps.txt` pour les deux profils.
`gvfs` et `gvfs-smb`, déjà présents, fournissent les montages GIO de Nemo (SMB/SFTP).
Provisioning par `install.sh`, fichier local et autorisation : voir README, « Provisioning ZeroTier ».
`python3 scripts/test-zerotier.py` vérifie les états réseau et la conservation des adhésions sur fichiers temporaires.
Ce banc ne remplace pas la validation en VM.

### Accès SSH au desktop

`install.sh` : `ssh`, `ssh-keygen`, `ssh-copy-id` du paquet `openssh`, `python` pour ajouter l'alias
sans modifier les réglages existants. Clé privée et destination uniquement dans `~/.ssh`, conservées
au retrait. Voir README, « Accès SSH au desktop ». Aucun service ajouté.
`python3 scripts/test-ssh-desktop.py` : vrais fichiers SSH jetables, pseudo-terminal Python et
connexions distantes simulées ; aucun accès réseau réel ni privilège requis.

### GRUB Horizon (profil travail)

Intégration GRUB + UKI existant seulement : aucun paquet de chargeur installé automatiquement. Ressources et module 2.16
prêts à utiliser. Reconstruction : Python, python-pillow, librsvg, grub (grub-mkfont) ; module : chaîne GCC/Make/Autotools,
bison/flex/gettext/patch/gawk et sources GRUB/Gnulib de la version cible. Aperçus : qemu-system-x86, edk2-ovmf ; pas de libvirt.
Polices Inter et DM Sans OFL embarquées. Voir `docs/GRUB-HORIZON.md` pour commandes, compatibilité et retour arrière.

`dmidecode` (deps/apps.txt) fournit les informations DMI demandées par libvirt.
Sans lui, libvirtd signale un exécutable absent au démarrage et ne fournit pas les
informations SMBIOS de l'hôte. Le paquet est optionnel pour libvirt mais fait partie
du profil d'applications QS qui installe la virtualisation.
