-- Dalle interne du laptop : échelle 1, comme l’écran central de terrier.
-- Description Hyprland (sans la virgule du fabricant EDID), pas de connecteur en dur.
hl.monitor({
   output = "desc:China Star Optoelectronics Technology Co. Ltd 0x1471",
   mode = "preferred",
   position = "auto",
   scale = 1,
})

-- Windows 11 : console SPICE sur 5, sans changer l'espace courant.
hl.window_rule({
   name = "windows11-console",
   match = { class = "^qs-windows11$" },
   workspace = "5 silent",
   float = false,
})

return {}
