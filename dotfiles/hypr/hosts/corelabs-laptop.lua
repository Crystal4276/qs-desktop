-- Dalle interne du laptop : échelle 1, comme l’écran central de terrier.
-- Description Hyprland (sans la virgule du fabricant EDID), pas de connecteur en dur.
-- Capot fermé : dalle éteinte, rallumée à l'ouverture ; état relu à chaque chargement (le `hyprctl reload` du réveil la
-- rallumerait). Veille : logind.
local function panel(disabled)
   hl.monitor({
      output = "desc:China Star Optoelectronics Technology Co. Ltd 0x1471",
      mode = "preferred",
      position = "auto",
      scale = 1,
      disabled = disabled,
   })
end
local lid = io.open("/proc/acpi/button/lid/LID0/state")
panel(lid ~= nil and lid:read("a"):find("closed") ~= nil)
if lid then
   lid:close()
end
hl.bind("switch:on:Lid Switch", function() panel(true) end, { locked = true })
hl.bind("switch:off:Lid Switch", function() panel(false) end, { locked = true })

-- Windows 11 : console SPICE sur l’espace du profil, sans changer l’espace courant.
local profile = require("lua/profile")
hl.window_rule({
   name = "windows11-console",
   match = { class = "^qs-windows11$" },
   workspace = (profile.workspaces.windows or 5) .. " silent",
   float = false,
})

return {}
