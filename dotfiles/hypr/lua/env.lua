-- Variables d'environnement transmises aux processus lancés par Hyprland.
--
-- hl.env est POSITIONNEL — hl.env(nom, valeur) — et la valeur doit être une
-- chaîne. hl.env("GDK_SCALE", 2) lèverait une erreur.
-- Chargé avant autostart.lua, qui dépend de ces valeurs.

hl.env("XCURSOR_SIZE", "48")
hl.env("XCURSOR_THEME", "Catppuccin-Mocha-Green-Cursors")
hl.env("HYPRCURSOR_SIZE", "48")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("DESKTOP_SESSION", "Hyprland")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- RESTAURÉ. Supprimé par erreur lors de la conversion 0.53 (aucune trace
-- d'intention dans le diff, le reste du bloc env était intact).
-- Indique à NVIDIA VA-API d'utiliser le backend direct pour le décodage vidéo
-- matériel sous Wayland. Le GPU de cette machine est une RTX 2080.
hl.env("NVD_BACKEND", "direct")
