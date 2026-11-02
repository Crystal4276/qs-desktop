#!/usr/bin/env bash
# (Re)lance l'instance de dev depuis le dépôt et affiche les erreurs du démarrage.
# Usage : scripts/dev.sh          relance
#         scripts/dev.sh stop     arrête
#         scripts/dev.sh log      suit le journal (Ctrl+C pour quitter)
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
log="${QS_DEV_LOG:-/tmp/qs-dev.log}"

case "${1:-}" in
    log) exec qs log -f -p "$repo" ;;
esac

# Une relance à la fois : deux appuis rapprochés sur le raccourci laisseraient deux instances.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/qs-dev.lock"
flock -n 9 || { echo "Relance déjà en cours."; exit 0; }

# Instance lancée depuis ce dépôt ? (`qs list` réussit aussi quand il n'y en a aucune : « No running instances ».)
running() { qs list -p "$repo" 2>/dev/null | grep -q "^Instance"; }

# Tue les instances de dev précédentes (celles lancées depuis ce dépôt uniquement) : `qs kill` n'en arrête qu'une par appel.
for _ in {1..10}; do
    running || break
    qs kill -p "$repo" >/dev/null 2>&1 || true
    sleep 0.3
done

[[ "${1:-}" == "stop" ]] && exit 0

# Répertoire et environnement hérités par les applications lancées depuis Quickshell : le dossier personnel, pas le dépôt. Lancé
# d'un terminal : XDG_CURRENT_DESKTOP repris de la session systemd (importé par Sway), sans les jetons d'activation à usage unique
# ni les variables du terminal.
cd "$HOME"
unset DESKTOP_STARTUP_ID XDG_ACTIVATION_TOKEN TERM COLORTERM VTE_VERSION GNOME_TERMINAL_SCREEN GNOME_TERMINAL_SERVICE
if [[ -z "${XDG_CURRENT_DESKTOP:-}" ]]; then
    desktop=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^XDG_CURRENT_DESKTOP=//p') || true
    [[ -n "$desktop" ]] && export XDG_CURRENT_DESKTOP="$desktop"
fi
nohup qs -p "$repo" >"$log" 2>&1 9>&- &   # 9>&- : l'instance ne garde pas le verrou
disown

# Laisse le temps au chargement, puis montre ce qui ne va pas.
# Le journal de l'instance (`qs log`) est à jour, contrairement à $log qui est écrit par blocs.
sleep 2
if ! running; then
    echo "Échec du démarrage :" >&2
    cat "$log" >&2
    exit 1
fi
# Sans effet, donc non affichés ici (ils restent dans `qs log`) : lignes vides de fichiers .desktop générés par SteamVR, échecs de la
# reconnexion automatique Bluetooth d'un appareil éteint (le panneau affiche les échecs des connexions demandées).
qs log -p "$repo" -r "quickshell.desktopentry.warning=false;quickshell.bluetooth.device.warning=false" | grep -E "WARN|ERROR" || echo "Démarré sans erreur."
# Avertissement attendu à chaque démarrage sous Sway, sans effet : « I3 event socket disconnected. »
if pgrep -u "$UID" -x dunst >/dev/null || pgrep -u "$UID" -x polkit-gnome-au >/dev/null; then
    echo "Dunst ou polkit-gnome tourne : notifications et polkit restent à l'ancien bureau (prise en main : scripts/takeover.sh)."
fi
