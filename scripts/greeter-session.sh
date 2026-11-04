#!/bin/sh
# Session choisie à l'écran de connexion (services/Greeter.qml), lancée par greetd sous l'utilisateur connecté : shell de connexion
# de l'utilisateur d'abord (/etc/profile, ~/.bash_profile… lus, comme le faisait SDDM), puis la commande `Exec` du fichier .desktop.
# X11 : par startx, sur le terminal virtuel de la session (XDG_VTNR, donné par pam_systemd) ; startx recoupe les arguments de son
# client aux espaces : la commande passe par l'environnement, et le client est ce script (`x11-client`), sans autre argument.
# Usage : GREETER_SESSION_EXEC=<commande> greeter-session.sh wayland|x11 (greetd recolle ses arguments pour `sh -c` : la commande,
# avec ses espaces et guillemets, passe par l'environnement ; retirée avant le lancement).
# Shell de connexion non POSIX (fish…) : /bin/sh de connexion à la place (/etc/profile, ~/.profile), comme le repli de SDDM.
kind=$1
if [ "$kind" = x11-client ]; then
    command=$GREETER_SESSION_EXEC
    unset GREETER_SESSION_EXEC
    # Comme le xinitrc par défaut (et le Xsession de SDDM) : DISPLAY, XAUTHORITY transmis à systemd --user et D-Bus.
    for f in /etc/X11/xinit/xinitrc.d/?*.sh; do
        [ -x "$f" ] && . "$f"
    done
    unset f
    eval "exec $command"
fi
case "${SHELL##*/}" in
    sh|bash|zsh|dash|ksh|mksh) login=$SHELL ;;
    *) login=/bin/sh ;;
esac
case "$kind" in
    x11) exec "$login" -lc 'exec startx "$0" x11-client -- "vt$XDG_VTNR"' "$(readlink -f "$0")" ;;
    *) exec "$login" -lc 'command=$GREETER_SESSION_EXEC; unset GREETER_SESSION_EXEC; eval "exec $command"' ;;
esac
