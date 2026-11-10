# Écran de démarrage Plymouth « Core Lab » (profil travail)

Thème Plymouth du bureau pour les machines au **profil `travail`** : il remplace l'écran texte du démarrage et la demande de phrase
de passe LUKS par un écran au design des wallpapers Core Lab (« 04 Diffraction »), puis passe la main à l'écran de connexion
(greetd + greeter Quickshell, `ARCHITECTURE.md` § 9).

Le design est **validé** (canvas « Plymouth Core Lab », proposition A · Assemblage, déclinée en 1920×1200, 3440×1440 et 3840×2160).
Ce document est la spécification complète : rien d'autre n'est à aller chercher.

## Contenu fourni

| Fichier | Rôle |
|---|---|
| `assets/plymouth/reference/assemblage.html` | **Étalon** visuel et temporel, exécutable dans Chromium / Playwright. Paramètres en tête du fichier : `?w=&h=` (taille d'écran), `boot`, `auto=1` (saisie automatique), `freeze=idle\|luks\|typing\|unlocking\|error\|caps` (états figés pour les captures), `noluks=1`. Phase courante : `window.qsPlymouth.phase`. |
| `assets/plymouth/source/corelab-mark.svg` | Logo : quatre demi-anneaux (`half-1` à `half-4`), à découper en quatre images. |
| `assets/plymouth/source/kaust-mark.svg` | Emblème KAUST du nom du lab. |

Toute divergence entre ce document et la référence : **la référence fait foi pour le rendu**, ce document pour le comportement
système. Les signaler dans `PROGRESS.md`.

## Règles propres à ce chantier (en plus de `CLAUDE.md`)

1. **Ne jamais rendre une machine indémarrable.** Ce chantier touche l'initramfs, la ligne de commande du noyau et l'ordre de
   démarrage. Avant toute modification système : sauvegarde des fichiers touchés (`<fichier>.bak-<date>`), image de secours
   (`fallback`) intacte et démarrable, procédure de retour écrite dans `docs/ROLLBACK.md` **avant** de l'appliquer. Toujours
   essayer d'abord dans la VM (avec un disque chiffré LUKS), jamais d'abord sur le laptop.
2. **Aucune étape système sans mon accord explicite** (`sudo`, `mkinitcpio`, chargeur de démarrage, unités systemd, paquets).
   Proposer la liste exacte des changements, attendre, puis appliquer.
3. **Profil `travail` uniquement.** Une machine au profil `jeux` (aujourd'hui `terrier`) n'est jamais touchée : pas de paquet, pas
   de hook, pas de thème. Le profil est celui de `scripts/profile.sh` (même règle que `Settings.qml` : absent ou inconnu → `travail`).
   Plymouth tourne dans l'initramfs, avant toute session : le choix se fait **à l'installation** (`install.sh`), pas au démarrage.
   Si une machine passe de `travail` à `jeux`, `install.sh` retire le thème proprement (même chemin que `--uninstall`).
4. **Charte** : couleurs exactes de `config/Theme.qml` (tableau ci-dessous), aucune valeur inventée. Deux exceptions
   **validées**, propres au design Core Lab : la police **DM Sans** SemiBold du nom du lab (celle des wallpapers) et les couleurs
   de l'emblème KAUST. Elles ne vivent que dans des images préparées, jamais à l'exécution.
5. Pas d'API Plymouth inventée : tout ce qui est marqué **« à vérifier »** ci-dessous se vérifie dans la documentation et les
   sources de la version installée (`pacman -Qi plymouth`, `/usr/share/doc/plymouth`, thèmes fournis dans
   `/usr/share/plymouth/themes/`, le thème `script` d'exemple), pas de mémoire.

## Design

### Séquence

| Phase | Déclencheur | Ce qu'on voit | Durée |
|---|---|---|---|
| 1 · Assemblage | Plymouth s'affiche | Fond crust. Les quatre demi-anneaux arrivent de leur côté (droite pour 1 et 3, gauche pour 2 et 4) et s'emboîtent au centre ; les anneaux en pointillés apparaissent de l'intérieur vers l'extérieur ; le filet horizontal et le nom du lab apparaissent en fondu. | 2,2 s |
| 2 · Phrase de passe | Demande de phrase de passe (LUKS) | Le logo reste en place. Sous lui, en fondu (0,3 s) : le texte de la demande, le champ, la ligne de message. **Le champ attend la fin de la phase 1** même si la demande arrive avant. | jusqu'à la saisie |
| 2b · Vérification | Entrée | Points du champ qui pulsent, bordure green, message « Unlocking… » pendant que cryptsetup dérive la clé. Refus : champ vidé, bordure red, « Wrong passphrase », retour en phase 2. | ~1 à 2 s (réel) |
| 3 · Chargement | Déverrouillage réussi (ou fin de la phase 1 sans demande de phrase de passe) | Le prompt disparaît en fondu (0,5 s) **pendant que** la rotation démarre : chaque demi-anneau fait un tour, sens alternés (diaphragme), puis se repose ; cycle de 2,4 s, en boucle. | jusqu'à la fin du démarrage |
| 4 · Sortie | Fin du démarrage (passage au greeter) | **À la fin du cycle en cours** (tous les demi-anneaux au repos) : les demi-anneaux repartent de leur côté, les anneaux s'effacent de l'extérieur vers l'intérieur, filet et nom du lab en fondu. Reste un écran crust uni, sur lequel le greeter s'affiche. | 0,95 s (+ fin du cycle, ≤ 2,4 s) |

### Couleurs (`config/Theme.qml`)

| Élément | Couleur |
|---|---|
| Fond, masque de la bande | `crust` `#11111b` |
| Filet horizontal ; fond du champ (opacité 0,85) | `mantle` `#181825` |
| Demi-anneaux 1 · 2 · 3 · 4 (opacité 0,9) | `green` `#a6e3a1` · `teal` `#94e2d5` · `sky` `#89dceb` · `sapphire` `#74c7ec` |
| Anneaux en pointillés | voir le tableau des anneaux |
| Bordure du champ : repos · saisie et vérification · refus | `overlay0` `#6c7086` · `green` · `red` `#f38ba8` |
| Points de saisie, nom du lab | `text` `#cdd6f4` |
| Texte de la demande, « Passphrase », cadenas, « Unlocking… » | `subtext0` `#a6adc8` |
| « Wrong passphrase » · « Caps Lock is on » | `red` · `yellow` `#f9e2af` |

### Géométrie

Tout est défini pour un écran de **1200 px de haut** et multiplié par **s = hauteur ÷ 1200** (1 en 1920×1200, 1,2 en 3440×1440,
1,8 en 3840×2160). Tout est centré sur (largeur ÷ 2, hauteur ÷ 2) = (cx, cy). **La largeur ne change aucune taille** : un écran
plus large montre seulement plus d'anneaux.

| Élément | Valeur (× s) |
|---|---|
| Logo | carré de 288 centré sur (cx, cy) ; demi-anneau *k* : arc de rayon *k* × 32, épaisseur 32 (soit un anneau de *k* − 0,5 à *k* + 0,5 dans le repère 9 × 9 du SVG) |
| Bande | masque `crust` de 18 de haut centré sur cy (sous le logo, au-dessus des anneaux) ; filet `mantle` de 4 centré sur cy |
| Bloc de saisie | commence à cy + 184 ; colonne centrée, espacement 14 : texte (16), champ, message (ligne de 24, texte 16) |
| Champ | 360 × 56, rayon 28, bordure 1 (arrondie à l'entier, min 1 px) ; cadenas 20 × 20 à 20 du bord gauche, centré verticalement (trait 1,75 dans une grille de 24) ; « Passphrase » 20 centré ; points de 10, espacés de 10, centrés, 22 au plus |
| Nom du lab | haut à 1090 ; « Imaging and Characterization Core Lab », DM Sans SemiBold 22, interlettrage −0,01 em ; emblème KAUST 30 × 29 à 14 à droite ; ensemble centré |

Textes de l'interface en **Inter** (charte), en anglais comme le reste du bureau.

### Anneaux en pointillés

Rayon = facteur × 144 × s. Points ronds : trait de longueur nulle, extrémités rondes, espacement = valeur × (144 × s) ÷ 180.
Épaisseur × s.

| # | Facteur | Couleur | Opacité | Épaisseur | Espacement |
|---|---|---|---|---|---|
| 1 | 1,278 | `sky` | 0,55 | 3 | 10 |
| 2 | 1,456 | `sky` | 0,32 | 2 | 14 |
| 3 | 1,733 | `sapphire` | 0,45 | 3 | 12 |
| 4 | 2,122 | `sapphire` | 0,28 | 2 | 16 |
| 5 | 2,467 | `blue` `#89b4fa` | 0,30 | 3 | 18 |
| 6 | 2,956 | `blue` | 0,20 | 2 | 20 |
| 7 | 3,456 | `overlay0` | 0,45 | 2 | 22 |
| 8 | 4,022 | `surface2` `#585b70` | 0,45 | 2 | 24 |
| 9 | 4,644 | `surface1` `#45475a` | 0,50 | 2 | 26 |
| 10 | 5,350 | `surface1` | 0,42 | 2 | 28 |
| 11 | 6,100 | `surface1` | 0,34 | 2 | 30 |
| 12 | 6,900 | `surface0` `#313244` | 0,70 | 2 | 32 |
| 13 | 7,750 | `surface0` | 0,55 | 2 | 34 |
| 14 | 8,650 | `surface0` | 0,45 | 2 | 36 |
| 15 | 9,600 | `surface0` | 0,35 | 2 | 38 |

Les anneaux 10 à 15 servent aux écrans larges ; hors de l'écran, ils ne coûtent rien à l'affichage mais pèsent dans les images
(voir « Images »).

### Mouvements et courbes

Courbes au format `cubic-bezier` (identiques dans la référence). *i* = indice du demi-anneau (0 à 3, du centre vers l'extérieur),
*j* = indice de l'anneau (0 à 14).

| Phase | Élément | Mouvement | Durée | Départ | Courbe |
|---|---|---|---|---|---|
| 1 | demi-anneau *i* | translation horizontale depuis ± 2,222 × taille du logo (640 × s) jusqu'à 0, opacité 0 → 1 | 900 ms | *i* × 120 ms | (.16, .84, .24, 1) |
| 1 | anneau *j* | échelle 0,94 → 1, opacité 0 → 1 | 600 ms | 900 + *j* × 45 ms | (.2, .8, .2, 1) |
| 1 | filet | opacité 0 → 1 | 400 ms | 0 | ease |
| 1 | nom du lab | opacité 0 → 1 | 600 ms | 400 ms | ease |
| 2 | bloc de saisie | opacité 0 → 1 | 300 ms | fin de la phase 1 | ease |
| 2b | points | opacité 1 → 0,35 → 1, en boucle | 1 200 ms | Entrée | ease-in-out |
| 3 | bloc de saisie | opacité 1 → 0 | 500 ms | déverrouillage | ease |
| 3 | demi-anneau *i* | rotation de 360° (*i* pair : sens horaire ; impair : antihoraire) pendant la 1re moitié du cycle, repos pendant la 2de ; cycle 2 400 ms, en boucle | 1 200 ms + 1 200 ms | *i* × 150 ms après le déverrouillage | (.65, 0, .35, 1) |
| 4 | demi-anneau *i* | translation 0 → ± 640 × s, opacité 1 → 0 | 650 ms | (3 − *i*) × 80 ms | (.5, 0, .75, 0) |
| 4 | anneau *j* | opacité 1 → 0 | 500 ms | (14 − *j*) × 30 ms | ease |
| 4 | filet · nom du lab | opacité 1 → 0 | 500 ms | 300 · 350 ms | ease |

### États du champ

| État | Bordure | Contenu | Message |
|---|---|---|---|
| Repos (champ vide) | `overlay0` | « Passphrase » | — |
| Saisie | `green` | un point par caractère | — |
| Vérification | `green` | points qui pulsent | « Unlocking… » (`subtext0`) |
| Refus | `red` jusqu'à la frappe suivante | champ vidé, « Passphrase » | « Wrong passphrase » (`red`) |
| Verr. Maj. (si détectable) | selon l'état | — | « Caps Lock is on » (`yellow`) |

Le texte de la demande est celui que fournit le système (par ex. « Please enter passphrase for disk … ») ; la référence montre
celui d'un volume `cryptroot`.

## Implémentation

### Choix techniques (à confirmer pendant l'audit)

- **Plugin `script`** de Plymouth : l'ordre assemblage → saisie → boucle → sortie ne correspond pas au plugin `two-step` (celui
  de Spinner : boucle puis animation de fin). Le script permet sprites, opacité, position, rotation et mise à l'échelle d'images,
  et des fonctions de rappel pour les événements. **À vérifier** dans la version installée : noms exacts des rappels (rafraîchissement,
  demande de mot de passe, retour à l'affichage normal, message, mise à jour d'état, progression, fin), fréquence de
  rafraîchissement, `Image.Rotate` / `Image.Scale` / `Image.Text`, gestion de plusieurs écrans (`Window.GetWidth/GetHeight/GetX/GetY`
  avec un indice), détection du verrouillage des majuscules.
- **Images préparées, un jeu par échelle** (étape 2, mesuré) : `scripts/plymouth-assets.py build` rend les PNG pour s = 0,9 ;
  1,0 ; 1,2 ; 1,5 ; 1,8 (1920×1080, 1920×1200, 2560×1440 et 3440×1440, 2560×1600, 4K) (formes en cairo, textes et champ par Chromium avec le CSS et les polices de la référence). Au démarrage, chaque
  écran prend le plus petit jeu au moins aussi grand que lui, réduit une seule fois par `Image.Scale`. Plymouth ne redimensionne
  que par échantillonnage bilinéaire ponctuel (sans moyenne) : un seul jeu 4K réduit en 1920×1200 épaissit le texte et
  amincit les points (écart à la référence doublé). Générateur reproductible, PNG et bloc de données committés (1,8 Mo).
- **Coût d'animation** (étape 2, mesuré) : Plymouth ne redessine que les rectangles des sprites qui changent. Les anneaux sont
  donc découpés en 16 arcs par anneau (petites PNG, points entiers), jamais en images plein écran ; l'échelle 0,94 → 1 est
  rendue en rapprochant les arcs du centre ; les demi-anneaux tournent par `Image.Rotate` (angle positif = sens horaire,
  comme le CSS). Mesuré en VM (i9-9900K) : 8,7 ms au pire moment de l'intro en 4K, 6,6 ms par image de rotation en 4K,
  4,8 ms en 1920×1200 ; budget 20 ms (50 images/s, minuteur réarmé avant le dessin). Le script n'a pas d'horloge : le temps
  compte les rafraîchissements, une image trop lente ralentirait l'animation.
- **Textes fixes** (« Passphrase », « Unlocking… », « Wrong passphrase », « Caps Lock is on », nom du lab) : images préparées en
  Inter / DM Sans, pour ne dépendre d'aucune police dans l'initramfs. **Texte de la demande** (variable) : `Image.Text` avec Inter
  si la police est bien embarquée dans l'initramfs (**à vérifier** : comment le hook `plymouth` choisit les polices) ; sinon,
  me proposer une solution avant de changer le design.
- **Pas de détection de résolution à l'installation** : à chaque démarrage, le thème lit la taille de **chaque** écran et calcule
  son s. Laptop seul ou avec un écran externe, sans réglage. Si Plymouth applique un facteur HiDPI, calculer s sur la taille qu'il
  expose au script. Plusieurs écrans : la même scène sur chacun, à son échelle.

### Fichiers proposés

```
dotfiles/plymouth/qs-corelab/qs-corelab.plymouth   # déclaration du thème (plugin script)
dotfiles/plymouth/qs-corelab/qs-corelab.script     # la séquence
dotfiles/plymouth/qs-corelab/images/*.png          # générées par scripts/plymouth-assets.*
scripts/plymouth-assets.*                          # SVG / référence → PNG (s = 1,8)
scripts/plymouth-setup.sh                          # install | uninstall | preview | status (étape système, comme greeter-setup.sh)
```

Plus : `deps/work.txt` (paquet `plymouth`, dépôt officiel), `install.sh` (étape système du profil `travail`, et retrait si le
profil n'est plus `travail`), `docs/ROLLBACK.md` (section Plymouth), `docs/ARCHITECTURE.md` (nouvelle section courte),
`README.md`, `scripts/test-install.py`.

### Événements → phases

| Événement Plymouth | Phase |
|---|---|
| Affichage du thème | phase 1 |
| Demande de phrase de passe | phase 2 (après la fin de la phase 1) ; nombre de points = nombre de caractères que Plymouth rapporte |
| Retour à l'affichage normal après Entrée | phase 2b (« Unlocking… ») — ne pas masquer le champ tout de suite |
| Nouvelle demande de phrase de passe après une 2b | refus |
| Déverrouillage réussi | phase 3. **À déterminer** : le signal fiable (reprise de la progression, message d'état de l'unité `systemd-cryptsetup@…`, ou absence de nouvelle demande après un délai). Proposer, mesurer dans la VM. |
| Pas de demande à la fin de la phase 1 | phase 3 directement (machine sans LUKS, ou volume déjà ouvert) |
| Passage au greeter | phase 4, puis Plymouth quitte |

### Intégration système (à auditer, puis à me proposer)

- **Initramfs** (`/etc/mkinitcpio.conf`) : hook `plymouth` à sa place (après `systemd` ou `udev`, avant `sd-encrypt` ou
  `encrypt`) ; pilote graphique chargé tôt (KMS : hook `kms` ou module du GPU dans `MODULES`) pour éviter le clignotement et un
  passage en mode texte quand le pilote change pendant l'assemblage. Mesurer la taille de l'initramfs avant / après (objectif :
  quelques Mo au plus ; regrouper ou recadrer les images d'anneaux si besoin).
- **Ligne de commande du noyau** : au minimum `splash` (et `quiet`). Détecter le chargeur réel (systemd-boot, UKI avec
  `/etc/kernel/cmdline`, GRUB, Limine…) au lieu de supposer.
- **Passage au greeter** : greetd démarre après Plymouth ; vérifier l'ordre réel des unités (`systemctl cat greetd`,
  `plymouth-quit.service`, `plymouth-quit-wait.service`). Objectif : la phase 4 joue en entier, puis Plymouth quitte **en gardant
  la dernière image** (écran crust), sans console texte visible, jusqu'à ce que le greeter dessine. Piste à valider : un
  complément de l'unité greetd (dans `dotfiles/greetd/`, installé par le script d'installation) qui signale la sortie au thème,
  attend la durée de la phase 4, puis fait quitter Plymouth en gardant l'image. Mesurer le temps ajouté au démarrage ; si la
  fin de cycle + sortie dépasse ~2 s en pratique, me le dire avant d'aller plus loin.
- **Retour arrière** : thème précédent noté, hook et `splash` retirés, initramfs reconstruite, sauvegardes restaurées ; une
  commande (`scripts/plymouth-setup.sh uninstall`) et la procédure manuelle depuis un TTY ou l'image de secours, dans
  `docs/ROLLBACK.md`.

## Vérification

1. **Référence d'abord** : captures de `assemblage.html` aux trois tailles (`?w=1920&h=1200`, `?w=3440&h=1440`,
   `?w=3840&h=2160`) et dans chaque état figé ; ce sont les étalons.
2. **Aperçu sans redémarrer** : afficher le thème hors démarrage (démon Plymouth lancé à la main sur un VT libre, ou moteur de
   rendu de test s'il existe dans la version installée — **à vérifier**), simuler la demande de phrase de passe, une mise à jour
   d'état et la fin. Captures comparées aux étalons (positions, tailles, couleurs) ; écarts nuls ou listés.
3. **VM** (procédure « VM d'installation » de `docs/DEVELOPMENT.md`) **avec un disque LUKS** : démarrage réel, bonne phrase,
   mauvaise phrase puis bonne, majuscules, passage au greeter, deux résolutions de VM. Désinstallation, puis redémarrage propre.
4. **Profils** : `test-install.py` couvre `travail` (thème installé) et `jeux` (rien d'installé, rien de modifié).
5. **Laptop réel** en dernier, avec mon accord, puis tests à la main listés dans `PROGRESS.md` : démarrage à froid, écran externe
   branché au démarrage (dont l'ultrawide 3440×1440), mauvaise phrase, majuscules, retour de veille prolongée si concerné,
   arrêt et redémarrage (Plymouth s'affiche aussi à l'arrêt : comportement à proposer, par défaut simple fondu sur crust).

## Étapes

Chaque étape suit la boucle de `CLAUDE.md` (lire `PROGRESS.md` → faire → vérifier → mettre à jour `PROGRESS.md` → committer →
**s'arrêter pour validation**).

1. **Audit (lecture seule, aucun changement)** : version de Plymouth et API réelle du plugin script (les points « à vérifier ») ;
   chargeur et ligne de commande ; `mkinitcpio.conf` (hooks, modules, `sd-encrypt` ou `encrypt`) ; volumes chiffrés
   (`/etc/crypttab`, `lsblk -f`) ; GPU et KMS précoce ; unités greetd / Plymouth ; profil de la machine. Rapport : ce qui est
   faisable tel quel, les écarts au design, la liste exacte des changements système proposés.
2. **Images** : script de génération, PNG, planche de contrôle comparée à la référence.
3. **Thème** : `.plymouth` + `.script`, aperçu sans redémarrage, captures aux trois tailles comparées aux étalons.
4. **Installation** : `scripts/plymouth-setup.sh`, `install.sh` (profil `travail` seulement), `deps/work.txt`, `ROLLBACK.md`,
   `test-install.py` ; essais complets dans la VM LUKS.
5. **Laptop** (après mon accord) : installation réelle, démarrage, tests à la main dans `PROGRESS.md`.
