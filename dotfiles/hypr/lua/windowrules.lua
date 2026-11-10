-- Règles de fenêtres.
--
-- L'ORDRE COMPTE : les règles sont évaluées de haut en bas. Il reproduit
-- celui de hyprland.conf, avec les corrections de parité Sway ci-dessous.
--
-- Structure : les critères vont dans `match`, les effets sont des clés soeurs.
-- Les 39 lignes hyprlang se replient ici en 23 règles, parce que la conversion
-- 0.53 avait dû dédoubler chaque `float, center` en deux lignes distinctes.
--
-- Chaque règle porte un `name` : ça rend la sortie de `hyprctl` lisible et ça
-- permet de désactiver une règle à la volée pour bissecter un problème
-- (la valeur de retour expose :set_enabled(false)).

------------------------------------------------------------------------------
-- Applications de démarrage envoyées sur leur espace sans voler le focus
-- (c'est ce que signifie « silent »).
------------------------------------------------------------------------------

hl.window_rule({ name = "discord-ws5",    match = { class = "^(discord)$" },   workspace = "5 silent" })
hl.window_rule({ name = "whatsdesk-ws5",  match = { class = "^(whatsdesk)$" }, workspace = "5 silent" })
-- Web apps Discord et WhatsApp (classes relevées sur la session, comme les `assign` de Sway).
-- Discord : classe selon l'adresse de départ, avec ou sans numéro de salon.
hl.window_rule({ name = "discord-web-ws5",  match = { class = "^(chrome-discord\\.com__channels_@me(_[0-9]+)?-Default)$" },      workspace = "5 silent" })
hl.window_rule({ name = "whatsapp-web-ws5", match = { class = "^(chrome-web\\.whatsapp\\.com__-Default)$" },                         workspace = "5 silent" })

-- La classe réelle est « Spotify » avec une majuscule (fenêtre X11, relevée sur
-- la session en cours). La conversion 0.53 l'avait passée en minuscules, ce qui
-- cassait silencieusement cette règle — RE2 est sensible à la casse.
-- La forme [Ss] couvre les deux orthographes sans rien coûter.
hl.window_rule({ name = "spotify-ws6",    match = { class = "^([Ss]potify)$" }, workspace = "6 silent" })

-- Steam et Deluge (profil jeux), DigitalMicrograph (profil travail) : profiles/<profil>.lua.

-- Thunderbird est passé à un app-id natif Wayland ; valeur confirmée sur la
-- session en cours.
hl.window_rule({ name = "thunderbird-ws8", match = { class = "^(org\\.mozilla\\.Thunderbird)$" }, workspace = "8 silent" })

------------------------------------------------------------------------------
-- Ouverture de fichiers dans une application déjà lancée.
------------------------------------------------------------------------------

-- Exceptions au focus_on_activate global : les autres applications restent inchangées.
hl.window_rule({
   name = "file-open-focus",
   match = { class = "^(deluge|geany|chromium)$" },
   focus_on_activate = true,
})

------------------------------------------------------------------------------
-- Fenêtres flottantes et centrées
------------------------------------------------------------------------------

local floatingCentered = {
   { name = "gnome-disks",           match = { class = "^(gnome-disks)$" } },
   { name = "blueman-manager",       match = { class = "^(blueman-manager)$" } },
   { name = "volume-control",        match = { title = "^(Volume Control)$" } },
   { name = "virt-manager",          match = { class = "^(virt-manager)$" } },
   { name = "calculator",            match = { title = "^(Calculator)$" } },
   { name = "nm-connection-editor",  match = { class = "^(nm-connection-editor)$" } },
}

for _, rule in ipairs(floatingCentered) do
   hl.window_rule({
      name   = rule.name,
      match  = rule.match,
      float  = true,
      center = true,
   })
end

-- Contenu externe : placement par origine dans lua/openorigin.lua, jamais par workspace source.

------------------------------------------------------------------------------
-- Règles générales (en dernier)
------------------------------------------------------------------------------

-- Ignore les demandes de maximisation venues des applications.
hl.window_rule({
   name           = "suppress-maximize",
   match          = { class = ".*" },
   suppress_event = "maximize",
})

-- RESTAURÉE. Supprimée au lieu d'être convertie lors du passage en 0.53 : c'est
-- la seule windowrulev2 du fichier qui a disparu sans être retraduite, alors que
-- les 32 autres l'ont toutes été. Corrige des problèmes de glisser-déposer avec
-- les fenêtres XWayland sans titre ni classe.
-- Forme reprise telle quelle de /usr/share/hypr/hyprland.lua.
hl.window_rule({
   name  = "fix-xwayland-drags",
   match = {
      class      = "^$",
      title      = "^$",
      xwayland   = true,
      float      = true,
      fullscreen = false,
      pin        = false,
   },
   no_focus = true,
})
