#!/usr/bin/env bash
# Passe la session Sway ou Hyprland en cours à Quickshell, sans toucher aux fichiers de config (la bascule durable est la phase 10).
#  - arrête les outils que Quickshell remplace (Waybar, Dunst, swaybg, swayidle ou hypridle, polkit-gnome, nm-applet, blueman, udiskie) :
#    sinon polkit reste à polkit-gnome, et veille, montage automatique et fond d'écran tournent en double ;
#  - (re)lance l'instance de dev (scripts/dev.sh) : son agent polkit s'inscrit une fois polkit-gnome arrêté ;
#  - raccourcis → `qs ipc` jusqu'au prochain `reload` du compositeur (lanceur, réglages, captures, volume et micro avec OSD, sortie
#    audio, luminosité, HDR, relance du shell). VPN (`$mod+u`, `$mod+i`) : inchangés.
# Usage : scripts/takeover.sh            prise en main (relançable)
#         scripts/takeover.sh restore    retour à l'ancien bureau : instance arrêtée, outils relancés, config du compositeur rechargée
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"

# Commandes des outils arrêtés, pour `restore`. Propre à cette session (socket de Sway, instance d'Hyprland) : après un redémarrage du
# compositeur, son autostart a déjà relancé les outils, et l'état de l'ancienne session les relancerait en double.
if [[ -n "${SWAYSOCK:-}" ]]; then
    session="$(basename "$SWAYSOCK" .sock)"
    # swaybg et Waybar : relancés par Sway lui-même (`output … bg`, `exec_always`) au `reload` de `restore`.
    restarted_by_reload=(swaybg waybar)
    tools=(waybar dunst swaybg swayidle polkit-gnome-au nm-applet blueman-applet blueman-tray udiskie)
    c_exec() { swaymsg exec "$1" >/dev/null; }
    c_reload() { swaymsg reload >/dev/null; }
    # bind <touche Sway> <touche Hyprland> <verrouillée : locked ou rien> <commande>
    bind() { swaymsg "bindsym ${3:+--locked }$1 exec $4" >/dev/null; }
elif [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    session="$HYPRLAND_INSTANCE_SIGNATURE"
    # `reload` ne repasse pas par `hyprland.start` (ton autostart, nordvpn compris : vérifié) : rien n'est relancé par lui.
    restarted_by_reload=()
    tools=(waybar dunst swaybg hypridle polkit-gnome-au nm-applet blueman-applet blueman-tray udiskie)
    c_exec() { hyprctl dispatch "hl.dsp.exec_cmd([==[$1]==])" >/dev/null; }
    c_reload() { hyprctl reload >/dev/null; }
    bind() {
        local options=""
        [[ -n "$3" ]] && options=", { repeating = true, locked = true }"   # comme tes touches multimédia
        hyprctl eval "hl.unbind(\"$2\") hl.bind(\"$2\", hl.dsp.exec_cmd([==[$4]==])$options)" >/dev/null
    }
else
    echo "Ni Sway ni Hyprland." >&2
    exit 1
fi

state="${XDG_RUNTIME_DIR:-/tmp}/qs-takeover.$session.cmds"
rm -f "${XDG_RUNTIME_DIR:-/tmp}"/qs-takeover.cmds   # ancien nom, non lié à une session

if [[ "${1:-}" == "restore" ]]; then
    "$repo/scripts/dev.sh" stop
    systemctl --user unmask --runtime dunst.service >/dev/null 2>&1 || true
    if [[ -f "$state" ]]; then
        while IFS= read -r cmd; do
            c_exec "$cmd"
        done <"$state"
        rm -f "$state"
    fi
    c_reload   # raccourcis d'origine
    echo "Ancien bureau rétabli."
    exit 0
fi

# Quickshell relancé ou planté : le nom D-Bus des notifications est libre un instant, une notification réactiverait Dunst, qui le
# garderait. Bloqué jusqu'au prochain démarrage de session ou `restore` (--runtime : aucun fichier de config touché).
systemctl --user mask --runtime dunst.service >/dev/null 2>&1 || true

for name in "${tools[@]}"; do
    for pid in $(pgrep -u "$UID" -x "$name" || true); do
        # Ligne de commande exacte, pour la relancer telle quelle. blueman-tray : relancé par blueman-applet ; une seconde Waybar
        # empilerait deux barres là où le `reload` en relance une.
        if [[ "$name" != blueman-tray && " ${restarted_by_reload[*]} " != *" $name "* ]]; then
            # Script Python : relancé par son propre nom, sinon il s'appelle `python` et la prise en main suivante ne le voit plus.
            # Ligne de commande illisible (outil terminé entre-temps) ou vide : rien à enregistrer (sans ce garde-fou, `set -e`
            # arrêtait le script avant Quickshell, Dunst bloqué : bureau sans barre ni notifications).
            argv=()
            mapfile -d '' -t argv 2>/dev/null </proc/"$pid"/cmdline || true
            if [[ ${#argv[@]} -gt 0 ]]; then
                [[ "${argv[0]##*/}" == python* ]] && argv=("${argv[@]:1}")
                cmd=$(printf '%q ' "${argv[@]}")
                grep -qxF "$cmd" "$state" 2>/dev/null || echo "$cmd" >>"$state"
            fi
        fi
        kill "$pid" 2>/dev/null || true
    done
done

# L'instance ne démarre pas : retour à l'ancien bureau, plutôt qu'une session sans barre ni notifications.
if ! "$repo/scripts/dev.sh"; then
    echo "Quickshell n'a pas démarré : retour à l'ancien bureau." >&2
    "$repo/scripts/takeover.sh" restore
    exit 1
fi

ipc="qs ipc -p $(printf '%q' "$repo") call"
bind Mod4+w "SUPER + W" "" "$ipc launcher toggle"
bind Mod4+Escape "SUPER + ESCAPE" "" "$ipc settings toggle"
bind Print "PRINT" "" "$ipc screenshot area"
bind Mod4+Print "SUPER + PRINT" "" "$ipc screenshot screen"
bind Mod4+Shift+Print "SUPER + SHIFT + PRINT" "" "$ipc screenshot window"
bind XF86AudioRaiseVolume XF86AudioRaiseVolume locked "$ipc audio volumeUp"
bind XF86AudioLowerVolume XF86AudioLowerVolume locked "$ipc audio volumeDown"
bind XF86AudioMute XF86AudioMute locked "$ipc audio toggleMute"
bind XF86AudioMicMute XF86AudioMicMute locked "$ipc audio toggleMicMute"
bind Mod4+s "SUPER + S" "" "$ipc audio cycleSink"
bind XF86MonBrightnessUp XF86MonBrightnessUp locked "$ipc brightness up"
bind XF86MonBrightnessDown XF86MonBrightnessDown locked "$ipc brightness down"
bind Mod4+d "SUPER + D" "" "$ipc display toggleHdr"
bind Mod4+Ctrl+w "SUPER + CTRL + W" "" "$(printf '%q' "$repo/scripts/dev.sh")"   # remplace `killall waybar && waybar`

echo "Quickshell aux commandes. Retour : scripts/takeover.sh restore"
