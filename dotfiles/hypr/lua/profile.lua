-- Profil de cette machine (jeux | travail : clé « profile » de hosts/<hostname>.json, lue par scripts/profile.sh) :
-- charge profiles/<profil>.lua (règles de ses applications) et renvoie sa table { workspaces = { chat, music, mail, windows }, autostart = { … } }.
-- Chargé par hyprland.lua avant lua/windowrules.lua (numéros d'espace des règles communes).
-- Script absent ou muet : travail. Aucun hl.exec_cmd hors de l'autostart (`Hyprland --verify-config` exécute ce fichier).

local MODULE = ...   -- nom passé par require ("lua/profile")
local script = os.getenv("HOME") .. "/.config/quickshell/desktop/scripts/profile.sh"
local pipe = io.popen("'" .. script:gsub("'", "'\\''") .. "' 2>/dev/null")
local name = pipe and pipe:read("l") or ""
if pipe then
   pipe:close()
end
if name ~= "jeux" then
   name = "travail"
end

local ok, result = pcall(require, "profiles/" .. name)
if ok then
   return result or {}
end
-- Erreur signalée ici, une fois (même raison que lua/host.lua).
package.loaded[MODULE] = {}
error(result)
