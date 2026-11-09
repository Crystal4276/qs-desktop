#!/usr/bin/env bash
# Installation du bureau sur une machine (README.md). Idempotent : relancé, il ne refait que ce qui manque ou a changé.
#
# Usage : ./install.sh [options]
#   --dry-run          affiche tout ce qui serait fait, sans rien modifier (ni paquet, ni fichier, ni sudo)
#   --with jeux        ajoute le profil « jeux » (deps/games.txt) sans le demander ; --without jeux : ne pas le proposer
#   --no-packages      ne touche pas aux paquets (ni multilib, ni paru)
#   --no-system        aucune étape système (sudo) : greeter, sonde réseau, Samba, services…
#   --yes              ne pose aucune question (étapes système et profil jeux : réponse « oui » / valeur des options)
#   --uninstall        retire les liens et copies, remet les sauvegardes et les réglages d'origine, étapes système comprises ;
#                      les paquets installés restent
#
# Étapes : 1 paquets (dépôts officiels, multilib, paru-bin) · 2 configs du compte (liens, sauvegardes `<x>.bak-<date>`) ·
# 3 thème · 4 réglages (dconf, applications par défaut, web apps, liens Chromium) · 5 config machine · 6 système (sudo).
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
[[ $EUID -ne 0 ]] || { echo "À lancer en utilisateur, sans sudo (sudo est demandé pour chaque étape système)." >&2; exit 1; }

dry=""
games=ask
packages=1
system=1
yes=""
uninstall=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) dry=1 ;;
        --with) [[ "${2:-}" == jeux ]] || { echo "Profil inconnu : ${2:-}" >&2; exit 2; }; games=yes; shift ;;
        --without) [[ "${2:-}" == jeux ]] || { echo "Profil inconnu : ${2:-}" >&2; exit 2; }; games=no; shift ;;
        --no-packages) packages="" ;;
        --no-system) system="" ;;
        --yes) yes=1 ;;
        --uninstall) uninstall=1 ;;
        -h|--help) sed -n '4,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Option inconnue : $1 (--help)" >&2; exit 2 ;;
    esac
    shift
done

host="$(cat /proc/sys/kernel/hostname)"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/qs-desktop/install"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/qs-desktop/downloads"
registry="$state/registry"   # une ligne par changement : <genre> <cible> <sauvegarde|->, tabulations
stamp="$(date +%Y%m%d-%H%M%S)"

# Simulation : archives du thème téléchargées à part, effacées à la fin.
dry_cache=""
if [[ -n "$dry" ]]; then dry_cache="$(mktemp -d)"; trap 'rm -rf "$dry_cache"' EXIT; fi

# --- Outils ------------------------------------------------------------------------------------------------------------

section() { printf '\n== %s\n' "$*"; }

run() {     # commande du compte
    printf '+ %s\n' "$*"
    [[ -n "$dry" ]] || "$@"
}

ask() {     # $1 = question ; oui par défaut avec --yes
    [[ -n "$yes" ]] && return 0
    [[ -n "$dry" ]] && { echo "? $1 (simulation : oui)"; return 0; }
    local answer
    read -r -p "? $1 [o/N] " answer </dev/tty
    [[ "$answer" == [oOyY]* ]]
}

recorded() {    # $1 = cible déjà notée ?
    [[ -f "$registry" ]] && awk -F'\t' -v t="$1" '$2 == t { found = 1 } END { exit !found }' "$registry"
}

record() {      # genre cible sauvegarde
    printf '+ (registre) %s %s\n' "$1" "$2"
    [[ -n "$dry" ]] && return
    mkdir -p "$state"
    printf '%s\t%s\t%s\n' "$1" "$2" "${3:--}" >> "$registry"
}

# Sauvegarde d'origine d'un fichier ou dossier du compte, une seule fois : `<cible>.bak-<date>` à côté, déplacée (link) ou
# copiée (edit). Rien à sauvegarder : « - ».
backup_once() {     # genre cible mv|cp
    local kind="$1" target="$2" how="$3" backup="-"
    recorded "$target" && return
    if [[ -e "$target" || -L "$target" ]]; then
        backup="$target.bak-$stamp"
        if [[ "$how" == cp ]]; then run cp -a "$target" "$backup"; else run mv "$target" "$backup"; fi
    fi
    record "$kind" "$target" "$backup"
}

# Lien `dest` → `src` (chemin du dépôt). Un fichier ou dossier déjà là est sauvegardé (déplacé) avant.
link() {        # src (chemin du dépôt, ou absolu) dest
    local src="$1" dest="$2"
    if [[ "$src" == . ]]; then src="$repo"; elif [[ "$src" != /* ]]; then src="$repo/$src"; fi
    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        echo "= $dest"
        return
    fi
    if [[ -e "$dest" || -L "$dest" ]]; then
        if ! recorded "$dest"; then backup_once link "$dest" mv
        elif [[ -L "$dest" ]]; then run rm -f "$dest"
        else run mv "$dest" "$dest.bak-$stamp"; fi   # remplacé depuis par un vrai fichier : mis de côté, jamais supprimé
    else
        recorded "$dest" || record link "$dest" -
    fi
    run mkdir -p "$(dirname "$dest")"
    run ln -sfn "$src" "$dest"
}

# Copie initiale d'un fichier que l'application réécrit elle-même (un lien casserait) : seulement s'il est absent.
seed() {        # src dest
    if [[ -e "$2" ]]; then echo "= $2 (déjà présent, gardé)"; return; fi
    record seed "$2" -
    run mkdir -p "$(dirname "$2")"
    run cp "$repo/$1" "$2"
}

# Clés d'un fichier INI (ou `clé = valeur` sans section) : seules ces clés changent, le reste du fichier est gardé.
ini_set() {     # fichier section clé valeur [clé valeur…] ; section "" = début du fichier ; séparateur "=" ou " = " gardé
    local file="$1" section="$2"; shift 2
    command -v python3 >/dev/null || { echo "- python3 absent (installé à l'étape 1) : $file non réglé"; return; }
    local changes
    changes="$(python3 -I - "$file" "$section" "$@" <<'EOF'
import sys
path, section, pairs = sys.argv[1], sys.argv[2], sys.argv[3:]
want = dict(zip(pairs[::2], pairs[1::2]))
try:
    lines = open(path, encoding="utf-8").read().splitlines()
except FileNotFoundError:
    lines = []
flat = section.startswith("@")
if flat:
    sep, section = section[1:], ""
else:
    sep = " = " if any(" = " in l for l in lines) else "="
cur, seen, out, end = "", set(), [], None
for i, l in enumerate(lines):
    s = l.strip()
    if flat:
        k = s.split(sep.strip() or None, 1)[0].strip() if s and not s.startswith(("#", "!")) else ""
        if k in want:
            seen.add(k)
            l = k + sep + want[k]
    elif s.startswith("[") and s.endswith("]"):
        if cur == section and end is None: end = len(out)
        cur = s[1:-1]
    elif cur == section and "=" in s and not s.startswith(("#", ";")):
        k = s.split("=", 1)[0].strip()
        if k in want:
            seen.add(k)
            l = k + sep + want[k]
    out.append(l)
if cur == section and end is None: end = len(out)
missing = [k + sep + v for k, v in want.items() if k not in seen]
if missing:
    if end is None:
        if section: out += (["", f"[{section}]"] if out else [f"[{section}]"])
        end = len(out)
    out[end:end] = missing
new = "\n".join(out) + "\n"
old = "\n".join(lines) + "\n" if lines else ""
print("same" if new == old else new, end="")
EOF
)"
    if [[ "$changes" == same ]]; then echo "= $file [$section] ${*:1:1}…"; return; fi
    if [[ -e "$file" ]]; then backup_once edit "$file" cp
    elif ! recorded "$file"; then record seed "$file" -; fi
    printf '+ %s : [%s] %s\n' "$file" "$section" "$*"
    [[ -n "$dry" ]] && return
    mkdir -p "$(dirname "$file")"
    printf '%s' "$changes" > "$file"
}

# Bloc ajouté à la fin d'un fichier (ex. ~/.bashrc), repéré par sa première ligne ; le reste du fichier n'est pas touché.
block() {       # fichier ligne-repère contenu
    if [[ -f "$1" ]] && grep -qxF "$2" "$1"; then echo "= $1 (bloc qs-desktop)"; return; fi
    recorded "$1" || record block "$1" "$2"
    printf '+ ajout à %s : %s\n' "$1" "$2"
    [[ -n "$dry" ]] && return
    printf '\n%s\n%s\n' "$2" "$3" >> "$1"
}

pkg_list() {    # fichiers de deps/ → noms de paquets
    for f in "$@"; do grep -v '^\s*#' "$repo/deps/$f" | cut -d'#' -f1 | xargs -r -n1; done
}

gpu_vendors() { # cartes graphiques présentes : nvidia intel amd
    command -v lspci >/dev/null || return 0
    lspci -nn | grep -E 'VGA|3D|Display' | grep -oE '\[(10de|8086|1002):' | sort -u | sed 's/\[10de:/nvidia/; s/\[8086:/intel/; s/\[1002:/amd/'
}

# --- 1. Paquets --------------------------------------------------------------------------------------------------------

is_arch() { [[ -f /etc/arch-release ]] || grep -qsE '^ID(_LIKE)?=.*\barch\b' /etc/os-release; }

step_packages() {
    section "1. Paquets"
    if ! is_arch; then
        echo "Distribution autre qu'Arch : paquets à installer soi-même, noms et correspondances dans deps/README.md"
        echo "(« Correspondance avec d'autres distributions »). Suite de l'installation : configs du compte seulement."
        return
    fi
    [[ -n "$system" ]] && "$repo/scripts/system-setup.sh" ${dry:+--dry-run} multilib
    local want=() vendors v
    mapfile -t want < <(pkg_list arch-pacman.txt apps.txt)
    if [[ "$games" == ask ]]; then
        if [[ -n "$yes" ]]; then games=no; elif ask "Installer aussi le profil jeux (Steam, gamescope, Lutris, GameMode) ?"; then games=yes; else games=no; fi
    fi
    [[ "$games" == yes ]] && mapfile -t -O "${#want[@]}" want < <(pkg_list games.txt)
    mapfile -t vendors < <(gpu_vendors)
    for v in "${vendors[@]}"; do
        mapfile -t -O "${#want[@]}" want < <(awk -v v="$v" -v g="$games" '!/^#/ && NF >= 2 && ($1 == v || (g == "yes" && $1 == v "-jeux")) { print $2 }' "$repo/deps/gpu.txt")
    done
    compgen -G '/sys/class/backlight/*' >/dev/null && want+=(brightnessctl)
    # Laptop (batterie) : profils d'énergie du panneau de réglages ; pas sur un desktop.
    compgen -G '/sys/class/power_supply/BAT*' >/dev/null && want+=(power-profiles-daemon)
    # « a|b » (deps/apps.txt) : l'un ou l'autre suffit ; sinon le premier est installé.
    local i alt choice
    for i in "${!want[@]}"; do
        [[ "${want[$i]}" == *"|"* ]] || continue
        choice="${want[$i]%%|*}"
        for alt in ${want[$i]//|/ }; do pacman -Q "$alt" >/dev/null 2>&1 && { choice=""; break; }; done
        if [[ -n "$choice" ]]; then want[$i]="$choice"; else unset 'want[i]'; fi
    done
    want=("${want[@]}")
    echo "Cartes graphiques : ${vendors[*]:-aucune détectée}"
    local missing
    missing="$(pacman -T "${want[@]}" || true)"
    if [[ -z "$missing" ]]; then
        echo "= tous les paquets sont installés (${#want[@]})"
    else
        echo "Paquets à installer : $(echo $missing)"
        printf '+ sudo pacman -Syu --needed %s%s\n' "${yes:+--noconfirm }" "$(echo $missing)"
        [[ -n "$dry" ]] || sudo pacman -Syu --needed ${yes:+--noconfirm} $missing
    fi
    # paru : seul paquet AUR, construit depuis aur.archlinux.org (binaire déjà compilé : paru-bin).
    if command -v paru >/dev/null || command -v yay >/dev/null; then
        echo "= $(command -v paru || command -v yay)"
    else
        if [[ -n "$dry" ]]; then
            echo "+ git clone --depth 1 https://aur.archlinux.org/paru-bin.git <dossier temporaire> && makepkg -si --noconfirm"
        else
            local tmp
            tmp="$(mktemp -d)"
            git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
            (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
            rm -rf "$tmp"
        fi
    fi
}

# --- 2. Configs du compte ----------------------------------------------------------------------------------------------

host_file() {   # dossier-du-dépôt extension → hosts/<machine>.<ext> s'il existe, sinon le défaut donné en $3
    if [[ -f "$repo/$1/hosts/$host.$2" ]]; then echo "$1/hosts/$host.$2"; else echo "$3"; fi
}

dnd_mutes() {   # la machine coupe-t-elle des applications la nuit ? (doNotDisturb.muteApps non vide)
    command -v python3 >/dev/null || return 1
    python3 -I - "$repo/hosts/default.json" "$repo/hosts/$host.json" <<'EOF'
import json, sys
conf = {}
for p in sys.argv[1:]:
    try: conf.update(json.load(open(p)))
    except FileNotFoundError: pass
sys.exit(0 if conf.get("doNotDisturb", {}).get("muteApps") else 1)
EOF
}

step_configs() {
    section "2. Configs du compte"
    link . "$config/quickshell/desktop"
    link dotfiles/sway "$config/sway"
    link dotfiles/hypr "$config/hypr"
    link dotfiles/fastfetch "$config/fastfetch"
    link dotfiles/starship/starship.toml "$config/starship.toml"
    link dotfiles/mpv "$config/mpv"
    # host.conf vit dans le dépôt (dotfiles/mpv est lié) : ignoré par git, choisi pour cette machine.
    local mpv_host
    mpv_host="$(host_file dotfiles/mpv conf dotfiles/mpv/hosts/default.conf)"
    if [[ "$(readlink "$repo/dotfiles/mpv/host.conf" 2>/dev/null)" == "${mpv_host#dotfiles/mpv/}" ]]; then
        echo "= dotfiles/mpv/host.conf → ${mpv_host#dotfiles/mpv/}"
    else
        run ln -sfn "${mpv_host#dotfiles/mpv/}" "$repo/dotfiles/mpv/host.conf"
    fi
    link "$(host_file dotfiles/chromium conf dotfiles/chromium/chromium-flags.conf)" "$config/chromium-flags.conf"
    if dnd_mutes; then
        link dotfiles/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf "$config/wireplumber/wireplumber.conf.d/50-dnd-no-restore.conf"
    fi
    seed dotfiles/viewnior/viewnior.conf "$config/viewnior/viewnior.conf"
    touch_bashrc
    # Dunst (ancien démon de notifications) masqué : Quickshell fait les notifications.
    if [[ -f /usr/lib/systemd/user/dunst.service ]] && systemctl --user show-environment >/dev/null 2>&1 \
        && [[ "$(systemctl --user is-enabled dunst.service 2>/dev/null)" != masked ]]; then
        run systemctl --user mask dunst.service
        record unit-mask dunst.service -
    fi
}

touch_bashrc() {
    block "$HOME/.bashrc" "# qs-desktop (install.sh) : starship, EDITOR, BROWSER" \
        "[ -f \"\${XDG_CONFIG_HOME:-\$HOME/.config}/quickshell/desktop/dotfiles/bash/qs-desktop.bash\" ] && . \"\${XDG_CONFIG_HOME:-\$HOME/.config}/quickshell/desktop/dotfiles/bash/qs-desktop.bash\""
}

# --- 3. Thème ----------------------------------------------------------------------------------------------------------

# Archive de deps/themes.txt : téléchargée une fois dans le cache, vérifiée, extraite dans un dossier temporaire.
fetch() {       # nom → affiche le dossier extrait
    local name="$1" sha url file dir
    read -r sha url < <(awk -v n="$name" '$1 == n { print $2, $3 }' "$repo/deps/themes.txt")
    [[ -n "$url" ]] || { echo "! $name absent de deps/themes.txt" >&2; return 1; }
    # Simulation : téléchargement dans un dossier temporaire, le cache n'est pas rempli.
    local store="$cache"
    [[ -n "$dry" ]] && store="$dry_cache"
    file="$store/$name-${sha:0:12}.${url##*.}"
    if [[ ! -f "$file" ]] || ! echo "$sha  $file" | sha256sum -c --status; then
        mkdir -p "$store"
        curl -fsSL --connect-timeout 15 --max-time 300 --retry 3 --retry-delay 5 --retry-all-errors -o "$file.part" "$url" || { echo "! téléchargement de $name impossible : $url" >&2; return 1; }
        if ! echo "$sha  $file.part" | sha256sum -c --status; then
            rm -f "$file.part"; echo "! $name : empreinte différente de deps/themes.txt, archive refusée" >&2; return 1
        fi
        mv "$file.part" "$file"
    fi
    dir="$(mktemp -d)"
    case "$file" in
        *.zip) unzip -q "$file" -d "$dir" ;;
        *) tar -xzf "$file" -C "$dir" ;;
    esac
    echo "$dir"
}

# Dossier du thème copié en entier ; un dossier déjà là sans notre marque est sauvegardé. Marque = empreinte de l'archive.
put_dir() {     # source cible nom-de-l'archive
    local mark="$2/.qs-desktop" sha
    sha="$(awk -v n="$3" '$1 == n { print $2 }' "$repo/deps/themes.txt")"
    if [[ -f "$mark" && "$(cat "$mark")" == "$sha" ]]; then echo "= $2"; return; fi
    if [[ -e "$2" ]]; then
        if recorded "$2"; then run rm -rf "$2"; else backup_once link "$2" mv; fi
    else
        recorded "$2" || record link "$2" -
    fi
    run mkdir -p "$(dirname "$2")"
    run cp -r "$1" "$2"
    [[ -n "$dry" ]] || echo "$sha" > "$mark"
}

put_file() {    # source cible : fichier du thème, l'ancien sauvegardé
    if [[ -f "$2" ]] && cmp -s "$1" "$2"; then echo "= $2"; return; fi
    if [[ -e "$2" ]]; then backup_once edit "$2" cp; elif ! recorded "$2"; then record seed "$2" -; fi
    run mkdir -p "$(dirname "$2")"
    run cp "$1" "$2"
}

# Dossiers Catppuccin lavande (ton choix : comme sur le desktop de référence) sans toucher au thème du système : surcouche Papirus dans le compte (mêmes noms de dossiers, les autres icônes
# viennent toujours de /usr/share/icons/Papirus). Les noms génériques (folder.svg, user-home.svg…) pointent vers $folders.
papirus_overlay() {     # dossier src/ de catppuccin/papirus-folders
    local src="$1" top="$data/icons" sys=/usr/share/icons/Papirus folders=cat-mocha-lavender color size f t new
    [[ -d "$sys" ]] || { echo "- Papirus absent (papirus-icon-theme) : couleur des dossiers ignorée"; return; }
    color="$(readlink "$sys/48x48/places/folder.svg")"; color="${color#folder-}"; color="${color%.svg}"
    local tree; tree="$(mktemp -d)"
    for size in 22x22 24x24 32x32 48x48 64x64; do
        mkdir -p "$tree/Papirus/$size/places"
        cp "$src/$size/places/"*-"$folders"* "$tree/Papirus/$size/places/"
        for f in "$sys/$size/places/"*; do
            [[ -L "$f" ]] || continue
            t="$(readlink "$f")"
            [[ "$t" == *"-$color"* && "$t" != */* ]] || continue
            new="${t/-$color/-$folders}"
            [[ -e "$tree/Papirus/$size/places/$new" || -e "$sys/$size/places/$new" ]] && ln -sfn "$new" "$tree/Papirus/$size/places/$(basename "$f")"
        done
        ln -sfn "$size" "$tree/Papirus/$size@2x"
        mkdir -p "$tree/Papirus-Dark"
        ln -sfn "../Papirus/$size" "$tree/Papirus-Dark/$size"
        ln -sfn "$size" "$tree/Papirus-Dark/$size@2x"
    done
    put_dir "$tree/Papirus" "$top/Papirus" papirus-folders
    put_dir "$tree/Papirus-Dark" "$top/Papirus-Dark" papirus-folders
    rm -rf "$tree"
    [[ -n "$dry" ]] || gtk-update-icon-cache -q -f -t "$top/Papirus" 2>/dev/null || true
}

step_theme() {
    section "3. Thème (Catppuccin Mocha, accent green)"
    local d v theme=catppuccin-mocha-green-standard+default cursor=catppuccin-mocha-green-cursors
    command -v curl >/dev/null && command -v unzip >/dev/null || { echo "! curl ou unzip absent : thème non installé"; return; }

    if d="$(fetch gtk)"; then
        for v in "" -hdpi -xhdpi; do [[ -d "$d/$theme$v" ]] && put_dir "$d/$theme$v" "$data/themes/$theme$v" gtk; done
        rm -rf "$d"
        # GTK 4 / libadwaita n'a pas de thème : feuilles du thème liées dans ~/.config/gtk-4.0.
        for f in gtk.css gtk-dark.css assets; do link "$data/themes/$theme/gtk-4.0/$f" "$config/gtk-4.0/$f"; done
    fi

    if d="$(fetch cursors)"; then
        put_dir "$d/$cursor" "$data/icons/$cursor" cursors
        rm -rf "$d"
    fi

    if d="$(fetch kvantum)"; then
        put_dir "$d"/kvantum-*/themes/catppuccin-mocha-green "$config/Kvantum/catppuccin-mocha-green" kvantum
        rm -rf "$d"
    fi

    if d="$(fetch papirus-folders)"; then
        papirus_overlay "$(echo "$d"/papirus-folders-*/src)"
        rm -rf "$d"
    fi

    if d="$(fetch geany)"; then
        put_file "$(echo "$d"/geany-*/src/catppuccin-mocha.conf)" "$config/geany/colorschemes/catppuccin-mocha.conf"
        rm -rf "$d"
    fi

    # Même thème, mêmes polices et même curseur partout (docs/THEME.md ; procédure du curseur : deps/README.md).
    local gtk=(gtk-theme-name "$theme" gtk-icon-theme-name Papirus-Dark gtk-font-name "Inter Light 12"
               gtk-cursor-theme-name "$cursor" gtk-cursor-theme-size 48 gtk-application-prefer-dark-theme 1)
    ini_set "$config/gtk-3.0/settings.ini" Settings "${gtk[@]}"
    ini_set "$config/gtk-4.0/settings.ini" Settings "${gtk[@]}"
    ini_set "$HOME/.gtkrc-2.0" "" gtk-theme-name "\"$theme\"" gtk-icon-theme-name '"Papirus-Dark"' gtk-font-name '"Inter Light 12"' \
        gtk-cursor-theme-name "\"$cursor\"" gtk-cursor-theme-size 48
    ini_set "$config/xsettingsd/xsettingsd.conf" "@ " Net/ThemeName "\"$theme\"" Net/IconThemeName '"Papirus-Dark"' \
        Gtk/CursorThemeName "\"$cursor\"" Gtk/CursorThemeSize 48
    ini_set "$HOME/.icons/default/index.theme" "Icon Theme" Inherits "$cursor" Size 48
    ini_set "$HOME/.Xresources" "@: " Xcursor.theme "$cursor" Xcursor.size 48
    # Qt : Kvantum Catppuccin, icônes Papirus-Dark, polices de GTK (QT_QPA_PLATFORMTHEME=qt6ct : étape système).
    ini_set "$config/Kvantum/kvantum.kvconfig" General theme catppuccin-mocha-green
    ini_set "$config/qt6ct/qt6ct.conf" Appearance style kvantum icon_theme Papirus-Dark custom_palette false standard_dialogs default
    ini_set "$config/qt6ct/qt6ct.conf" Fonts general '"Inter,12,-1,5,300,0,0,0,0,0,0,0,0,0,0,1"' \
        fixed '"Source Code Pro,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"'
}

# --- 4. Réglages -------------------------------------------------------------------------------------------------------

dconf_apply() { # fichier ini du dépôt ; anciennes valeurs gardées dans $state/dconf-old.ini pour --uninstall
    python3 -I "$repo/scripts/dconf-keys.py" ${dry:+--dry-run} apply "$repo/$1" "$state/dconf-old.ini" "$HOME"
}

step_settings() {
    section "4. Réglages des applications"
    if command -v dconf >/dev/null && command -v python3 >/dev/null; then
        dconf_apply dotfiles/dconf/desktop.ini
        [[ -f "$repo/dotfiles/dconf/hosts/$host.ini" ]] && dconf_apply "dotfiles/dconf/hosts/$host.ini"
    else
        echo "- dconf absent : réglages GSettings ignorés"
    fi

    # Applications par défaut.
    local mimeapps="$config/mimeapps.list" app types
    while read -r app types; do
        [[ -z "$app" || "$app" == \#* ]] && continue
        if [[ ! -f "/usr/share/applications/$app" && ! -f "$data/applications/$app" ]]; then
            echo "- $app absent : ses types ne changent pas"; continue
        fi
        local todo=() t
        for t in $types; do [[ "$(xdg-mime query default "$t" 2>/dev/null)" == "$app" ]] || todo+=("$t"); done
        if [[ ${#todo[@]} -eq 0 ]]; then echo "= $app par défaut"; continue; fi
        if [[ -e "$mimeapps" ]]; then backup_once edit "$mimeapps" cp; elif ! recorded "$mimeapps"; then record seed "$mimeapps" -; fi
        run xdg-mime default "$app" "${todo[@]}"
    done < "$repo/dotfiles/mime/defaults.list"

    # Geany : son fichier de réglages est réécrit par l'application ; seules les clés du thème et des polices changent.
    ini_set "$config/geany/geany.conf" geany color_scheme catppuccin-mocha.conf editor_font "Inter 16" tagbar_font "Symbols Nerd Font Mono 9"

    if command -v python3 >/dev/null; then step_webapps; else echo "- python3 absent (installé à l'étape 1) : web apps non générées"; fi
    if command -v chromium >/dev/null; then
        python3 "$repo/scripts/browser-links-setup.py" ${dry:+--dry-run} install
    fi
}

# Web apps (deps/README.md, « Web apps ») : lanceurs et manifestes de l'hôte natif développés depuis dotfiles/webapps.
step_webapps() {
    local webapps="$repo/dotfiles/webapps" profiles="$data/ice/profiles" tpl name out content
    if [[ "$webapps$profiles" == *[\"\`\$\\%]* ]]; then
        echo "! chemin du dépôt ou des profils avec \" \` \$ \\ ou % : web apps non installées"; return
    fi
    local quote=""
    [[ "$profiles$webapps" == *" "* ]] && quote='s/(--(user-data-dir|load-extension)=@(PROFILES|WEBAPPS)@[^ ]*)/"\1"/g'
    for tpl in "$webapps"/applications/*.desktop; do
        name="$(basename "$tpl")"; out="$data/applications/$name"
        # Chemin avec espace : argument entier entre guillemets dans Exec.
        content="$(sed -E "${quote:-}" "$tpl" | sed -e "s|@PROFILES@|$profiles|g" -e "s|@WEBAPPS@|$webapps|g")"
        if [[ -f "$out" ]] && [[ "$(cat "$out")" == "$content" ]]; then echo "= $out"; continue; fi
        backup_once edit "$out" cp
        printf '+ %s (modèle %s)\n' "$out" "$name"
        [[ -n "$dry" ]] || { mkdir -p "$data/applications"; printf '%s\n' "$content" > "$out"; }
    done
    local profile manifest json
    json="$(python3 -I -c 'import json,sys; print(json.dumps(sys.argv[1])[1:-1])' "$webapps")"
    for profile in $(grep -ho -- '--user-data-dir=@PROFILES@/[^ "]*' "$webapps"/applications/*.desktop | sed 's|.*/||' | sort -u); do
        manifest="$profiles/$profile/NativeMessagingHosts/qs_desktop.open_link.json"
        content="$(sed "s|@WEBAPPS@|$json|g" "$webapps/qs_desktop.open_link.json")"
        if [[ -f "$manifest" ]] && [[ "$(cat "$manifest")" == "$content" ]]; then echo "= $manifest"; continue; fi
        backup_once edit "$manifest" cp
        printf '+ %s\n' "$manifest"
        [[ -n "$dry" ]] || { mkdir -p "$(dirname "$manifest")"; printf '%s\n' "$content" > "$manifest"; }
    done
    [[ -x "$webapps/open-link" ]] || run chmod +x "$webapps/open-link"
    if [[ -z "$dry" ]] && command -v update-desktop-database >/dev/null; then
        [[ -e "$data/applications/mimeinfo.cache" ]] || recorded "$data/applications/mimeinfo.cache" || record seed "$data/applications/mimeinfo.cache" -
        update-desktop-database "$data/applications" 2>/dev/null || true
    fi
}

# --- 5. Config machine -------------------------------------------------------------------------------------------------

step_host() {
    section "5. Config machine ($host)"
    local file="$repo/hosts/$host.json"
    if [[ -f "$file" ]]; then echo "= hosts/$host.json"; return; fi
    # Valeurs détectées seulement ; le reste vient de hosts/default.json (écran unique, laptop).
    local session=""
    (. "$repo/scripts/qs-env.sh" && qs_nvidia_only) && session='  "greeter": { "defaultSession": "wayland/sway-vulkan" }'
    printf '+ hosts/%s.json créé (à committer)\n' "$host"
    record seed "$file" -
    [[ -n "$dry" ]] || printf '{\n%s\n}\n' "$session" > "$file"
}

# --- 6. Système (sudo) -------------------------------------------------------------------------------------------------

# Script système : en simulation sur une machine neuve, ses prérequis (paquets de l'étape 1) peuvent manquer.
sub() {
    "$@" && return 0
    [[ -n "$dry" ]] || return 1
    echo "! ${1##*/} : simulation incomplète, prérequis installés à l'étape 1"
}

step_system() {
    section "6. Système (sudo, avec confirmation)"
    if ask "Écran de connexion greetd + greeter Quickshell (remplace le gestionnaire actuel) ?"; then
        sub "$repo/scripts/greeter-setup.sh" ${dry:+--dry-run} install
        if [[ -n "$dry" && ! -d /usr/local/share/qs-desktop ]]; then
            echo "+ scripts/greeter-setup.sh enable (après l'installation ci-dessus)"
        else
            sub "$repo/scripts/greeter-setup.sh" ${dry:+--dry-run} enable
        fi
    fi
    if ask "Samba, services (réseau, Bluetooth, énergie, VM), groupes et thème Qt du système ?"; then
        sub "$repo/scripts/system-setup.sh" ${dry:+--dry-run} install
    fi
    if ask "Sonde de connectivité NetworkManager (portails captifs Wi-Fi) ?"; then
        # Déjà installée : le script rechargerait NetworkManager pour rien.
        if cmp -s "$repo/dotfiles/NetworkManager/conf.d/90-qs-desktop-connectivity.conf" /etc/NetworkManager/conf.d/90-qs-desktop-connectivity.conf \
            && [[ -f /var/lib/qs-desktop/network-setup/ready ]]; then
            echo "= sonde de connectivité installée"
        else
            sub "$repo/scripts/network-setup.sh" ${dry:+--dry-run} install
        fi
    fi
}

# --- Retrait -----------------------------------------------------------------------------------------------------------

do_uninstall() {
    section "Retrait des configs du compte"
    if [[ -f "$registry" ]]; then
        local kind target backup
        while IFS=$'\t' read -r kind target backup <&3; do
            case "$kind" in
                link|seed|edit)
                    if [[ "$backup" == - ]]; then run rm -rf "$target"
                    elif [[ -e "$backup" || -L "$backup" ]]; then run rm -rf "$target"; run mv "$backup" "$target"
                    else echo "! sauvegarde $backup introuvable : $target laissé tel quel"; fi ;;
                block)
                    printf '+ retrait du bloc de %s\n' "$target"
                    [[ -n "$dry" ]] || python3 -I - "$target" "$backup" <<'EOF'
import sys
path, marker = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().split("\n")
if marker in lines:
    i = lines.index(marker)
    del lines[i:i + 2]
    if i > 0 and lines[i - 1] == "": del lines[i - 1]
open(path, "w", encoding="utf-8").write("\n".join(lines))
EOF
                    ;;
                unit-mask) run systemctl --user unmask "$target" ;;
            esac
        done 3< <(tac "$registry")
        [[ -f "$state/dconf-old.ini" ]] && python3 -I "$repo/scripts/dconf-keys.py" ${dry:+--dry-run} restore "$state/dconf-old.ini"
        run rm -f "$registry" "$state/dconf-old.ini"
        [[ -L "$repo/dotfiles/mpv/host.conf" ]] && run rm -f "$repo/dotfiles/mpv/host.conf"
    else
        echo "= rien à retirer ($registry absent)"
    fi
    command -v chromium >/dev/null && python3 "$repo/scripts/browser-links-setup.py" ${dry:+--dry-run} uninstall
    if [[ -n "$system" ]] && ask "Défaire aussi les étapes système (greeter → ancien gestionnaire, sonde réseau, Samba, services, groupes) ?"; then
        "$repo/scripts/system-setup.sh" ${dry:+--dry-run} uninstall
        "$repo/scripts/network-setup.sh" ${dry:+--dry-run} uninstall
        "$repo/scripts/greeter-setup.sh" ${dry:+--dry-run} uninstall
    fi
    echo "Paquets conservés (paru compris)."
}

# --- Vérifications finales ---------------------------------------------------------------------------------------------

step_check() {
    section "Vérifications"
    local c missing=()
    for c in qs sway hyprctl checkupdates fakeroot bluetoothctl udisksctl gdbus busctl grim slurp wl-copy pavucontrol fastfetch starship chromium; do
        command -v "$c" >/dev/null || missing+=("$c")
    done
    for f in "Inter" "Symbols Nerd Font Mono" "Hack Nerd Font" "Font Awesome 7 Free" "FontAwesome" "Source Code Pro"; do
        fc-list ":family=$f" family 2>/dev/null | grep -q . || missing+=("« $f »")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then echo "= commandes et polices du bureau présentes"; else echo "! absents : ${missing[*]}"; fi
    [[ -n "$dry" ]] && return
    echo
    echo "Terminé. À faire soi-même (README.md) : mot de passe Samba (sudo smbpasswd -a $USER), première connexion des web apps,"
    echo "thème Catppuccin dans Obsidian / Thunderbird, logiciels hors dépôts (Claude Code, NordVPN, Plex, RustDesk)."
    echo "Nouveaux groupes et thème Qt : effectifs à la prochaine connexion."
}

if [[ -n "$uninstall" ]]; then
    do_uninstall
    exit 0
fi
[[ -n "$dry" ]] && echo "Simulation : rien ne sera modifié."
[[ -n "$packages" ]] && step_packages
step_configs
step_theme
step_settings
step_host
[[ -n "$system" ]] && is_arch && step_system
step_check
