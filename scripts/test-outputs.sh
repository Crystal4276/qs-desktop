#!/usr/bin/env bash
# Teste la répartition dynamique des espaces de travail (services/Outputs.qml) sous Sway,
# dans une session Sway isolée sans écran physique (backend headless) : ta session n'est jamais touchée.
#
# La session de test reproduit un bureau à trois écrans (gauche 4K × 1.5, centre 3440x1440, droite 4K × 1.5),
# lance sa propre instance Quickshell sur ce dépôt et des fenêtres zenity sur les espaces 1, 2, 4–9,
# puis enchaîne les scénarios (ajout, retrait, désactivation d'écrans, création d'espace) et vérifie après chacun :
#   - la répartition calculée par Quickshell (`qs ipc call outputs blocks`) = la règle recalculée ici, indépendamment ;
#   - chaque espace existant est sur l'écran de son bloc ;
#   - l'espace focalisé n'a pas changé ;
#   - chaque écran qui reste affiche toujours l'espace qu'il affichait, s'il y est chez lui ;
#   - à la fin, aucune fenêtre perdue et chacune dans son espace d'origine.
# Tout est arrêté à la fin, même en cas d'échec.
#
# Usage : scripts/test-outputs.sh [-v]     (-v : garde les journaux de la session de test)
# Dépendances : sway, jq, zenity, quickshell, dbus (`dbus-run-session`).
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
verbose="${1:-}"
failures=0
sway_pid=""
qs_pid=""
bus_pid=""

cleanup() {
    set +e
    [[ -n "$qs_pid" ]] && kill "$qs_pid" 2>/dev/null
    [[ -n "$bus_pid" ]] && kill "$bus_pid" 2>/dev/null
    [[ -n "$sway_pid" ]] && kill "$sway_pid" 2>/dev/null
    wait 2>/dev/null
    if [[ "$verbose" == "-v" ]]; then
        echo "Journaux : $work"
    else
        rm -rf -- "$work"
    fi
    echo "--- $failures échec(s)"
    [[ $failures -eq 0 ]] || exit 1
}
trap cleanup EXIT

# --- Session Sway isolée -------------------------------------------------------------------------------
printf 'xwayland disable\nswaybg_command -\n' >"$work/sway.conf"
env -u SWAYSOCK -u I3SOCK -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=3 WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
    sway -c "$work/sway.conf" >"$work/sway.log" 2>&1 &
sway_pid=$!
# Les deux variables : swaymsg et Quickshell.I3 lisent I3SOCK en priorité ; sans elle, ils parleraient à ta session.
export SWAYSOCK="$XDG_RUNTIME_DIR/sway-ipc.$UID.$sway_pid.sock"
export I3SOCK="$SWAYSOCK"
for _ in $(seq 1 50); do [[ -S "$SWAYSOCK" ]] && break; sleep 0.1; done
[[ -S "$SWAYSOCK" ]] || { echo "La session Sway de test n'a pas démarré :" >&2; cat "$work/sway.log" >&2; exit 2; }

# Socket Wayland de la session de test (Sway le donne aux programmes qu'il lance).
swaymsg "exec echo \$WAYLAND_DISPLAY > $work/wayland" >/dev/null
for _ in $(seq 1 50); do [[ -s "$work/wayland" ]] && break; sleep 0.1; done
wayland="$(cat "$work/wayland")"
# Sans lui, Quickshell retomberait sur wayland-0, peut-être ta session.
[[ -n "$wayland" ]] || { echo "Socket Wayland de la session de test introuvable : arrêt." >&2; exit 2; }

# Disposition du bureau de référence.
mapfile -t outputs < <(swaymsg -t get_outputs | jq -r '.[].name' | sort)
swaymsg output "${outputs[0]}" mode 3840x2160 scale 1.5 pos 0 0 >/dev/null
swaymsg output "${outputs[1]}" mode 3440x1440 scale 1 pos 2560 0 >/dev/null
swaymsg output "${outputs[2]}" mode 3840x2160 scale 1.5 pos 6000 0 >/dev/null

# Quickshell sur cette session, avec son propre bus de session (notifications, tray, lecteurs : rien n'atteint les tiens)
# et sans montage automatique (le bus système, lui, est le vrai).
(cd "$repo" && exec env -u HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY="$wayland" SWAYSOCK="$SWAYSOCK" I3SOCK="$SWAYSOCK" \
    QS_NO_AUTOMOUNT=1 dbus-run-session -- qs -p "$repo" >"$work/qs.log" 2>&1) &
bus_pid=$!
# Quickshell est l'enfant de dbus-run-session : c'est son PID que `qs ipc --pid` attend.
for _ in $(seq 1 50); do qs_pid="$(pgrep -P "$bus_pid" -x qs || true)"; [[ -n "$qs_pid" ]] && break; sleep 0.1; done
[[ -n "$qs_pid" ]] || { echo "Quickshell n'a pas démarré :" >&2; cat "$work/qs.log" >&2; exit 2; }
for _ in $(seq 1 50); do qs ipc --pid "$qs_pid" call outputs blocks >/dev/null 2>&1 && break; sleep 0.2; done
qs ipc --pid "$qs_pid" call outputs blocks >/dev/null 2>&1 || { echo "Quickshell n'a pas démarré :" >&2; cat "$work/qs.log" >&2; exit 2; }
# Garde-fou : l'instance de test doit voir les écrans de la session de test, pas ceux de ta session.
for _ in $(seq 1 25); do
    seen="$(qs ipc --pid "$qs_pid" call outputs blocks | jq -r 'keys | sort | join(" ")')"
    [[ "$seen" == "$(printf '%s\n' "${outputs[@]}" | sort | xargs)" ]] && break
    sleep 0.2
done
[[ "$seen" == "$(printf '%s\n' "${outputs[@]}" | sort | xargs)" ]] || { echo "L'instance de test ne voit pas la session de test (écrans : $seen) : arrêt." >&2; exit 2; }

# Une fenêtre par espace occupé (comme le bureau de référence : 3 vide).
for n in 1 2 4 5 6 7 8 9; do
    swaymsg "workspace number $n; exec env GDK_BACKEND=wayland zenity --info --title=qs-test-$n --text=$n" >/dev/null
    for _ in $(seq 1 50); do
        swaymsg -t get_tree | jq -e --arg t "qs-test-$n" '[.. | objects | select(.name? == $t)] | length > 0' >/dev/null && break
        sleep 0.1
    done
done
swaymsg workspace number 2 >/dev/null
sleep 1

# --- Outils -------------------------------------------------------------------------------------------
# Répartition attendue selon la règle générale (ARCHITECTURE § 3.3), calculée indépendamment du QML :
# écran principal d'abord (plus grande surface, égalité → plus à gauche ; la config de cette machine
# désigne un écran réel, absent ici), puis gauche → droite ; blocs de floor(9/n), le reste aux premiers.
expected_rule() {
    swaymsg -t get_outputs | jq -cS '
        [.[] | select(.active) | {name, x: .rect.x, y: .rect.y, area: (.rect.width * .rect.height)}] as $o
        | ($o | sort_by(-.area, .x) | .[0]) as $p
        | ([$p] + ($o | map(select(.name != $p.name)) | sort_by(.x, .y))) as $ord
        | ($ord | length) as $n
        | reduce range(0; $n) as $i ({next: 1, map: {}};
            ((9 / $n | floor) + (if $i < (9 % $n) then 1 else 0 end)) as $size
            | reduce range(0; $size) as $k (.; .map[(.next + $k | tostring)] = $ord[$i].name)
            | .next += $size)
        | .map'
}

actual_blocks() {
    qs ipc --pid "$qs_pid" call outputs blocks | jq -cS 'to_entries | map(.key as $o | .value[] | {(tostring): $o}) | add // {}'
}

actual_workspaces() {
    swaymsg -t get_workspaces | jq -cS 'map(select(.num >= 1 and .num <= 9) | {(.num | tostring): .output}) | add // {}'
}

focused_num() { swaymsg -t get_workspaces | jq -r '.[] | select(.focused) | .num'; }
visible_map() { swaymsg -t get_workspaces | jq -cS 'map(select(.visible) | {(.output): .num}) | add // {}'; }

windows() {
    swaymsg -t get_tree | jq -cS '[.. | objects | select(.type == "workspace") | .num as $n
        | .. | objects | select(.pid? != null) | {name, ws: $n}] | sort_by(.name)'
}

# Vue attendue d'une configuration déjà vue : celle qu'elle avait (même règle que Outputs.qml, sans choix de l'utilisateur).
declare -A seen_views
layout_key() {
    swaymsg -t get_outputs | jq -r '[.[] | select(.active) | "\(.name)|\(.rect.x),\(.rect.y)|\(.rect.width)x\(.rect.height)"] | sort | join(";")'
}

initial_focus="$(focused_num)"
initial_windows="$(windows)"

# Mise en place : chaque fenêtre qs-test-N doit être dans l'espace N (ce qui teste déjà la correction à la création).
misplaced="$(jq -r '[.[] | select(.name != "qs-test-\(.ws)") | "\(.name)→\(.ws)"] | join(" ")' <<<"$initial_windows")"
if [[ -z "$misplaced" && "$(jq length <<<"$initial_windows")" == "8" ]]; then
    echo "OK    mise en place : 8 fenêtres, chacune dans son espace"
else
    echo "ÉCHEC mise en place : ${misplaced:-nombre de fenêtres $(jq length <<<"$initial_windows")}"
    failures=$((failures + 1))
fi
prev_visible="$(visible_map)"

# Écrans dont l'espace visible attendu n'est pas affiché : vue de cette configuration si elle a déjà existé,
# sinon vue d'avant le changement ; seulement pour les écrans présents dont cet espace est chez lui.
lost_visible() {
    local key seen
    key="$(layout_key)"
    seen="${seen_views[$key]-}"
    [[ -n "$seen" ]] || seen='{}'
    jq -rn --argjson p "$(jq -c --argjson s "$seen" '. + $s' <<<"$prev_visible")" --argjson now "$(visible_map)" --argjson e "$1" \
        --argjson outs "$(swaymsg -t get_outputs | jq -c '[.[] | select(.active) | .name]')" \
        '[$p | to_entries[] | select((.key | IN($outs[]))
            and (if (.value >= 1 and .value <= 9) then $e[(.value | tostring)] == .key else true end)
            and $now[.key] != .value) | "\(.key):\(.value)"] | join(" ")'
}

# check <libellé> <attendu> [focus attendu] [skip : ne pas contrôler les espaces visibles]
check() {
    local label="$1" expected="$2" want_focus="${3:-$initial_focus}" skip_visible="${4:-}"
    local blocks="" placed="" lost="" ok=""
    for _ in $(seq 1 30); do
        blocks="$(actual_blocks)"
        placed="$(jq -n --argjson e "$expected" --argjson a "$(actual_workspaces)" \
            '[$a | to_entries[] | select($e[.key] != .value)] | length')"
        lost=""; [[ -z "$skip_visible" ]] && lost="$(lost_visible "$expected")"
        ok=""; [[ "$blocks" == "$expected" && "$placed" == "0" && "$(focused_num)" == "$want_focus" && -z "$lost" ]] && ok=1
        [[ -n "$ok" ]] && break
        sleep 0.2
    done
    if [[ -n "$ok" ]]; then
        echo "OK    $label : $(jq -r 'to_entries | group_by(.value) | map("\(.[0].value)=\(map(.key) | join(","))") | join("  ")' <<<"$expected")  (focus $want_focus)"
    else
        echo "ÉCHEC $label"
        echo "      attendu  : $expected"
        echo "      calculé  : $blocks"
        echo "      espaces  : $(actual_workspaces)"
        echo "      focus    : $(focused_num) (attendu $want_focus)"
        echo "      visibles perdus : ${lost:-aucun}"
        failures=$((failures + 1))
    fi
    prev_visible="$(visible_map)"
    seen_views[$(layout_key)]="$prev_visible"
}

add_output() {
    local before after name
    before="$(swaymsg -t get_outputs | jq -r '.[].name' | sort)"
    swaymsg create_output >/dev/null
    after="$(swaymsg -t get_outputs | jq -r '.[].name' | sort)"
    name="$(comm -13 <(echo "$before") <(echo "$after"))"
    swaymsg output "$name" mode 1920x1080 >/dev/null
    echo "$name"
}

# --- Scénarios ------------------------------------------------------------------------------------------
left="${outputs[0]}"; center="${outputs[1]}"; right="${outputs[2]}"
echo "--- Session de test : $left (gauche), $center (centre), $right (droite)"

initial_expected="$(expected_rule)"
check "trois écrans (référence : centre 1-3, gauche 4-6, droite 7-9)" "$initial_expected"

h1="$(add_output)"
check "+ $h1 (4 écrans)" "$(expected_rule)"

h2="$(add_output)"
check "+ $h2 (5 écrans)" "$(expected_rule)"

# Espace créé depuis un autre écran que le sien : il doit rejoindre son écran, focalisé.
layout="$(expected_rule)"
focused_output="$(swaymsg -t get_workspaces | jq -r '.[] | select(.focused) | .output')"
target="$(jq -r --argjson a "$(actual_workspaces)" --arg f "$focused_output" \
    '[to_entries[] | select((.key | in($a) | not) and .value != $f) | .key] | first // empty' <<<"$layout")"
if [[ -n "$target" ]]; then
    swaymsg workspace number "$target" >/dev/null
    check "création de l'espace $target depuis $focused_output" "$layout" "$target" skip
    swaymsg workspace number "$initial_focus" >/dev/null
    sleep 0.5
    prev_visible="$(visible_map)"
else
    echo "SAUTÉ création (aucun espace libre hors de l'écran focalisé)"
fi

swaymsg output "$h1" disable >/dev/null
check "$h1 désactivé" "$(expected_rule)"

swaymsg output "$h1" enable >/dev/null
check "$h1 réactivé" "$(expected_rule)"

swaymsg output "$h2" unplug >/dev/null
check "$h2 débranché" "$(expected_rule)"

swaymsg output "$h1" unplug >/dev/null
check "$h1 débranché (retour à trois écrans)" "$initial_expected"

swaymsg output "$right" disable >/dev/null
check "écran de droite éteint (2 écrans)" "$(expected_rule)"

swaymsg output "$left" disable >/dev/null
check "écran de gauche éteint aussi (1 écran)" "$(expected_rule)"

swaymsg output "$left" enable >/dev/null
swaymsg output "$right" enable >/dev/null
check "écrans rallumés (retour à la référence)" "$initial_expected"

# Seule fenêtre d'un espace envoyée vers un espace inexistant d'un autre écran (cas le plus courant) : l'espace naît en
# arrière-plan sur l'écran focalisé et doit rejoindre le sien sans détruire l'espace de départ, devenu vide, ni changer la vue
# de l'écran d'arrivée, ni créer d'espace parasite (revue de code du 2026-10-16, reproduit avant correction).
swaymsg "focus output $left" >/dev/null
sleep 0.5
from_ws="$(focused_num)"
count_before="$(swaymsg -t get_workspaces | jq length)"
placed_before="$(qs log --pid "$qs_pid" | grep -c "placement des espaces" || true)"
prev_visible="$(visible_map)"
swaymsg "[title=\"^qs-test-$from_ws\$\"] move container to workspace number 3" >/dev/null
check "fenêtre seule de l'espace $from_ws envoyée vers 3 (centre)" "$initial_expected" "$from_ws"
sleep 0.5
count_after="$(swaymsg -t get_workspaces | jq length)"
placed_after="$(qs log --pid "$qs_pid" | grep -c "placement des espaces" || true)"
if [[ "$count_after" == "$((count_before + 1))" && "$placed_after" == "$((placed_before + 1))" ]]; then
    echo "OK    une seule correction, aucun espace parasite ($count_after espaces : les $count_before d'avant + 3)"
else
    echo "ÉCHEC $((placed_after - placed_before)) correction(s) au lieu d'une, $count_after espaces au lieu de $((count_before + 1))"
    failures=$((failures + 1))
fi
swaymsg "[title=\"^qs-test-$from_ws\$\"] move container to workspace number $from_ws" >/dev/null
swaymsg workspace number "$initial_focus" >/dev/null
sleep 0.5
prev_visible="$(visible_map)"

# L'écran focalisé (et principal) s'éteint : le compositeur déplace le focus avant Quickshell ;
# l'espace focalisé doit le rester, et la vue de chaque écran revenir au rallumage.
reference_visible="$(visible_map)"
swaymsg output "$center" disable >/dev/null
check "écran du centre (principal, focalisé) éteint" "$(expected_rule)"
swaymsg output "$center" enable >/dev/null
check "écran du centre rallumé" "$initial_expected"
if [[ "$(visible_map)" == "$reference_visible" ]]; then
    echo "OK    vue retrouvée : $(jq -r 'to_entries | map("\(.key)=\(.value)") | join(" ")' <<<"$reference_visible")"
else
    echo "ÉCHEC vue après rallumage : $(visible_map) au lieu de $reference_visible"
    failures=$((failures + 1))
fi

if [[ "$(windows)" == "$initial_windows" ]]; then
    echo "OK    fenêtres : $(jq length <<<"$initial_windows"), toutes dans leur espace d'origine"
else
    echo "ÉCHEC fenêtres"
    echo "      avant : $initial_windows"
    echo "      après : $(windows)"
    failures=$((failures + 1))
fi

# Pas de boucle : une répartition par changement d'écrans, plus une correction par espace créé ailleurs.
placements="$(qs log --pid "$qs_pid" | grep -c "placement des espaces" || true)"
if [[ "$placements" -le 30 ]]; then
    echo "OK    commandes de placement envoyées : $placements"
else
    echo "ÉCHEC commandes de placement : $placements (boucle ?)"
    failures=$((failures + 1))
fi
