#!/usr/bin/env bash
# Bureau Quickshell de la session : config `desktop` (~/.config/quickshell/desktop → ce dépôt), lancée par l'autostart de Sway et
# d'Hyprland (dotfiles/). Un seul processus porte tout le bureau (ARCHITECTURE.md § 11.2) : s'il s'arrête, il est relancé tant que
# la session dure ; plus de 5 arrêts en une minute : abandon, avec un message du compositeur.
# Usage : desktop.sh           autostart : lance l'instance, chaque écran affiche le premier espace de son bloc (1 / 4 / 7), surveille
#         desktop.sh restart   relance la surveillance et l'instance depuis l'environnement de l'appelant ($mod+Ctrl+W,
#                              scripts/dev.sh), sans toucher aux espaces, et affiche les erreurs du démarrage
#         desktop.sh stop      arrête la surveillance et l'instance
#         desktop.sh log       suit le journal de l'instance (Ctrl+C pour quitter)
#         desktop.sh pid       PID de l'instance (scripts/perf.sh)
# Instance visée par son PID, jamais par `-c desktop` : toutes les copies du dépôt (bancs de test) ont le même identifiant
# (`//@ pragma ShellId desktop`), un `qs kill -c desktop` les arrêterait toutes.
set -uo pipefail

repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
runtime="${XDG_RUNTIME_DIR:-/tmp}"
log="$runtime/qs-desktop.log"

if [[ -n "${SWAYSOCK:-}" ]]; then
    session="$(basename "$SWAYSOCK" .sock)"
    alive() { swaymsg -t get_version >/dev/null 2>&1; }
    warn() { swaymsg exec "swaynag -t warning -m \"$1\"" >/dev/null 2>&1; }
elif [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    session="$HYPRLAND_INSTANCE_SIGNATURE"
    alive() { hyprctl version >/dev/null 2>&1; }   # le dossier de l'instance reste après la fin d'Hyprland : pas un test de fichier
    warn() { hyprctl notify 0 30000 0 "$1" >/dev/null 2>&1; }
else
    echo "Ni Sway ni Hyprland." >&2
    exit 1
fi
# Propres à cette session : verrou de la surveillance (son PID y est écrit) et PID de l'instance qu'elle a lancée.
lock="$runtime/qs-desktop.$session.lock"
pidfile="$runtime/qs-desktop.$session.pid"

instance() {
    local pid
    pid="$(cat "$pidfile" 2>/dev/null)" || return 1
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && echo "$pid"
}

# Répertoire et environnement hérités par les applications lancées depuis le bureau : le dossier personnel, sans les jetons
# d'activation à usage unique ni les variables d'un terminal (lancement à la main) ; réglages du processus (docs/PERFORMANCE.md).
prepare() {
    cd "$HOME" || exit 1
    unset DESKTOP_STARTUP_ID XDG_ACTIVATION_TOKEN TERM COLORTERM VTE_VERSION GNOME_TERMINAL_SCREEN GNOME_TERMINAL_SERVICE
    if [[ -z "${XDG_CURRENT_DESKTOP:-}" ]]; then
        local desktop
        desktop=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^XDG_CURRENT_DESKTOP=//p') || true
        [[ -n "$desktop" ]] && export XDG_CURRENT_DESKTOP="$desktop"
    fi
    # PERF_NO_ENV : sans les réglages du processus (mesures A/B de scripts/perf.sh).
    [[ -n "${PERF_NO_ENV:-}" ]] || . "$repo/scripts/qs-env.sh"
}

# Surveillance en cours dans cette session : son PID (verrou tenu, processus `desktop.sh watch`).
supervisor() {
    local pid
    flock -n "$lock" true 2>/dev/null && return 1
    pid="$(cat "$lock" 2>/dev/null)"
    [[ -n "$pid" ]] && grep -qa "desktop.sh" "/proc/$pid/cmdline" 2>/dev/null && echo "$pid"
}

# watch [home]
watch() {
    exec 9>>"$lock"   # sans vider le fichier : il porte le PID d'une surveillance peut-être en cours
    flock -n 9 || { echo "Bureau déjà surveillé dans cette session."; exit 0; }
    echo $$ >"$lock"   # lu seulement tant que le verrou est tenu (supervisor) : jamais un PID périmé
    prepare
    local home="${1:-}" starts=() now t pid
    while alive; do
        qs -c desktop >"$log" 2>&1 9>&- &
        pid=$!
        echo "$pid" >"$pidfile"
        if [[ -n "$home" ]]; then
            for _ in $(seq 1 50); do qs ipc --pid "$pid" call outputs home >/dev/null 2>&1 && break; sleep 0.2; done
            home=""
        fi
        wait "$pid"
        alive || break
        now=$(date +%s)
        local recent=()
        for t in "${starts[@]}"; do (( now - t < 60 )) && recent+=("$t"); done
        starts=("${recent[@]}" "$now")
        if (( ${#starts[@]} > 5 )); then
            warn "Quickshell s'est arrêté 5 fois en une minute : bureau non relancé. Journal : $log ; relance : Super+Ctrl+W"
            break
        fi
        sleep 1
    done
    rm -f "$pidfile"
}

kill_instance() {
    local pid
    pid="$(instance)" || return 0
    qs kill --pid "$pid" >/dev/null 2>&1 || kill "$pid" 2>/dev/null
    for _ in {1..20}; do kill -0 "$pid" 2>/dev/null || return 0; sleep 0.1; done
    kill -9 "$pid" 2>/dev/null   # bloqué (gestionnaire de plantage)
}

# Surveillance arrêtée d'abord (elle relancerait l'instance), puis l'instance.
stop() {
    local pid
    if pid="$(supervisor)"; then
        kill "$pid" 2>/dev/null
        for _ in {1..20}; do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    fi
    kill_instance
    rm -f "$pidfile"
}

case "${1:-}" in
    "")
        watch home
        ;;
    watch)
        watch
        ;;
    log)
        pid="$(instance)" || { echo "Aucune instance lancée par desktop.sh dans cette session." >&2; exit 1; }
        exec qs log -f --pid "$pid"
        ;;
    stop)
        stop
        ;;
    pid)
        instance
        ;;
    restart)
        # Nouvelle surveillance, partie de l'environnement de l'appelant (variables de scripts/perf.sh ab, comme l'ancien dev.sh) ;
        # une relance voulue ne compte donc pas parmi les arrêts de la précédente. Détachée de ce terminal.
        old="$(instance)" || old=""
        stop
        setsid -f "$0" watch >/dev/null 2>&1 </dev/null
        pid=""
        for _ in {1..30}; do
            pid="$(instance)" && [[ "$pid" != "$old" ]] && break
            pid=""
            sleep 0.2
        done
        sleep 1.5
        if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
            echo "Échec du démarrage :" >&2
            cat "$log" >&2
            exit 1
        fi
        # Sans effet, donc non affichés ici (ils restent dans `qs log`) : lignes vides de fichiers .desktop générés par SteamVR,
        # échecs de la reconnexion automatique Bluetooth d'un appareil éteint.
        qs log --pid "$pid" -r "quickshell.desktopentry.warning=false;quickshell.bluetooth.device.warning=false" | grep -E "WARN|ERROR" \
            || echo "Démarré sans erreur."
        ;;
    *)
        echo "Usage : $0 [restart|stop|log]" >&2
        exit 2
        ;;
esac
