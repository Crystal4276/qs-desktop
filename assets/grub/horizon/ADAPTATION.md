# Adaptation aux écrans

## Deux décisions distinctes

1. Choisir un mode vidéo que le firmware et GRUB savent afficher. `gfxmode=auto` et les modes de repli sont des pistes à vérifier sur la version cible ; `videoinfo` permet d’inspecter les modes. Cela ne garantit ni la résolution native de chaque écran, ni une gestion multi-écran semblable à celle de Sway.
2. Adapter le thème au mode effectivement choisi. Les zones peuvent utiliser des coordonnées relatives, mais les fontes PF2, les icônes et les coins des pilules nécessitent des tailles préparées et une sélection cohérente. Les propriétés disponibles dépendent de la version.

Un thème fixe 1920×1080 étiré sur tous les écrans ne satisfait pas la demande. Un thème régénéré uniquement d’après la résolution Linux à l’installation ne la satisfait pas non plus.

## Ressources fournies

Fonds sans texte et géométries pour 800×600, 1024×768, 1280×720, 1280×800, 1366×768, 1600×900, 1920×1080, 1920×1200, 2560×1080, 2560×1440, 2560×1600, 3440×1440, 3840×1600 et 3840×2160. Toute autre résolution peut être ajoutée à la liste du générateur. Les rendus ne sont pas des preuves de compatibilité matérielle.

La mise à l’échelle conserve les cercles et le symbole, réduit les éléments avec la contrainte la plus forte de largeur ou de hauteur, et laisse davantage de décor sur les écrans larges. Les fonds sont déjà aux dimensions exactes : éviter un second étirement non proportionnel. Pour une taille inconnue, définir une stratégie vérifiée de sélection du fond et du thème ; le format SVG source permet de reconstruire une ressource mais GRUB ne doit pas être supposé lire le SVG directement.

## Liste et compatibilité

Utiliser le boot_menu réel pour navigation, sous-menus et défilement. Ne pas dessiner sept pilules fixes dans le fond : le nombre d’entrées varie. Vérifier le support effectif de item_pixmap_style pour toutes les lignes et selected_item_pixmap_style pour la sélection. Les neuf tranches permettent des largeurs variables ; leurs coins et bordures doivent correspondre à l’échelle.

Ne pas supposer une API de redimensionnement, une variable de dimensions ou des media queries sans les vérifier dans le GRUB cible. La sélection de déclinaisons techniques peut demander un sélecteur GRUB chargé avant le menu ; son mécanisme doit être démontré, y compris lors d’un changement d’écran. Garder toutes les déclinaisons fidèles au même dessin.

Les intitulés longs et 12 entrées doivent rester accessibles. Aux faibles résolutions, accepter moins de lignes visibles et le défilement plutôt qu’une fonte illisible. Les modes insuffisants et les erreurs de ressources doivent aboutir à un menu de secours utilisable.
