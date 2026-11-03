-- Machine « terrier » (chargée par lua/host.lua selon /etc/hostname). Écrans identifiés par description (marque modèle numéro de
-- série), jamais par connecteur : un connecteur (DP-2…) peut changer de nom sur un dock ou un autre câble (docs/ARCHITECTURE.md
-- § 3.1). Mêmes réglages que dotfiles/sway/hosts/terrier.conf. Aucun espace de travail attaché à un écran (services/Outputs.qml).
--
-- Taux de rafraîchissement : les LG 27GN950 ne proposent que 144 / 94,98 / 60 Hz. Le 60 Hz est le statu quo assumé.

local lgLeft  = "desc:LG Electronics 27GN950 207NTLEFY824"
local dell    = "desc:Dell Inc. Dell AW3418DW #ASPFPBQwWjbd"
local lgRight = "desc:LG Electronics 27GN950 207NTHMFY841"

hl.monitor({ output = lgLeft,  mode = "3840x2160@60",  position = "0x0",    scale = 1.5 })
hl.monitor({ output = dell,    mode = "3440x1440@100", position = "2560x0", scale = 1 })
hl.monitor({ output = lgRight, mode = "3840x2160@60",  position = "6000x0", scale = 1.5 })

-- Curseur au démarrage sur l'écran central (sélecteur d'écran : `desc:` accepté).
hl.config({ cursor = { default_monitor = dell } })

-- Fenêtres ouvertes sur les espaces 7 et 8 (écran de droite) renvoyées sur l'écran central, sauf Deluge et Thunderbird
-- (comme sous Sway).
hl.window_rule({ name = "ws7-to-center", match = { workspace = "7", class = "negative:^(deluge)$" }, monitor = dell })
hl.window_rule({ name = "ws8-to-center", match = { workspace = "8", class = "negative:^(org\\.mozilla\\.Thunderbird)$" }, monitor = dell })

-- Décodage vidéo matériel NVIDIA (VA-API, backend direct) : propre au GPU de cette machine (RTX 2080).
hl.env("NVD_BACKEND", "direct")

return {
   -- Matériel de cette machine.
   autostart = {
      "openrazer-daemon",
      "openrgb -p purple",
   },
}
