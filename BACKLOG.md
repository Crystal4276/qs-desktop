# Backlog

Idées et défauts connus hors du programme des phases. Rien ici n'est implémenté sans accord.

## À terminer — diagnostic temporaire Thunderbird

- [ ] Capturer un vrai blocage après logout / login sous Hyprland, identifier sa cause, puis corriger et valider la résolution.
  Le problème reste ouvert : les essais sur profil vide ne l'ont pas reproduit. Procédure de capture :
  `docs/DEVELOPMENT.md`, « Diagnostic Thunderbird après reconnexion ».
- [ ] **Après résolution, retirer l'instrumentation temporaire** : `scripts/thunderbird-diagnostic.py`, son test dédié,
  le branchement dans l'autostart / les programmes Hyprland et ses mentions dans les dépendances et la documentation active.
  Conserver le correctif validé et le constat dans le journal d'avancement ; préserver les journaux privés utilisateur.
- [ ] **Avant de finaliser la phase 12**, vérifier que l'instrumentation de diagnostic n'est ni incluse, ni déployée,
  ni activée par `install.sh`. Elle sert uniquement à cette investigation et ne fait pas partie du bureau à installer.

## Fonctions

- Titre de la fenêtre active / mode Sway dans la barre (retirés de `Compositor` faute de widget : à rétablir avec lui).
- Événements Thunderbird dans le calendrier : lecture seule de `calendar-data/cache.sqlite` et `local.sqlite` (3 CalDAV, 2 Owl, 1 local) ;
  difficultés : lecture sans gêner Thunderbird (WAL : `immutable` ou copie), récurrences, fuseaux, présence des calendriers Owl dans le cache.
- Vue des fenêtres façon « Activités » : aperçus en direct (`Toplevel` + `ScreencopyView`), clic pour y aller, raccourci.
- Animations (ouverture des panneaux, menus, notifications, changement d'espace) avec `EasingCurve` et Qt Quick.
- Effet verre : panneaux, menu et lanceur semi-transparents sur le fond d'écran flouté par Quickshell (`MultiEffect`) ; les fenêtres
  derrière n'apparaîtraient pas (Sway ne floute pas). Valeurs de transparence à choisir ensemble.
- Partage d'écran : choix de l'écran par une fenêtre Quickshell au lieu de `slurp` (`chooser_cmd` de `xdg-desktop-portal-wlr`).
- Confirmation avant Reboot / Shutdown (absente, comme Rofi).
- Notifications : raccourcis clavier pour le centre et « ne pas déranger » ; historique conservé après un redémarrage de Quickshell ;
  choix parmi plusieurs liens d'une notification ; couleurs par notification (`fgcolor`, `bgcolor`).
- Fonctions des applets non reprises : nm-applet (« Enable Networking », VPN NetworkManager — `NMSettings`, Wi-Fi caché, point
  d'accès), blueman (envoi de fichiers, adaptateurs), udiskie (« Mount disc image », interrupteurs), NordVPN (réglages, compte ;
  recherche par ville, qui demanderait `nordvpn cities` pour ~150 pays).
- Informations des anciens tooltips Waybar : swap, titre complet du morceau.
- Seuil critique de température GPU (l'option de Waybar était sans effet).
- Écrans : activer le VRR dans les règles d'écran (accepté par Sway + Nvidia ; effet à juger à l'œil) ; DP-1 / DP-3 en 144 Hz ;
  réévaluer Kanshi si un même écran doit être placé différemment selon les autres (plusieurs docks).
- Disques : VeraCrypt et BitLocker (`udisksctl --key-file` ne vaut que pour LUKS : appeler `Encrypted.Unlock` sans mettre la phrase
  dans la ligne de commande) ; images en boucle d'un autre utilisateur limitées à `Loop.SetupByUID` = son uid.

## Défauts connus

- Capture : deux captures dans la même seconde portent le même nom (la seconde écrase la première) ; la découpe
  (`ShaderEffectSource`) est rendue sur chaque écran tant que l'outil est ouvert (~85 Mo de VRAM pour rien sur deux écrans sur trois :
  la créer dans `onCaptureRequested`) ; avec un curseur logiciel (écrans virtuels, VM, certains laptops), le curseur est dans l'image.
- Polkit : agent perdu si polkitd redémarre (surveiller le propriétaire de `org.freedesktop.PolicyKit1` et recréer l'agent).
- HDR sous Hyprland : la règle complète fige la position (sans `hosts/`, un écran HDR n'est plus replacé si un autre écran change,
  jusqu'au `reload` suivant) et perd les autres champs de la règle de l'écran (miroir, zone réservée) tant que le HDR est actif.
  Piste : à l'arrêt du HDR, un `reload` plutôt qu'une règle SDR complète.
- Barre des espaces : un espace déplacé à la main (`swaymsg` / `hyprctl`) sur un autre écran reste sur la barre de son bloc jusqu'au
  changement d'écrans suivant. Si un raccourci déplace un jour des espaces : le montrer sur sa nouvelle barre, après un délai.
- Web apps : un lien envoyé au navigateur est aussi demandé par la web app (un lien à usage unique peut être consommé). Parade :
  intercepter le clic dans la page (script de contenu) — plus invasif.
- Plantage `QQmlDelegateModel::_q_itemsMoved` (3 sur banc le 2026-11-02, jamais sur le vrai bureau) : déplacement de lignes d'un
  `ScriptModel` non identifié. À reprendre si un rapport apparaît dans `~/.cache/quickshell/crashes/`.
- Performance : `perf` refuse tout événement sur cette machine ; pente mémoire sur plusieurs heures et coût du verrouillage à relever
  (`docs/PERFORMANCE.md`).

## À signaler en amont (avec ton accord)

- Quickshell : `I3.focusedMonitor` pendant quand l'écran focalisé disparaît (`bFocusedMonitor` écrit sans suivre `destroyed`) ;
  file d'attente inopérante de `PolkitAgentImpl` et aucun nouvel essai d'enregistrement ; mémoire libérée réutilisée à chaque
  réponse de requête Hyprland (`QAbstractSocketPrivate::canReadNotification`, visible sous `MALLOC_CONF=junk:free`, qui devient
  inutilisable pour tester sous Hyprland).
- Hyprland 0.57 : un contrôle gamma refusé reste enregistré (`protocols/GammaControl.cpp`) et l'écran est refusé à tout client
  jusqu'au redémarrage (contourné : jamais deux gammastep à la fois).
