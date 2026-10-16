# Dépendances

- `arch-pacman.txt` : dépôts officiels Arch.
- `arch-aur.txt` : AUR (via `paru` ou `yay`).
- `optional.txt` : selon le matériel ou les modules utilisés.
- Fichiers fournis par le dépôt lui-même (polices, images, feuilles de style) : colonne « Fichiers du dépôt » ci-dessous.

Règle : chaque composant ajouté au dépôt met à jour **dans le même commit** la table « Par module » et les listes de paquets.
`install.sh` (phase 11) vérifiera, pour chaque ligne, que la commande, la police ou le service est réellement présent après installation.

## Par module

Établi en phase 0 pour l'implémentation **Quickshell** prévue (pas pour Waybar).
Chaque commande a été rattachée à son paquet sur cette machine avec `pacman -Qo`.

« Natif » = fait par Quickshell lui-même, sans programme externe. Le paquet `quickshell` installe déjà Qt 6, `qt6-svg`,
`qt6-wayland` et `libpipewire`. Les modules Quickshell utilisés (`I3`, `Hyprland`, `Services.Pipewire`, `.Mpris`, `.SystemTray`,
`.Notifications`, `.UPower`) sont tous inclus dans ce paquet.

### Barre

| Module | Comment il obtient ses données | Paquets requis | Optionnel (module masqué / clic inactif si absent) | Polices | Fichiers du dépôt |
|---|---|---|---|---|---|
| Barre (toutes) | layer-shell Wayland | `quickshell`, `sway` ou `hyprland` | — | — | — |
| Bouton Arch | natif (ouvre le menu d'applications maison, phase 8) | — | — | — | `assets/arch_linux_icon_green.svg`, `arch_linux_icon_mantle.svg` |
| Espaces de travail | natif (`Quickshell.I3` / `Quickshell.Hyprland`) | — | — | Symbols Nerd Font Mono | — |
| Média (mpris) | natif (`Services.Mpris`, D-Bus) | — | un lecteur MPRIS (Spotify, AUR, n'est pas une dépendance du bureau) ; choix du lecteur à la molette natif (plus de `playerctl`) | Inter, Font Awesome 7 Brands, FontAwesome 4.7 | — |
| cava | programme `cava` (sortie brute) | `cava` ; `pipewire-pulse` (source audio) | — | **DejaVu Sans** (barres `▁…█`) | `config/cava.conf` |
| Volume (icône + curseur) | natif (`Services.Pipewire`) | `pipewire`, `wireplumber` (services utilisateur actifs) | `pavucontrol` (clic droit) | Symbols Nerd Font Mono | — |
| Sortie audio suivante (ex-`audio-toggle.sh`) | natif (`Services.Pipewire`) + `notify-send` (phase 6 : notification interne) | `libnotify` | — | — | — |
| Mises à jour | `checkupdates` | `pacman-contrib`, **`fakeroot`** (`checkupdates` échoue sans lui ; non déclaré par `pacman-contrib`) | `paru` ou `yay` (clic) ; terminal | Inter, Hack Nerd Font | — |
| GPU | NVIDIA : `nvidia-smi` ; AMD / Intel : sysfs (natif) | — | `nvidia-utils` (NVIDIA uniquement) ; `nvtop` (clic, tous constructeurs) ; module masqué sans température lisible | Inter, Hack Nerd Font | — |
| CPU | natif (`/proc/stat`) | — | `btop` (clic) | Inter, Hack Nerd Font | — |
| Mémoire | natif (`/proc/meminfo`) | — | `btop` (clic) | Inter, Hack Nerd Font | — |
| Horloge + fenêtre calendrier | natif (Qt) | `tzdata` (système) | — | Inter, Hack Nerd Font, Font Awesome 7 Free | — |
| Réseau (débit) | natif (`/proc/net/dev`, `/proc/net/route`) | — | — | Inter, Hack Nerd Font | — |
| Tray | natif (`Services.SystemTray` ; Quickshell fait aussi le rôle de « watcher ») | — | — | Inter (menus) | — |
| Bouton power → power menu | natif | `systemd` (Reboot/Shutdown) ; Lock → verrouillage natif | — | Symbols Nerd Font Mono | `assets/{lock,logout,restart,shutdown}.svg` |
| Batterie (laptop) | natif (`Services.UPower`) | — | `upower` (service système) | Symbols Nerd Font Mono (icônes v3 `U+F0079`…) | — |
| Luminosité (laptop) | `/sys/class/backlight` | — | `brightnessctl` (écriture sans root) | Symbols Nerd Font Mono | — |

Rendu de tous les SVG : `qt6-svg` (installé avec `quickshell`).
Thème d'icônes des applications (tray, lanceur, notifications) : `papirus-icon-theme` (`Papirus-Dark`).

### Autres composants (phases suivantes, à compléter)

| Composant | Paquets requis | Optionnel | Polices | Fichiers du dépôt |
|---|---|---|---|---|
| Notifications | — (natif) | `libnotify` (tests `notify-send`) | Noto Sans Mono (`noto-fonts`) | — |
| Lanceur | — (natif, `DesktopEntries`) | terminal pour les applis `Terminal=true` | Inter, Symbols Nerd Font Mono | — |
| Menu d'applications (modèle Cinnamon, remplace nwg-menu) | — (natif, `DesktopEntries`) | à préciser en phase 8 (ex. ouverture de dossiers → gestionnaire de fichiers par défaut via `xdg-open`) | à préciser | — |
| Verrouillage (design refait) | — (natif, `WlSessionLock` + PAM, `pam` installé avec `quickshell`) | — | à définir | — |
| Veille des écrans | — (natif, `IdleMonitor` + commande DPMS au compositeur) | — | — | — |
| Agent polkit | — (natif, `PolkitAgent` ; `polkit` installé avec `quickshell`) | — | à définir | — |
| Fond d'écran + utilitaire | — (natif) | — | à définir | dépôt `wallpapers` cloné dans `~/Pictures/Wallpapers` |
| Réseau (tray) | `networkmanager` (natif, `Networking`) | `nm-connection-editor` pour l'édition des connexions | icônes Papirus-Dark (`nm-*`) | — |
| Bluetooth (tray) | `bluez` (natif, `Bluetooth`), `bluez-utils` (agent d'appairage) | — | icônes Papirus-Dark (`blueman-tray*`) | — |
| Disques amovibles (tray) | `udisks2`, `glib2` (`gdbus`), `systemd` (`busctl`), `xdg-utils` (ouvrir) | — | icônes Papirus-Dark | — |
| NordVPN (tray) | — | `nordvpn-bin` (AUR) + service `nordvpnd` + compte connecté (sinon module masqué) ; icônes `nordvpn-tray-*` du paquet | — | historique des pays : `~/.local/state/quickshell/by-shell/desktop/vpn-recent.json` |
| Outil de capture | `grim`, `slurp`, `wl-clipboard` (au départ) | — | à définir | — |
| Événements Thunderbird (backlog) | `sqlite` | — | — | — |

### Hors barre (configs compositeur, phase 10)

Thème GTK et curseur (AUR). Tout le reste (fond, veille, verrouillage, polkit, applets réseau/Bluetooth/disques, captures) est repris par Quickshell :
`swaybg`, `swayidle`, `hypridle`, `swaylock`, `polkit-gnome`, `blueman`, `udiskie`, `hyprshot` ne seront plus nécessaires après la bascule.
Les applications personnelles lancées au démarrage (Steam, Spotify, Thunderbird, NordVPN…) ne sont **pas** des dépendances du bureau.

### Outils de développement (phases 1–9)

`grim`, `imagemagick` (captures et recadrage), `jq` (tests), `libnotify` (tests de notifications), `zenity` (fenêtres de test de `scripts/test-outputs.sh`).

| Script | Rôle | Commandes |
|---|---|---|
| `scripts/dev.sh [stop]` | (re)lance l'instance de dev depuis le dépôt, affiche les erreurs | `qs` |
| `scripts/shot.sh <nom> [sortie\|géométrie]` | capture dans `.shots/` (ignoré par git) | `grim` |
| `scripts/crop.sh <image> <géométrie> [sortie]` | recadre une capture | `magick` (`imagemagick`) |
| `scripts/test-outputs.sh [-v]` | teste la répartition des espaces dans une session Sway isolée | `sway`, `jq`, `zenity`, `qs` |

## Prérequis système d'un nouveau PC (au-delà des paquets)

Ce que `install.sh` (phase 11) devra installer, activer ou vérifier — relevé sur cette machine le 2026-10-15.

| Élément | Pourquoi | Sur cette machine | Action sur un nouveau PC |
|---|---|---|---|
| Service `NetworkManager` | module réseau (`Quickshell.Networking`) | activé | `systemctl enable --now NetworkManager` (demande `sudo` : à confirmer) |
| Service `bluetooth` | module Bluetooth | activé | `systemctl enable --now bluetooth` (`sudo`) ; module masqué si absent |
| `upower`, `udisks2` | batterie, disques | activés à la demande par D-Bus | rien |
| `polkit` | agent polkit natif, montage des disques sans mot de passe | actif (statique) | rien |
| Services utilisateur `pipewire.socket`, `pipewire-pulse.socket`, `wireplumber` | audio, cava | activés | `systemctl --user enable --now …` |
| Fichier PAM du verrouillage | `WlSessionLock` + `PamContext` vérifient le mot de passe ; aujourd'hui c'est `/etc/pam.d/swaylock` (installé par `swaylock`, qui sera retiré) | `swaylock`, `login`, `system-auth` présents | le dépôt fournit son propre fichier (`pam/qs-lock`, `auth include login`) lu via `PamContext.configDirectory`, sans rien écrire dans `/etc` **[à vérifier en phase 8b]** |
| Polices d'icônes (Symbols Nerd Font Mono, Hack Nerd Font, Font Awesome 7 Free / Brands, FontAwesome 4.7) | icônes de la barre (`THEME.md` § 2) | paquets (`ttf-nerd-fonts-symbols-mono`, `ttf-hack-nerd`, `otf-font-awesome`, `awesome-terminal-fonts`) | copiées depuis `assets/fonts/` dans `~/.local/share/fonts` + `fc-cache` ; aucun paquet nécessaire |
| Images `assets/*.svg` | bouton Arch, power menu | dans `~/.config/sway/assets/` | versionnées dans le dépôt depuis la phase 1 (`THEME.md` § 12) |
| Lien `~/.config/quickshell/desktop` → dépôt | lancement par `qs -c desktop` | créé en phase 1 | créé par `install.sh` |
| Thème d'icônes `Papirus-Dark` | icônes d'applications | paquet | paquet + `//@ pragma IconTheme Papirus-Dark` dans `shell.qml` (indispensable : le thème `breeze` de qt6ct n'est pas installé ici, `ARCHITECTURE.md` § 11.1) |
| Curseur, thème GTK | apparence des applications et des tooltips | AUR | paquets AUR + `gtk-3.0/settings.ini` (à rapatrier en phase 10) |
| Dépôt `wallpapers` | fonds d'écran | `~/Pictures/Wallpapers` | `git clone git@github.com:Crystal4276/wallpapers.git "$(xdg-user-dir PICTURES)/Wallpapers"` (dépôt privé : clé SSH GitHub nécessaire) ; facultatif |
| Commande de session Sway sur Nvidia | `WLR_RENDERER=vulkan sway --unsupported-gpu` | fichier `sway-vulkan.desktop` créé à la main pour SDDM | SDDM abandonné : la commande sera fournie par la config du greeter Quickshell (phase 12), selon la présence d'un GPU Nvidia |
| Gestionnaire de connexion | greetd + greeter Quickshell (phase 12, `ARCHITECTURE.md` § 10.4) | SDDM activé (`sddm.service`), PAM `/etc/pam.d/sddm` avec `pam_gnome_keyring.so` | paquets `greetd` + `greetd-agreety`, `/etc/greetd/config.toml`, `/etc/pam.d/greetd` (lignes du trousseau), `systemctl disable sddm` / `enable greetd` — fichiers système, avec ton accord |
| `QT_QPA_PLATFORMTHEME=qt6ct` | thème des applications Qt (Kvantum `KvArcDark`) | dans `/etc/environment` | à reproduire (fichier système, `sudo`) ; Quickshell en hérite (`ARCHITECTURE.md` § 11.1) |
| Réglages dconf (`text-scaling-factor 1.25`, thème GTK, icônes, polices, `prefer-dark`) | apparence des applications GTK | dconf | `gsettings set …` par `install.sh` (liste : `INVENTORY.md` § 11.2) |
| Polices CJK | titres et notifications en japonais/chinois/coréen | polices MS copiées à la main | `noto-fonts-cjk` (repli du bureau) |
| Polices Microsoft (optionnel) | documents Word, repli CJK | `/usr/share/fonts/MS_Fonts` (363 Mo) | dépôt privé `Crystal4276/fonts-ms`, cloné à la demande dans `~/.local/share/fonts/fonts-ms` + `fc-cache -f` (clé SSH GitHub nécessaire) |
| Utilisateur dans le groupe `video` ou règles udev | `brightnessctl` sans `sudo` (laptop) | sans objet (pas de rétroéclairage) | fourni par le paquet `brightnessctl` (règles udev) ; à vérifier sur le laptop |

Commandes dont `install.sh` vérifiera la présence après installation :
`qs`, `cava`, `checkupdates`, `fakeroot`, `bluetoothctl`, `udisksctl`, `gdbus`, `busctl`, `grim`, `slurp`, `wl-copy`, `pavucontrol`, `btop`
(+ optionnels : `nvidia-smi`, `nvtop`, `brightnessctl`, `paru`/`yay`, `nm-connection-editor`).

## Correspondance avec d'autres distributions

Correspondances attendues, **non encore vérifiées** (phase 11).

| Arch | Fedora | Debian / Ubuntu | Remarque |
|---|---|---|---|
| quickshell | quickshell (COPR `errornointernet/quickshell`) | — | à compiler sur Debian/Ubuntu |
| qt6-svg | qt6-qtsvg | qt6-svg-plugins | |
| sway | sway | sway | |
| hyprland | hyprland | hyprland (Debian ≥ 13) | |
| swaybg / swayidle / swaylock | idem | idem | |
| hypridle | hypridle | — | à compiler |
| *(polices d'icônes : Symbols Nerd Font Mono, Hack Nerd Font, Font Awesome 7, FontAwesome 4.7)* | — | — | fournies par le dépôt (`assets/fonts/`), aucun paquet nécessaire |
| inter-font | rsms-inter-fonts | fonts-inter | |
| noto-fonts | google-noto-sans-mono-fonts | fonts-noto-mono | |
| ttf-dejavu | dejavu-sans-fonts | fonts-dejavu-core | |
| noto-fonts-cjk | google-noto-sans-cjk-fonts | fonts-noto-cjk | |
| noto-fonts-emoji | google-noto-color-emoji-fonts | fonts-noto-color-emoji | |
| papirus-icon-theme | papirus-icon-theme | papirus-icon-theme | |
| pipewire / wireplumber / pipewire-pulse | idem (`pipewire-pulseaudio`) | idem | |
| pavucontrol / cava | idem | idem | |
| upower | upower | upower | |
| networkmanager | NetworkManager | network-manager | |
| bluez / bluez-utils | bluez | bluez (contient `bluetoothctl`) | |
| udisks2 | udisks2 | udisks2 | |
| glib2 (`gdbus`) | glib2 | libglib2.0-bin | souvent déjà présent |
| systemd (`busctl`) | systemd | systemd | toujours présent |
| nm-connection-editor (optionnel) | nm-connection-editor | network-manager-gnome | |
| pacman-contrib + fakeroot | — | — | spécifique Arch : module mises à jour masqué |
| btop / nvtop | idem | idem | |
| gnome-terminal | idem | idem | |
| libnotify | libnotify | libnotify-bin | |
| grim / slurp / wl-clipboard / jq | idem | idem | |
| zenity | zenity | zenity | tests uniquement |
| imagemagick | ImageMagick | imagemagick | |
| catppuccin-gtk-theme-mocha | — | — | depuis github.com/catppuccin/gtk |
| catppuccin-cursors-mocha | — | — | depuis github.com/catppuccin/cursors |
| nvidia-utils | xorg-x11-drv-nvidia (RPM Fusion) | nvidia-smi | optionnel |
| brightnessctl | brightnessctl | brightnessctl | optionnel |
