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
| Bouton Arch | — | `nwg-menu` ; `nemo` (ouverture des dossiers depuis le menu) ; `gnome-terminal` (option `-term`) ; `swaylock` (bouton Lock du menu) | — | Symbols Nerd Font Mono (texte du menu) | `assets/arch_linux_icon_green.svg`, `arch_linux_icon_mantle.svg` ; `dotfiles/nwg-panel/menu-start.css` + `mocha.css` (lus par nwg-menu dans `~/.config/nwg-panel/`) ; `swaylock.conf` |
| Espaces de travail | natif (`Quickshell.I3` / `Quickshell.Hyprland`) | — | — | Symbols Nerd Font Mono | — |
| Média (mpris) | natif (`Services.Mpris`, D-Bus) | — | un lecteur MPRIS (Spotify, AUR, n'est pas une dépendance du bureau) | Inter, Symbols Nerd Font Mono | — |
| cava | programme `cava` (sortie brute) | `cava` ; `pipewire-pulse` (source audio) | — | **DejaVu Sans** (barres `▁…█`) | config cava générée par le service |
| Volume (icône + curseur) | natif (`Services.Pipewire`) | `pipewire`, `wireplumber` (services utilisateur actifs) | `pavucontrol` (clic droit) | Symbols Nerd Font Mono | — |
| Sortie audio suivante (ex-`audio-toggle.sh`) | natif (`Services.Pipewire`) + notification interne | — | — | — | — |
| Mises à jour | `checkupdates` | `pacman-contrib`, **`fakeroot`** (`checkupdates` échoue sans lui ; non déclaré par `pacman-contrib`) | `paru` ou `yay` (clic) ; terminal | Inter, Symbols Nerd Font Mono | — |
| GPU | `nvidia-smi` | — | `nvidia-utils` (sinon module masqué) ; `nvtop` (clic) | Inter, Symbols Nerd Font Mono | — |
| CPU | natif (`/proc/stat`) | — | `btop` (clic) | Inter, Symbols Nerd Font Mono | — |
| Mémoire | natif (`/proc/meminfo`) | — | `btop` (clic) | Inter, Symbols Nerd Font Mono | — |
| Horloge + fenêtre calendrier | natif (Qt) | `tzdata` (système) | — | Inter, Symbols Nerd Font Mono | — |
| Réseau (débit) | natif (`/proc/net/dev`, `/proc/net/route`) | — | — | Inter, Symbols Nerd Font Mono | — |
| Tray | natif (`Services.SystemTray` ; Quickshell fait aussi le rôle de « watcher ») | — | — | — | — |
| Bouton power → power menu | natif | `swaylock` (Lock), `systemd` (Reboot/Shutdown) | — | Symbols Nerd Font Mono | `assets/{lock,logout,restart,shutdown}.svg`, `swaylock.conf` |
| Batterie (laptop) | natif (`Services.UPower`) | — | `upower` (service système) | Symbols Nerd Font Mono | — |
| Luminosité (laptop) | `/sys/class/backlight` | — | `brightnessctl` (écriture sans root) | Symbols Nerd Font Mono | — |

Rendu de tous les SVG : `qt6-svg` (installé avec `quickshell`).
Thème d'icônes des applications (tray, lanceur, notifications) : `papirus-icon-theme` (`Papirus-Dark`).

### Autres composants (phases suivantes, à compléter)

| Composant | Paquets requis | Optionnel | Polices | Fichiers du dépôt |
|---|---|---|---|---|
| Notifications | — (natif) | `libnotify` (tests `notify-send`) | Noto Sans Mono (`noto-fonts`) | — |
| Lanceur | — (natif, `DesktopEntries`) | terminal pour les applis `Terminal=true` | Inter, Symbols Nerd Font Mono | — |
| Verrouillage | `swaylock` | — | Symbols Nerd Font Mono | `swaylock.conf` |
| Événements Thunderbird (backlog) | `sqlite` | — | — | — |

### Hors barre (configs compositeur, phase 10)

`swaybg` / `swayidle` (Sway), `hypridle` (Hyprland), captures `grim` + `slurp` + `wl-clipboard` + `jq` (Sway) / `hyprshot` (Hyprland),
agent polkit `polkit-gnome`, applets du tray (`network-manager-applet`, `blueman`, `udiskie`), thème GTK et curseur (AUR).
Les applications personnelles lancées au démarrage (Steam, Spotify, Thunderbird, NordVPN…) ne sont **pas** des dépendances du bureau.

### Outils de développement (phases 1–9)

`grim`, `imagemagick` (captures et recadrage), `jq` (tests), `libnotify` (tests de notifications).

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
| *(Symbols Nerd Font Mono)* | — | — | fournie par le dépôt (`assets/fonts/`), aucun paquet nécessaire |
| inter-font | rsms-inter-fonts | fonts-inter | |
| noto-fonts | google-noto-sans-mono-fonts | fonts-noto-mono | |
| ttf-dejavu | dejavu-sans-fonts | fonts-dejavu-core | |
| papirus-icon-theme | papirus-icon-theme | papirus-icon-theme | |
| pipewire / wireplumber / pipewire-pulse | idem (`pipewire-pulseaudio`) | idem | |
| pavucontrol / cava | idem | idem | |
| upower | upower | upower | |
| pacman-contrib + fakeroot | — | — | spécifique Arch : module mises à jour masqué |
| btop / nvtop | idem | idem | |
| gnome-terminal | idem | idem | |
| nwg-menu | — | — | à compiler (Go) |
| nemo | nemo | nemo | |
| libnotify | libnotify | libnotify-bin | |
| grim / slurp / wl-clipboard / jq | idem | idem | |
| imagemagick | ImageMagick | imagemagick | |
| catppuccin-gtk-theme-mocha | — | — | depuis github.com/catppuccin/gtk |
| catppuccin-cursors-mocha | — | — | depuis github.com/catppuccin/cursors |
| nvidia-utils | xorg-x11-drv-nvidia (RPM Fusion) | nvidia-smi | optionnel |
| brightnessctl | brightnessctl | brightnessctl | optionnel |
