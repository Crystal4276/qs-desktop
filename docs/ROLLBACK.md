# Retour arrière de la bascule (phase 10, 2026-11-03), de l'écran de connexion (phase 11) et de l'écran de démarrage

Ce que la bascule a changé sur cette machine, et comment revenir à l'ancien bureau (Waybar, Dunst, Rofi, swaybg, swayidle /
hypridle, polkit-gnome, nm-applet, blueman, udiskie). Aucun paquet n'a été désinstallé.

| Changement | Avant | Après |
|---|---|---|
| Config Sway | `~/.config/sway/` (dépôt `Crystal4276/sway`) | lien `~/.config/sway` → `dotfiles/sway/` ; ancienne : `~/.config/sway.bak-2026-11-03/` |
| Config Hyprland | `~/.config/hypr/` (dépôt `Crystal4276/hyprland`) | lien `~/.config/hypr` → `dotfiles/hypr/` ; ancienne : `~/.config/hypr.bak-2026-11-03/` |
| Dunst | activé par D-Bus | masqué : `~/.config/systemd/user/dunst.service` → `/dev/null` |
| Historique du lanceur | — | `~/.local/state/quickshell/by-shell/desktop/launcher.json` recréé depuis l'historique Rofi |

Les deux sauvegardes sont les dossiers d'origine, intacts (y compris leur `.git` et les changements non commités du 2026-11-03 :
web apps, `openrgb -p purple`).

Depuis le correctif OpenRGB du 2026-11-05, le bureau actuel utilise le service système ([OPENRGB.md](OPENRGB.md)). Si les anciennes
configs sont restaurées avec ce service encore actif, retirer leurs lancements OpenRGB pour garder une seule instance matérielle.

## Revenir à l'ancien bureau

Depuis un terminal, ou un TTY (`Ctrl+Alt+F3`) si la session ne démarre plus :

```sh
cd ~/.config
rm sway hypr                              # les liens seulement : dotfiles/ reste dans le dépôt
mv sway.bak-2026-11-03 sway
mv hypr.bak-2026-11-03 hypr
systemctl --user unmask dunst.service
```

Puis fermer la session et se reconnecter (ou, depuis la session en cours : `swaymsg reload` sous Sway ; sous Hyprland,
`hyprctl reload` ne relance pas l'autostart, il faut se reconnecter). Le bureau Quickshell encore lancé s'arrête avec
`~/qs-desktop/scripts/desktop.sh stop`.

## Revenir au bureau Quickshell ensuite

```sh
cd ~/.config
mv sway sway.bak-2026-11-03 && ln -s ~/qs-desktop/dotfiles/sway sway
mv hypr hypr.bak-2026-11-03 && ln -s ~/qs-desktop/dotfiles/hypr hypr
systemctl --user mask dunst.service
```

## Si le bureau Quickshell ne démarre pas

La session reste utilisable : raccourcis et fenêtres sont ceux du compositeur ; `$mod+1…9` et `$mod+Ctrl+1…9` retombent sur la
commande native. Relance : `$mod+Ctrl+W` (ou `~/qs-desktop/scripts/desktop.sh restart` dans un terminal, qui affiche les erreurs) ;
journal : `scripts/desktop.sh log` ou `$XDG_RUNTIME_DIR/qs-desktop.<session>.log` (instance précédente : `.log.1`). Après 5 arrêts en une minute, `desktop.sh` abandonne et
le compositeur affiche un message.

Écran verrouillé quand Quickshell s'arrête : la session reste verrouillée (protocole `ext-session-lock`, voulu). `desktop.sh` relance
Quickshell, et la nouvelle instance reprend d'elle-même le verrouillage (fichier `$XDG_RUNTIME_DIR/qs-desktop.<session>.locked` ;
Hyprland : `misc.allow_session_lock_restore`). Testé sur banc sous Sway et Hyprland, pas en réel. Si l'écran reste vide malgré tout
(après 5 arrêts, la relance est abandonnée) : depuis un TTY (`Ctrl+Alt+F3`), relancer le bureau, qui reverrouille, puis revenir à
la session (`Ctrl+Alt+F1` ou `F2`) et taper le mot de passe :

```sh
SWAYSOCK=$(for s in $XDG_RUNTIME_DIR/sway-ipc.*.sock; do swaymsg -s "$s" -t get_version >/dev/null 2>&1 && echo "$s" && break; done) ~/qs-desktop/scripts/desktop.sh restart   # Sway
HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances -j | jq -r '.[0].instance') ~/qs-desktop/scripts/desktop.sh restart   # Hyprland
```

En dernier recours : `loginctl terminate-user $USER` (ferme la session, applications comprises).

## Écran de connexion (phase 11)

`scripts/greeter-setup.sh install` copie le dépôt dans `/usr/local/share/qs-desktop`, crée `/var/lib/qs-desktop/` et remplace
`/etc/greetd/config.toml` et `/etc/pam.d/greetd` (originaux sauvegardés dans `/var/lib/qs-desktop/backup/`, notés dans
`/var/lib/qs-desktop/backups`),
plus `/etc/pam.d/greetd-greeter` et, sur une machine Nvidia, `/usr/local/share/wayland-sessions/sway-vulkan.desktop` (nouveaux,
retirés par `uninstall`). `enable` désactive l'ancien gestionnaire (noté dans `/var/lib/qs-desktop/previous-dm`,
ici `sddm.service`) et active greetd. **SDDM n'est pas désinstallé.**

### Revenir à SDDM

Depuis un terminal de la session, ou un TTY (`Ctrl+Alt+F2`, connexion en texte) si l'écran de connexion ne marche pas :

```sh
~/qs-desktop/scripts/greeter-setup.sh uninstall   # greetd désactivé, SDDM réactivé
sudo reboot
~/qs-desktop/scripts/greeter-setup.sh uninstall   # après le redémarrage : fichiers d'origine remis, copie retirée
```

Tant que greetd tourne (y compris depuis un TTY, écran de connexion cassé), `uninstall` ne fait que rebasculer les services : greetd
garde sa config en mémoire et relancerait l'écran de connexion à la déconnexion. Après le redémarrage (SDDM revenu), la seconde
exécution remet les fichiers d'origine et retire la copie. Le nettoyage retire uniquement l’état/cache du greeter et ses
registres une fois les sauvegardes restaurées ; `/var/lib/qs-desktop` est conservé, avec les sauvegardes réseau/OpenRGB et
les fonds exportés des utilisateurs. Une sauvegarde manquante conserve le registre nécessaire à une nouvelle tentative.

À la main, sans le script : `sudo systemctl disable greetd && sudo systemctl enable sddm && sudo reboot`.

### Secours sans quitter greetd

Si le greeter Quickshell ne s'affiche pas (écran noir, retour en boucle), passer greetd sur son greeter console, depuis un TTY :

```sh
sudo sed -i 's|^command = .*|command = "agreety --cmd \\"env WLR_RENDERER=vulkan sway --unsupported-gpu\\""|' /etc/greetd/config.toml
sudo systemctl restart greetd
```

Journal de l'écran de connexion : `journalctl -b -u greetd` (greetd, PAM) ; Quickshell du greeter :
`/run/user/$(id -u greeter)/quickshell/` pendant qu'il tourne, `/var/lib/qs-desktop/greeter/` (caches, état).

## Écran de démarrage Plymouth (profil travail, `docs/PLYMOUTH.md`)

`scripts/plymouth-setup.sh install` (étape système d'`install.sh`, profil travail seulement). Le script reconnaît deux modes de
démarrage (`plymouth-setup.sh status`, ligne « démarrage ») :

- **UKI** (archinstall « Unified kernel images », le laptop) : un preset de `/etc/mkinitcpio.d` porte `default_uki=` ; GRUB
  (`/etc/grub.d/15_uki`) ou systemd-boot lance l'image telle quelle, ligne de commande du noyau comprise (intégrée depuis
  `/etc/kernel/cmdline` et `/etc/cmdline.d/*.conf`). GRUB n'est pas touché.
- **GRUB classique** (initramfs à part, `/etc/grub.d/10_linux`) : la VM de l'étape 4.

| Changement | Mode | Défait par `uninstall` |
|---|---|---|
| Thème dans `/usr/share/plymouth/themes/qs-corelab` (version committée) | les deux | retiré |
| Thème par défaut `qs-corelab` (`/etc/plymouth/plymouthd.conf`) | les deux | fichier d'origine remis, ou thème précédent |
| Hook `plymouth` avant `block` / `encrypt` dans `HOOKS` (`/etc/mkinitcpio.conf` ou `.conf.d`) | les deux | mot retiré |
| Surcharges `/etc/systemd/system/plymouth-quit-wait.service.d/qs-corelab.conf` et `plymouth-quit.service.d/qs-corelab.conf` | les deux | retirées |
| `splash` : `/etc/cmdline.d/qs-corelab.conf`, seulement s'il manque à la ligne de commande | UKI | fichier retiré |
| **Image de secours sans Plymouth** par noyau : preset `rescue` ajouté (`-S plymouth`), `<image>~rescue.efi` | UKI | preset remis, image retirée |
| Logo Arch de systemd-stub retiré (`--splash <bmp>` de `default_options`, mis par archinstall) | UKI | option remise |
| `splash` dans `GRUB_CMDLINE_LINUX_DEFAULT` (`/etc/default/grub`) | GRUB | mot retiré |
| Initramfs (`mkinitcpio -P`), et `/boot/grub/grub.cfg` (`grub-mkconfig`) en mode GRUB | — | refaits |

Ce qui a été ajouté est noté dans `/var/lib/qs-desktop/plymouth/state` ; une copie d'origine de chaque fichier touché reste dans
`/var/lib/qs-desktop/plymouth/backup/` (retour à la main). Le paquet `plymouth` n'est pas désinstallé. Une machine passée en profil
jeux le perd au prochain `install.sh` (même retrait) ; `install.sh --uninstall` le retire aussi.

**Mises à jour d'Arch** : rien à faire. Le hook pacman de mkinitcpio (`90-mkinitcpio-install.hook`) refait toutes les images
(normales et de secours) à chaque mise à jour du noyau, de `plymouth`, de systemd, de cryptsetup ou des firmwares, avec ces
réglages ; GRUB (`15_uki`) découvre les images au démarrage. Machine GRUB + UKI : `system-setup.sh install` pose aussi
`/etc/pacman.d/hooks/90-qs-grub-uki.hook`, qui garde `/etc/grub.d/10_linux` désactivé : le paquet `grub` le réactive à chaque
mise à jour, et un `grub-mkconfig` mettrait alors en tête du menu des entrées sans initramfs, qui ne démarrent pas (vérifié en VM).

```sh
~/qs-desktop/scripts/plymouth-setup.sh status      # état de chaque élément
~/qs-desktop/scripts/plymouth-setup.sh uninstall   # tout défaire, initramfs (et GRUB) refaits
```

### La machine ne démarre plus (écran figé, pas de demande de phrase de passe)

**Mode UKI (le laptop)** : entrée de secours.

1. Au menu GRUB (`Échap` ou `Maj` au démarrage s'il est caché), sous chaque « Arch Linux » : « Arch Linux (linux-lts rescue,
   no splash) » (ou `linux`). Elle démarre la même machine sans Plymouth dans l'initramfs : la phrase de passe est demandée en
   mode texte. Plymouth peut encore s'afficher une fois le disque ouvert (thème lancé depuis la racine) ; s'il gêne,
   `Ctrl+Alt+F2` pour un TTY.
2. Une fois connecté : `~/qs-desktop/scripts/plymouth-setup.sh uninstall`, puis `sudo reboot`.
3. Sans entrée de secours (retrait déjà fait, ou image abîmée) : l'autre noyau (linux ↔ linux-lts) ; en dernier recours, clé
   USB Arch, `cryptsetup open`, `arch-chroot`, puis le retrait ci-dessous.

L'ordre du menu : GRUB range les UKI par nom décroissant, donc chaque secours juste sous son image normale ; la première entrée
(par défaut) est une image normale. Les deux images normales sont toutes deux titrées « Arch Linux » : celle du haut est
`linux-lts`, celle du bas `linux`.

**Mode GRUB classique** : ligne de commande éditée au menu.

1. Au menu GRUB, sur l'entrée Arch Linux : `e`.
2. Sur la ligne `linux …`, retirer `splash` (et `quiet` pour voir les messages). `Ctrl+X` pour démarrer : sans `splash`,
   Plymouth reste en mode texte et la phrase de passe LUKS est demandée comme avant (`plymouth.enable=0` n'y fait rien : le
   hook de l'initramfs lance `plymouthd` sans le lire).
3. Une fois connecté (TTY `Ctrl+Alt+F2` si l'écran de connexion ne vient pas) : `~/qs-desktop/scripts/plymouth-setup.sh uninstall`,
   puis `sudo reboot`.

À la main, sans le script : remettre les copies de `/var/lib/qs-desktop/plymouth/backup/` (`etc_mkinitcpio.conf.bak-*` →
`/etc/mkinitcpio.conf`, `etc_mkinitcpio.d_<noyau>.preset.bak-*` → `/etc/mkinitcpio.d/<noyau>.preset`, `etc_default_grub.bak-*` →
`/etc/default/grub`, `etc_plymouth_plymouthd.conf.bak-*` → `/etc/plymouth/plymouthd.conf`), supprimer les deux surcharges et
`/etc/cmdline.d/qs-corelab.conf` s'il existe, puis `sudo systemctl daemon-reload && sudo mkinitcpio -P` ; en mode GRUB classique
seulement, `sudo grub-mkconfig -o /boot/grub/grub.cfg` ; en mode UKI, `sudo rm /boot/EFI/Linux/*~rescue.efi`.

L'écran de connexion n'apparaît pas après l'écran de démarrage : `systemctl status plymouth-quit-wait plymouth-quit greetd` ;
`sudo plymouth quit` libère l'écran si Plymouth est resté actif.

## GRUB Horizon

`python3 scripts/grub-horizon-setup.py uninstall` restaure les réglages suivis et régénère GRUB, sans retirer d'image UKI.
Procédure depuis un support de secours et copie originale de grub.cfg : [GRUB Horizon](GRUB-HORIZON.md).
