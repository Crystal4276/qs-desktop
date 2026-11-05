-- Variables d'environnement transmises aux processus lancés par Hyprland.
--
-- hl.env est POSITIONNEL — hl.env(nom, valeur) — et la valeur doit être une
-- chaîne. hl.env("GDK_SCALE", 2) lèverait une erreur.
-- Chargé avant autostart.lua, qui dépend de ces valeurs.

hl.env("XCURSOR_SIZE", "48")
hl.env("XCURSOR_THEME", "catppuccin-mocha-green-cursors")   -- nom installé (minuscules), comme sous Sway
-- Hyprcursor choisit sinon le premier thème disponible avant le setcursor de l'autostart.
hl.env("HYPRCURSOR_THEME", "catppuccin-mocha-green-cursors")
hl.env("HYPRCURSOR_SIZE", "48")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("DESKTOP_SESSION", "Hyprland")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- NVD_BACKEND (NVIDIA) : hosts/<machine>.lua.
