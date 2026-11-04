#!/bin/sh
# Session choisie à l'écran de connexion (services/Greeter.qml), lancée par greetd sous l'utilisateur connecté : shell de connexion
# de l'utilisateur d'abord (/etc/profile, ~/.bash_profile… lus, comme le faisait SDDM), puis la commande `Exec` du fichier .desktop.
# X11 : par startx, sur le terminal virtuel de la session (XDG_VTNR, donné par pam_systemd).
# Usage : greeter-session.sh wayland|x11 <commande>
kind=$1
command=$2
case "$kind" in
    x11) exec "${SHELL:-/bin/sh}" -lc 'exec startx /bin/sh -c "$0" -- "vt$XDG_VTNR"' "$command" ;;
    *) exec "${SHELL:-/bin/sh}" -lc 'eval "exec $0"' "$command" ;;
esac
