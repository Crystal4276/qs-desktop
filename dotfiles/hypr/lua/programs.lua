-- Programmes et chemins référencés par les binds et l'autostart.

local home = os.getenv("HOME")
-- Dépôt du bureau, via le lien de la config Quickshell (aucun chemin personnel).
local desktop = home .. "/.config/quickshell/desktop"

return {
   -- Guillemets doubles dans la valeur : chaîne Lua entre apostrophes.
   terminal    = 'gnome-terminal -- bash -c "neofetch; exec bash"',
   fileManager = "nemo",

   -- Bureau Quickshell : lancement et surveillance, appels IPC vers l'instance de cette session.
   desktop     = desktop .. "/scripts/desktop.sh",
   ipc         = desktop .. "/scripts/ipc.sh",
   -- Traces privées pour le prochain blocage à la reconnexion (sans arrêt automatique).
   thunderbird = "python3 '" .. (desktop .. "/scripts/thunderbird-diagnostic.py"):gsub("'", "'\\''") .. "' run",
}
