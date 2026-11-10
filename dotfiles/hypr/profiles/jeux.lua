-- Profil « jeux » (chargé par lua/profile.lua d'après scripts/profile.sh) : Steam, ses jeux, EVE, gamescope et Deluge.
-- Mêmes règles que dotfiles/sway/profiles/jeux.conf. Renvoie { autostart = { commandes } }, lancées par lua/autostart.lua.
-- Aucun hl.exec_cmd ici : `Hyprland --verify-config` exécute le code de premier niveau.

-- Applications de démarrage envoyées sur leur espace sans voler le focus.
hl.window_rule({ name = "steam-ws9",  match = { class = "^(steam)$" },  workspace = "9 silent" })
hl.window_rule({ name = "deluge-ws7", match = { class = "^(deluge)$" }, workspace = "7 silent" })

-- Comme sous Sway : le dialogue d'ajout affiche l'espace de Deluge, même si
-- GTK ne transmet pas de jeton d'activation. Après « 7 silent » pour le remplacer.
hl.window_rule({
   name = "deluge-add-torrents",
   match = { class = "^(deluge)$", title = "^Add Torrents.*$" },
   workspace = "7",
})

-- Fenêtres de Steam flottantes et centrées.
for _, rule in ipairs({
   { name = "steam-settings",       title = "^(Steam Settings)$" },
   { name = "steam-special-offers", title = "^(Special Offers)$" },
}) do
   hl.window_rule({
      name   = rule.name,
      match  = { class = "^(steam)$", title = rule.title },
      float  = true,
      center = true,
   })
end

------------------------------------------------------------------------------
-- Jeux Steam
------------------------------------------------------------------------------

hl.window_rule({
   name      = "steam-games",
   match     = { class = "^(steam_app_[0-9]+)$" },
   workspace = "3 silent",
   tile      = true,
})

-- Lanceur EVE.
hl.window_rule({
   name      = "eve-launcher",
   match     = { class = "^(steam_app_8500)$", title = "^(EVE Launcher)$" },
   workspace = "9 silent",
   float     = true,
   size      = "1600 800",
   center    = true,
})

-- Fenêtre de zone de notification d'EVE : ni titre ni titre initial.
hl.window_rule({
   name      = "eve-systray",
   match     = { class = "^(steam_app_8500)$", title = "^$", initial_title = "^$" },
   workspace = "9 silent",
   float     = true,
   move      = "1280 20",
})

-- Fenêtre de jeu EVE.
hl.window_rule({
   name      = "eve-game",
   match     = { class = "^(steam_app_8500)$", initial_title = "^(EVE)$" },
   workspace = "3",
   tile      = true,
})

------------------------------------------------------------------------------
-- Gamescope
------------------------------------------------------------------------------

hl.window_rule({
   name      = "gamescope",
   match     = { class = "^(gamescope)$" },
   float     = true,
   animation = "none",
   workspace = "3 silent",
})

return {
   autostart = {
      "deluge",
      -- Attend que le compositeur soit posé avant de démarrer.
      "sleep 4 && steam",
   },
}
