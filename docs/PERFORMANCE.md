# Performance de Quickshell

Mesures du 2026-11-02 : Sway, RTX 2080, trois écrans (4K à l'échelle 1,5 ; 3440×1440 ; 4K à l'échelle 1,5), Quickshell 0.3.2, Qt 6.12.
Instance neuve, 25 à 30 s après le lancement, relevé repos sur 30 à 60 s (`scripts/perf.sh`, résultats bruts dans `.shots/perf.tsv`).

## Résultat

| Mesure | Avant | Après | Écart |
|---|---|---|---|
| Mémoire résidente (RSS) | 736 Mo | 412 Mo | −44 % |
| Mémoire proportionnelle (PSS) | 564 Mo | 301 Mo | −47 % |
| Pic au démarrage | ~796 Mo | 458 Mo | −42 % |
| VRAM | 452 Mio | 378 Mio | −16 % |
| Threads | 23 | 16 | |
| CPU au repos, Quickshell | 1,4 à 2,1 % d'un cœur | 0,6 % | environ ÷ 3 |
| CPU au repos, processus enfants | 0,6 à 1,9 % | 0,5 % | |
| Temps QML au repos (sur ~53 s) | 556 ms | 138 ms (avant retrait du titre) | −75 % |
| Temps QML, 15 premières secondes | 776 ms | 548 ms | −29 % |
| Ouverture lanceur / menu / réglages | ~230–250 ms | ~80–110 ms | ÷ 2,5 |

Ouverture : de `qs ipc call` au premier pixel changé à l'écran, l'appel IPC et la capture `grim` (25 ms) compris. Médiane de 95 ms, maximum
de 121 ms sur 25 ouvertures du lanceur. Une valeur isolée à 2838 ms lors de la première série, jamais reproduite, reste inexpliquée.

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
| `QSG_RENDER_LOOP=basic` | −126 Mo seul, −100 Mo combiné | −13 Mio | **gardé** : aussi le gain de latence |
| `__EGL_VENDOR_LIBRARY_FILENAMES` (Nvidia) | −34 Mo | = | **gardé**, seulement si le pilote Nvidia est actif |
| `QSG_ATLAS_WIDTH/HEIGHT=1024` | −29 Mo | −14 Mio | **gardé** ; barres identiques à l'œil |
| `QSG_TRANSIENT_IMAGES=1` | −4 Mo | = | écarté : sans effet réel |
| `MALLOC_CONF=dirty_decay_ms…` | +3 Mo | = | écarté |
| `QSG_NO_DEPTH_BUFFER`, `QSG_NO_STENCIL_BUFFER` | +114 Mo | −92 Mio | écarté : la RAM augmente, cause non cherchée |

Ces variables valent pour le seul processus Quickshell : `Apps.launchEnvironment` les retire pour les applications lancées depuis le bureau
(lanceur, menu, `xdg-open`, terminal de mise à jour). À garder identique à `qs-env.sh`. Lancer `qs` sans sourcer ce fichier fonctionne, sans ces gains.

### Boucle de rendu `basic` : le compromis

Toutes les fenêtres sont rendues dans le thread principal, avec un seul contexte graphique. Le rendu par fil recrée vraisemblablement son
contexte à chaque affichage (une ouverture à chaud y est aussi lente qu'à froid ; cause déduite, pas vérifiée dans le code de Qt). Contrepartie : un
traitement QML long retarde aussi le rendu. Le QML au repos ne prend que 0,25 % du temps et aucun bloc n'a dépassé ~40 ms hors démarrage. À surveiller à l'usage ; retrait : une ligne dans `qs-env.sh`.

Vérifié dans ce mode : `test-outputs.sh` sans échec (Sway isolé, rendu logiciel), outil de capture et verrouillage ouverts sur banc, 25 ouvertures du lanceur.

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

## Pentes mémoire (banc isolé, rendu logiciel)

Départ 343 Mo → 50 ouvertures du lanceur 433 Mo → 50 des réglages 352 Mo → 200 notifications 359 Mo → capture 384 Mo → verrouillage 531 Mo.
Pas de fuite visible sur les notifications ni sur les ouvertures répétées. Le verrouillage (flou du fond, un écran en logiciel) coûte ~150 Mo sur ce banc, à
mesurer sur le vrai GPU. Pas encore relevé : la pente sur plusieurs heures de l'instance réelle.

## Méthode

- `scripts/perf.sh snap | idle | ab` : mémoire, VRAM, CPU, réveils ; `ab` relance avec des variables. `PERF_NO_ENV=1` lance sans `qs-env.sh`.
- `qs -p . --debug 3768 --waitfordebug` puis `qmlprofiler --interactive --attach localhost --port 3768` : commandes `r`, `o <fichier>`, `q` (rien n'est écrit si on l'interrompt).
- `heaptrack -o <fichier> qs -p .` puis `heaptrack_print -f <fichier>.zst`. **Il ouvre son interface à la fin et bloque tant qu'elle reste ouverte.**
- `perf` (7.3.1 sur noyau 7.2.14) refuse d'ouvrir tout événement sur cette machine, même `perf record -- sleep` : non résolu, profil CPU natif non obtenu.
- Non mesuré : frappe dans le lanceur (pas de moyen sûr d'injecter des touches).
