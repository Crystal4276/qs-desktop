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
| Volume (icône + curseur) | natif (`Services.Pipewire`) | `pipewire`, `wireplumber` (services utilisateur actifs) | `pavucontrol` (réglages avancés du panneau audio ; `pipewire-pulse`) | Symbols Nerd Font Mono | — |
| Sortie audio suivante (ex-`audio-toggle.sh`) | natif (`Services.Pipewire`) + `notify-send` (phase 6 : notification interne) | `libnotify` | — | — | — |
| Mises à jour | `checkupdates` | `pacman-contrib`, **`fakeroot`** (`checkupdates` échoue sans lui ; non déclaré par `pacman-contrib`) | `paru` ou `yay` (clic) ; terminal | Inter, Hack Nerd Font | — |
| GPU | NVIDIA : `nvidia-smi` ; AMD / Intel : sysfs (natif) | — | `nvidia-utils` (NVIDIA uniquement : température, charge, mémoire vidéo, processus) ; module masqué sans température lisible | Inter, Hack Nerd Font | — |
| CPU | natif (`/proc/stat`) | — | — | Inter, Hack Nerd Font | — |
| Mémoire | natif (`/proc/meminfo`) | — | — | Inter, Hack Nerd Font | — |
| Panneau de statistiques (clic CPU / mémoire / GPU, remplace btop et nvtop) | natif (`/proc`, `/sys`) | `procps-ng` (`ps`), `util-linux` (`kill`), `coreutils` (`df`) ; NVIDIA : `nvidia-smi` | — | Inter, Hack Nerd Font | — |
| Horloge + fenêtre calendrier | natif (Qt) | `tzdata` (système) | — | Inter, Hack Nerd Font, Font Awesome 7 Free | — |
| Réseau (débit) | natif (`/proc/net/dev`, `/proc/net/route`) | — | — | Inter, Hack Nerd Font | — |
| Tray | natif (`Services.SystemTray` ; Quickshell fait aussi le rôle de « watcher ») | — | — | Inter (menus) | — |
| Engrenage → panneau de réglages (remplace le power menu) | natif (`Pipewire`, `UPower`, `PowerProfiles`, `IdleInhibitor`, IPC du compositeur pour HDR / VRR) | `systemd` (redémarrer, éteindre), `gammastep` (veilleuse), `util-linux` (`rfkill`, mode avion), capture et verrouiller : natifs (phase 8b, voir plus bas) | `power-profiles-daemon` (3 boutons masqués sans lui) ; `brightnessctl` (luminosité, laptop) | Inter, Symbols Nerd Font Mono | `assets/{lock,logout,restart,shutdown}.svg` |
| Bouton Arch → menu d'applications (remplace nwg-menu) | natif (`DesktopEntries`) | `xdg-user-dirs` (dossiers), `xdg-utils` (ouvrir dossiers et fichiers) ; boutons de session comme le panneau de réglages | — | Inter, Symbols Nerd Font Mono | `assets/{lock,logout,restart,shutdown}.svg`, icônes Papirus-Dark |
| Batterie (laptop) | natif (`Services.UPower`) | — | `upower` (service système) | Symbols Nerd Font Mono (icônes v3 `U+F0079`…) | — |
| Luminosité (laptop) | `/sys/class/backlight` | — | `brightnessctl` (écriture sans root) | Symbols Nerd Font Mono | — |

Rendu de tous les SVG : `qt6-svg` (installé avec `quickshell`).
Thème d'icônes des applications (tray, lanceur, menu d'applications, notifications) : `papirus-icon-theme` (`Papirus-Dark`).

### Autres composants (phases suivantes, à compléter)

| Composant | Paquets requis | Optionnel | Polices | Fichiers du dépôt |
|---|---|---|---|---|
| Notifications | — (natif) | `libnotify` (tests `notify-send`) | Inter (police homogène ; Dunst : Noto Sans Mono) | — |
| Lanceur | — (natif, `DesktopEntries`) | terminal pour les applis `Terminal=true` | Inter, Symbols Nerd Font Mono | — |
| Menu d'applications (modèle Cinnamon, remplace nwg-menu) | — (natif, `DesktopEntries`) | à préciser en phase 8 (ex. ouverture de dossiers → gestionnaire de fichiers par défaut via `xdg-open`) | à préciser | — |
| Verrouillage (design refait, phase 8b) | — (natif, `WlSessionLock` + `PamContext`, `pam` installé avec `quickshell`) | — | — | Inter |
| Fond d'écran + utilitaire (phase 8b) | — (natif) | `xdg-user-dirs` (dossier Images) | dépôt privé des fonds cloné dans `~/Pictures/Wallpapers` | Inter, Symbols Nerd Font Mono |
| Veille des écrans | natif (`IdleMonitor` + commande DPMS au compositeur) ; `systemd` (`systemd-inhibit`), `glib2` (`gdbus` : mise en veille du système) | — | — | — |
| Agent polkit | — (natif, `PolkitAgent` ; `polkit` installé avec `quickshell`) | — | à définir | — |
| Réseau (tray) | `networkmanager` (natif, `Networking` ; `nmcli` pour les détails filaires), `wl-clipboard` (copies) | `nm-connection-editor` pour l'édition des connexions ; onglets `tailscale` (actions : `tailscale set --operator=$USER`) et `zerotier-one` (jeton copié dans `~/.zeroTierOneAuthToken`), masqués si absents | icônes Papirus-Dark (`nm-*`, `network-vpn`, `zerotier-gui`, `computer`, `smartphone`) | — |
| Wi-Fi (tray) | `networkmanager` (natif ; `nmcli` pour bande, canal, débit, adresse) | — | glyphe dessiné (géométrie Papirus) | — |
| Bluetooth (tray) | `bluez` (natif, `Bluetooth`), `bluez-utils` (agent d'appairage) | — | icônes Papirus-Dark (`blueman-tray*`) | — |
| Disques amovibles (tray) | `udisks2`, `glib2` (`gdbus`), `systemd` (`busctl`), `xdg-utils` (ouvrir), `libnotify` (notifications), `util-linux` (`setpriv`) | — | icônes Papirus-Dark | — |
| NordVPN (tray) | — | `nordvpn-bin` (AUR) + service `nordvpnd` + compte connecté (sinon module masqué) ; icônes `nordvpn-tray-*` du paquet | — | historique des pays : `~/.local/state/quickshell/by-shell/desktop/vpn.json` |
| Outil de capture (phase 8b) | natif (`ScreencopyView`) ; `wl-clipboard` (presse-papiers), `xdg-user-dirs` (dossier Images) | — | Inter, Symbols Nerd Font Mono | — |
| Événements Thunderbird (backlog) | `sqlite` | — | — | — |

### Hors barre (configs compositeur, phase 10)

Thème GTK et curseur (AUR). Tout le reste (fond, veille, verrouillage, polkit, applets réseau/Bluetooth/disques, captures) est repris par Quickshell :
`swaybg`, `swayidle`, `hypridle`, `swaylock`, `polkit-gnome`, `blueman`, `udiskie`, `hyprshot`, ainsi que `waybar`, `dunst` et `rofi`, ne sont
plus utilisés depuis la bascule (phase 10, 2026-11-03 ; Dunst masqué : `systemctl --user mask dunst.service`). Leur désinstallation reste ta décision.
Les applications personnelles lancées au démarrage (Steam, Spotify, Thunderbird, NordVPN…) ne sont **pas** des dépendances du bureau.

| Script (phase 10) | Rôle | Commandes |
|---|---|---|
| `scripts/desktop.sh [restart\|stop\|log]` | lance le bureau depuis l'autostart de Sway / Hyprland, le relance s'il s'arrête | `qs`, `flock`, `setsid` (`util-linux`), `swaymsg` / `swaynag` (`sway`), `hyprctl` |
| `scripts/ipc.sh <cible> <fonction> …` | `qs ipc call` vers le bureau de la session (raccourcis) | `qs` |

### Web apps et « ne pas déranger » (2026-10-27)

Web apps du dépôt : WhatsApp, Discord, Word, Excel, PowerPoint, Notion (`dotfiles/webapps/applications/`).

| Composant | Comment | Paquets requis | Fichiers du dépôt |
|---|---|---|---|
| Sons coupés pendant « ne pas déranger » | natif (`Services.Pipewire`, `services/Audio.qml`) ; flux repérés par `application.id` (web apps) ou binaire (application Discord) | `wireplumber` | règle `dotfiles/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf` ; liste `doNotDisturb.muteApps` de `hosts/<machine>.json` |
| Web apps WhatsApp et Discord | `chromium --app` dans un profil isolé ; `PULSE_PROP_OVERRIDE=application.id=…` dans le lanceur (coupure de nuit) | `chromium` | modèles de lanceurs `dotfiles/webapps/applications/*.desktop` |
| Web apps Word, Excel, PowerPoint, Notion | `chromium --app` dans un profil isolé (pas de coupure de nuit : pas de sons de notification) | `chromium` | modèles de lanceurs `dotfiles/webapps/applications/*.desktop` |
| Liens des web apps ouverts dans le profil Chromium principal (sauf liens vers les domaines de l'app : Microsoft 365, Notion) | extension chargée par le lanceur (`--load-extension`) + hôte natif, qui fait afficher par Quickshell l'espace de travail du navigateur (`qs ipc call compositor focusNextWindowOf chromium`) | `chromium`, `python`, `quickshell` | `dotfiles/webapps/open-links/`, `dotfiles/webapps/open-link`, manifeste `dotfiles/webapps/qs_desktop.open_link.json` |

`webapp-manager` n'est **pas** une dépendance : les lanceurs de ces web apps viennent du dépôt. Ne pas les modifier avec
lui (il réécrit la ligne `Exec` et ferait sauter `PULSE_PROP_OVERRIDE` et `--load-extension`) ; modifier le modèle du dépôt.

### Outils de développement (phases 1–9)

`grim`, `imagemagick` (captures et recadrage), `jq` (tests), `libnotify` (tests de notifications), `zenity` (fenêtres de test de `scripts/test-outputs.sh`).

| Script | Rôle | Commandes |
|---|---|---|
| `scripts/dev.sh [stop\|log]` | relance le bureau et affiche les erreurs (`scripts/desktop.sh restart` depuis la phase 10) | `qs` |
| `scripts/shot.sh <nom> [sortie\|géométrie]` | capture dans `.shots/` (ignoré par git) | `grim` |
| `scripts/crop.sh <image> <géométrie> [sortie]` | recadre une capture | `magick` (`imagemagick`) |
| `scripts/test-outputs.sh [sway\|hyprland] [-v]` | teste la répartition des espaces (et `$mod+N`, `$mod+Ctrl+N`, début de session) dans une session isolée | `sway` ou `hyprland`, `jq`, `zenity`, `qs` |

## Prérequis système d'un nouveau PC (au-delà des paquets)

Ce que `install.sh` (phase 11) devra installer, activer ou vérifier — relevé sur cette machine le 2026-10-15.

| Élément | Pourquoi | Sur cette machine | Action sur un nouveau PC |
|---|---|---|---|
| Service `NetworkManager` | module réseau (`Quickshell.Networking`) | activé | `systemctl enable --now NetworkManager` (demande `sudo` : à confirmer) |
| Service `bluetooth` | module Bluetooth | activé | `systemctl enable --now bluetooth` (`sudo`) ; module masqué si absent |
| `upower`, `udisks2` | batterie, disques | activés à la demande par D-Bus | rien |
| `polkit` | agent polkit natif, montage des disques sans mot de passe | actif (statique) | rien |
| Services utilisateur `pipewire.socket`, `pipewire-pulse.socket`, `wireplumber` | audio | activés | `systemctl --user enable --now …` |
| Fichier PAM du verrouillage | `WlSessionLock` + `PamContext` vérifient le mot de passe ; aujourd'hui c'est `/etc/pam.d/swaylock` (installé par `swaylock`, qui sera retiré) | `swaylock`, `login`, `system-auth` présents | **vérifié en phase 8b** : configuration `login` de `/etc/pam.d` (présente partout, celle qu'incluait swaylock) ; un fichier propre au dépôt ne marche pas (`include` se résout dans son propre dossier). Rien n'est écrit dans `/etc` |
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
| Règle WirePlumber « ne pas déranger » | les flux coupés la nuit ne sont pas retenus par WirePlumber (sinon coupés le lendemain) | copiée dans `~/.config/wireplumber/wireplumber.conf.d/` | lien vers `dotfiles/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf`, puis `systemctl --user restart wireplumber` ; voir « Web apps » ci-dessous |
| Web apps (WhatsApp, Discord, Word, Excel, PowerPoint, Notion) | lanceurs, coupure de nuit (WhatsApp, Discord), liens vers le navigateur | créées avec `webapp-manager`, puis lanceurs modifiés à la main | générées par `install.sh` depuis `dotfiles/webapps/` : voir « Web apps » ci-dessous |
| Utilisateur dans le groupe `video` ou règles udev | `brightnessctl` sans `sudo` (laptop) | sans objet (pas de rétroéclairage) | fourni par le paquet `brightnessctl` (règles udev) ; à vérifier sur le laptop |

Commandes dont `install.sh` vérifiera la présence après installation :
`qs`, `checkupdates`, `fakeroot`, `bluetoothctl`, `udisksctl`, `gdbus`, `busctl`, `grim`, `slurp`, `wl-copy`, `pavucontrol`
(+ optionnels : `nvidia-smi`, `brightnessctl`, `paru`/`yay`, `nm-connection-editor`, `chromium` et `python3` pour les web apps).

### Web apps : ce que fait `install.sh`

Tout en une fois, idempotent : un fichier généré identique à l'existant n'est pas réécrit ; sinon, sauvegarde
`<fichier>.bak-<date>` avant de le remplacer, seulement si aucune sauvegarde n'existe encore (l'original de l'utilisateur, pas
une sortie d'`install.sh`). `--uninstall` : copies générées (lanceurs, manifestes de l'hôte) retirées, sauvegardes remises
s'il y en a. `WEBAPPS` = dossier
`dotfiles/webapps` du dépôt (chemin absolu), `PROFILES` = `~/.local/share/ice/profiles` (dossier de `webapp-manager`, gardé :
les profils et sessions déjà connectées de cette machine sont repris tels quels).

1. Paquets : `chromium`, `python` (`deps/optional.txt`), `wireplumber`, `papirus-icon-theme` (icônes `whatsapp`, `discord`,
   `notion`, `solstice-microsoft-365-{word,excel,powerpoint}`).
2. Règle WirePlumber, seulement si `doNotDisturb.muteApps` de la machine n'est pas vide (sinon elle ne sert à rien et les web
   apps perdent la mémoire de leur volume) : lien `~/.config/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf` →
   `dotfiles/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf`, puis `systemctl --user restart wireplumber` si le lien
   vient d'être créé ou changé (le redémarrage coupe le son un instant).
3. Pour chaque modèle `dotfiles/webapps/applications/<lanceur>.desktop` : remplacer `@PROFILES@` et `@WEBAPPS@`, écrire le
   résultat dans `~/.local/share/applications/<lanceur>.desktop` (copie, pas lien : les chemins y sont développés), puis
   `update-desktop-database ~/.local/share/applications` s'il existe. Chemin avec espace : argument entier entre guillemets
   dans `Exec` (`"--load-extension=…"`) ; chemin contenant `"`, `` ` ``, `$`, `\` ou `%` : refusé avec un message (deux
   niveaux d'échappement dans `Exec`, pas la peine pour un cas improbable).
4. Pour chaque profil (`Whatsapp8699`, `DiscordWeb2996`, `Word9053`, `Excel7169`, `Powerpoint0904`, `Notion5106`, lus dans
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
modèles : app_id relevé avec ces adresses). Changer l'adresse d'un modèle change son app_id ; la règle Sway `assign` de
Discord (espace 5) devra viser `chrome-discord.com__channels_@me-Default` (phase 10).

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
| noto-fonts-cjk | google-noto-sans-cjk-fonts | fonts-noto-cjk | |
| noto-fonts-emoji | google-noto-color-emoji-fonts | fonts-noto-color-emoji | |
| papirus-icon-theme | papirus-icon-theme | papirus-icon-theme | |
| pipewire / wireplumber / pipewire-pulse | idem (`pipewire-pulseaudio`) | idem | |
| pavucontrol | idem | idem | |
| chromium | chromium | chromium | web apps (optionnel) |
| python | python3 | python3 | hôte natif des web apps (optionnel) |
| upower | upower | upower | |
| networkmanager | NetworkManager | network-manager | |
| bluez / bluez-utils | bluez | bluez (contient `bluetoothctl`) | |
| udisks2 | udisks2 | udisks2 | |
| glib2 (`gdbus`) | glib2 | libglib2.0-bin | souvent déjà présent |
| systemd (`busctl`) | systemd | systemd | toujours présent |
| nm-connection-editor (optionnel) | nm-connection-editor | network-manager-gnome | |
| tailscale (optionnel) | — (dépôt de l'éditeur : pkgs.tailscale.com) | — (dépôt de l'éditeur : pkgs.tailscale.com) | absent des dépôts officiels Fedora et Debian/Ubuntu |
| iproute2 | iproute | iproute2 | toujours présent |
| zerotier-one (optionnel) | — (dépôt de l'éditeur : install.zerotier.com) | — (dépôt de l'éditeur : install.zerotier.com) | absent des dépôts officiels Fedora et Debian/Ubuntu |
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
| gammastep | gammastep | gammastep | |
| power-profiles-daemon | power-profiles-daemon (ou `tuned-ppd` sur Fedora ≥ 41, même interface D-Bus) | power-profiles-daemon | |
| xdg-user-dirs | xdg-user-dirs | xdg-user-dirs | |
| util-linux (`rfkill`, `setpriv`) | util-linux (tire util-linux-core) | rfkill, util-linux | |
