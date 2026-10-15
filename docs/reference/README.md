# Captures de référence

Prises le 2026-10-15 sous Sway, trois écrans, Waybar visible. Pixels **physiques** : DP-2 en scale 1, DP-1/DP-3 en scale 1.5.

| Fichier | Contenu | Conditions |
|---|---|---|
| `waybar-DP-2-left.png` / `-right.png` | barre centrale, moitiés gauche et droite (bande de 80 px) | espace 2 focalisé (1 et 3 vides), Spotify en pause, pas de mise à jour en attente |
| `waybar-DP-1-left.png` / `-right.png` | barre gauche (bande de 120 px = 80 logiques) | espace 4 visible, 5 et 6 occupés |
| `waybar-DP-3-left.png` / `-right.png` | barre droite | espace 8 visible ; débit réseau en cours |
| `rofi-launcher.png` | lanceur (`$mod+w`), fenêtre seule | DP-2, recherche vide |
| `rofi-powermenu.png` | power menu, sous le tray | DP-2, premier élément (Lock) survolé |
| `nwg-menu.png` | menu du bouton Arch (bouton actif en vert) | DP-2 |
| `dunst-DP-2.png` | 3 notifications : critique avec icône, normale, basse | `notify-send -u critical -i dialog-warning …`, `-u normal -i audio-volume-high …` (icône non trouvée), `-u low …` |
| `glyphs.png` | planche de toutes les icônes utilisées (barre, power menu, lanceur), avec leur code | rendue avec `Symbols Nerd Font Mono` (`scripts` non requis : ImageMagick) |
