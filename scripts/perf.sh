#!/usr/bin/env bash
# Mesures de performance de l'instance Quickshell (docs/PERFORMANCE.md). Lecture seule, sauf `ab`, qui relance le bureau
# (scripts/dev.sh → desktop.sh restart : la nouvelle surveillance garde les variables données, jusqu'à la relance suivante).
# Usage : scripts/perf.sh snap [étiquette]                  mémoire de l'instance, tout de suite
#         scripts/perf.sh idle [secondes] [étiquette]       mémoire + CPU et réveils sur la durée (60 s par défaut)
#         scripts/perf.sh ab <étiquette> [VAR=valeur …]     relance avec ces variables, attend, puis `idle`
# Chaque mesure est affichée et ajoutée à .shots/perf.tsv (ignoré par git).
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
results="$repo/.shots/perf.tsv"
settle="${PERF_SETTLE:-30}"   # s entre le lancement et la mesure (fonds décodés, services démarrés)
mkdir -p "$repo/.shots"

instance() {
    # Instance du bureau de cette session (scripts/desktop.sh), jamais une autre copie du dépôt (banc de test, même ShellId).
    "$repo/scripts/desktop.sh" pid || { echo "Aucune instance Quickshell lancée par desktop.sh." >&2; exit 1; }
}

status() { awk -v k="$2:" '$1 == k { print int($2 / 1024) }' "/proc/$1/status"; }
ticks() { awk '{ print $14 + $15, $16 + $17 }' "/proc/$1/stat"; }
switches() { { cat "/proc/$1"/task/*/status 2>/dev/null || true; } | awk '/^voluntary_ctxt_switches/ { sum += $2 } END { print sum + 0 }'; }   # tous les threads
vram() { { nvidia-smi 2>/dev/null || true; } | awk -v p="$1" '$5 == p { gsub("MiB", "", $(NF-1)); sum += $(NF-1); f = 1 } END { print f ? sum : "-" }'; }
pss() { awk '/^Pss:/ { print int($2 / 1024) }' "/proc/$1/smaps_rollup"; }
renderers() { cat "/proc/$1"/task/*/comm | grep -c QSGRenderThread || true; }

measure() {   # étiquette secondes
    local pid cpu="-" children="-" wakeups="-"
    pid=$(instance)
    if (( $2 > 0 )); then
        local s1 c1 v1 s2 c2 v2
        read -r s1 c1 < <(ticks "$pid"); v1=$(switches "$pid")
        sleep "$2"
        read -r s2 c2 < <(ticks "$pid"); v2=$(switches "$pid")
        cpu=$(awk -v d="$((s2 - s1))" -v t="$2" 'BEGIN { printf "%.2f", d / t }')
        children=$(awk -v d="$((c2 - c1))" -v t="$2" 'BEGIN { printf "%.2f", d / t }')
        wakeups=$(( (v2 - v1) / $2 ))
    fi
    [[ -f "$results" ]] || printf 'date\tétiquette\tRSS\tPSS\tanon\tfichiers\tshmem\tpic\tVRAM\tthreads\trendu\tCPU%%\tenfants%%\tréveils/s\n' > "$results"
    local line
    line=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' "$(date +%H:%M:%S)" "$1" \
        "$(status "$pid" VmRSS)" "$(pss "$pid")" "$(status "$pid" RssAnon)" "$(status "$pid" RssFile)" "$(status "$pid" RssShmem)" \
        "$(status "$pid" VmHWM)" "$(vram "$pid")" "$(awk '/^Threads/ { print $2 }' "/proc/$pid/status")" "$(renderers "$pid")" \
        "$cpu" "$children" "$wakeups")
    echo "$line" >> "$results"
    head -1 "$results"
    echo "$line"
}

case "${1:-}" in
    snap)
        measure "${2:-snap}" 0
        ;;
    idle)
        measure "${3:-idle}" "${2:-60}"
        ;;
    ab)
        label="${2:?Usage : perf.sh ab <étiquette> [VAR=valeur …]}"
        shift 2
        env "$@" "$repo/scripts/dev.sh" >/dev/null
        sleep "$settle"
        measure "$label" "${PERF_IDLE:-30}"
        ;;
    *)
        sed -n '2,6p' "$0" | cut -c3-
        exit 1
        ;;
esac
