-- Profil « travail » (chargé par lua/profile.lua d'après scripts/profile.sh) : espace 5 libre, Discord-WhatsApp sur 6, Spotify
-- sur 7 (lua/windowrules.lua), DigitalMicrograph sur 9. Mêmes règles que dotfiles/sway/profiles/travail.conf. Pas de démarrage
-- automatique.

-- DigitalMicrograph (Wine, dépôt GMSFreeAnalysis17), relevé sur la VM : « digitalmicrograph.exe », app_id avec le pilote Wayland
-- de Wine (défaut) comme classe X11 sous XWayland (GMS_WAYLAND=0) ; Hyprland les lit tous deux dans `class`.
hl.window_rule({ name = "digitalmicrograph-ws9", match = { class = "^(digitalmicrograph\\.exe)$" }, workspace = "9 silent" })

return {
   workspaces = { chat = 6, music = 7 },
}
