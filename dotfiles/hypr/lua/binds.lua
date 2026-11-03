-- Raccourcis clavier et souris.
--
-- Chargé EN PREMIER par hyprland.lua : si un module suivant lève une erreur
-- d'exécution, le clavier reste entièrement fonctionnel. Le mode d'urgence de
-- Hyprland (SUPER+Q / R / M) ne se déclenche que si AUCUN bind n'a pu être
-- enregistré, ce que cet ordre rend très improbable.
--
-- Actions du bureau (lanceur, réglages, captures, volume, VPN…) : Quickshell, par `qs ipc` (scripts/ipc.sh) ; mêmes raccourcis
-- que sous Sway (dotfiles/sway/config).
--
-- Correspondance des suffixes hyprlang -> table d'options :
--   bind   -> (aucune option)
--   bindm  -> { mouse = true }       glisser-déposer souris
--   bindel -> { repeating = true, locked = true }
--   bindl  -> { locked = true }

local prog = require("lua/programs")

local mod = "SUPER"

local function ipc(call)
   return hl.dsp.exec_cmd(prog.ipc .. " " .. call)
end

------------------------------------------------------------------------------
-- Applications
------------------------------------------------------------------------------

hl.bind(mod .. " + X", hl.dsp.exec_cmd("geany"))
hl.bind(mod .. " + A", hl.dsp.exec_cmd("chromium"))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("chromium https://claude.ai"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(prog.fileManager))
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(prog.terminal))
hl.bind(mod .. " + W", ipc("launcher toggle"))

-- VPN : connexion au dernier pays utilisé, déconnexion.
hl.bind(mod .. " + U", ipc('vpn connect ""'))
hl.bind(mod .. " + i", ipc("vpn disconnect"))

-- Bascule de la sortie audio vers la suivante.
hl.bind(mod .. " + S", ipc("audio cycleSink"))

-- HDR des écrans compatibles.
hl.bind(mod .. " + D", ipc("display toggleHdr"))

------------------------------------------------------------------------------
-- Captures d'écran : zone, écran, fenêtre (Images/screenshot, copiées)
------------------------------------------------------------------------------

hl.bind(mod .. " + SHIFT + PRINT", ipc("screenshot window"))
hl.bind(mod .. " + PRINT", ipc("screenshot screen"))
hl.bind("PRINT", ipc("screenshot area"))

------------------------------------------------------------------------------
-- Session et fenêtres
------------------------------------------------------------------------------

hl.bind(mod .. " + CTRL + R", hl.dsp.force_renderer_reload())
hl.bind(mod .. " + ESCAPE", ipc("settings toggle"))
-- Relance du bureau Quickshell.
hl.bind(mod .. " + CTRL + W", hl.dsp.exec_cmd(prog.desktop .. " restart"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + CTRL + Q", hl.dsp.exit())

hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
-- Clic molette : pression simple, pas un glisser — donc pas de { mouse = true },
-- qui est réservé aux binds maintenus (voir bindm plus bas).
hl.bind(mod .. " + mouse:274", hl.dsp.window.float({ action = "toggle" }))

hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))

hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
-- hyprlang « fullscreen, 1 » = maximisation (fenêtre plein cadre, décorations
-- conservées), à distinguer du plein écran réel ci-dessus.
hl.bind(mod .. " + TAB", hl.dsp.window.fullscreen({ mode = "maximized" }))

-- Bascule dwindle <-> master.
-- L'appel shell d'origine passait par `hyprctl keyword`, qui n'existe plus sous
-- parseur Lua. hl.bind accepte une fonction : on lit et on écrit l'option
-- directement, sans sous-shell ni analyse d'une sortie formatée.
hl.bind(mod .. " + quoteleft", function()
   local courant = hl.get_config("general.layout")
   hl.config({ general = { layout = courant == "master" and "dwindle" or "master" } })
end)

-- Déplacement de la fenêtre active vers l'écran voisin.
hl.bind(mod .. " + right", hl.dsp.window.move({ monitor = "+1" }))
hl.bind(mod .. " + left", hl.dsp.window.move({ monitor = "-1" }))

-- Déplacement de la fenêtre active dans la disposition.
hl.bind(mod .. " + CTRL + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + CTRL + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + CTRL + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + CTRL + down", hl.dsp.window.move({ direction = "down" }))

------------------------------------------------------------------------------
-- Espaces de travail 1 à 9
-- Note : ce poste utilise CTRL (et non SHIFT) pour envoyer une fenêtre.
-- Aucun espace attaché à un écran : répartition par Quickshell (docs/ARCHITECTURE.md § 3.2). Un espace qui n'existe pas encore est
-- créé sur l'écran de son bloc ; sans Quickshell, commande native.
------------------------------------------------------------------------------

for i = 1, 9 do
   hl.bind(mod .. " + " .. i, hl.dsp.exec_cmd(prog.ipc .. " outputs focus " .. i
      .. " || hyprctl dispatch 'hl.dsp.focus({ workspace = " .. i .. " })'"))
   -- Le focus suit la fenêtre.
   hl.bind(mod .. " + CTRL + " .. i, hl.dsp.exec_cmd(prog.ipc .. " outputs moveWindow " .. i
      .. " || hyprctl dispatch 'hl.dsp.window.move({ workspace = " .. i .. " })'"))
end

-- Molette pour faire défiler les espaces existants.
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Déplacer / redimensionner à la souris (binds maintenus).
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

------------------------------------------------------------------------------
-- Touches multimédia (volume et luminosité avec OSD ; lecteur choisi dans la barre)
-- repeating : la touche maintenue répète l'action.
-- locked    : fonctionne aussi quand un inhibiteur d'entrée (écran de
--             verrouillage) est actif.
------------------------------------------------------------------------------

local volumeAndBrightness = {
   { "XF86AudioRaiseVolume",   "audio volumeUp" },
   { "XF86AudioLowerVolume",   "audio volumeDown" },
   { "XF86AudioMute",          "audio toggleMute" },
   { "XF86AudioMicMute",       "audio toggleMicMute" },
   { "XF86MonBrightnessUp",    "brightness up" },
   { "XF86MonBrightnessDown",  "brightness down" },
}

for _, entry in ipairs(volumeAndBrightness) do
   hl.bind(entry[1], ipc(entry[2]), { repeating = true, locked = true })
end

local playerControls = {
   { "XF86AudioNext",  "media next" },
   { "XF86AudioPause", "media playPause" },
   { "XF86AudioPlay",  "media playPause" },
   { "XF86AudioPrev",  "media previous" },
}

for _, entry in ipairs(playerControls) do
   hl.bind(entry[1], ipc(entry[2]), { locked = true })
end
