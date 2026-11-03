-- Réglages de cette machine : hosts/<hostname>.lua (écrans par description, règles qui les visent, matériel). Il renvoie une table
-- { autostart = { commandes } }, lancées par lua/autostart.lua. Pas de fichier pour cette machine : rien, et {}.
-- Aucun hl.exec_cmd hors de l'autostart : `Hyprland --verify-config` exécute le code de premier niveau.

local MODULE = ...   -- nom passé par require ("lua/host")
local file = io.open("/etc/hostname")
local name = file and file:read("l") or ""
if file then
   file:close()
end

local ok, result = pcall(require, "hosts/" .. name)
if ok then
   return result or {}
end
if tostring(result):find("module 'hosts/" .. name .. "' not found", 1, true) then
   return {}
end
-- Erreur signalée ici, une fois ; un require() suivant (lua/autostart.lua) reçoit {} sans réexécuter le fichier de la machine
-- (require ne garde pas un module en erreur : ses règles seraient posées deux fois).
package.loaded[MODULE] = {}
error(result)
