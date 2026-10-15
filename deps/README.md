# Dépendances

- `arch-pacman.txt` : dépôts officiels Arch.
- `arch-aur.txt` : AUR (via `paru` ou `yay`).
- `optional.txt` : selon le matériel ou les modules utilisés.

Première version établie en phase 0 à partir du bureau actuel ; complétée à chaque phase, dans le même commit que le composant qui l'utilise.
Le tableau de correspondance sera vérifié paquet par paquet en phase 11 (les noms ci-dessous sont des correspondances attendues, non encore testées).

| Arch | Fedora | Debian / Ubuntu | Remarque |
|---|---|---|---|
| quickshell | quickshell (COPR `errornointernet/quickshell`) | — | à compiler sur Debian/Ubuntu |
| qt6-svg | qt6-qtsvg | qt6-svg-plugins | |
| sway | sway | sway | |
| hyprland | hyprland | hyprland (Debian ≥ 13) | |
| kanshi | kanshi | kanshi | |
| swaybg / swayidle / swaylock | idem | idem | |
| hypridle | hypridle | — | à compiler |
| ttf-nerd-fonts-symbols-mono | — | — | télécharger `NerdFontsSymbolsOnly` depuis nerdfonts.com |
| inter-font | rsms-inter-fonts | fonts-inter | |
| noto-fonts | google-noto-sans-mono-fonts | fonts-noto-mono | |
| papirus-icon-theme | papirus-icon-theme | papirus-icon-theme | |
| pipewire / wireplumber / pipewire-pulse | idem (`pipewire-pulseaudio`) | idem | |
| pavucontrol / cava | idem | idem | |
| upower | upower | upower | |
| pacman-contrib | — | — | spécifique Arch : module mises à jour masqué |
| btop / nvtop | idem | idem | |
| gnome-terminal | idem | idem | |
| nwg-menu | — | — | à compiler (Go) |
| libnotify | libnotify | libnotify-bin | |
| grim / slurp / wl-clipboard / jq | idem | idem | |
| imagemagick | ImageMagick | imagemagick | |
| catppuccin-gtk-theme-mocha | — | — | depuis github.com/catppuccin/gtk |
| catppuccin-cursors-mocha | — | — | depuis github.com/catppuccin/cursors |
| nvidia-utils | xorg-x11-drv-nvidia (RPM Fusion) | nvidia-smi | optionnel |
| brightnessctl | brightnessctl | brightnessctl | optionnel |
