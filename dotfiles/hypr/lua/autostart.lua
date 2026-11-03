-- Démarrage automatique.
--
-- Remplace les `exec-once =` : en Lua on s'abonne à l'événement hyprland.start.
-- hl.exec_cmd détache déjà le processus, aucun « & » n'est nécessaire.
-- Chargé en DERNIER : c'est le module le plus à effets de bord, et une panne
-- ici ne doit empêcher aucun autre réglage de s'appliquer.
--
-- Barre, notifications, fond d'écran, veille (hypridle), agent polkit, nm-applet, blueman et udiskie : remplacés par le bureau
-- Quickshell, lancé en premier.

local prog = require("lua/programs")
-- Fichier de la machine en erreur : déjà signalé par son require() dans hyprland.lua ; ici, le bureau et les applications
-- démarrent quand même (sans pcall, l'erreur relevée une deuxième fois arrêterait ce fichier entier).
local ok, host = pcall(require, "lua/host")
if not ok then
   host = {}
end

hl.on("hyprland.start", function()
   -- Bureau Quickshell : relancé s'il s'arrête ; chaque écran affiche le premier espace de son bloc (1 / 4 / 7).
   hl.exec_cmd(prog.desktop)

   -- VPN. La ligne `nordvpn login --token ...` de l'ancien hyprland.conf n'est pas
   -- reportée : l'authentification est persistée par nordvpn lui-même.
   hl.exec_cmd("nordvpn c Netherlands")

   -- Curseur.
   hl.exec_cmd("hyprctl setcursor Catppuccin-Mocha-Green-Cursors 48")
   hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 48")

   -- Applications.
   hl.exec_cmd("LD_PRELOAD=/usr/lib/spotify-adblock.so spotify")
   hl.exec_cmd("deluge")

   -- Ces deux-là attendent que le compositeur soit posé avant de démarrer.
   hl.exec_cmd("sleep 4 && steam")
   hl.exec_cmd("sleep 4 && thunderbird")
   -- Discord et WhatsApp : web apps, comme sous Sway.
   hl.exec_cmd("gtk-launch WebApp-DiscordWeb2996")
   hl.exec_cmd("gtk-launch WebApp-Whatsapp8699")

   -- Matériel de cette machine (hosts/<hostname>.lua).
   for _, command in ipairs(host.autostart or {}) do
      hl.exec_cmd(command)
   end
end)
