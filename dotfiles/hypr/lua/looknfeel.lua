-- Apparence : bordures, décorations, animations.

local palette = require("lua/palette")

hl.config({
   general = {
      gaps_in     = 5,
      gaps_out    = 10,
      border_size = 1,

      -- La clé pointée hyprlang `col.active_border` devient une sous-table.
      col = {
         active_border   = palette.overlay1,
         inactive_border = palette.surface1,
      },

      resize_on_border = false,
      allow_tearing    = false,
      layout           = "dwindle",
   },

   decoration = {
      rounding         = 17,
      active_opacity   = 1.0,
      inactive_opacity = 1.0,

      shadow = {
         enabled      = true,
         range        = 4,
         render_power = 3,
         color        = "rgba(1a1a1aee)",
      },

      blur = {
         enabled  = true,
         size     = 3,
         passes   = 1,
         vibrancy = 0.1696,
      },
   },

   -- Interrupteur global. Les animations elles-mêmes se déclarent hors de
   -- hl.config, via hl.curve et hl.animation ci-dessous.
   animations = {
      enabled = true,
   },

   -- Mise à l'échelle des fenêtres XWayland lissée (polices de Steam nettes en scale 1.5 ; défaut : true).
   xwayland = {
      use_nearest_neighbor = false,
   },
})

-- Courbes. Remplace `bezier = nom,x0,y0,x1,y1`.
-- hl.curve couvre aussi les ressorts (type = "spring").
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },       { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1.0 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })

-- Animations. Remplace `animation = feuille, actif, vitesse, courbe, style`.
-- « default » est une courbe intégrée, à ne pas redéfinir.
hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
-- Rallumage des écrans après la veille sans fondu : avec celui hérité de `fade`, le réveil était plus lent que sous Sway (validé
-- par toi le 2026-11-03).
hl.animation({ leaf = "fadeDpms",      enabled = false })
