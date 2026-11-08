# Dépendances

- `arch-pacman.txt` : dépôts officiels Arch.
- `arch-aur.txt` : AUR (via `paru` ou `yay`).
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
| Média (mpris) | natif (`Services.Mpris`, D-Bus) | — | un lecteur MPRIS (Spotify, AUR, n'est pas une dépendance du bureau) ; choix du lecteur à la molette natif (plus de `playerctl`) | Inter, Font Awesome 7 Brands, FontAwesome 4.7 | — |
| Volume (icône + curseur) | natif (`Services.Pipewire`) | `pipewire`, `wireplumber` (services utilisateur actifs) | `pavucontrol` (réglages avancés du panneau audio ; `pipewire-pulse`) | Symbols Nerd Font Mono | — |
| Sortie audio suivante (ex-`audio-toggle.sh`) | natif (`Services.Pipewire`) + `notify-send` | `libnotify` | — | — | — |
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

### Autres composants

| Composant | Paquets requis | Optionnel | Polices | Fichiers du dépôt |
|---|---|---|---|---|
| Notifications | — (natif) | `libnotify` (tests `notify-send`) | Inter | — |
| Lanceur | — (natif, `DesktopEntries`) | terminal pour les applis `Terminal=true` | Inter, Symbols Nerd Font Mono | — |
| Menu d'applications (modèle Cinnamon, remplace nwg-menu) | — (natif, `DesktopEntries`) ; `xdg-user-dirs` (dossiers), `xdg-utils` (ouvrir dossiers et fichiers) | — | Inter, Symbols Nerd Font Mono | icônes de session `assets/*.svg` |
| Verrouillage | — (natif, `WlSessionLock` + `PamContext`, `pam` installé avec `quickshell`) ; `systemd` (éteindre, redémarrer, veille) | — | Inter | `assets/{shutdown,restart,suspend}.svg` |
| Écran de connexion (greetd, `ARCHITECTURE.md` § 9) | `greetd` (natif, `Services.Greetd`), `sway` (compositeur du greeter), `git` + `tar` (copie système par `scripts/greeter-setup.sh`), `sudo` (mise en place) | `greetd-agreety` (secours console) ; `xorg-xinit` + `xorg-server` (sessions X11, par `startx`) ; `gnome-keyring` (trousseau déverrouillé par PAM) | Inter, Symbols Nerd Font Mono | `greeter.qml`, `dotfiles/greetd/`, `scripts/greeter*.sh` |
| Fond d'écran + utilitaire | — (natif) | `xdg-user-dirs` (dossier Images) ; dépôt privé des fonds cloné dans `~/Pictures/Wallpapers` | Inter, Symbols Nerd Font Mono | — |
| Veille des écrans | natif (`IdleMonitor` + commande DPMS au compositeur) ; `python`, `python-gobject` (service D-Bus ScreenSaver) ; `systemd` (`systemd-inhibit`), `glib2` (`gdbus` : mise en veille du système) | — | — | — |
| Agent polkit | — (natif, `PolkitAgent` ; `polkit` installé avec `quickshell`) | — | Inter | — |
| Réseau (tray) | `networkmanager` (natif, `Networking` ; `nmcli` pour les détails filaires), `wl-clipboard` (copies) | `nm-connection-editor` pour l'édition des connexions ; onglets `tailscale` (actions : `tailscale set --operator=$USER`) et `zerotier-one` (jeton copié dans `~/.zeroTierOneAuthToken`), masqués si absents | icônes Papirus-Dark (`nm-*`, `network-vpn`, `zerotier-gui`, `computer`, `smartphone`) | — |
| Wi-Fi (tray) | `networkmanager` (natif ; `nmcli` pour bande, canal, débit, adresse), `xdg-utils` (portail captif dans le navigateur par défaut) | — | glyphe dessiné (géométrie Papirus) | — |
| Bluetooth (tray) | `bluez` (natif, `Bluetooth`), `bluez-utils` (agent d'appairage) | — | icônes Papirus-Dark (`blueman-tray*`) | — |
| Disques amovibles (tray) | `udisks2`, `glib2` (`gdbus`), `systemd` (`busctl`), `xdg-utils` (ouvrir), `libnotify` (notifications), `util-linux` (`setpriv`) | — | icônes Papirus-Dark | — |
| NordVPN (tray) | — | `nordvpn-bin` (AUR) + service `nordvpnd` + compte connecté (sinon module masqué) ; icônes `nordvpn-tray-*` du paquet | — | historique des pays : `~/.local/state/quickshell/by-shell/desktop/vpn.json` |
| Outil de capture | natif (`ScreencopyView`) ; `wl-clipboard` (presse-papiers), `xdg-user-dirs` (dossier Images) | — | Inter, Symbols Nerd Font Mono | — |
| Événements Thunderbird (backlog) | `sqlite` | — | — | — |

### Hors barre (configs compositeur)

Thème GTK et curseur (AUR). Tout le reste (fond, veille, verrouillage, polkit, applets réseau/Bluetooth/disques, captures) est fait par
Quickshell : `swaybg`, `swayidle`, `hypridle`, `swaylock`, `polkit-gnome`, `blueman`, `udiskie`, `hyprshot`, `waybar`, `dunst`, `rofi`
ne sont pas des dépendances (Dunst, s'il est installé, doit être masqué : `systemctl --user mask dunst.service`).
Les applications personnelles lancées au démarrage (Steam, Spotify, Thunderbird, NordVPN…) ne sont **pas** des dépendances du bureau.

| Script | Rôle | Commandes |
|---|---|---|
| `scripts/desktop.sh [restart\|stop\|log]` | lance le bureau depuis l'autostart de Sway / Hyprland, le relance s'il s'arrête | `qs`, `flock`, `setsid` (`util-linux`), `swaymsg` / `swaynag` (`sway`), `hyprctl` |
| `scripts/thunderbird-diagnostic.py run\|snapshot` | **temporaire, hors installateur final** : traces Thunderbird sous Hyprland ; à retirer après résolution (BACKLOG.md) | `python`, `loginctl` (`systemd`), `/proc` Linux ; Thunderbird reste une application personnelle |
| `scripts/ipc.sh <cible> <fonction> …` | `qs ipc call` vers le bureau de la session (raccourcis) | `qs` |
| `scripts/greeter.sh [shell]` | écran de connexion : Sway minimal puis Quickshell (lancé par greetd) | `sway`, `swaymsg`, `qs` |
| `scripts/greeter-session.sh` | session choisie : shell de connexion puis `Exec` ; X11 par `startx` | `sh`, `startx` (`xorg-xinit`, sessions X11) |
| `scripts/greeter-setup.sh [--dry-run] install\|enable\|uninstall` | mise en place système de l'écran de connexion | `sudo`, `git`, `tar`, `install` / `cmp` (`coreutils`, `diffutils`), `systemctl`, `getent`, `setfacl` (`acl`, paquet de base) |

Portails captifs : `scripts/network-setup.sh [--dry-run] install|uninstall` (`sudo`, `nmcli`, `coreutils`, `diffutils`, `flock` de `util-linux`).
Configuration et sauvegarde système, à reprendre par `install.sh` en phase 12 : [NETWORK.md](../docs/NETWORK.md).

### Web apps et « ne pas déranger »

Web apps du dépôt : WhatsApp, Discord, Word, Excel, PowerPoint, Notion (`dotfiles/webapps/applications/`).

| Composant | Comment | Paquets requis | Fichiers du dépôt |
|---|---|---|---|
| Sons coupés pendant « ne pas déranger » | natif (`Services.Pipewire`, `services/Audio.qml`) ; flux repérés par `application.id` (web apps) ou binaire (application Discord) | `wireplumber` | règle `dotfiles/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf` ; liste `doNotDisturb.muteApps` de `hosts/<machine>.json` |
| Web apps WhatsApp et Discord | `chromium --app` dans un profil isolé ; `PULSE_PROP_OVERRIDE=application.id=…` dans le lanceur (coupure de nuit) | `chromium` | modèles de lanceurs `dotfiles/webapps/applications/*.desktop` |
| Web apps Word, Excel, PowerPoint, Notion | `chromium --app` dans un profil isolé (pas de coupure de nuit : pas de sons de notification) | `chromium` | modèles de lanceurs `dotfiles/webapps/applications/*.desktop` |
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

## Prérequis système d'un nouveau PC (au-delà des paquets)

Ce que `install.sh` (phase 12) devra installer, activer ou vérifier — relevé sur cette machine.

| Élément | Pourquoi | Sur cette machine | Action sur un nouveau PC |
|---|---|---|---|
| Service `NetworkManager` | module réseau (`Quickshell.Networking`) | activé | `systemctl enable --now NetworkManager` (demande `sudo` : à confirmer) |
| Service `bluetooth` | module Bluetooth | activé | `systemctl enable --now bluetooth` (`sudo`) ; module masqué si absent |
| `upower`, `udisks2` | batterie, disques | activés à la demande par D-Bus | rien |
| `polkit` | agent polkit natif, montage des disques sans mot de passe | actif (statique) | rien |
| Services utilisateur `pipewire.socket`, `pipewire-pulse.socket`, `wireplumber` | audio | activés | `systemctl --user enable --now …` |
| Fichier PAM du verrouillage | `WlSessionLock` + `PamContext` vérifient le mot de passe | configuration `login` de `/etc/pam.d` (présente partout) | rien : un fichier propre au dépôt ne marche pas (`include` se résout dans son propre dossier) ; rien n'est écrit dans `/etc` |
| Polices d'icônes (Symbols Nerd Font Mono, Hack Nerd Font, Font Awesome 7 Free / Brands, FontAwesome 4.7) | icônes de la barre (`THEME.md` § 2) | paquets (`ttf-nerd-fonts-symbols-mono`, `ttf-hack-nerd`, `otf-font-awesome`, `awesome-terminal-fonts`) | copiées depuis `assets/fonts/` dans `~/.local/share/fonts` + `fc-cache` ; aucun paquet nécessaire |
| Images `assets/*.svg` | bouton Arch, icônes de session | dans le dépôt | rien (`THEME.md` § 12) |
| Lien `~/.config/quickshell/desktop` → dépôt | lancement par `qs -c desktop` | existe | créé par `install.sh` |
| Thème d'icônes `Papirus-Dark` | icônes d'applications | paquet | paquet + `//@ pragma IconTheme Papirus-Dark` dans `shell.qml` (indispensable : le thème `breeze` de qt6ct n'est pas installé ici, `ARCHITECTURE.md` § 8.1) |
| Curseur, thème GTK | apparence des applications | AUR | paquets AUR + `gtk-3.0/settings.ini` et `gtk-4.0/settings.ini` (ici incohérents : `prefer-dark` 1 et 0) |
| Dépôt `wallpapers` | fonds d'écran | `~/Pictures/Wallpapers` | `git clone git@github.com:Crystal4276/wallpapers.git "$(xdg-user-dir PICTURES)/Wallpapers"` (dépôt privé : clé SSH GitHub nécessaire) ; facultatif |
| Commande de session Sway sur Nvidia | `WLR_RENDERER=vulkan sway --unsupported-gpu` | fichier `/usr/share/wayland-sessions/sway-vulkan.desktop` créé à la main pour SDDM | versionné (`dotfiles/greetd/sway-vulkan.desktop`), installé dans `/usr/local/share/wayland-sessions/` par `scripts/greeter-setup.sh` si Nvidia est la seule carte graphique (laptop hybride : phase 12) ; le Sway du greeter le détecte seul (`scripts/greeter.sh`) |
| Gestionnaire de connexion | greetd + greeter Quickshell (phase 11, `ARCHITECTURE.md` § 9) | SDDM activé (`sddm.service`), PAM `/etc/pam.d/sddm` avec `pam_gnome_keyring.so` | paquets `greetd` (+ `greetd-agreety`), puis `scripts/greeter-setup.sh install` (copie dans `/usr/local/share/qs-desktop`, `/etc/greetd/config.toml`, `/etc/pam.d/greetd` avec le trousseau, `/etc/pam.d/greetd-greeter`, `/var/lib/qs-desktop/`) et `enable` (ancien gestionnaire désactivé) — `sudo`, avec ton accord |
| `QT_QPA_PLATFORMTHEME=qt6ct` | thème des applications Qt (Kvantum `KvArcDark`, icônes `breeze`) | dans `/etc/environment` | à reproduire (fichier système, `sudo`) ; Quickshell en hérite (`ARCHITECTURE.md` § 8.1) |
| Réglages dconf | apparence des applications GTK | dconf | `gsettings set org.gnome.desktop.interface …` par `install.sh` (liste ci-dessous) |
| Polices CJK | titres et notifications en japonais/chinois/coréen | polices MS copiées à la main | `noto-fonts-cjk` (repli du bureau) |
| Polices Microsoft (optionnel) | documents Word, repli CJK | `/usr/share/fonts/MS_Fonts` (363 Mo) | dépôt privé `Crystal4276/fonts-ms`, cloné à la demande dans `~/.local/share/fonts/fonts-ms` + `fc-cache -f` (clé SSH GitHub nécessaire) |
| Règle WirePlumber « ne pas déranger » | les flux coupés la nuit ne sont pas retenus par WirePlumber (sinon coupés le lendemain) | copiée dans `~/.config/wireplumber/wireplumber.conf.d/` | lien vers `dotfiles/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf`, puis `systemctl --user restart wireplumber` ; voir « Web apps » ci-dessous |
| Web apps (WhatsApp, Discord, Word, Excel, PowerPoint, Notion) | lanceurs, coupure de nuit (WhatsApp, Discord), liens vers le navigateur | créées avec `webapp-manager`, puis lanceurs modifiés à la main | générées par `install.sh` depuis `dotfiles/webapps/` : voir « Web apps » ci-dessous |
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
- `logind` par défaut (bouton power = extinction ; capot = mise en veille) ;
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
modèles : app_id relevé avec ces adresses). Changer l'adresse d'un modèle change son app_id, donc les règles d'espace des
configs compositeur (Discord : `…@me-Default` et `…@me_<salon>-Default`, espace 5).

## Correspondance avec d'autres distributions

Correspondances attendues, **non encore vérifiées** (phase 12).

| Arch | Fedora | Debian / Ubuntu | Remarque |
|---|---|---|---|
| quickshell | quickshell (COPR `errornointernet/quickshell`) | — | à compiler sur Debian/Ubuntu |
| qt6-svg | qt6-qtsvg | qt6-svg-plugins | |
| sway | sway | sway | |
| hyprland | hyprland | hyprland (Debian ≥ 13) | |
| greetd, greetd-agreety | greetd (agreety inclus) | greetd (agreety inclus) | utilisateur du greeter : `greeter` sur Arch, `_greetd` sur Debian (`default_session.user` à adapter) |
| xorg-xinit (optionnel) | xorg-x11-xinit | xinit | sessions X11 de l'écran de connexion |
| *(polices d'icônes : Symbols Nerd Font Mono, Hack Nerd Font, Font Awesome 7, FontAwesome 4.7)* | — | — | fournies par le dépôt (`assets/fonts/`), aucun paquet nécessaire |
| inter-font | rsms-inter-fonts | fonts-inter | |
| noto-fonts | google-noto-sans-mono-fonts | fonts-noto-mono | |
| noto-fonts-cjk | google-noto-sans-cjk-fonts | fonts-noto-cjk | |
| noto-fonts-emoji | google-noto-color-emoji-fonts | fonts-noto-color-emoji | |
| papirus-icon-theme | papirus-icon-theme | papirus-icon-theme | |
| pipewire / wireplumber / pipewire-pulse | idem (`pipewire-pulseaudio`) | idem | |
| pavucontrol | idem | idem | |
| chromium | chromium | chromium | web apps (optionnel) |
| python | python3 | python3 | inhibition vidéo D-Bus ; moniteur (pidfd : Python ≥ 3.9, Linux ≥ 5.3) ; hôte natif des web apps |
| python-gobject | python3-gobject | python3-gi | Gio / GLib du service d’inhibition vidéo |
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


### Contenu ouvert depuis Deluge, Thunderbird et Steam

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
