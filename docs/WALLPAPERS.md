# Fonds d'écran — recensement et proposition

Relevé le 2026-10-15, **en lecture seule** : aucun fichier n'a été déplacé, copié ni supprimé.

## Où ils sont aujourd'hui

| Emplacement | Fichiers | Taille | Remarque |
|---|---|---|---|
| `~/Pictures/Wallpaper/` | 53 + `3-screens/` (6) + `Live/` (26 + 3) | 3,4 Go | collection principale ; `Live/` = vidéos et WebP animés |
| `~/.config/sway/assets/{wallpaper,wallpaper2,widewallpaper}` | 44 | 132 Mo | quasi-copie des trois suivants |
| `~/.config/hypr/assets/{wallpaper,wallpaper2}` | 41 | 127 Mo | copie |
| `~/.config/qtile/assets/{wallpaper,wallpaper2}` | 41 | 127 Mo | copie |
| `~/Documents/backup/assets/{wallpaper,wallpaper2,widewallpaper}` | 43 | 131 Mo | copie |
| `~/.cache/swww/` | — | **11 Go** | cache de l'ancien outil swww (images pré-décodées, pas des originaux) ; supprimable sans perte |
| `~/.config/{waypaper,wpaperd,azote}` | — | — | réglages d'anciens gestionnaires, pointent vers `~/Pictures/Wallpaper` |

Total : **255 fichiers, 127 uniques** (empreinte MD5). Les quatre dossiers `assets` sont des copies les uns des autres ;
seuls 3 fichiers n'existent que là (`aishot-517.jpeg`, `aishot-637.jpeg`, `UltrawideWallpapersDotNet-638.jpeg`).

Utilisés aujourd'hui : Sway → `3-screens/monitor_{left,center,right}_*.png` ; Hyprland → `3-screens/swaybg_spread_*_DP-{1,2,3}.png`.

## Catégories

- **simple** : une image pour un écran (4K, ultrawide…), utilisable partout.
- **panorama** : image très large (rapport > 2,5 : 5760x1080, 7680x1294, 8576x1440…), prévue pour s'étaler sur plusieurs écrans.
  Quickshell peut la **découper à la volée** selon la position réelle des écrans : pas besoin de pré-découpe, et ça marche avec 2 ou 3 écrans.
- **triptyque** : panorama déjà découpé en gauche / centre / droite.
  - `swaybg_spread_*_DP-{1,2,3}.png` (Hyprland) = découpage du panorama `a_city_wallpaper__catppuccin_colors_1_2__Tsutomu_Nihei__Blame…jpeg`, présent → **redondant** ;
  - `monitor_{left,center,right}_*.png` (Sway) : **original introuvable** sur le disque → à garder comme triptyque.
  Un triptyque ne s'affiche que sur une configuration à 3 écrans ; un panorama, sur toute configuration multi-écran.
- **animé** : vidéos MP4/WebM et WebP animés (`Live/`), utilisés autrefois avec `mpvpaper` / `swww` (lignes commentées dans la config Sway).
- **exclu** : icônes de l'ancienne barre qtile (`layout/png/`) et 3 images portrait (fonds de téléphone) — à confirmer.

## État (2026-10-15)

Décisions : W1 dépôt séparé ✔ ; W2 pas de fonds animés ✔ ; W3 icônes et portraits exclus ✔ ; W4 cache swww supprimé ✔ (11 Go libérés).

Fait :
- 91 images copiées dans `~/Pictures/Wallpapers/` (42 `simple/`, 43 `panorama/`, triptyques `green-storm` et `blame-city`), **chaque copie vérifiée par MD5**.
- Dépôt Git `~/Pictures/Wallpapers`, poussé sur GitHub en **privé** : `Crystal4276/wallpapers`.
- Configs actuelles adaptées (exception à la règle « lecture seule », demandée par toi) :
  `~/.config/sway/config` (3 lignes `output … bg` → `triptych/green-storm/`), `~/.config/hypr/lua/autostart.lua` et `~/.config/hypr/hyprland.conf`
  (repli) → `triptych/blame-city/`. Sway : `sway -C` valide, nouveaux chemins appliqués en direct (`swaybg` relancé dessus). Hyprland : `luac -p` valide.
  Ces modifications ne sont **pas committées** dans les dépôts git de `~/.config/sway` et `~/.config/hypr`.

Reste à faire (suppression, bloquée par le garde-fou : à faire par toi ou à autoriser) :
- originaux devenus doublons dans `~/Pictures/Wallpaper/` (hors `Live/`) ;
- `~/Pictures/Wallpaper/Live/` (3,2 Go, fonds animés non retenus) : garder ailleurs ou supprimer ?
- copies dans `~/.config/{sway,hypr,qtile}/assets/{wallpaper,wallpaper2,widewallpaper}` et `~/Documents/backup/assets/` (dans des dépôts git pour sway et hypr).

## Proposition initiale

1. **Un dossier unique** : `~/Pictures/Wallpapers/` (nouveau nom, pour ne pas toucher à `~/Pictures/Wallpaper/` que la config actuelle utilise
   jusqu'à la bascule), organisé en `simple/`, `panorama/`, `triptych/<nom>/{left,center,right}.<ext>`, `live/`.
2. **Consolidation par copie** (pas de déplacement) : le bureau actuel continue de fonctionner. Les anciens emplacements ne sont supprimés
   qu'après la bascule (phase 10), sur liste et avec ton accord.
3. **Versionnement** — voir la décision W1 ci-dessous. Les images fixes (314 Mo) se versionnent bien ; les animés (3,2 Go, dont un fichier
   de 1,48 Go) **ne passent pas sur GitHub** sans Git LFS (fichiers > 100 Mo refusés).
4. **Utilitaire de changement de fond** (Quickshell) : fenêtre moderne avec vignettes, filtrée selon les écrans présents
   (panoramas seulement s'il y a plusieurs écrans côte à côte, triptyques seulement à 3 écrans), application à un écran ou à tous,
   choix mémorisé par machine (`~/.local/state`, hors dépôt). Le chemin du dossier vient de la config machine.

5. **Fond d'écran natif** (phase 8b) : une surface Quickshell par écran sur la couche Background remplace `swaybg` (Sway et Hyprland).
   `swaybg` a une zone d'entrée vide : un clic sur le fond focalise l'espace de travail (et ferme ainsi le calendrier épinglé de l'horloge).
   La surface native devra garder ce comportement (zone d'entrée vide), ou recevoir le clic, fermer le calendrier
   (`BarState.closePopups()`, ARCHITECTURE § 8.3) et focaliser l'espace de l'écran elle-même — ce qui couvrirait aussi le cas d'un clic
   juste après un clic dans le calendrier. À trancher en phase 8b.

## Mise en œuvre (phase 8b, 2026-10-17)

- **Fond natif** (`modules/wallpaper/Background.qml`, service `services/Wallpapers.qml`) : une surface par écran sur la couche
  Background, **sans zone d'entrée** (point 5 tranché : comme `swaybg`, un clic sur le fond va au compositeur, qui focalise l'écran
  et l'espace — vérifié dans un Sway isolé). Image simple : couvre l'écran, décodée à sa taille. Panorama : couvre le rectangle
  englobant tous les écrans, chaque écran en montre sa part (positions réelles, logiques). Triptyque : gauche / centre / droite
  selon la position, à 3 écrans ; sinon le centre partout. Panorama sur un seul écran : image simple. Taille d'un panorama lue
  une seule fois par le service pour tous les écrans et l'écran de verrouillage ; au changement de fond, l'ancien reste affiché
  pendant le décodage du nouveau (revue du 2026-10-27).
- **Choix** : état local (`wallpaper.json`, hors dépôt) : un fond pour tous les écrans, plus une image simple par écran (clé :
  description de l'écran, comme la config machine). Rien de choisi : `wallpaper` de la config machine (ici le triptyque
  green-storm, comme Sway aujourd'hui) ; sinon aucune image. Dossier : `wallpapersDir` de la config machine, sinon « Wallpapers »
  dans le dossier Images XDG.
- **Utilitaire** (`modules/wallpaper/PickerWindow.qml`, `qs ipc call wallpaper-picker toggle`) : onglets Images, Panoramas (plusieurs
  écrans), Triptychs (trois écrans) ; vignettes ; fond actuel entouré de vert ; clic ou Entrée : appliqué tout de suite, fenêtre
  gardée ouverte ; rangée « All screens » / un écran pour les images simples ; flèches, Échap, clic à côté. Vignettes en cache
  (`~/.cache/quickshell/by-shell/desktop/wallpaper-thumbs/`, PNG à la taille affichée, nom tiré du chemin, de la date de l'image et
  de la taille ; périmées effacées à la lecture du dossier) : supprimer ce dossier est sans risque, il se reconstruit.
- IPC de test : `qs ipc call wallpaper state` (JSON) et `qs ipc call wallpaper set <kind> <chemin>`.

## Décisions à prendre

| # | Question | Recommandation |
|---|---|---|
| W1 | Où versionner les images ? | **Dépôt séparé** (`wallpapers`), cloné par `install.sh` dans `~/Pictures/Wallpapers`. Le dépôt du bureau reste léger (clonage rapide, historique propre — une image ajoutée à git y reste pour toujours, même supprimée ensuite), et un laptop peut s'en passer. |
| W2 | Fonds animés : on les garde dans l'utilitaire ? | Si oui : lecture vidéo via `qt6-multimedia` (nouvelle dépendance, décodage GPU à tester avec Nvidia), fichiers **non versionnés** (restent locaux dans `live/`). Sinon : on les laisse de côté. |
| W3 | Exclure les 6 icônes et les 3 images portrait ? | oui |
| W4 | Supprimer le cache `~/.cache/swww` (11 Go) ? | oui, quand tu veux (c'est un cache, swww n'est plus utilisé) — je ne le fais pas sans ton accord |

## Détail fichier par fichier (uniques)

« Copies » = nombre d'exemplaires identiques trouvés sur le disque.

| Catégorie | Fichiers uniques | Taille |
|---|---|---|
| simple | 42 | 174 Mo |
| panorama | 43 | 114 Mo |
| triptyque | 6 | 26 Mo |
| animé | 27 | 3225 Mo |
| exclu (portrait) | 3 | 4 Mo |
| exclu (icône) | 6 | 0 Mo |

| Catégorie | Résolution | Taille | Fichier (emplacement principal) | Copies |
|---|---|---|---|---|
| simple | 1920x1080 | 0.6 Mo | `~/.config/hypr/assets/wallpaper/wallhaven-6k3oox.jpg` | 4 |
| simple | 3440x1440 | 4.5 Mo | `~/.config/hypr/assets/wallpaper/wallhaven-dpqjwj-3440.png` | 4 |
| simple | 5640x2400 | 8.5 Mo | `~/.config/hypr/assets/wallpaper/wallhaven-j37lop.png` | 4 |
| simple | 3704x2084 | 8.1 Mo | `~/.config/hypr/assets/wallpaper/wallhaven-pkmj69.png` | 4 |
| simple | 5397x3602 | 4.2 Mo | `~/.config/hypr/assets/wallpaper/wallhaven-q2wv5r.jpg` | 4 |
| simple | 3840x2160 | 2.6 Mo | `~/.config/hypr/assets/wallpaper/wallhaven-wqkk17.jpg` | 4 |
| simple | 4096x2048 | 8.7 Mo | `~/.config/hypr/assets/wallpaper/wallhaven-x8xzzl.png` | 4 |
| simple | 3840x2160 | 6.8 Mo | `~/.config/hypr/assets/wallpaper/wallhaven-z87z1j.jpg` | 4 |
| simple | 4096x2304 | 1.7 Mo | `~/.config/hypr/assets/wallpaper/wallhaven-zyx9lw.jpg` | 4 |
| simple | 3840x2160 | 3.3 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-287eg9.jpg` | 4 |
| simple | 3840x2160 | 7.2 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-28q9mm.jpg` | 4 |
| simple | 3840x2160 | 1.8 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-72mq8y.jpg` | 4 |
| simple | 3840x2160 | 6.4 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-72ozj3.png` | 4 |
| simple | 3840x2160 | 12.9 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-72qq29.png` | 4 |
| simple | 3840x2160 | 3.4 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-7p3g8y.jpg` | 4 |
| simple | 3840x2160 | 0.6 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-8oy372.jpg` | 4 |
| simple | 3840x2160 | 1.5 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-e7rymw.jpg` | 4 |
| simple | 3840x2160 | 6.8 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-j3z8pw.jpg` | 4 |
| simple | 3840x2160 | 1.2 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-k7v9yq.png` | 4 |
| simple | 3840x2160 | 0.5 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-l3lrqy.jpg` | 4 |
| simple | 3840x2160 | 2.5 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-l3p2jr.jpg` | 4 |
| simple | 3840x2160 | 1.8 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-m9vw9y.png` | 4 |
| simple | 3840x2160 | 4.1 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-pkxqpm.jpg` | 4 |
| simple | 3840x2160 | 10.2 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-q2wgpl.png` | 4 |
| simple | 3840x2160 | 1.2 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-weowzp.jpg` | 4 |
| simple | 3840x2160 | 1.7 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-y8kzjk.jpg` | 4 |
| simple | 3840x2160 | 2.2 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-y8o51x.jpg` | 4 |
| simple | 3840x2160 | 3.6 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-y8rvy7.jpg` | 4 |
| simple | 3840x2160 | 3.7 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-z8l6ko.jpg` | 4 |
| simple | 3840x2160 | 0.6 Mo | `~/.config/hypr/assets/wallpaper2/wallhaven-z8wl3w.jpg` | 4 |
| simple | 7010x2955 | 5.0 Mo | `~/Pictures/Wallpaper/nathan-anderson-kujXUuh1X0o-unsplash.jpg` | 1 |
| simple | 2999x1436 | 0.7 Mo | `~/Pictures/Wallpaper/photo-1445953993297-28dff00088f3.jpeg` | 1 |
| simple | 3476x1465 | 1.2 Mo | `~/Pictures/Wallpaper/photo-1475738198235-4b30fc20cff4.jpeg` | 1 |
| simple | 4614x3671 | 2.9 Mo | `~/Pictures/Wallpaper/wallhaven-4xg523.jpg` | 1 |
| simple | 5120x3200 | 13.6 Mo | `~/Pictures/Wallpaper/wallhaven-9mel2k.png` | 1 |
| simple | 3440x1440 | 1.6 Mo | `~/Pictures/Wallpaper/wallhaven-dpqjwj-3440.jpg` | 1 |
| simple | 3840x2160 | 2.6 Mo | `~/Pictures/Wallpaper/wallhaven-dpqjwj.jpg` | 1 |
| simple | 3840x2400 | 5.2 Mo | `~/Pictures/Wallpaper/wallhaven-eyp3ro.png` | 1 |
| simple | 3072x2048 | 1.0 Mo | `~/Pictures/Wallpaper/wallhaven-l35jjp.jpg` | 1 |
| simple | 3840x2160 | 13.5 Mo | `~/Pictures/Wallpaper/wallhaven-l3l12y.png` | 1 |
| simple | 8688x5792 | 3.5 Mo | `~/Pictures/Wallpaper/wallhaven-m9yz68.jpg` | 5 |
| simple | 3840x1920 | 0.9 Mo | `~/Pictures/Wallpaper/wallhaven-r2gz3q.jpg` | 1 |
| panorama | 7680x1288 | 1.6 Mo | `~/.config/sway/assets/widewallpaper/UltrawideWallpapersDotNet-638.jpeg` | 1 |
| panorama | 7680x1294 | 1.9 Mo | `~/.config/sway/assets/widewallpaper/aishot-517.jpeg` | 2 |
| panorama | 7680x1283 | 1.6 Mo | `~/.config/sway/assets/widewallpaper/aishot-637.jpeg` | 2 |
| panorama | 5760x1200 | 0.7 Mo | `~/Pictures/Wallpaper/2viIKfC.jpeg` | 1 |
| panorama | 5760x1200 | 0.4 Mo | `~/Pictures/Wallpaper/336341.jpg` | 1 |
| panorama | 5760x1080 | 0.4 Mo | `~/Pictures/Wallpaper/336375.jpg` | 1 |
| panorama | 11520x2160 | 2.4 Mo | `~/Pictures/Wallpaper/336537.jpg` | 1 |
| panorama | 5760x1080 | 0.4 Mo | `~/Pictures/Wallpaper/52RY9Px.jpeg` | 1 |
| panorama | 5760x1080 | 0.1 Mo | `~/Pictures/Wallpaper/5eSzcIF.jpeg` | 1 |
| panorama | 5760x1080 | 0.2 Mo | `~/Pictures/Wallpaper/6Or5Qw6.jpeg` | 1 |
| panorama | 7680x2400 | 0.8 Mo | `~/Pictures/Wallpaper/87139.jpg` | 1 |
| panorama | 8576x1440 | 2.5 Mo | `~/Pictures/Wallpaper/a_city_wallpaper__catppuccin_colors_1_2__Tsutomu_Nihei__Blame__colorfu_S635188153_St30_G7.jpeg` | 1 |
| panorama | 8576x1440 | 2.3 Mo | `~/Pictures/Wallpaper/an_abstract_wallpaper_S3048452640_St30_G7.jpeg` | 1 |
| panorama | 8576x1440 | 2.9 Mo | `~/Pictures/Wallpaper/an_hyperdetailed_abstract_wallpaper_based_on_catppuccin_colors_S2173427720_St30_G7.jpeg` | 5 |
| panorama | 8576x1440 | 3.3 Mo | `~/Pictures/Wallpaper/an_hyperdetailed_abstract_wallpaper_based_on_catppuccin_colors_S2173427721_St30_G7.jpeg` | 1 |
| panorama | 8576x1440 | 3.7 Mo | `~/Pictures/Wallpaper/an_hyperdetailed_abstract_wallpaper_based_on_catppuccin_colors_S2173427723_St30_G7.jpeg` | 1 |
| panorama | 8576x1440 | 3.8 Mo | `~/Pictures/Wallpaper/an_hyperdetailed_abstract_wallpaper_based_on_catppuccin_colors_S2173427732_St30_G7 (1).jpeg` | 1 |
| panorama | 8576x1440 | 3.6 Mo | `~/Pictures/Wallpaper/an_hyperdetailed_city_wallpaper__catppuccin_colors_1_2__Tsutomu_Nihei_S4245323042_St30_G7.jpeg` | 1 |
| panorama | 10591x3555 | 8.8 Mo | `~/Pictures/Wallpaper/andrii-ganzevych-ydCof_Xt9SM-unsplash.jpg` | 1 |
| panorama | 5760x1080 | 0.5 Mo | `~/Pictures/Wallpaper/blendergeometry-2.jpg` | 1 |
| panorama | 5760x1080 | 0.3 Mo | `~/Pictures/Wallpaper/dark-triple-monitor-wallpapers-46703-43383-8031537.png` | 1 |
| panorama | 5760x1440 | 3.5 Mo | `~/Pictures/Wallpaper/Firefox_wallpaper.png` | 1 |
| panorama | 5760x1080 | 0.3 Mo | `~/Pictures/Wallpaper/fkhzPbo.jpeg` | 1 |
| panorama | 5760x1200 | 0.4 Mo | `~/Pictures/Wallpaper/HD-Wallpaper-Triple-Monitor.jpg` | 1 |
| panorama | 5760x1080 | 0.5 Mo | `~/Pictures/Wallpaper/HUnbRnI.jpeg` | 1 |
| panorama | 5759x1079 | 0.6 Mo | `~/Pictures/Wallpaper/IN21weG.jpeg` | 1 |
| panorama | 5760x1080 | 0.6 Mo | `~/Pictures/Wallpaper/KQykkYQ.jpeg` | 1 |
| panorama | 5760x1080 | 1.2 Mo | `~/Pictures/Wallpaper/MoMcrob.jpeg` | 1 |
| panorama | 5759x1079 | 0.5 Mo | `~/Pictures/Wallpaper/NjUykg5.jpeg` | 1 |
| panorama | 3456x1160 | 0.2 Mo | `~/Pictures/Wallpaper/photo-1536919641626-48734852bee8.jpeg` | 1 |
| panorama | 5759x1079 | 0.5 Mo | `~/Pictures/Wallpaper/PqpH3BT.jpeg` | 1 |
| panorama | 5760x1200 | 0.4 Mo | `~/Pictures/Wallpaper/Qpi8xkA.jpeg` | 1 |
| panorama | 5760x1080 | 0.3 Mo | `~/Pictures/Wallpaper/rainbowline.jpg` | 1 |
| panorama | 5760x1080 | 0.7 Mo | `~/Pictures/Wallpaper/teahub.io-multi-monitor-wallpaper-329234.jpg` | 1 |
| panorama | 5760x1200 | 0.4 Mo | `~/Pictures/Wallpaper/teahub.io-triple-screen-wallpaper-329702.jpg` | 1 |
| panorama | 7680x1294 | 18.6 Mo | `~/Pictures/Wallpaper/UltrawideWallpapersDotNet-3223.png` | 1 |
| panorama | 7680x1294 | 18.1 Mo | `~/Pictures/Wallpaper/UltrawideWallpapersDotNet-4199.png` | 1 |
| panorama | 10320x1440 | 4.0 Mo | `~/Pictures/Wallpaper/wallhaven-eyp3ro-10320x1440.png` | 1 |
| panorama | 6827x1280 | 5.4 Mo | `~/Pictures/Wallpaper/wallhaven-l3gv1r.jpg` | 1 |
| panorama | 5120x1440 | 0.8 Mo | `~/Pictures/Wallpaper/wallhaven-o3zx59.jpg` | 1 |
| panorama | 10240x2880 | 13.1 Mo | `~/Pictures/Wallpaper/wallhaven-wer7qx.jpg` | 1 |
| panorama | 4722x885 | 0.6 Mo | `~/Pictures/Wallpaper/ZbZFm8t.jpeg` | 1 |
| panorama | 5760x1080 | 0.3 Mo | `~/Pictures/Wallpaper/zfenEuZ.jpeg` | 1 |
| triptyque | 3440x1440 | 5.5 Mo | `~/Pictures/Wallpaper/3-screens/monitor_center_3440x1440.png` | 1 |
| triptyque | 2560x1440 | 3.3 Mo | `~/Pictures/Wallpaper/3-screens/monitor_left_2560x1440.png` | 1 |
| triptyque | 2560x1440 | 4.3 Mo | `~/Pictures/Wallpaper/3-screens/monitor_right_2560x1440.png` | 1 |
| triptyque | 2560x1440 | 3.6 Mo | `~/Pictures/Wallpaper/3-screens/swaybg_spread_11841399237980754484_DP-1.png` | 1 |
| triptyque | 3440x1440 | 5.5 Mo | `~/Pictures/Wallpaper/3-screens/swaybg_spread_11841399237980754484_DP-2.png` | 1 |
| triptyque | 2560x1440 | 4.0 Mo | `~/Pictures/Wallpaper/3-screens/swaybg_spread_11841399237980754484_DP-3.png` | 1 |
| animé | 3840x2160 | 3.1 Mo | `~/Pictures/Wallpaper/dark-future-4k-fantasy-live-wallpaper.mp4` | 1 |
| animé | 3440x1440 | 18.3 Mo | `~/Pictures/Wallpaper/Live/3440x1440/mylivewallpapers-com-Futuristic-City-Marvel-Rivals-3440X1440.mp4` | 1 |
| animé | 3440x1440 | 19.6 Mo | `~/Pictures/Wallpaper/Live/3440x1440/mylivewallpapers-com-Vivi-Fishing-3440X1440px.mp4` | 1 |
| animé | ?x? | 163.4 Mo | `~/Pictures/Wallpaper/Live/3440x1440/mylivewallpapers-com-Vivi-Fishing-3440X1440px.webp` | 1 |
| animé | 3840x2160 | 23.8 Mo | `~/Pictures/Wallpaper/Live/black-hole-in-outer-space.3840x2160.mp4` | 1 |
| animé | 3840x2160 | 14.6 Mo | `~/Pictures/Wallpaper/Live/blue-moonlight-lake.3840x2160.mp4` | 1 |
| animé | 1920x1080 | 12.0 Mo | `~/Pictures/Wallpaper/Live/child_room.mp4` | 1 |
| animé | 3840x2160 | 77.9 Mo | `~/Pictures/Wallpaper/Live/forest_airy.mp4` | 1 |
| animé | 3840x2160 | 17.3 Mo | `~/Pictures/Wallpaper/Live/space-bedroom.3840x2160.mp4` | 1 |
| animé | 3840x2160 | 14.3 Mo | `~/Pictures/Wallpaper/Live/the-centenary.3840x2160.mp4` | 1 |
| animé | 3840x2160 | 94.3 Mo | `~/Pictures/Wallpaper/Live/Wallpaper (117).mp4` | 1 |
| animé | 3840x2160 | 131.4 Mo | `~/Pictures/Wallpaper/Live/Wallpaper (14).mp4` | 1 |
| animé | 1920x1076 | 89.0 Mo | `~/Pictures/Wallpaper/Live/Wallpaper (16).mp4` | 1 |
| animé | 3840x2160 | 146.0 Mo | `~/Pictures/Wallpaper/Live/Wallpaper (115).mp4` | 2 |
| animé | 3840x2160 | 20.9 Mo | `~/Pictures/Wallpaper/Live/Wallpaper (19).mp4` | 1 |
| animé | 3840x2160 | 31.0 Mo | `~/Pictures/Wallpaper/Live/Wallpaper (54).mp4` | 1 |
| animé | 1920x1080 | 6.6 Mo | `~/Pictures/Wallpaper/Live/Wallpaper (55).mp4` | 1 |
| animé | 1920x1080 | 0.7 Mo | `~/Pictures/Wallpaper/Live/Wallpaper (6).mp4` | 1 |
| animé | 3840x2160 | 88.1 Mo | `~/Pictures/Wallpaper/Live/Wallpaper (64).mp4` | 1 |
| animé | 3840x2160 | 49.4 Mo | `~/Pictures/Wallpaper/Live/Wallpaper (67).mp4` | 1 |
| animé | 1920x1080 | 15.5 Mo | `~/Pictures/Wallpaper/Live/Wallpaper (71).mp4` | 1 |
| animé | 1920x1080 | 41.6 Mo | `~/Pictures/Wallpaper/Live/Wallpaper (80).mp4` | 1 |
| animé | 3840x2160 | 193.4 Mo | `~/Pictures/Wallpaper/Live/Wallpaper_forest_chamber.mp4` | 1 |
| animé | 2560x1440 | 7.7 Mo | `~/Pictures/Wallpaper/Live/Wallpaper_forest_chamber.webm` | 1 |
| animé | ?x? | 1479.7 Mo | `~/Pictures/Wallpaper/Live/Wallpaper_forest_chamber_1440p.webp` | 1 |
| animé | ?x? | 292.3 Mo | `~/Pictures/Wallpaper/Live/Wallpaper_forest_chamber_20s.webp` | 1 |
| animé | 3840x2160 | 173.8 Mo | `~/Pictures/Wallpaper/Live/Wallpaper_forest_rain.mp4` | 1 |
| exclu (portrait) | 1350x2400 | 2.1 Mo | `~/.config/hypr/assets/wallpaper/wallhaven-13yw9g.jpg` | 4 |
| exclu (portrait) | 1080x1920 | 0.3 Mo | `~/.config/hypr/assets/wallpaper/wallhaven-eyq6zr.jpg` | 4 |
| exclu (portrait) | 1242x2208 | 1.3 Mo | `~/.config/hypr/assets/wallpaper/wallhaven-qde11d.jpg` | 4 |
| exclu (icône) | 500x500 | 0.0 Mo | `~/.config/hypr/assets/layout/png/layout-columns.png` | 4 |
| exclu (icône) | 500x500 | 0.0 Mo | `~/.config/hypr/assets/layout/png/layout-floating.png` | 4 |
| exclu (icône) | 850x850 | 0.0 Mo | `~/.config/hypr/assets/layout/png/layout-max.png` | 4 |
| exclu (icône) | 500x500 | 0.0 Mo | `~/.config/hypr/assets/layout/png/layout-spiral.png` | 4 |
| exclu (icône) | 32x32 | 0.0 Mo | `~/.config/hypr/assets/layout/png/layout-tile.png` | 4 |
| exclu (icône) | 32x32 | 0.0 Mo | `~/.config/hypr/assets/layout/png/layout-treetab.png` | 4 |
