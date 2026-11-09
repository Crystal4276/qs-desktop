#!/usr/bin/env bash
# Targeted Intel PMU access; keep the system perf_event_paranoid setting unchanged.
set -euo pipefail
repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
state=/var/lib/qs-desktop/intel-gpu
binary=/usr/bin/intel_gpu_top
hook=/etc/pacman.d/hooks/90-qs-intel-gpu.hook
dry=""
[[ "${1:-}" == --dry-run ]] && { dry=1; shift; }
action="${1:-}"
[[ "$action" == install || "$action" == uninstall ]] || { echo 'Usage: intel-gpu-setup.sh [--dry-run] install|uninstall' >&2; exit 2; }
[[ "$action" != uninstall || -d "$state" ]] || exit 0
if [[ -n "$dry" ]]; then
    echo "+ Intel GPU: $action CAP_PERFMON on $binary and package hook $hook"
    exit 0
fi
if [[ "$action" == install ]]; then
    [[ -x "$binary" ]] || { echo '! intel-gpu-tools requis pour la charge Intel' >&2; exit 1; }
    if [[ -f "$state/caps" ]] && cmp -s "$repo/dotfiles/pacman/hooks/90-qs-intel-gpu.hook" "$hook" \
        && [[ "$(getcap "$binary")" == "$binary cap_perfmon=ep" ]]; then
        echo '= Intel GPU permission and package hook already configured'; exit 0
    fi
fi
# One authenticated transaction, also usable from install.sh without a terminal.
pkexec /usr/bin/bash -s -- "$action" "$state" "$binary" "$hook" "$repo/dotfiles/pacman/hooks/90-qs-intel-gpu.hook" <<'ROOT'
set -euo pipefail
action=$1 state=$2 binary=$3 hook=$4 source=$5
caps() { local value; value=$(getcap "$binary"); value=${value#"$binary"}; printf '%s' "${value# }"; }
restore_caps() { if [[ -n "$1" ]]; then setcap "$1" "$binary"; else setcap -r "$binary" 2>/dev/null || [[ -z "$(caps)" ]]; fi; }
if [[ "$action" == uninstall ]]; then
    [[ -d "$state" ]] || exit 0
    if [[ -f "$hook" ]] && ! cmp -s "$source" "$hook"; then
        echo '! Intel GPU hook modified since installation; left in place' >&2; exit 1
    fi
    if [[ -x "$binary" && -f "$state/caps" ]]; then
        if [[ "$(caps)" == cap_perfmon=ep ]]; then restore_caps "$(cat "$state/caps")"
        else echo '= Intel GPU capabilities changed since installation; current rights preserved'; fi
    fi
    rm -f "$hook"
    [[ ! -f "$state/hook" ]] || cp -a "$state/hook" "$hook"
    rm -rf "$state"
    exit 0
fi
[[ -f "$binary" && ! -L "$binary" && -x "$binary" && "$(stat -c %u "$binary")" == 0 ]] || {
    echo '! Expected a root-owned Intel GPU executable' >&2; exit 1;
}
[[ ! -L "$hook" && ( ! -e "$hook" || -f "$hook" ) ]] || exit 1
previous=$(mktemp -d)
oldcaps=$(caps)
fresh=""; replaced=""
[[ ! -f "$hook" ]] || cp -a "$hook" "$previous/hook"
cleanup() {
    status=$?
    if [[ "$status" != 0 ]]; then
        restore_caps "$oldcaps" || true
        if [[ -n "$replaced" ]]; then
            rm -f "$hook"
            [[ ! -f "$previous/hook" ]] || cp -a "$previous/hook" "$hook"
        fi
        [[ -z "$fresh" ]] || rm -rf "$state"
    fi
    rm -rf "$previous"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
if [[ ! -d "$state" ]]; then
    fresh=1
    install -d -m 755 "$state"
    printf '%s\n' "$oldcaps" > "$state/caps"
    [[ ! -f "$previous/hook" ]] || cp -a "$previous/hook" "$state/hook"
fi
install -d -m 755 "${hook%/*}"
install -m 644 "$source" "$previous/new-hook"
replaced=1
install -m 644 "$previous/new-hook" "$hook"
setcap cap_perfmon=ep "$binary"
[[ "$(caps)" == cap_perfmon=ep ]]
ROOT
