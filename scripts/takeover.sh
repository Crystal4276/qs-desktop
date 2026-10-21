#!/usr/bin/env bash
# Passe la session Sway en cours à Quickshell, sans toucher aux fichiers de config (la bascule durable est la phase 10).
#  - arrête les outils que Quickshell remplace (Waybar, Dunst, swaybg, swayidle, polkit-gnome, nm-applet, blueman, udiskie) :
#    sinon polkit reste à polkit-gnome, et veille, montage automatique et fond d'écran tournent en double ;
#  - (re)lance l'instance de dev (scripts/dev.sh) : son agent polkit s'inscrit une fois polkit-gnome arrêté ;
#  - raccourcis → `qs ipc` jusqu'au prochain `reload` de Sway (lanceur, réglages, captures, volume et micro avec OSD, sortie
#    audio, luminosité, HDR, relance du shell). VPN (`$mod+u`, `$mod+i`) : inchangés.
# Usage : scripts/takeover.sh            prise en main (relançable)
#         scripts/takeover.sh restore    retour à l'ancien bureau : instance arrêtée, outils relancés, config Sway rechargée
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
state="${XDG_RUNTIME_DIR:-/tmp}/qs-takeover.cmds"   # commandes des outils arrêtés, pour `restore`

[[ -n "${SWAYSOCK:-}" ]] || { echo "Sway seulement (Hyprland : phase 9)." >&2; exit 1; }

# Nom de processus (comm, 15 caractères au plus) → outil remplacé. swaybg est relancé par Sway lui-même (`output … bg`).
tools=(waybar dunst swaybg swayidle polkit-gnome-au nm-applet blueman-applet blueman-tray udiskie)

if [[ "${1:-}" == "restore" ]]; then
    "$repo/scripts/dev.sh" stop
    if [[ -f "$state" ]]; then
        while IFS= read -r cmd; do
            swaymsg exec "$cmd" >/dev/null
        done <"$state"
        rm -f "$state"
    fi
    swaymsg reload >/dev/null   # raccourcis d'origine ; relance aussi Waybar (exec_always) et swaybg
    echo "Ancien bureau rétabli."
    exit 0
fi

for name in "${tools[@]}"; do
    for pid in $(pgrep -u "$UID" -x "$name" || true); do
        # Ligne de commande exacte, pour la relancer telle quelle (blueman-tray : relancé par blueman-applet ; swaybg : par Sway).
        if [[ "$name" != swaybg && "$name" != blueman-tray ]]; then
            cmd=$(xargs -0 printf '%q ' </proc/"$pid"/cmdline)
            grep -qxF "$cmd" "$state" 2>/dev/null || echo "$cmd" >>"$state"
        fi
        kill "$pid" 2>/dev/null || true
    done
done

"$repo/scripts/dev.sh"

ipc="qs ipc -p $(printf '%q' "$repo") call"
bind() { swaymsg "bindsym $1 exec $ipc $2" >/dev/null; }
bind Mod4+w "launcher toggle"
bind Mod4+Escape "settings toggle"
bind Print "screenshot area"
bind Mod4+Print "screenshot screen"
bind Mod4+Shift+Print "screenshot window"
bind "--locked XF86AudioRaiseVolume" "audio volumeUp"
bind "--locked XF86AudioLowerVolume" "audio volumeDown"
bind "--locked XF86AudioMute" "audio toggleMute"
bind "--locked XF86AudioMicMute" "audio toggleMicMute"
bind Mod4+s "audio cycleSink"
bind "--locked XF86MonBrightnessUp" "brightness up"
bind "--locked XF86MonBrightnessDown" "brightness down"
bind Mod4+d "display toggleHdr"
swaymsg "bindsym Mod4+Ctrl+w exec $(printf '%q' "$repo/scripts/dev.sh")" >/dev/null   # remplace `killall waybar && waybar`

echo "Quickshell aux commandes. Retour : scripts/takeover.sh restore"
