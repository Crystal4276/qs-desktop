-- Profil « travail » (chargé par lua/profile.lua d'après scripts/profile.sh) : DigitalMicrograph sur l'espace 9, l'espace 7 libre.
-- Mêmes règles que dotfiles/sway/profiles/travail.conf. Pas de démarrage automatique.

-- DigitalMicrograph (Wine, dépôt GMSFreeAnalysis17) : classe « digitalmicrograph.exe » sous XWayland (StartupWMClass du
-- lanceur) ; même nom, casse possiblement différente, avec le pilote Wayland de Wine.
hl.window_rule({ name = "digitalmicrograph-ws9", match = { class = "(?i)^(digitalmicrograph\\.exe)$" }, workspace = "9 silent" })

return {}
