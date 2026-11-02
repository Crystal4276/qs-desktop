#!/usr/bin/env bash
# Teste la répartition dynamique des espaces de travail (services/Outputs.qml) dans une session de test isolée : ta session
# n'est jamais touchée.
#   Sway     : backend headless, aucune fenêtre, lançable depuis n'importe quelle session.
#   Hyprland : imbriqué dans ta session Hyprland (en headless, il n'alloue aucune image sur Nvidia) : une fenêtre s'ouvre le temps
#              du test sur ton espace focalisé. Son écran WAYLAND-1 est désactivé, le test se joue sur des écrans virtuels.
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
# Usage : scripts/test-outputs.sh [sway|hyprland] [-v]     (sans argument : le compositeur de la session, sinon Sway ;
#                                                           -v : garde les journaux de la session de test)
# Dépendances : sway ou hyprland, jq, zenity, quickshell, dbus (`dbus-run-session`), procps-ng (`pgrep`), util-linux (`setsid`).
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
compositor=""
verbose=""
for arg in "$@"; do
    case "$arg" in
        sway|hyprland) compositor="$arg" ;;
        -v) verbose="-v" ;;
        *) echo "Usage : $0 [sway|hyprland] [-v]" >&2; exit 2 ;;
    esac
done
[[ -n "$compositor" ]] || { [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && compositor=hyprland || compositor=sway; }
if [[ "$compositor" == hyprland && -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    echo "Hyprland : à lancer depuis une session Hyprland (Hyprland imbriqué)." >&2
    exit 2
fi
failures=0
session_pid=""
qs_pid=""
bus_pid=""

cleanup() {
    local status=$?
    set +e
    # Tout le groupe de l'instance : Quickshell, son bus privé et leurs enfants (sinon orphelins : vu, un bus et un
    # `gdbus monitor` sur le vrai bus système par passage).
    [[ -n "$bus_pid" ]] && kill -- -"$bus_pid" 2>/dev/null
    [[ -n "$session_pid" ]] && kill "$session_pid" 2>/dev/null
    wait 2>/dev/null
    [[ -n "${instance:-}" ]] && rm -rf -- "$XDG_RUNTIME_DIR/hypr/$instance"   # Hyprland ne l'efface pas
    if [[ "$verbose" == "-v" ]]; then
        echo "Journaux : $work"
    else
        rm -rf -- "$work"
    fi
    # Arrêt avant la fin (session ou instance qui ne démarre pas) : pas de faux « 0 échec ».
    [[ $status -eq 0 ]] || { echo "--- test interrompu (code $status)"; exit "$status"; }
    echo "--- $failures échec(s)"
    [[ $failures -eq 0 ]] || exit 1
}
trap cleanup EXIT

# --- Actions et lectures du compositeur -----------------------------------------------------------------
# Même forme pour les deux. c_ws : [{ num, output, focused, visible }] ; c_outs : [{ name, active, x, y, width, height }] (px
# logiques) ; c_windows : [{ name, ws }].
if [[ "$compositor" == sway ]]; then
    c_ws() { swaymsg -t get_workspaces | jq -c '[.[] | {num, output, focused, visible}]'; }
    c_outs() { swaymsg -t get_outputs | jq -c '[.[] | {name, active, x: .rect.x, y: .rect.y, width: .rect.width, height: .rect.height}]'; }
    c_windows() {
        swaymsg -t get_tree | jq -cS '[.. | objects | select(.type == "workspace") | .num as $n
            | .. | objects | select(.pid? != null) | {name, ws: $n}] | sort_by(.name)'
    }
    c_goto() { swaymsg workspace number "$1" >/dev/null; }
    c_focus_output() { swaymsg "focus output $1" >/dev/null; }
    c_open_window() { swaymsg "workspace number $1; exec env GDK_BACKEND=wayland zenity --info --title=qs-test-$1 --text=$1" >/dev/null; }
    c_move_window() { swaymsg "[title=\"^qs-test-$1\$\"] move container to workspace number $2" >/dev/null; }   # le focus ne suit pas
    c_move_focused_window_following() { swaymsg "move container to workspace number $1; workspace number $1" >/dev/null; }
    c_move_focused_ws() { swaymsg "move workspace to output $1" >/dev/null; }
    c_move_ws() { swaymsg "[workspace=\"^$1\$\"] move workspace to output $2" >/dev/null; }
    c_disable() { swaymsg output "$1" disable >/dev/null; }
    c_enable() { swaymsg output "$1" enable >/dev/null; }
    c_unplug() { swaymsg output "$1" unplug >/dev/null; }
    c_create_output() { swaymsg create_output >/dev/null; }
    c_set_output() { swaymsg output "$1" mode "$2" scale "$3" pos "${4%x*}" "${4#*x}" >/dev/null; }
else
    declare -A output_rules
    h() { HYPRLAND_INSTANCE_SIGNATURE="$instance" hyprctl "$@"; }
    dsp() { [[ "$(h dispatch "$1")" == ok ]] || { echo "Action refusée : $1" >&2; failures=$((failures + 1)); }; }
    c_ws() {
        jq -cn --argjson w "$(h workspaces -j)" --argjson m "$(h monitors -j)" --argjson a "$(h activeworkspace -j)" \
            '[$w[] | .id as $id | {num: $id, output: .monitor, focused: ($id == $a.id),
                visible: ([$m[].activeWorkspace.id] | index($id) != null)}]'
    }
    c_outs() {
        h monitors all -j | jq -c '[.[] | select(.name != "WAYLAND-1" and .name != "FALLBACK") | {name, active: (.disabled | not), x, y,
            width: (.width / .scale | round), height: (.height / .scale | round)}]'
    }
    c_windows() { h clients -j | jq -cS '[.[] | {name: .title, ws: .workspace.id}] | sort_by(.name)'; }
    c_goto() { dsp "hl.dsp.focus({ workspace = $1 })"; }
    c_focus_output() { dsp "hl.dsp.focus({ monitor = \"$1\" })"; }
    c_open_window() {
        c_goto "$1"
        dsp "hl.dsp.exec_cmd(\"env GDK_BACKEND=wayland zenity --info --title=qs-test-$1 --text=$1\")"
    }
    c_move_window() { dsp "hl.dsp.window.move({ window = \"title:^qs-test-$1\$\", workspace = $2, follow = false })"; }
    c_move_focused_window_following() { dsp "hl.dsp.window.move({ workspace = $1 })"; }   # ton `$mod+Ctrl+N`
    c_move_focused_ws() { dsp "hl.dsp.workspace.move({ monitor = \"$1\" })"; }
    c_move_ws() { dsp "hl.dsp.workspace.move({ workspace = $1, monitor = \"$2\" })"; }
    c_disable() { h eval "hl.monitor({ output = \"$1\", disabled = true })" >/dev/null; }
    # hl.monitor fusionne avec la règle existante de cet écran : `disabled` reste posé tant qu'on ne le remet pas à faux.
    c_enable() { h eval "hl.monitor({ output = \"$1\", disabled = false, ${output_rules[$1]:-mode = \"preferred\", position = \"auto\", scale = 1} })" >/dev/null; }
    c_unplug() { h output remove "$1" >/dev/null; }
    c_create_output() { h output create headless >/dev/null; }
    c_set_output() {
        output_rules[$1]="mode = \"$2\", position = \"$4\", scale = $3"
        h eval "hl.monitor({ output = \"$1\", ${output_rules[$1]} })" >/dev/null
    }
fi

output_names() { c_outs | jq -r '.[].name' | sort; }

# --- Session isolée -------------------------------------------------------------------------------------
if [[ "$compositor" == sway ]]; then
    printf 'xwayland disable\nswaybg_command -\n' >"$work/sway.conf"
    env -u SWAYSOCK -u I3SOCK -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
        WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=3 WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
        sway -c "$work/sway.conf" >"$work/session.log" 2>&1 &
    session_pid=$!
    # Les deux variables : swaymsg et Quickshell.I3 lisent I3SOCK en priorité ; sans elle, ils parleraient à ta session.
    export SWAYSOCK="$XDG_RUNTIME_DIR/sway-ipc.$UID.$session_pid.sock"
    export I3SOCK="$SWAYSOCK"
    for _ in $(seq 1 50); do [[ -S "$SWAYSOCK" ]] && break; sleep 0.1; done
    [[ -S "$SWAYSOCK" ]] || { echo "La session Sway de test n'a pas démarré :" >&2; cat "$work/session.log" >&2; exit 2; }
    # Socket Wayland de la session de test (Sway le donne aux programmes qu'il lance).
    swaymsg "exec echo \$WAYLAND_DISPLAY > $work/wayland" >/dev/null
    for _ in $(seq 1 50); do [[ -s "$work/wayland" ]] && break; sleep 0.1; done
    wayland="$(cat "$work/wayland")"
    session_env=(-u HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK="$SWAYSOCK" I3SOCK="$SWAYSOCK")
else
    printf '%s\n' 'hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true, disable_autoreload = true },' \
        '  ecosystem = { no_update_news = true, no_donation_nag = true }, animations = { enabled = false } })' \
        'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })' >"$work/hyprland.lua"
    known="$(ls "$XDG_RUNTIME_DIR/hypr" | sort)"
    env -u HYPRLAND_INSTANCE_SIGNATURE -u SWAYSOCK -u I3SOCK -u DISPLAY Hyprland -c "$work/hyprland.lua" >"$work/session.log" 2>&1 &
    session_pid=$!
    instance=""
    for _ in $(seq 1 50); do
        instance="$(comm -13 <(echo "$known") <(ls "$XDG_RUNTIME_DIR/hypr" | sort) | head -1)"
        [[ -n "$instance" && -S "$XDG_RUNTIME_DIR/hypr/$instance/.socket.sock" ]] && break
        sleep 0.2
    done
    [[ -n "$instance" ]] || { echo "La session Hyprland de test n'a pas démarré :" >&2; cat "$work/session.log" >&2; exit 2; }
    sleep 1
    wayland="$(h instances -j | jq -r --arg i "$instance" '.[] | select(.instance == $i) | .wl_socket')"
    for _ in 1 2 3; do c_create_output; done
    sleep 0.5
    h eval 'hl.monitor({ output = "WAYLAND-1", disabled = true })' >/dev/null
    sleep 0.5
    session_env=(-u SWAYSOCK -u I3SOCK HYPRLAND_INSTANCE_SIGNATURE="$instance")
fi
# Sans lui, Quickshell retomberait sur wayland-0, peut-être ta session.
[[ -n "$wayland" ]] || { echo "Socket Wayland de la session de test introuvable : arrêt." >&2; exit 2; }

# Disposition du bureau de référence.
mapfile -t outputs < <(output_names)
c_set_output "${outputs[0]}" 3840x2160 1.5 0x0
c_set_output "${outputs[1]}" 3440x1440 1 2560x0
c_set_output "${outputs[2]}" 3840x2160 1.5 6000x0
sleep 0.5

# Quickshell sur cette session, avec son propre bus de session (notifications, tray, lecteurs : rien n'atteint les tiens)
# et ni montage automatique ni reconnexion Bluetooth automatique (QS_TEST : le bus système, lui, est le vrai). État à part
# (XDG_STATE_HOME) : les fichiers d'état de ton instance (historique du lanceur, fond, veilleuse…) ne sont ni lus ni écrits.
# Sans gvfs : un second gvfsd lancé sur ce bus casserait le montage /run/user/$UID/gvfs de ta session (vu le 2026-10-26).
# Groupe de processus à lui (setsid, sans fork : son PID est $bus_pid), arrêté en entier à la fin.
(cd "$repo" && exec setsid env "${session_env[@]}" WAYLAND_DISPLAY="$wayland" \
    QS_TEST=1 XDG_STATE_HOME="$work/state" GIO_USE_VFS=local GVFS_DISABLE_FUSE=1 \
    dbus-run-session -- qs -p "$repo" >"$work/qs.log" 2>&1) &
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
sleep 1   # première répartition (500 ms après le dernier changement d'écrans)

# Une fenêtre par espace occupé (comme le bureau de référence : 3 vide).
for n in 1 2 4 5 6 7 8 9; do
    c_open_window "$n"
    for _ in $(seq 1 50); do
        c_windows | jq -e --arg t "qs-test-$n" 'any(.name == $t)' >/dev/null && break
        sleep 0.1
    done
    sleep 0.2
done
c_goto 2
sleep 1

# --- Outils -------------------------------------------------------------------------------------------
# Répartition attendue selon la règle générale (ARCHITECTURE § 3.3), calculée indépendamment du QML :
# écran principal d'abord (plus grande surface, égalité → plus à gauche ; la config de cette machine
# désigne un écran réel, absent ici), puis gauche → droite ; blocs de floor(9/n), le reste aux premiers.
expected_rule() {
    c_outs | jq -cS '
        [.[] | select(.active) | {name, x, y, area: (.width * .height)}] as $o
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
    c_ws | jq -cS 'map(select(.num >= 1 and .num <= 9) | {(.num | tostring): .output}) | add // {}'
}

focused_num() { c_ws | jq -r '.[] | select(.focused) | .num'; }
visible_map() { c_ws | jq -cS 'map(select(.visible) | {(.output): .num}) | add // {}'; }
windows() { c_windows; }
# Commandes de placement envoyées depuis le démarrage (journal de l'instance de test).
placement_count() { qs log --pid "$qs_pid" | grep -cE "placement des espaces|actions Hyprland" || true; }

# Vue attendue d'une configuration déjà vue : celle qu'elle avait (même règle que Outputs.qml, sans choix de l'utilisateur).
declare -A seen_views
layout_key() {
    c_outs | jq -r '[.[] | select(.active) | "\(.name)|\(.x),\(.y)|\(.width)x\(.height)"] | sort | join(";")'
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
        --argjson outs "$(c_outs | jq -c '[.[] | select(.active) | .name]')" \
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
    before="$(output_names)"
    c_create_output
    after="$(output_names)"
    name="$(comm -13 <(echo "$before") <(echo "$after"))"
    echo "$name"
}

# Écrans demandés actifs : sans ce contrôle, un écran resté éteint passerait (la règle est recalculée sur l'état réel).
expect_active() {
    local want="$1" got=""
    for _ in $(seq 1 20); do
        got="$(c_outs | jq -c '[.[] | select(.active) | .name] | sort | join(" ")' | tr -d '"')"
        [[ "$got" == "$want" ]] && return 0
        sleep 0.1
    done
    echo "ÉCHEC écrans actifs : « $got » au lieu de « $want »"
    failures=$((failures + 1))
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
focused_output="$(c_ws | jq -r '.[] | select(.focused) | .output')"
target="$(jq -r --argjson a "$(actual_workspaces)" --arg f "$focused_output" \
    '[to_entries[] | select((.key | in($a) | not) and .value != $f) | .key] | first // empty' <<<"$layout")"
if [[ -n "$target" ]]; then
    c_goto "$target"
    check "création de l'espace $target depuis $focused_output" "$layout" "$target" skip
    c_goto "$initial_focus"
    sleep 0.5
    prev_visible="$(visible_map)"
else
    echo "SAUTÉ création (aucun espace libre hors de l'écran focalisé)"
fi

c_disable "$h1"
check "$h1 désactivé" "$(expected_rule)"

c_enable "$h1"
expect_active "$(printf '%s\n' "${outputs[@]}" "$h1" "$h2" | sort | xargs)"
check "$h1 réactivé" "$(expected_rule)"

c_unplug "$h2"
check "$h2 débranché" "$(expected_rule)"

c_unplug "$h1"
check "$h1 débranché (retour à trois écrans)" "$initial_expected"

c_disable "$right"
check "écran de droite éteint (2 écrans)" "$(expected_rule)"

c_disable "$left"
check "écran de gauche éteint aussi (1 écran)" "$(expected_rule)"

c_enable "$left"
c_enable "$right"
expect_active "$(printf '%s\n' "${outputs[@]}" | sort | xargs)"
check "écrans rallumés (retour à la référence)" "$initial_expected"

# Seule fenêtre d'un espace envoyée vers un espace inexistant d'un autre écran (cas le plus courant) : l'espace naît en
# arrière-plan sur l'écran focalisé et doit rejoindre le sien sans détruire l'espace de départ, devenu vide, ni changer la vue
# de l'écran d'arrivée, ni créer d'espace parasite (revue de code du 2026-10-16, reproduit avant correction).
c_focus_output "$left"
sleep 0.5
from_ws="$(focused_num)"
count_before="$(c_ws | jq length)"
placed_before="$(placement_count)"
prev_visible="$(visible_map)"
c_move_window "$from_ws" 3
check "fenêtre seule de l'espace $from_ws envoyée vers 3 (centre)" "$initial_expected" "$from_ws"
sleep 0.5
count_after="$(c_ws | jq length)"
placed_after="$(placement_count)"
if [[ "$count_after" == "$((count_before + 1))" && "$placed_after" == "$((placed_before + 1))" ]]; then
    echo "OK    une seule correction, aucun espace parasite ($count_after espaces : les $count_before d'avant + 3)"
else
    echo "ÉCHEC $((placed_after - placed_before)) correction(s) au lieu d'une, $count_after espaces au lieu de $((count_before + 1))"
    failures=$((failures + 1))
fi
c_move_window "$from_ws" "$from_ws"
c_goto "$initial_focus"
sleep 0.5
prev_visible="$(visible_map)"

# Espace créé depuis un écran qui affichait un espace vide (Sway le détruit en le quittant) : l'écran de départ doit le
# retrouver (revue de code du 2026-10-26 : il affichait un autre de ses espaces).
left_block=($(jq -r --arg o "$left" 'to_entries | map(select(.value == $o) | .key | tonumber) | sort | .[]' <<<"$initial_expected"))
empty_ws="${left_block[2]}"
c_move_window "$empty_ws" "${left_block[0]}"
c_focus_output "$left"; c_goto "$empty_ws"
sleep 0.5
c_goto 3
check "espace 3 créé depuis $left, qui affichait $empty_ws (vide)" "$initial_expected" 3 skip
if [[ "$(visible_map | jq -r --arg o "$left" '.[$o]')" == "$empty_ws" ]]; then
    echo "OK    $left affiche toujours $empty_ws"
else
    echo "ÉCHEC $left affiche $(visible_map | jq -r --arg o "$left" '.[$o]') au lieu de $empty_ws"
    failures=$((failures + 1))
fi

# Espace seul d'un écran déplacé à la main : Sway crée sur l'écran vidé un espace bouche-trou au premier numéro libre (ici 3,
# chez lui au centre). Avant correction, le déplacer en faisait naître un autre, sans fin (revue de code du 2026-10-26).
for n in "${left_block[@]}"; do c_move_window "$n" "$empty_ws"; done
c_focus_output "$left"; c_goto "$empty_ws"
c_goto "$initial_focus"
sleep 1
placed_before="$(placement_count)"
c_focus_output "$left"; c_move_focused_ws "$right"
sleep 2
placed_after="$(placement_count)"
shown_left="$(visible_map | jq -r --arg o "$left" '.[$o]')"
if [[ "$((placed_after - placed_before))" -le 2 && " ${left_block[*]} " == *" $shown_left "* ]]; then
    echo "OK    écran vidé : $left affiche $shown_left (son bloc), $((placed_after - placed_before)) correction(s)"
else
    echo "ÉCHEC écran vidé : $left affiche $shown_left, $((placed_after - placed_before)) corrections (boucle ?)"
    failures=$((failures + 1))
fi
# Remise en état : l'espace déplacé à la main revient, chaque fenêtre dans son espace.
c_move_ws "$empty_ws" "$left"; c_focus_output "$left"
for n in "${left_block[@]}"; do c_move_window "$n" "$n"; done
c_focus_output "$left"; c_goto "$empty_ws"; c_goto "$initial_focus"
sleep 1
prev_visible="$(visible_map)"
seen_views[$(layout_key)]="$prev_visible"   # même configuration : la vue choisie ici remplace celle relevée plus haut
check "remise en état" "$initial_expected"

# L'écran focalisé (et principal) s'éteint : le compositeur déplace le focus avant Quickshell ;
# l'espace focalisé doit le rester, et la vue de chaque écran revenir au rallumage.
reference_visible="$(visible_map)"
c_disable "$center"
check "écran du centre (principal, focalisé) éteint" "$(expected_rule)"
c_enable "$center"
check "écran du centre rallumé" "$initial_expected"
if [[ "$(visible_map)" == "$reference_visible" ]]; then
    echo "OK    vue retrouvée : $(jq -r 'to_entries | map("\(.key)=\(.value)") | join(" ")' <<<"$reference_visible")"
else
    echo "ÉCHEC vue après rallumage : $(visible_map) au lieu de $reference_visible"
    failures=$((failures + 1))
fi

# Espace focalisé vide qui change d'écran (droite éteinte : le premier espace du bloc de gauche passe au centre) : il doit
# arriver au centre, focalisé, en une seule correction. Avant correction, le centre affichait d'abord son espace mémorisé :
# Sway détruisait l'espace vide, le focus final le recréait à gauche, puis une seconde correction (revue du 2026-10-27).
moving_ws="${left_block[0]}"
c_move_window "$moving_ws" "${left_block[1]}"
c_focus_output "$left"; c_goto "$moving_ws"
sleep 1
placed_before="$(placement_count)"
c_disable "$right"
check "droite éteinte, espace $moving_ws focalisé et vide" "$(expected_rule)" "$moving_ws" skip
sleep 0.5
placed_after="$(placement_count)"
moving_output="$(c_ws | jq -r --argjson n "$moving_ws" '.[] | select(.num == $n) | .output')"
if [[ "$moving_output" == "$center" && "$((placed_after - placed_before))" == "1" ]]; then
    echo "OK    espace $moving_ws au centre, une seule correction"
else
    echo "ÉCHEC espace $moving_ws sur $moving_output, $((placed_after - placed_before)) correction(s)"
    failures=$((failures + 1))
fi
c_enable "$right"
check "droite rallumée (l'espace $moving_ws focalisé retourne à gauche)" "$initial_expected" "$moving_ws" skip
c_move_window "$moving_ws" "$moving_ws"
c_goto "$initial_focus"
sleep 1
prev_visible="$(visible_map)"
seen_views[$(layout_key)]="$prev_visible"
check "remise en état" "$initial_expected"

# Fenêtre envoyée vers un espace inexistant d'un autre écran, le focus la suit (`$mod+Ctrl+N` sous Hyprland) : l'espace rejoint son
# écran, focalisé avec la fenêtre ; l'écran de départ retrouve un espace de son bloc.
c_focus_output "$left"; c_goto "${left_block[2]}"
sleep 0.5
c_move_focused_window_following 3
check "fenêtre ${left_block[2]} envoyée vers 3 (le focus suit)" "$initial_expected" 3 skip
c_goto "${left_block[2]}"
c_move_window "${left_block[2]}" "${left_block[2]}"
c_goto "$initial_focus"
sleep 1
prev_visible="$(visible_map)"
seen_views[$(layout_key)]="$prev_visible"
check "remise en état" "$initial_expected"

# Aucun écran actif (capot fermé sans écran externe) : Quickshell ne fait rien et l'instance survit ; tout revient au rallumage.
reference_visible="$(visible_map)"
placed_before="$(placement_count)"
c_disable "$left"; c_disable "$right"; c_disable "$center"
sleep 1.5
blocks_none="$(qs ipc --pid "$qs_pid" call outputs blocks)"
placed_after="$(placement_count)"
if [[ "$blocks_none" == "{}" && "$placed_after" == "$placed_before" ]]; then
    echo "OK    aucun écran actif : répartition vide, aucune commande"
else
    echo "ÉCHEC aucun écran actif : $blocks_none, $((placed_after - placed_before)) commande(s)"
    failures=$((failures + 1))
fi
c_enable "$center"; c_enable "$left"; c_enable "$right"
expect_active "$(printf '%s\n' "${outputs[@]}" | sort | xargs)"
check "écrans rallumés après extinction totale" "$initial_expected"
if [[ "$(visible_map)" == "$reference_visible" ]]; then
    echo "OK    vue retrouvée après extinction totale"
else
    echo "ÉCHEC vue après extinction totale : $(visible_map) au lieu de $reference_visible"
    failures=$((failures + 1))
fi

# Écran focalisé débranché avec une fenêtre (plantage de Quickshell sous Sway, 2026-11-02 : pointeur vers l'écran disparu relu).
h3="$(add_output)"
sleep 1
check "+ $h3 (écran à débrancher)" "$(expected_rule)"
h3_ws="$(jq -r --arg o "$h3" '[to_entries[] | select(.value == $o) | .key | tonumber] | min' <<<"$(expected_rule)")"
c_focus_output "$h3"; c_goto "$h3_ws"
c_move_window "$h3_ws" "$h3_ws"
sleep 1
c_unplug "$h3"
check "$h3 focalisé débranché, espace $h3_ws conservé" "$initial_expected" "$h3_ws" skip
if kill -0 "$qs_pid" 2>/dev/null; then
    echo "OK    Quickshell toujours là"
else
    echo "ÉCHEC Quickshell a planté"
    failures=$((failures + 1))
fi
c_goto "$initial_focus"
sleep 1
prev_visible="$(visible_map)"
seen_views[$(layout_key)]="$prev_visible"
check "remise en état" "$initial_expected"

if [[ "$(windows)" == "$initial_windows" ]]; then
    echo "OK    fenêtres : $(jq length <<<"$initial_windows"), toutes dans leur espace d'origine"
else
    echo "ÉCHEC fenêtres"
    echo "      avant : $initial_windows"
    echo "      après : $(windows)"
    failures=$((failures + 1))
fi

# Pas de boucle : une répartition par changement d'écrans, plus une correction par espace créé ailleurs.
placements="$(placement_count)"
if [[ "$placements" -le 40 ]]; then
    echo "OK    commandes de placement envoyées : $placements"
else
    echo "ÉCHEC commandes de placement : $placements (boucle ?)"
    failures=$((failures + 1))
fi
