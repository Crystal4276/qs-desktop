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

- `python scripts/test-greeter-cleanup.py` : retrait du greeter sur fichiers temporaires et commandes sudo/systemctl factices ;
  sauvegardes réseau/OpenRGB, fonds utilisateur, service actif, sauvegarde manquante et répétition.
- `python scripts/test-sleep.py` : vrai service Idle sur plateforme Qt offscreen, bus privé, services QML et commandes logind factices ;
  confirmation tardive du verrouillage, libération volontaire, réveil et relance des processus. Aucune suspension ni authentification.

## Diagnostic Thunderbird après reconnexion

**Instrumentation temporaire, réservée à cette investigation.** Après résolution et validation du blocage, retirer
le collecteur, son test et son branchement Hyprland (suivi : `BACKLOG.md`). Ne pas l'intégrer à l'installateur final
ni à ses vérifications de dépendances ; contrôler son retrait avant de finaliser la phase 12.

Hyprland conserve le délai de 4 s et lance Thunderbird via `scripts/thunderbird-diagnostic.py run`.
Le script ne ferme ni ne relance automatiquement une instance existante. Sway garde son démarrage actuel.
L'instrumentation automatique prend effet à la prochaine connexion Hyprland ; inutile de fermer le Thunderbird courant.

Si « already running, but is not responding » revient, **avant de tuer le processus**, exécuter :

```sh
python3 ~/.config/quickshell/desktop/scripts/thunderbird-diagnostic.py snapshot
```

La commande affiche le dossier de capture. Les traces sont sous
`${XDG_STATE_HOME:-~/.local/state}/qs-desktop/thunderbird-diagnostic/` : dossiers 700, fichiers 600.
Conservation : cinq derniers enregistrements par type (lancement / capture), plus les enregistrements encore actifs
s'ils sont plus anciens ; rotation au prochain enregistrement du même type.

- `before.json` : heure, environnement d'affichage limité à une liste autorisée, processus Thunderbird du même UID,
  PID / date de démarrage noyau, cgroups, état logind, threads / points d'attente et verrous détenus.
- `launch.json`, `output.log`, `exit.json` : PID lancé, sorties standard / erreur et code de sortie. Une interruption du
  collecteur peut laisser `exit.json` absent. Aucun argument de lancement n'est copié dans les métadonnées.
- L'appartenance à une session vient des cgroups ; `XDG_SESSION_ID` hérité est enregistré séparément et ne suffit pas à la prouver.
  Aucun contenu de mail ni réglage de compte n'est lu, aucune trace protocolaire réseau n'est activée. Les sorties émises par
  Thunderbird peuvent néanmoins contenir des informations privées : examiner les journaux avant de les partager.
- Une défaillance du diagnostic initial laisse Thunderbird démarrer normalement ; logind absent / inaccessible est indiqué.

Test : `python3 scripts/test-thunderbird-diagnostic.py` (profils et commandes factices, permissions, rotation, repli,
processus survivant simulé avec vrai verrou, collecte sans arrêt). Ce scénario simulé ne reproduit pas le bug utilisateur.
Le diagnostic initial n'a pas reproduit le blocage sur quatre essais à profil vide (deux Sway, deux Hyprland).

## Pièges connus

**Moteur JavaScript de Qt 6 / QML**
- `WeakMap` : plante le moteur (`QV4::Value::sameValueZero`). Cache à clé texte à la place.
- `flatMap`, `Object.fromEntries` : absents.
- `grabToImage` multiplie sa taille cible par l'échelle de l'écran (450 px → 675 en scale 1.5) : diviser.
- Bogue de Qt 6.12 au coin des menus (raison parmi d'autres de l'abandon du menu copié de GTK).

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
