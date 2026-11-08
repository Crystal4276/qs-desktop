-- Configuration Hyprland — point d'entrée (phase 10 : reprise de ~/.config/hypr, sauvegardé dans ~/.config/hypr.bak-<date>).
-- Barre, notifications, lanceur, menus, fond d'écran, veille, verrouillage, agent polkit, réseau, Bluetooth et disques : Quickshell
-- (scripts/desktop.sh, lancé par lua/autostart.lua). Écrans de cette machine et matériel : hosts/<hostname>.lua (lua/host.lua).
--
-- L'ordre des require() n'est pas cosmétique. Chaque require() est un scope Lua
-- isolé : une erreur d'EXÉCUTION n'interrompt que son propre fichier, les
-- suivants se chargent quand même. binds.lua vient donc en premier pour que le
-- clavier survive à n'importe quelle panne en aval — le mode d'urgence de
-- Hyprland ne se déclenche que si AUCUN bind n'a pu être enregistré.
-- (Une erreur de SYNTAXE, elle, fait refuser tout le rechargement : d'où
-- `luac -p` avant chaque test.)

require("lua/binds")       -- 1er : garantit un clavier utilisable en toutes circonstances
require("lua/env")         -- avant autostart, qui en dépend
require("lua/monitors")
require("lua/looknfeel")
require("lua/input")
require("lua/windowrules") -- clés d'effet non typées : plus fort risque d'erreur d'exécution
require("lua/openorigin") -- placement du contenu externe avant le premier rendu
require("lua/host")        -- après les règles communes : celles de la machine s'y ajoutent
require("lua/autostart")   -- dernier : le plus à effets de bord
