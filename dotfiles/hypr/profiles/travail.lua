-- Profil « travail » (chargé par lua/profile.lua d'après scripts/profile.sh) : DigitalMicrograph sur 5, Windows sur 6,
-- Thunderbird sur 7, Discord-WhatsApp sur 8, Spotify sur 9 (lua/windowrules.lua). Mêmes règles que dotfiles/sway/profiles/travail.conf. Pas de démarrage
-- automatique.

-- DigitalMicrograph (Wine, dépôt GMSFreeAnalysis17), relevé sur la VM : « digitalmicrograph.exe », app_id avec le pilote Wayland
-- de Wine (défaut) comme classe X11 sous XWayland (GMS_WAYLAND=0) ; Hyprland les lit tous deux dans `class`.
hl.window_rule({ name = "digitalmicrograph-ws5", match = { class = "^(digitalmicrograph\\.exe)$" }, workspace = "5 silent" })

return {
   workspaces = { chat = 8, music = 9, mail = 7, windows = 6 },
}
