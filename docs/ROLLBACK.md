# Retour arrière de la bascule (phase 10, 2026-11-03) et de l'écran de connexion (phase 11)

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

Tant que greetd tourne (session ouverte par lui), `uninstall` ne fait que rebasculer les services : greetd garde sa config en mémoire
et relancerait l'écran de connexion à la déconnexion. Lancé depuis un TTY ou une session SDDM, il fait tout en une fois.

À la main, sans le script : `sudo systemctl disable greetd && sudo systemctl enable sddm && sudo reboot`.

### Secours sans quitter greetd

Si le greeter Quickshell ne s'affiche pas (écran noir, retour en boucle), passer greetd sur son greeter console, depuis un TTY :

```sh
sudo sed -i 's|^command = .*|command = "agreety --cmd \\"env WLR_RENDERER=vulkan sway --unsupported-gpu\\""|' /etc/greetd/config.toml
sudo systemctl restart greetd
```

Journal de l'écran de connexion : `journalctl -b -u greetd` (greetd, PAM) ; Quickshell du greeter :
`/run/user/$(id -u greeter)/quickshell/` pendant qu'il tourne, `/var/lib/qs-desktop/greeter/` (caches, état).
