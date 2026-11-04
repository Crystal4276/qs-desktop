#!/bin/sh
# Session choisie à l'écran de connexion (services/Greeter.qml), lancée par greetd sous l'utilisateur connecté : shell de connexion
# de l'utilisateur d'abord (/etc/profile, ~/.bash_profile… lus, comme le faisait SDDM), puis la commande `Exec` du fichier .desktop.
# X11 : par startx, sur le terminal virtuel de la session (XDG_VTNR, donné par pam_systemd).
# Usage : greeter-session.sh wayland|x11 <commande>
# Shell de connexion non POSIX (fish…) : /bin/sh de connexion à la place (/etc/profile, ~/.profile), comme le repli de SDDM.
kind=$1
command=$2
case "${SHELL##*/}" in
    sh|bash|zsh|dash|ksh|mksh) login=$SHELL ;;
    *) login=/bin/sh ;;
esac
case "$kind" in
    x11) exec "$login" -lc 'exec startx /bin/sh -c "$0" -- "vt$XDG_VTNR"' "$command" ;;
    *) exec "$login" -lc 'eval "exec $0"' "$command" ;;
esac
