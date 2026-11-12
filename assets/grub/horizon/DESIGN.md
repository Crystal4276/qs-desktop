# Spécification visuelle

Le même dessin s’applique à tous les formats. À gauche : les quatre demi-anneaux Core Lab et leurs cercles pointillés. À droite : une liste verticale en pilules, puis le compte à rebours vert. En bas : les indications clavier et l’identité du laboratoire. Aucun titre de projet et aucun trait traversant l’écran.

Exigence explicite finale : les anneaux pointillés sont des CERCLES, jamais des ovales. Même rayon en X et en Y, points ronds, centre commun avec le symbole. Les fonds fournis sont calculés par x=cx+r*cos(a), y=cy+r*sin(a), et non obtenus en étirant une image. Un écran ultralarge montre davantage de décor ; il n’allonge pas les cercles. La maquette IA reste secondaire à cette contrainte géométrique.

Palette : crust #11111b ; mantle #181825 ; texte #cdd6f4 ; secondaire #a6adc8 ; bordure sélectionnée overlay0 #6c7086 ; bordure normale surface1 #45475a ; green #a6e3a1 ; teal #94e2d5 ; sky #89dceb ; sapphire #74c7ec. Le symbole original utilise une opacité de 0,9.

Interface Inter Regular. Le nom du laboratoire est historiquement en DM Sans SemiBold, comme les wallpapers et Plymouth ; cette fonte n’est pas incluse dans ce kit. La récupérer avec sa licence auprès de sa source officielle avant fabrication du lockup, ou utiliser les ressources originales du dépôt si elles permettent de conserver la netteté souhaitée. Ne pas lui substituer silencieusement une police.

Pilules : hauteur de référence 55, rayon 20, bordure 1, intervalle 10. Le rayon n’est pas la demi-hauteur. Fond uniforme mantle, pas de halo ni de dégradé. Même texte et mêmes icônes dans les états normal et sélectionné. Seule la bordure s’éclaircit discrètement à la sélection, comme Sway.

Quatre icônes Arch identiques et vertes, même dans la sélection. Le SVG du dépôt est la référence, pas le dessin de l’image IA. Tailles PNG disponibles : 16, 20, 24, 28, 32, 40, 48, 64, 80, 96 et 128 pixels.

Compte à rebours : 2 secondes, texte et progression verts. Les secondes doivent venir de GRUB. Le menu doit pouvoir contenir davantage que sept entrées sans chevaucher ce bloc ni le pied de page.

La géométrie proposée dans geometry.json conserve les deux colonnes. Son échelle est bornée par la largeur ET la hauteur, pour réduire les éléments sur un écran étroit sans changer de composition. Les valeurs sont un point de départ à valider avec les métriques réelles des PF2 et les neuf tranches de GRUB.
