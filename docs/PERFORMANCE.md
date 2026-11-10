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

## Collecteur GPU Intel — laptop (2026-11-09)

Solution retenue : `intel_gpu_top` 2.6-1, capacité ciblée `CAP_PERFMON`, un seul processus persistant à **5 s** partagé entre
barre et moniteur. Le flux comprend la charge matérielle par moteur, la fréquence moyenne réelle, la consommation GPU
et la mémoire déclarée par les processus. Aucun second parcours Python Intel lorsque ce flux est disponible.

Mesures du collecteur (temps CPU, un cœur, machine au repos avec le bureau actif) :

| Cadence | Durée | CPU | Moyenne |
|---|---:|---:|---:|
| 1 s | 15,34 s | 340,1 ms | 2,22 % |
| 2,6 s | 15,79 s | 191,1 ms | 1,21 % |
| **5 s** | 20,12 s | 120,3 ms | **0,60 %** |
| **5 s, intégré au bureau** | 20 s | 80 ms | **0,40 %** |

Mesure complémentaire isolant le module QML `Gpu` et son enfant natif, sur 20 s après démarrage :
**0,15 % d'un cœur pour QML + 0,40 % pour le collecteur = 0,55 % au total**. Le coût de l'ensemble du moniteur
(CPU, réseau, processus, rendu) n'est pas attribué à la collecte GPU dans ce test.

Le collecteur reste actif panneau fermé pour alimenter la barre. La première mesure, couvrant l'initialisation des compteurs,
est ignorée. Le pourcentage de la barre est celui de Render/3D, sans somme artificielle des moteurs. La fréquence `avg` est
une moyenne sur l'intervalle, intégrant les périodes de repos ; elle diffère de la fréquence instantanée sysfs.

Ancien chemin sans PMU (repli uniquement désormais) : Python 140–163 ms CPU par collecte initiale, puis 84–100 ms après
filtrage des descripteurs DRM ; mémoire espacée à ~10 s panneau ouvert et fréquence native à 1 s. Ce parcours ne tourne plus
pour Intel avec le flux matériel valide.

## Sélecteur Core Lab — cache des empreintes (2026-11-10)

Le cache PNG existait, mais chaque ouverture recalculait les empreintes des 341 images (252 variantes Core Lab),
puis remplaçait les objets du modèle. Trace QML Hyprland : 100–220 ms dans le traitement du scan sur une instance fraîche.
Un banc avec 4 000 appels Qt.md5 supplémentaires reproduit le retard : **1 043 ms du relâchement du clic à apply**,
**1 091 ms à Image.Ready**, avec un trou de **1 184 ms** sur le fil de l'interface à la réouverture.
Ce préchargement simule l'accumulation d'appels ; il ne mesure pas une durée précise de session réelle.

Correction : empreintes des vignettes calculées une fois par chemin/date ; empreintes des copies écran mémorisées par
chemin absolu. Un scan identique conserve les objets du modèle et les réservations d'écritures de vignettes.
Noms des fichiers en cache et résolution des variantes inchangés. Scan des métadonnées conservé à l'ouverture.

Après correction, même banc Hyprland 1920×1200 avec bibliothèque réelle, copie du cache et préchargement de 4 000 appels :
**1–2 ms** du clic à apply, **31–52 ms** à Image.Ready sur dix clics. À la réouverture, attendre que l'animation de la surface
soit stabilisée avant d'envoyer le pointeur virtuel ; un clic injecté trop tôt peut manquer le cadre animé.
Les pixels du fond sont comparés à l'original sur une bande hors du sélecteur : dix captures PPM identiques.
Le temps de lancement et de lecture des captures (114–179 ms) n'est pas confondu avec le décodage.
Le choix de résolution n'est pas le poste coûteux : quelques millisecondes au total pour 135 appels.

`test-wallpapers.py` et `--compositor hyprland` vérifient sans seuil temporel fragile qu'un scan inchangé ne recalcule
aucune empreinte connue et ne remplace pas le modèle ; un fichier modifié ne recalcule que sa clé.

## Onglets du sélecteur — grilles conservées (2026-11-10)

Sur b1d8212, les cellules demandent transitoirement un original avec sourceSize=240×0 avant le PNG 240×135.
Le remplacement de l’unique modèle recrée aussi 25 cellules Images / 9 Core Lab. Sans profileur : médianes de séries
courtes à cache chaud 391,5 ms / 43 ms jusqu’à Image.Ready. Le simple garde-fou de taille et un cache Qt conditionnel
abaissent ces valeurs à 50,5 / 8 ms, mais conservent les reconstructions ; cette variante n’est pas retenue.

Correction finale : Loader stable par onglet, grille créée à sa première visite puis conservée, modèle comparé avant
remplacement, Image.cache=false et sources uniquement à sourceSize valide. Cent bascules mesurées sur le code final :
les 98 après les premières visites totalisent **zéro cellule créée/détruite et zéro nouvelle demande de source**.
Huit vrais clics avec comparaison de pixels du banc Hyprland : première capture correcte vers **31–33 ms**, coût
de capture inclus. Aucun nouveau chargement ne signifie pas un rendu en zéro milliseconde.

Captures logiques : à l’échelle 1,5, les PNG nommés 360×203 font désormais réellement 360×203, au lieu de 540×305.
Cache isolé par bibliothèque ; l’ancien cache plat est ignoré et les vignettes régénérées une fois, choix conservés.
Jobs par identité : échec/fermeture/destruction libèrent la réservation, résultats périmés ignorés. Une vignette
corrompue est oubliée puis régénérée ; un onglet caché ne réserve pas de capture. Pas de minuteur de maintenance.

Banc de diagnostic et rapport détaillé conservés dans /tmp : profile-wallpaper-tabs.py et corelab-tabs-profiling.md.
Le premier décodage à cache vide reste nécessaire et asynchrone ; aucun paquet ou outil natif ajouté.
