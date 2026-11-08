# Performance de Quickshell

Référence : Sway, RTX 2080, trois écrans, Quickshell 0.3.2, Qt 6.12 (mesures des 2 et 4 novembre 2026). Version détaillée
(chiffres avant / après de chaque correction) : `git log -p -- docs/PERFORMANCE.md`.

## Ordres de grandeur

| Mesure | Valeur |
|---|---|
| Mémoire résidente (RSS) | ~490–510 Mo (736 avant optimisation) |
| VRAM | ~350–390 Mio |
| CPU au repos | ~0,6 % d'un cœur (+0,5 % pour les processus enfants) |
| Ouverture du lanceur | ~131 ms (de `qs ipc call` au premier pixel, IPC et capture compris) |
| Démarrage (banc Hyprland, 3 écrans) | config chargée ~300 ms, écrans décrits ~590 ms, fonds et barres ~850 ms |

Mémoire : surtout les fonds décodés (décodés à l'échelle réelle de la sortie) et le pilote Nvidia (un contexte graphique par
fenêtre) ; les objets QML pèsent ~25 Mo. Le QML est le levier du CPU au repos (largeurs fixes mesurées une fois, `WidthTexts`),
pas de la mémoire.

## Réglages du processus (`scripts/qs-env.sh`)

| Réglage | Effet | Décision |
|---|---|---|
| `MALLOC_CONF=narenas:2` | −100 Mo RSS | gardé |
| `__EGL_VENDOR_LIBRARY_FILENAMES` (Nvidia) | −34 Mo | gardé, seulement si Nvidia est la seule carte |
| `QSG_ATLAS_WIDTH/HEIGHT=1024` | −29 Mo, −14 Mio VRAM | gardé |
| `QSG_RENDER_LOOP=basic` | −100 Mo, ~50 ms par ouverture, ~250 ms au démarrage | **écarté** (ta décision) : un dessin lent retarde le QML et les entrées, animations sur minuteur de 16 ms |
| `QSG_TRANSIENT_IMAGES`, `dirty_decay_ms`, `QSG_NO_DEPTH/STENCIL_BUFFER` | nul ou négatif | écartés |

Ces variables valent pour le seul processus Quickshell : `services/Launch.qml` les retire pour les applications lancées depuis le
bureau. **À garder identique à `qs-env.sh`.** Sans ce fichier, `qs` fonctionne, sans ces gains.

## Contraintes connues

- Quickshell détruit la fenêtre Qt masquée : chaque affichage crée un thread et un contexte graphique (~43 ms). Les surfaces
  `OutsideClick` des autres écrans sont donc créées **après** l'affichage du popup et l'obtention du clavier. Clavier `on_demand` sans
  surfaces : écarté (Sway reprend aussitôt le clavier ; le banc ne le reproduisait pas).
- Panneaux du tray créés d'avance (4 à 16 ms chacun) : gardés ; un différé coûterait ~20 ms à la première ouverture.
- Sans levier : compilation du QML à chaque lancement (le cache disque de Qt ne prend pas les chemins `qs:@/…`) ; un contexte
  OpenGL par fenêtre (40 à 75 ms de premier affichage chacune). Essayés sans gain : Vulkan, fenêtres à la demande, barres créées
  après les écrans.
- Gardés malgré leur coût : `checkupdates` au démarrage (sinon la pilule apparaîtrait en pleine session) ; lectures Tailscale et
  ZeroTier (icône du tray) ; `nvidia-smi` lancé toutes les 5 s (`-l 5` résident : −0,2 % CPU mais +30 Mo).
- Une seule construction de chaque barre au démarrage (`Bar.qml`) ; barres affichées avec les fonds (copie des fonds à la taille de
  l'écran : `ARCHITECTURE.md` § 7.11).
- Pentes mémoire (banc, rendu logiciel) : pas de conclusion sur une fuite ; le verrouillage coûte ~170 Mo en rendu logiciel, à mesurer
  sur le vrai GPU ; pente sur plusieurs heures non relevée (`BACKLOG.md`).

## Méthode

- `scripts/perf.sh snap | idle | ab` : mémoire, VRAM, CPU, réveils ; résultats dans `.shots/perf.tsv` ; `ab` relance avec des
  variables ; `PERF_NO_ENV=1` lance sans `qs-env.sh`. CPU au repos bruité : ordre de grandeur seulement.
- Profil QML : `qs -p . --debug 3768 --waitfordebug` puis `/usr/lib/qt6/bin/qmlprofiler --interactive --attach localhost --port 3768`
  (`r`, `o <fichier>`, `q` ; rien n'est écrit si on l'interrompt).
- Tas : `heaptrack -o <fichier> qs -p .` puis `heaptrack_print -f <fichier>.zst` (pas une dépendance ; son interface bloque à la fin).
- Démarrage : battement QML de 10 ms qui journalise les trous, `QT_LOGGING_RULES="qt.scenegraph.time.renderloop=true"`,
  `strace -f -e trace=execve` — sur un banc, jamais sur le dépôt (`docs/DEVELOPMENT.md`).
- `perf` refuse tout événement sur cette machine (non résolu). Frappe dans le lanceur non mesurée.


## Lancement de Chromium (2026-11-08)

Optimisation adaptée de [Omarchy #13530](https://github.com/omacom/omarchy/pull/13530) : transmettre directement la commande au
`SingletonSocket` du profil principal quand Chromium tourne déjà, plutôt que démarrer un second processus qui transmet puis sort.
Le [retrait du sondage `--help`](https://github.com/omacom/omarchy/pull/15037) n'apportait rien ici : ce sondage n'existait pas.

Mesures Chromium 156.0.8078.79, Hyprland imbriqué, RTX 2080, profil jetable, page `about:blank`, flags vidéo locaux conservés.
Délai entre lancement et événement `openwindow` (fenêtre mappée, pas premier pixel ni fin d'animation). Caches système chauds,
réseau de fond coupé et trousseau de test `basic` : ces chiffres ne prédisent pas le chargement du profil quotidien.
Chaque fenêtre est fermée et sa disparition vérifiée avant l'essai suivant. Aucun profil utilisateur lu ou copié.

| Scénario | Normal | Lanceur complet | Échantillons par méthode |
|---|---:|---:|---:|
| Nouvelle fenêtre, série 1 | 104,4 ms | 86,0 ms | 24 |
| Nouvelle fenêtre, série 2 | 116,8 ms | 105,2 ms | 24 |
| Médiane des deux séries réunies | 109,5 ms | 87,0 ms | 48 |
| Navigateur arrêté, profil réutilisé | 772,8 ms | 763,9 ms | 12 |
| Règle d’origine finale active (nouvelle série) | 104,1 ms | 74,9 ms | 24 |

Huit ouvertures d'échauffement exclues par série ; ordre ABBA entrelacé. Gain global : **22,4 ms (20,5 %)**, mais variable :
18,4 ms sur la première série, 11,7 ms sur la seconde. Adoption selon le seuil convenu de 15 ms et 10 % sur la médiane globale ;
aucune régression médiane du démarrage supérieure à 10 ms. Pas de promesse de gain à chaque ouverture.

Trace préalable : initialisation GPU ~588 ms, dont ~447 ms avant sandbox. Contre-épreuve jetable sans décodage vidéo matériel :
806 → 389 ms (trois essais par méthode). Elle indique un coût lié au décodage matériel ; ce n'est pas un réglage retenu.
**Décodage matériel conservé, aucun préchargement à la connexion.**

`scripts/chromium-launch.sh <commande Chromium> [arguments…]` sert Super+A / Super+C sous les deux compositeurs et l'entrée
Chromium du lanceur/menu Quickshell. Le chemin résolu doit désigner le lanceur système ; les alias Arch `/usr/bin` et `/usr/sbin`
sont reconnus par identité de fichier. Socket du même utilisateur, flags de processus connus seulement, ACK exact requis.
Commande d'origine exécutée en repli : instance absente, socket périmé, `socat` absent, absence d'ACK après 2 s, wrapper,
profil de données alternatif, flags inconnus, jeton d'activation ou message trop long. Arguments et répertoire courant préservés.
La surcharge desktop `browser-link.py` utilise aussi ce lanceur pour une ouverture manuelle sans argument.
Les web apps à profils séparés et les gestionnaires HTTP/HTTPS restent sur leur chemin actuel.

Vérification : `python3 scripts/test-chromium-launch.py` (nécessite Chromium et `socat`) utilise de faux sockets privés et un wrapper
factice, jamais le navigateur quotidien : octets du message, espaces/Unicode, absence d'arguments, profils, flags inconnus,
jetons d'activation, socket absent/périmé, ACK incorrect/tardif et repli avec code de sortie et répertoire conservés.
Les séries de mesure et le prototype restent dans le scratchpad de session, hors installateur et dépendances de production.

Après correction du placement par origine : nouvelle série ABBA, huit ouvertures d'échauffement, 24 par méthode, suivi GIO
et hook Lua actifs. Médianes 104,1 → 74,9 ms : **29,2 ms (28,0 %)**. Le gain satisfait à nouveau le seuil ; accélération rétablie.
Contre-épreuves sur la même version : Chromium manuel reste sur 6/7/8, liens source créés/réutilisés au centre, vrai Celluloid
placé dans le mapping natif. L'accélération ne choisit pas le workspace et ne désactive pas le décodage matériel.
