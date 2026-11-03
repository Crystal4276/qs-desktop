-- Réglages de cette machine : hosts/<hostname>.lua (écrans par description, règles qui les visent, matériel). Il renvoie une table
-- { autostart = { commandes } }, lancées par lua/autostart.lua. Pas de fichier pour cette machine : rien, et {}.
-- Aucun hl.exec_cmd hors de l'autostart : `Hyprland --verify-config` exécute le code de premier niveau.

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
error(result)
