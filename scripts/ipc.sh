#!/bin/sh
# `qs ipc call` vers le bureau de cette session (instance lancée par scripts/desktop.sh, désignée par son PID) : utilisé par les
# raccourcis des configs compositeur (dotfiles/). Pas `-c desktop` : les copies du dépôt (bancs de test) ont le même identifiant
# et pourraient recevoir l'appel. Sans instance connue (lancée à la main) : `-c desktop`.
# Usage : ipc.sh <cible> <fonction> [arguments…]      code de sortie non nul si aucune instance ne répond
if [ -n "$SWAYSOCK" ]; then
    session="$(basename "$SWAYSOCK" .sock)"
else
    session="$HYPRLAND_INSTANCE_SIGNATURE"
fi
pid="$(cat "${XDG_RUNTIME_DIR:-/tmp}/qs-desktop.$session.pid" 2>/dev/null)"
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    exec qs ipc --pid "$pid" call "$@"
fi
exec qs ipc -c desktop call "$@"
