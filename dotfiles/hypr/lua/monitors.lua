-- Écrans. Ceux d'une machine connue : hosts/<hostname>.lua, par description (docs/ARCHITECTURE.md § 3.1).
-- Ici, la règle de repli d'un écran inconnu : mode préféré, placé à droite, échelle choisie par Hyprland.
-- Aucun espace de travail attaché à un écran : répartition par Quickshell (services/Outputs.qml).

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
