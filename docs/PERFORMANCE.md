# Performance de Quickshell

Mesures du 2026-11-02 : Sway, RTX 2080, trois écrans (4K à l'échelle 1,5 ; 3440×1440 ; 4K à l'échelle 1,5), Quickshell 0.3.2, Qt 6.12.
Instance neuve, 25 à 30 s après le lancement, relevé repos sur 30 à 60 s (`scripts/perf.sh`, résultats bruts dans `.shots/perf.tsv`).

## Résultat

| Mesure | Avant | Après | Écart |
|---|---|---|---|
| Mémoire résidente (RSS) | 736 Mo | ~510 Mo | −31 % |
| Mémoire proportionnelle (PSS) | 564 Mo | ~350 Mo | −38 % |
| Pic au démarrage | ~796 Mo | ~550 Mo | −31 % |
| VRAM | 452 Mio | ~388 Mio | −14 % |
| CPU au repos, Quickshell | 1,4 à 2,1 % d'un cœur | 0,6 % | environ ÷ 3 |
| CPU au repos, processus enfants | 0,6 à 1,9 % | 0,5 % | |
| Temps QML au repos (sur ~53 s) | 556 ms | 138 ms (avant retrait du titre) | −75 % |
| Temps QML, 15 premières secondes | 776 ms | 548 ms | −29 % |
| Ouverture du lanceur | 239 ms | 125 ms | −48 % |

Ouverture : de `qs ipc call` au premier pixel changé à l'écran, appel IPC (26 ms) et capture `grim` (25 ms) compris ; médiane sur 25 ouvertures.

Le CPU au repos est bruité (l'usage de la machine compte) : à lire comme un ordre de grandeur.

## Où partait la mémoire

`heaptrack` au démarrage, pic du tas 288 Mo, sur 736 Mo de RSS :

- **139 Mo : images de fond décodées.** Écrans 4K décodés en 5120×2880 (59 Mo chacun), car `Screen.devicePixelRatio` vaut 2 à l'échelle 1,5.
- **124 Mo : pilote Nvidia** (textures, 6 contextes graphiques).
- **~25 Mo : tout le reste**, objets QML compris. Le tas JavaScript en ajoute 16.
- Le reste du RSS : réserve de l'allocateur (jemalloc, ~100 Mo), bibliothèques, mémoire mappée du pilote.

Le QML n'est donc pas le levier de la mémoire ; il l'est pour le CPU au repos.

## Réglages du processus (`scripts/qs-env.sh`)

Testés un par un, contre 736 Mo :

| Réglage | RSS | VRAM | Décision |
|---|---|---|---|
| `MALLOC_CONF=narenas:2` | −100 Mo | = | **gardé** ; `narenas:1` n'apporte que ~5 Mo de plus |
| `QSG_RENDER_LOOP=basic` | −126 Mo seul, −100 Mo combiné | −13 Mio | **écarté, ta décision du 2026-11-02** (voir plus bas) |
| `__EGL_VENDOR_LIBRARY_FILENAMES` (Nvidia) | −34 Mo | = | **gardé**, seulement si le pilote Nvidia est actif |
| `QSG_ATLAS_WIDTH/HEIGHT=1024` | −29 Mo | −14 Mio | **gardé** ; barres identiques à l'œil |
| `QSG_TRANSIENT_IMAGES=1` | −4 Mo | = | écarté : sans effet réel |
| `MALLOC_CONF=dirty_decay_ms…` | +3 Mo | = | écarté |
| `QSG_NO_DEPTH_BUFFER`, `QSG_NO_STENCIL_BUFFER` | +114 Mo | −92 Mio | écarté : la RAM augmente, cause non cherchée |

Ces variables valent pour le seul processus Quickshell : `Apps.launchEnvironment` les retire pour les applications lancées depuis le bureau
(lanceur, menu, `xdg-open`, terminal de mise à jour). À garder identique à `qs-env.sh`. Lancer `qs` sans sourcer ce fichier fonctionne, sans ces gains.

### Boucle de rendu `basic` : essayée, écartée

Rendu de toutes les fenêtres dans le thread principal, un seul contexte graphique : −100 Mo et ~50 ms de moins par ouverture, mais un dessin lent retarde aussi le
QML et les entrées, et les animations suivent un minuteur de 16 ms au lieu de l'écran (documentation de Qt). `test-outputs.sh` passait dans ce mode. Pour y revenir :
`QSG_RENDER_LOOP=basic` dans `qs-env.sh` et `Apps.launchEnvironment`.

### Coût d'une ouverture

Quickshell détruit la fenêtre Qt quand elle est masquée. Par fil, chaque fenêtre affichée crée donc un thread et un contexte graphique (~43 ms sur cette carte, à la suite).
Un popup en affichait trois : le sien et deux `OutsideClick` sur les autres écrans, créés avant lui (trace `qt.scenegraph.renderloop`). Ces surfaces sont
retirées depuis le 2026-11-02 : fermeture à la perte du clavier (`ARCHITECTURE.md`, « Clavier des popups »), lanceur à **125 ms** sur le bureau réel. Médianes
mesurées avant ce retrait, en les désactivant :

| | Par fil | `basic` |
|---|---|---|
| Normal | 239 ms | 95 ms |
| Sans `OutsideClick` | 128 ms | 76 ms |

Une ouverture isolée à ~3 s apparaît dans les deux modes (1 sur ~50) ; cause inconnue.

## Corrections du code

| Correction | Effet mesuré |
|---|---|
| Fonds décodés à l'échelle réelle de la sortie (`WallpaperView`, `PickerWindow`) | −50 Mo, −54 Mio de VRAM. Les vignettes du sélecteur sont recréées une fois. |
| Largeurs fixes mesurées une fois par liste (`InfoModule`, listes constantes dans `SystemStats`, `Network`, `ClockTexts`) | temps QML au repos −75 %, démarrage −29 %, largeurs identiques au pixel |
| Texte riche de référence stable (`InfoModule`) | inclus ci-dessus |
| Titre et mode retirés (`Compositor`, ta décision) ; plus de `swaymsg -t get_tree` à chaque focus ; événements de titre non analysés ; relectures d'espaces regroupées | plus aucun processus au changement de focus |
| NordVPN : 30 s au repos, 5 s panneau ouvert ou état transitoire, relecture immédiate si une interface change | enfants −5 lancements sur 6 |

Essayé puis annulé : `nvidia-smi -l 5` résident au lieu d'un lancement toutes les 5 s. Il économise ~0,2 % de CPU mais coûte 30 Mo de PSS.

## Panneaux : données pour la décision

| Élément | Création (QML, à l'ouverture de l'instance) | Note |
|---|---|---|
| Panneau VPN / réseau / Wi-Fi / disques / Bluetooth / notifications | 16 / 15 / 11 / 9 / 8 / 4 ms | créés d'avance |
| Calendrier | jusqu'à 42 ms | un par horloge |
| Tout le tray retiré, icônes comprises | −17 à −27 Mo | borne haute du gain |

Ouverture à froid contre à chaud en boucle `basic` : lanceur 110 / ~85 ms, menu 117 / ~95 ms, réglages 92 / ~90 ms : un différé coûte environ 20 ms à la première ouverture.

## Pentes mémoire (banc isolé, rendu logiciel, mode par fil)

Départ 547 Mo → 50 ouvertures du lanceur 625 → 50 des réglages 656 → 100 notifications 657 → 200 notifications 671 → capture 661 → verrouillage 830 Mo.
Pas de conclusion sur une fuite : la hausse peut venir du premier chargement de chaque élément, et aucun plateau n'a été mesuré. Le verrouillage coûte ~170 Mo sur ce
banc (flou du fond en rendu logiciel), à mesurer sur le vrai GPU. Pas encore relevé : la pente sur plusieurs heures de l'instance réelle. Un premier relevé, sans
`I3SOCK` (instance reliée au vrai Sway), a été écarté.

## Méthode

- `scripts/perf.sh snap | idle | ab` : mémoire, VRAM, CPU, réveils ; `ab` relance avec des variables. `PERF_NO_ENV=1` lance sans `qs-env.sh`.
- `qs -p . --debug 3768 --waitfordebug` puis `qmlprofiler --interactive --attach localhost --port 3768` : commandes `r`, `o <fichier>`, `q` (rien n'est écrit si on l'interrompt).
- Banc isolé : exporter `I3SOCK` comme `SWAYSOCK` (`scripts/test-outputs.sh`), sinon l'instance parle au vrai Sway.
- `heaptrack -o <fichier> qs -p .` puis `heaptrack_print -f <fichier>.zst`. **Il ouvre son interface à la fin et bloque tant qu'elle reste ouverte.**
- `perf` (7.3.1 sur noyau 7.2.14) refuse d'ouvrir tout événement sur cette machine, même `perf record -- sleep` : non résolu, profil CPU natif non obtenu.
- Non mesuré : frappe dans le lanceur (pas de moyen sûr d'injecter des touches).
