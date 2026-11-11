# Développement

Savoir-faire pour modifier le bureau sans le casser. Version cible : **Quickshell 0.3.2**, Qt 6.

## Le bureau réel

- `~/.config/quickshell/desktop` → ce dépôt. L'instance de la session est lancée par `scripts/desktop.sh` (autostart de Sway et
  d'Hyprland, `dotfiles/`), qui la relance après un arrêt (abandon après 5 arrêts en une minute).
- **Chaque fichier QML sauvegardé dans le dépôt recharge à chaud le vrai bureau** (barres, fonds, services).
- Commandes : `scripts/dev.sh` (= `desktop.sh restart`, affiche les erreurs du démarrage), `scripts/dev.sh stop`, `scripts/dev.sh log`,
  `scripts/desktop.sh pid`. Journal : `$XDG_RUNTIME_DIR/qs-desktop.<session>.log`. Relance au clavier : `$mod+Ctrl+W`.
- Raccourcis → `scripts/ipc.sh <cible> <fonction> [args]` : `qs ipc --pid <instance de la session>`, 2 s au plus, sinon échec et
  repli natif (`$mod+N`).
- **Jamais `-c desktop`** dans un test ou un `kill` : toutes les copies du dépôt portent `//@ pragma ShellId desktop`, `qs list -c desktop`
  les voit toutes (incident du 2026-11-03 : un `kill -SEGV` de test a touché le vrai bureau). Viser par `--pid`.
- Variables du processus : `scripts/qs-env.sh` (sourcé par `desktop.sh`), mesures dans `docs/PERFORMANCE.md`.

## Méthode

1. **Préparer sur une copie du dépôt** (scratchpad), tester sur un banc, puis copier les fichiers d'un seul coup dans le dépôt.
   Jamais d'expérience écrite directement dans le dépôt (incident du 2026-11-04 : un `WeakMap` a planté le bureau 5 fois, abandon
   de la surveillance, ~5 min sans barres ni fonds).
2. Sur le banc, lire **toutes** les lignes WARN/ERROR d'un **démarrage complet**, pas seulement d'un rechargement à chaud (une boucle
   de liaison n'apparaissait qu'au démarrage complet).
3. Après la copie : instance réelle vivante (`scripts/desktop.sh pid`, `qs log --pid`), 3 barres et 3 fonds (captures `scripts/shot.sh`).
4. Si les écrans ou les espaces sont touchés : `scripts/test-outputs.sh sway` et `scripts/test-outputs.sh hyprland` (0 échec).
5. Un banc ne prouve pas le focus clavier : vérifier l'ouverture des popups sur la vraie session avant d'annoncer un succès.
6. **Revue en boucle** (quand demandée) : `/code-review high` sur les fichiers entiers, chaque constat reproduit sur banc avant
   correction (contre-épreuve sur l'ancien code), un commit par passe, arrêt quand une passe ne trouve plus que du négligeable.
   Partir de l'usage réel (applications, réglages, chemins vraiment utilisés) ; ignorer les rapports en retard sur du code remplacé.
7. **Jamais d'action `nordvpn`** (connexion, déconnexion, réglage), ni sur le vrai système ni sur banc : faux `nordvpn` qui transmet
   les lectures et simule les actions. Consigne à transmettre à tout sous-agent, avec celles des bancs.
8. Ne pas laisser traîner d'instance de test : l'arrêter avec tout son groupe de processus (bus privés, `gdbus monitor`).

## Bancs d'essai

Construits dans le scratchpad de session (perdus au redémarrage). Reprendre le bloc d'environnement de `scripts/test-outputs.sh`.

**Sway isolé (headless)** — lançable depuis n'importe quelle session :
- `WLR_BACKENDS=headless WLR_RENDERER=pixman sway`, écrans virtuels `swaymsg create_output` puis `output HEADLESS-N pos … res …`.
- Exporter **`SWAYSOCK` et `I3SOCK`** (le même socket) et retirer `HYPRLAND_INSTANCE_SIGNATURE` : `Quickshell.I3` lit `I3SOCK` d'abord ;
  sans lui, l'instance du banc parle au vrai Sway sans que `swaymsg` le montre. Contrôle : `qs ipc --pid $pid call outputs blocks`
  doit lister des `HEADLESS-*`.
- Instance : `QS_TEST=1 XDG_STATE_HOME=… XDG_CACHE_HOME=… GIO_USE_VFS=local GVFS_DISABLE_FUSE=1 dbus-run-session -- qs -p <copie>`.
  `QS_TEST` coupe montage automatique, reconnexion Bluetooth et agent polkit ; état et cache à part (sinon partagés avec le vrai
  bureau par le `ShellId`) ; le PID à viser est celui de `qs`, enfant de `dbus-run-session`. Le bus système reste le vrai.
- La veille de l'instance de test éteint les écrans virtuels et `grim` bloque : `swaymsg output '*' power on` ou inhibition.
  Idem sur les vrais écrans en veille : lire `power` dans `swaymsg -t get_outputs` avant `grim`.

**Hyprland imbriqué** — dans la session Hyprland (sous Nvidia, le mode headless n'alloue aucune image ; imbriqué dans Sway : refusé,
`xdg_wm_base` v5) : une fenêtre s'ouvre le temps du test. Régler le banc comme la vraie config, en particulier `cursor.no_warps` ;
déplacer le pointeur comme un vrai geste (sinon `follow_mouse` rend le focus au dernier écran visé : échecs aléatoires).

**Écran de connexion** — sur le Sway headless, `qs -p <copie>/greeter.qml` avec `GREETD_SOCK` (faux greetd) et `QS_GREETER_DIR`
(dossier d'état et fonds exportés, au lieu de `/var/lib/qs-desktop`) ; le bureau du banc exporte ses fonds sous `QS_GREETER_DIR` aussi.
`fakegreet` n'est pas dans le paquet Arch : faux greetd en Python (protocole de `greetd-ipc(7)` : longueur u32 native + JSON ;
`create_session` → `auth_message` secret, réponse « good » → `success`, sinon `auth_error` ; `start_session` journalisé, rien n'est
lancé). Chaîne complète : `scripts/greeter.sh` avec `WLR_BACKENDS=headless WLR_RENDERER=pixman` et
`__EGL_VENDOR_LIBRARY_FILENAMES=…/50_mesa.json` (sinon `qs-env.sh` impose l'EGL Nvidia, sans contexte sur un Sway logiciel). **Toujours
neutraliser `systemctl` de `services/Session.qml` dans la copie** (boutons éteindre / redémarrer / veille de l'écran de connexion et du
verrouillage).

**Entrées et applications factices** (outils hors dépôt, à recréer) :
- clics et frappe : client Wayland `zwlr_virtual_pointer_v1` + `zwp_virtual_keyboard_v1` (pywayland ; liaisons générées par
  `python -m pywayland.scanner` depuis les XML de wlr-protocols, clavier `xkbcli compile-keymap`) ; `swaymsg seat - cursor press`
  n'atteint pas les surfaces Qt. Avec plusieurs écrans, les coordonnées absolues portent sur toute la disposition ; sans périphérique
  de pointage, Sway n'envoie aucun événement de pointeur ; garder le client vivant (sinon le survol tombe) ;
- tray : StatusNotifierItem en Python + `Dbusmenu` ;
- audio : sortie `module-null-sink` ; verrouillage : PAM factice (`pam_exec`, `pam_echo`) ;
- web apps : profil Chromium jetable, page pilotée par DevTools, sites simulés (`--host-resolver-rules`). Ne jamais lancer
  `swaymsg exec chromium` depuis un banc : le `PATH` n'est pas transmis, c'est le vrai Chromium qui s'ouvre.
- mémoire : `MALLOC_CONF=junk:free` révèle les accès à de la mémoire libérée.

## Scripts (`scripts/`)

| Script | Rôle |
|---|---|
| `desktop.sh` | lance et surveille le bureau de la session ; `restart`, `stop`, `log`, `pid` |
| `dev.sh` | raccourci de `desktop.sh restart` / `stop` / `log` |
| `ipc.sh` | `qs ipc call` des raccourcis vers l'instance de la session (par PID) |
| `qs-env.sh` | variables du processus Quickshell (allocateur, atlas…) |
| `test-outputs.sh [sway\|hyprland]` | répartition dynamique des espaces sur banc isolé, ~45 contrôles |
| `shot.sh <nom> [sortie\|géométrie]` | capture `grim` dans `.shots/` |
| `crop.sh <image> <géométrie>` | recadrage ImageMagick |
| `perf.sh snap\|idle\|ab` | mesures mémoire / CPU (`docs/PERFORMANCE.md`) |

## Tests ciblés de robustesse

- `python3 scripts/test-wallpapers.py` : service et sélecteur réels sur Sway isolé ; regroupement Core Lab, résolution physique,
  échelle fractionnaire, replis, choix par écran, persistance et changement de profil, dossier ou variante absents.
  `--compositor hyprland` utilise un Hyprland imbriqué et un écran headless 1920×1200 ; aucun autostart réel.
  Les deux bancs vérifient aussi les scans inchangés sans empreinte supplémentaire ni remplacement du modèle,
  les fichiers ajoutés / modifiés / supprimés, les écritures de vignettes en cours et le changement de dossier.
  `--scale 1.25|1.5|2` garde un écran logique 1920×1200 ; contrôle des dimensions PNG, callbacks périmés, fermeture
  pendant une capture et régénération d’un cache corrompu. Les bascules chaudes conservent les cellules existantes.

- `python3 scripts/test-bar.py` : barre réelle sur Sway headless isolé, services média/audio/batterie factices ;
  1280–3440 px, ellipse artiste/titre, mises à jour, tray, replis et restauration, curseur conservé, absence de matériel.
- `python3 scripts/test-battery.py` : service Battery réel, source de données simulée et `notify-send` factice ;
  couleurs, seuils 30 % / 15 %, urgence, absence de doublons et réarmement en charge. Aucune décharge ni notification réelle.

- `python scripts/test-reflector.py` : amorçage avant les paquets et gestion des miroirs avec sudo/pacman/systemctl factices ;
  simulation, options, échecs, reprise, idempotence, sauvegardes et restauration de l'état du timer. Aucun réseau ni sudo réel.
- `python scripts/test-greeter-cleanup.py` : retrait du greeter sur fichiers temporaires et commandes sudo/systemctl factices ;
  sauvegardes réseau/OpenRGB, fonds utilisateur, service actif, sauvegarde manquante et répétition.
- `python scripts/test-sleep.py` : vrai service Idle sur plateforme Qt offscreen, bus privé, services QML et commandes logind factices ;
  confirmation tardive du verrouillage, libération volontaire, réveil et relance des processus. Aucune suspension ni authentification.

- `python scripts/test-idle-lock.py` : IdleMonitor, verrou Wayland et DPMS réels sur Sway headless ; politiques laptop/desktop,
  confirmation tardive, annulation, refus, inhibitions Wayland/D-Bus et délai désactivé. Aucun verrouillage de la vraie session.

- `python3 scripts/test-lid.py` : vrai service Lid, bus privé et source capot / sorties / veille / suspension factices ;
  fermeture, externes multiples et désactivés, dalle désactivée capot ouvert, réouverture, retrait du dernier, délai après
  réveil et nouvelle demande, erreurs, restauration après perte d’état, aucune lecture capot ouvert.
- `python3 scripts/test-lid-bridge.py` : vrais proxies et échange de FD sur bus privé avec faux UPower / logind ;
  refus de logind (une seule relance), libération à l'arrêt, machine sans capot (arrêt, code 0). Aucun accès matériel,
  aucune inhibition de la machine réelle.

## VM d'installation (`install.sh` sur une machine neuve)

Image officielle Arch « basic » (`geo.mirror.pkgbuild.com/images/latest/`, empreinte `.SHA256` vérifiée ; compte `arch` / `arch`,
sshd actif, sudo sans mot de passe) gardée dans `~/.cache/qs-desktop-vm/` ; chaque essai sur un disque overlay jetable, QEMU lancé
en utilisateur (libvirt non touché) :

```sh
D=~/.cache/qs-desktop-vm; qemu-img create -f qcow2 -b $D/Arch-Linux-x86_64-basic-<date>.qcow2 -F qcow2 $D/test.qcow2
qemu-system-x86_64 -enable-kvm -cpu host -m 8192 -smp 6 -drive file=$D/test.qcow2,if=virtio \
  -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-vga,xres=1920,yres=1080 \
  -display none -vnc 127.0.0.1:15 -qmp unix:<dossier>/qmp.sock,server,nowait -daemonize
```

- SSH sans `sshpass` : `SSH_ASKPASS` (script qui affiche `arch`) + `SSH_ASKPASS_REQUIRE=force`, `setsid -w ssh -p 2222 arch@127.0.0.1`.
- Dépôt : `git bundle create … master` copié dans la VM puis cloné (version committée). Fixer un nom de machine
  (`hostnamectl set-hostname`) avant, comme archinstall : sinon NetworkManager prend celui du DHCP.
- Lancement : `./install.sh --yes --profil travail` en arrière-plan (`setsid`), code de sortie écrit dans un fichier ; ne pas
  surveiller par `pgrep -f "<motif>"` (la commande de surveillance contient le motif) ; ne jamais `pkill -f` un mot présent dans sa
  propre commande SSH.
- Fonds d'écran : `QS_WALLPAPERS_REPO=<bundle du dépôt wallpapers>` évite tout accès GitHub depuis la VM.
- Captures et clavier : socket QMP (`screendump` en PNG, `human-monitor-command` → `sendkey a r c h ret` pour l'écran de connexion).
- Écran : `xres` / `yres` de `virtio-vga` = mode préféré, pris tel quel par Sway, Hyprland et le greeter. Rendu sans 3D (pixman).
- Mémoire : 8 Go pour la VM ; `/tmp` est en RAM (bundles volumineux ailleurs) ; une seconde VM ouverte peut épuiser la mémoire.
- Critères : premier passage code 0 ; second passage **0 ligne `+ `** ; redémarrage → greetd → session Sway ; `--uninstall`.

## VM chiffrée (Plymouth, `docs/PLYMOUTH.md`)

Comme le laptop : ISO officielle (`~/.cache/qs-desktop-vm/archlinux-x86_64.iso`, SHA-256 vérifiée), UEFI (OVMF), archinstall
sans intervention (`--config` / `--creds` / `--silent`), **GRUB**, racine **LUKS** sans clé matérielle → hooks `udev … encrypt`
et `cryptdevice=UUID=…:root` (choix d'archinstall 4.5). Comptes de test : `arch` / `arch`, phrase LUKS `corelab`.

- Outils dans `~/.cache/qs-desktop-vm/plymouth/` : `vm.sh start|shot|type|keys|ssh|wait-ssh|stop` (SSH par clé sur le port 2223,
  VNC :16, QMP), `config.json` / `creds.json` d'archinstall, `cidata.iso` (cloud-init de l'ISO live : clé SSH de root).
- Couches en lecture seule : `plymouth-luks-base.qcow2` (Arch minimal chiffré) → `plymouth-luks-desktop.qcow2` (`install.sh --yes
  --profil travail` passé) → essais sur `plymouth-trial.qcow2` (jetable, avec sa copie `*-vars.fd` d'OVMF).
- Démarrage : `vm.sh start <disque> <vars> [W H]`, puis `vm.sh type corelab` à la demande de phrase de passe, `vm.sh wait-ssh`.
- Arch minimal sans `python3` : `install.sh` s'arrête sans message (code 127) ; python installé à la main dans la VM.
- **Banc Plymouth** : `bench.sh push <dossier du thème>` (copie dans `/usr/share/plymouth/themes/qs-corelab`, sans initramfs),
  `bench.sh show` (greetd arrêté, `plymouthd --kernel-command-line="quiet splash plymouth.debug=file:/tmp/ply.log"` : sans
  `splash`, aucun écran graphique), `bench.sh measure <statut> <s>` (`plymouth update --status=…`, CPU et mémoire de `plymouthd`),
  `bench.sh quit`. Hors démarrage, le texte passe par `label-pango` (fontconfig) ; dans l'initramfs, par `label-freetype`.
- `preview.sh <dossier> [W H]` : tous les états hors démarrage (demande simulée par `plymouth ask-for-password --command=
  /tmp/check-pw.sh`, phrase `corelab`, ~1,2 s de vérification ; touches par QMP), puis rotation et sortie.
- Deux écrans : seconde carte `-device virtio-gpu-pci,xres=…,yres=…,id=gpu1`, capture QMP `screendump` avec `"device":"gpu1"`.
- Installation réelle (étape 4) : overlay `plymouth-step4.qcow2` sur `plymouth-luks-desktop.qcow2`, dépôt par `git bundle`,
  `./install.sh --yes --profil travail` (puis `--profil jeux --no-packages`, `--uninstall`) ; enregistrement du démarrage complet
  (captures QMP toutes les 0,15 s) jusqu'au greeter.
- Vrai démarrage : hook `plymouth` avant `block encrypt`, `splash` dans GRUB, `mkinitcpio -P` ; pour mesurer après le
  démarrage, `plymouth-quit.service` masqué et greetd désactivé **dans l'overlay d'essai seulement** (à recréer depuis
  `plymouth-luks-desktop.qcow2` pour revenir à zéro).

## VM UKI (démarrage du laptop : GRUB + UKI, LUKS)

Construite sur le laptop (2026-11-11) pour `plymouth-setup.sh` en mode UKI, dans `~/.cache/qs-desktop-vm/uki/` (hors dépôt).
- `install-vm.sh`, lancé par SSH dans la session live de l'ISO (clé de root par `cidata.iso`, cloud-init) : GPT, ESP en `/boot`
  (`dmask=0077` comme archinstall), racine LUKS (phrase `corelab`, argon2id 1 s), `pacstrap` (`linux`, `linux-lts`, `grub`,
  `plymouth`, `binutils` pour l'assemblage des UKI…), puis **les fichiers du laptop** (`files/` : presets `default_uki`,
  `HOOKS`, `/etc/default/grub` d'origine, `15_uki`) ; `10_linux` en 644, `grub-install --removable`, compte `arch` (sudo sans
  mot de passe), thème `spinner` comme avant le 2026-11-11.
- Couches en lecture seule : `base.qcow2` (installation) → `laptop-state.qcow2` (ancienne version de `plymouth-setup.sh`
  appliquée, comme le laptop ce jour-là) → essais sur un overlay jetable.
- `vm.sh start <disque> [iso]` (VNC 127.0.0.1:17, SSH 127.0.0.1:2224, QMP), `shot`, `type corelab`, `key down|ret…`, `ssh`,
  `wait-ssh`, `stop`. Le menu GRUB reste 5 s : capturer dès que la ligne du haut s'allume.
- **Piège** : QEMU sans `-serial none` → systemd-stub ajoute `console=uart,io,0x3f8` à la ligne de commande d'une UKI, et
  Plymouth passe en mode texte (le laptop n'est pas concerné). La police Inter n'est pas installée dans cette VM : texte de
  la demande en police de secours.
- Contenu d'une UKI : `objcopy -O binary --only-section=.initrd|.cmdline|.osrel <image>.efi <fichier>`, puis `lsinitcpio`.

## Pièges connus

**Moteur JavaScript de Qt 6 / QML**
- `WeakMap` : plante le moteur (`QV4::Value::sameValueZero`). Cache à clé texte à la place.
- `flatMap`, `Object.fromEntries` : absents.
- `grabToImage` multiplie sa taille cible par l'échelle de l'écran (450 px → 675 en scale 1.5) : diviser.
- Bogue de Qt 6.12 au coin des menus (raison parmi d'autres de l'abandon du menu copié de GTK).

**Plymouth 26 (plugin `script`)**
- Pas de littéraux hexadécimaux (`0x11`) : l'analyse du script se bloque sans message, écran noir. Décimal seulement, sans
  exposant (`1e-05` : erreur d'analyse) ; pas d'`include`, un seul fichier de script.
- Ni rotation ni échelle de sprite : `Image.Rotate` (angle positif = sens horaire) / `Image.Scale` créent de nouvelles images ;
  `Image.Scale` échantillonne sans moyenne (réduire beaucoup = texte crénelé).
- Le coût d'une image = rectangles des sprites modifiés × calques qui s'y superposent : petits sprites, rien de plein écran ne bouge.
- Pas d'horloge : le temps compte les rafraîchissements (50/s, minuteur réarmé avant le dessin).
- Tous les écrans sont centrés sur une seule toile (largeur et hauteur max) : chaque sprite apparaît sur chaque écran.
- Sans aucun sprite (fond seul), le plugin ne prend pas l'écran : la console reste affichée.
- `Image.Text(…, "Inter 16px")` : taille en pixels entiers (`label-freetype` dans l'initramfs, Pango hors démarrage).
- `plymouth quit --retain-splash` seul : écran noir (l'image disparaît avec `plymouthd`) ; `plymouth deactivate` la garde.
- Écrire dans une variable globale depuis une fonction : `global.x = …` (sinon variable locale créée).

**Quickshell 0.3.2**
- `FileView` dont on change `path` rend encore les données de l'ancien fichier : un `FileView` par fichier. `setData` crée les dossiers.
- `I3.focusedMonitor` n'est pas remis à zéro quand l'écran focalisé disparaît avec un espace qui a des fenêtres : pointeur pendant,
  plantage aléatoire (`lookupSingletonProperty`). Ne pas le relire pendant un changement d'écrans (`Compositor.focusedOutput`).
- L'écran affiché par un espace n'est pas mis à jour quand l'espace change d'écran : relire les sorties après chaque déplacement.
- Aucun jeton d'activation transmis : une fenêtre activée n'est que marquée urgente (d'où `Compositor.focusNextActivation()`).
- `onNotificationChanged` est émis aussi à la création ; au rechargement, les notifications affichées sont réémises *après* la
  restauration de l'historique.
- `qs kill` moins d'une seconde après un rechargement à chaud peut planter (deux générations du moteur) : rapport dans
  `~/.cache/quickshell/crashes/`, sans gravité.
- Le cache disque QML de Qt ne prend pas les chemins `qs:@/` : tout est recompilé à chaque lancement.
- `Hyprland.usingLua` faux : le backend Hyprland n'envoie aucune action (seule la config Lua est prise en charge).
- `Greetd` : après un refus (`auth_error`), Quickshell annule lui-même la session puis journalise « Received unexpected greetd response
  success » (réponse de greetd à cette annulation) : sans effet. Ne pas rappeler `cancelSession()` après `authFailure`.
- `Greetd.launch(…, true)` arrête Quickshell aussitôt la session acceptée : enregistrer l'état (dernier choix) **avant**
  (`blockWrites`).

**greetd 0.10**
- La commande de `start_session` est **recollée avec des espaces** et passée à `sh -c "exec …"` (`session/worker.rs`) : pas
  d'argument à espaces ou guillemets (passer par l'environnement). Le faux greetd du banc ne l'exécute pas : vérifier `cmd` à la main.
- `source_profile` (vrai par défaut) lit `/etc/profile` et `~/.profile` avant la commande.
- Service PAM du greeter : `greetd-greeter`, sinon repli sur `greetd`.

**Qt Quick**
- Un `TapHandler` ne prend qu'une prise passive : un clic sur lui atteint aussi le `TapHandler` d'un élément **dessous** (liste des
  sessions au-dessus des boutons d'alimentation : mise en veille vue sur banc). Un élément posé par-dessus d'autres absorbe ses clics
  avec des `MouseArea` (prise exclusive), fond compris.
- `startx` recoupe aux espaces les arguments de son client (`clientargs` non cité).

**Hyprland 0.57 (config Lua)**
- `hyprctl keyword` n'existe plus ; `hyprctl dispatch` attend une expression Lua (`hl.dsp.focus({ workspace = 4 })`).
- `hl.monitor` **fusionne** les champs avec la règle existante (`disabled = true` reste posé) ; une règle partielle visant le connecteur
  fait perdre échelle et position à un écran déclaré par `desc:` : toujours une règle complète, sur la même clé que la config.
- `hl.dsp.dpms` attend `action`, pas `mode` (avec `mode`, il bascule).
- Les changements d'écran sont appliqués après la réponse de `hyprctl` : attendre l'état réel.
- Au rallumage d'un écran, les espaces reviennent avant la relecture des moniteurs : se fier à `monitoradded` / `monitorremoved`.
- Afficher un espace ne focalise pas sa fenêtre.

**Sway**
- `swaymsg` et `Quickshell.I3` lisent `I3SOCK` avant `SWAYSOCK` (voir Bancs).
- `GIO_USE_VFS=local` dans tout banc : sinon son `gvfsd` tente de monter à côté du vrai.
