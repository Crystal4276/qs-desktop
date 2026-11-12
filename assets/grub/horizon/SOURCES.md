# Provenance

Ressources consultées ou récupérées le 12 novembre 2026.

- Projet utilisateur : https://github.com/Crystal4276/qs-desktop
- Palette et pilules : config/Theme.qml dans ce dépôt ; copie en reference/Theme.qml.
- Bordures de sélection : dotfiles/sway/config ; copie en reference/sway-config.txt.
- Arch SVG : assets/arch_linux_icon_green.svg du même dépôt, copié sans redessin.
- Core Lab et KAUST : assets/plymouth/source/corelab-mark.svg et kaust-mark.svg du même dépôt. Ce sont des ressources fournies dans le cadre du projet utilisateur ; ce kit ne leur attribue pas une nouvelle licence.
- Wallpaper : fichier 04-diffraction_3840x2160.png fourni par l’utilisateur. Source de style, pas fond de menu à utiliser directement.
- Référence de style : génération ImageGen de la révision validée, puis changement du délai affiché à 2 s, conservée dans reference/style-approved-2s.png. Elle peut contenir des déformations ; ne pas reprendre ses cercles ovalisés.
- Référence géométrique finale : reference/horizon-approved-2s.svg et .png, construite par tools/build_reference.py à partir des vrais SVG, des couleurs et de cercles mathématiques. Elle remplace la maquette IA pour la géométrie. Le petit nom du laboratoire y est temporairement en Inter, en attendant le lockup DM Sans original demandé dans DESIGN.md.
- Inter : copie de la face Inter Regular de la collection installée sur la machine ; licence SIL OFL jointe depuis https://github.com/rsms/inter/blob/master/LICENSE.txt. Le script de fontes ne change pas la famille.

Documentation technique à vérifier contre la version cible :

- https://www.gnu.org/software/grub/manual/grub/html_node/Theme-file-format.html
- https://www.gnu.org/software/grub/manual/grub/html_node/gfxmode.html
- https://www.gnu.org/software/grub/manual/grub/html_node/Simple-configuration.html
- Source documentaire GRUB consultée : https://github.com/rhboot/grub2/blob/master/docs/grub.texi

Ce kit n’embarque pas le manuel GRUB ; il donne des liens et des recommandations propres au projet.

Icônes Advanced options, UEFI Firmware Settings et Restart : géométries extraites sans redessin des trois glyphes
vectoriels de `tools/build_reference.py` (référence Horizon approuvée). SVG autonomes dans `assets/source/`,
trait `#cdd6f4`, largeur 2.5, coordonnées 48×48 identiques. Les PNG de chaque déclinaison sont régénérés par
`scripts/grub-horizon-build.py` du dépôt, aux mêmes dimensions que les icônes Arch.
