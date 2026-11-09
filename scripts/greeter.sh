#!/bin/sh
# Écran de connexion (docs/ARCHITECTURE.md § 9), lancé par greetd sous l'utilisateur `greeter` (dotfiles/greetd/config.toml), depuis
# la copie système du dépôt (scripts/greeter-setup.sh) :
#   greeter.sh          Sway minimal (dotfiles/greetd/sway.conf + écrans de la machine, dotfiles/sway/hosts/<hostname>.outputs.conf)
#   greeter.sh shell    lancé par ce Sway : Quickshell sur greeter.qml, puis fin de Sway (session choisie ou Quickshell arrêté)
# Nvidia : `--unsupported-gpu` toujours ; rendu Vulkan s'il est la seule carte (sinon Sway part sur l'autre).
# État et caches dans /var/lib/qs-desktop/greeter : `greeter` n'a pas de dossier personnel (/).
repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
state="${QS_GREETER_DIR:-/var/lib/qs-desktop}/greeter"   # QS_GREETER_DIR : banc (comme services/Greeter.qml)
export XDG_CACHE_HOME="$state/cache" XDG_STATE_HOME="$state/state" XDG_CONFIG_HOME="$state/config"
# Curseur du thème : paquet (/usr/share/icons) ou copie système d'install.sh (/usr/local/share/icons, hors du chemin par défaut
# de libXcursor / wlroots).
export XCURSOR_PATH="/usr/local/share/icons:/usr/share/icons:/usr/share/pixmaps"

if [ "${1:-}" = shell ]; then
    . "$repo/scripts/qs-env.sh"
    qs -p "$repo/greeter.qml"
    exec swaymsg exit
fi

config="${XDG_RUNTIME_DIR:?}/qs-greeter-sway.conf"
outputs="$repo/dotfiles/sway/hosts/$(cat /proc/sys/kernel/hostname).outputs.conf"
{
    cat "$repo/dotfiles/greetd/sway.conf"
    [ -f "$outputs" ] && echo "include \"$outputs\""
    echo "exec \"$repo/scripts/greeter.sh shell\""
} >"$config"

# --unsupported-gpu toujours : sans effet sans pilote Nvidia, et pas de course avec son chargement au démarrage (pilote hors
# initramfs). qs_nvidia_only dans un sous-shell : les réglages de qs-env.sh sont pour Quickshell, pas pour Sway.
if (. "$repo/scripts/qs-env.sh" && qs_nvidia_only); then
    export WLR_RENDERER="${WLR_RENDERER:-vulkan}"   # déjà fixé (banc) : gardé
fi
exec sway --unsupported-gpu -c "$config"
