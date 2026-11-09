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
        -h|--help) sed -n '4,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

# --- Outils ------------------------------------------------------------------------------------------------------------

section() { printf '\n== %s\n' "$*"; }

# Réglage remis à plus tard (application ouverte…) : signalé tout de suite et rappelé à la fin.
pending=()
later() { echo "! $*"; pending+=("$*"); }

run() {     # commande du compte
    printf '+ %s\n' "$*"
    [[ -n "$dry" ]] || "$@"
}

ask() {     # $1 = question, $2 = réponse à Entrée : oui | non (défaut non) ; oui avec --yes
    local default="${2:-non}" answer=""
    [[ -n "$yes" ]] && return 0
    [[ -n "$dry" ]] && { echo "? $1 (simulation : oui)"; return 0; }
    # Aucun terminal (lancement automatique) : réponse « non », sans attendre.
    if ! { : </dev/tty; } 2>/dev/null; then echo "? $1 (pas de terminal : non)"; return 1; fi
    # Question écrite sur le terminal lui-même : visible même si la sortie du script est redirigée.
    if [[ "$default" == oui ]]; then printf '? %s [O/n] ' "$1" >/dev/tty; else printf '? %s [o/N] ' "$1" >/dev/tty; fi
    read -r answer </dev/tty || return 1
    [[ -z "$answer" ]] && answer="$default"
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
# copiée (edit). Rien à sauvegarder : « - ». Copie : contenu du fichier même si la cible est un lien (stow…), car l'écriture qui suit
# passe à travers le lien ; le retrait réécrit ce contenu à travers le lien, qui reste en place.
backup_once() {     # genre cible mv|cp
    local kind="$1" target="$2" how="$3" backup="-"
    recorded "$target" && return
    if [[ -e "$target" || -L "$target" ]]; then
        backup="$target.bak-$stamp"
        if [[ "$how" == cp ]]; then run cp -pL "$target" "$backup"; else run mv "$target" "$backup"; fi
    fi
    record "$kind" "$target" "$backup"
}

# Empreinte d'un fichier tel qu'install.sh l'a écrit : le retrait sait si une application l'a modifié depuis.
written_mark() { echo "$state/written/$(printf '%s' "$1" | sha256sum | cut -c1-16)"; }
written() {
    [[ -n "$dry" || ! -f "$1" ]] && return 0
    mkdir -p "$state/written"
    sha256sum < "$1" > "$(written_mark "$1")"
}

# Lien `dest` → `src` (chemin du dépôt). Un fichier ou dossier déjà là est sauvegardé (déplacé) avant.
link() {        # src (chemin du dépôt, ou absolu) dest
    local src="$1" dest="$2"
    if [[ "$src" == . ]]; then src="$repo"; elif [[ "$src" != /* ]]; then src="$repo/$src"; fi
    # Déjà le bon lien, ou la cible elle-même (dépôt cloné directement dans ~/.config/quickshell/desktop).
    if [[ -e "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
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
    # Lien (stow) déjà là, même vers un fichier encore absent : à toi, gardé (cp n'écrit pas à travers un lien qui ne mène à rien).
    if [[ -e "$2" || -L "$2" ]]; then echo "= $2 (déjà présent, gardé)"; return; fi
    recorded "$2" || record seed "$2" -
    run mkdir -p "$(dirname "$2")"
    run cp "$repo/$1" "$2"
    written "$2"
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
)" || { echo "! $file illisible (encodage ?) : non réglé"; return 0; }
    [[ -n "$changes" ]] || return 0
    if [[ "$changes" == same ]]; then echo "= $file [$section] ${*:1:1}…"; return; fi
    before_write "$file"
    printf '+ %s : [%s] %s\n' "$file" "$section" "$*"
    [[ -n "$dry" ]] && return
    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$changes" > "$file"
    written "$file"
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

gpu_vendors() { # cartes graphiques présentes : nvidia intel amd, lues par lspci (pciutils, installé avant par step_packages)
    if command -v lspci >/dev/null; then
        lspci -nn | grep -E 'VGA|3D|Display' | grep -oE '\[(10de|8086|1002):' | sort -u \
            | sed 's/\[10de:/nvidia/; s/\[8086:/intel/; s/\[1002:/amd/'
        return
    fi
    # Simulation sur une machine sans pciutils : mêmes informations lues dans sysfs (classe PCI 03 : affichage).
    local d
    for d in /sys/bus/pci/devices/*; do
        [[ "$(cat "$d/class" 2>/dev/null)" == 0x03* ]] || continue
        case "$(cat "$d/vendor" 2>/dev/null)" in
            0x10de) echo nvidia ;; 0x8086) echo intel ;; 0x1002) echo amd ;;
        esac
    done | sort -u
}

# --- 1. Paquets --------------------------------------------------------------------------------------------------------

is_arch() { [[ -f /etc/arch-release ]] || grep -qsE '^ID(_LIKE)?=.*\barch\b' /etc/os-release; }

step_packages() {
    section "1. Paquets"
    if ! is_arch; then
        echo "Distribution autre qu'Arch : paquets à installer soi-même (listes Arch de deps/, pas encore de correspondances"
        echo "pour les autres distributions). Suite de l'installation : configs du compte seulement."
        return
    fi
    if [[ -n "$system" ]] && ! grep -q '^\[multilib\]' /etc/pacman.conf \
        && ask "Activer le dépôt multilib de pacman (Steam, jeux 32 bits) ?" oui; then
        "$repo/scripts/system-setup.sh" ${dry:+--dry-run} multilib || echo "! multilib non activé : Steam et les paquets lib32 resteront indisponibles"
    fi
    local want=() vendors v
    mapfile -t want < <(pkg_list arch-pacman.txt apps.txt)
    if [[ "$games" == ask ]]; then
        if [[ -n "$yes" ]]; then games=no; elif ask "Installer aussi le profil jeux (Steam, gamescope, Lutris, GameMode) ?"; then games=yes; else games=no; fi
    fi
    # Steam et les paquets lib32 viennent de [multilib] : sans lui, profil jeux retiré (pacman échouerait et arrêterait tout).
    local multilib=""
    grep -q '^\[multilib\]' /etc/pacman.conf && multilib=1
    if [[ "$games" == yes && -z "$multilib" && -z "$dry" ]]; then
        echo "! [multilib] inactif : profil jeux non installé (relancer install.sh et accepter multilib)"; games=no
    fi
    [[ "$games" == yes ]] && mapfile -t -O "${#want[@]}" want < <(pkg_list games.txt)
    # lspci d'abord : il choisit les paquets de la carte graphique de ce même passage.
    # -Syu : base des paquets à jour (une base périmée ferait échouer le téléchargement), système mis à jour d'abord ; une fois.
    local sync=-Syu
    if ! command -v lspci >/dev/null; then
        printf '+ sudo pacman -Syu --needed %spciutils\n' "${yes:+--noconfirm }"
        [[ -n "$dry" ]] || sudo pacman -Syu --needed ${yes:+--noconfirm} pciutils
        sync=-S
    fi
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
        printf '+ sudo pacman %s --needed %s%s\n' "$sync" "${yes:+--noconfirm }" "$(echo $missing)"
        [[ -n "$dry" ]] || sudo pacman "$sync" --needed ${yes:+--noconfirm} $missing
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
            # Optionnel (mises à jour AUR) : un échec (AUR injoignable…) n'arrête pas l'installation.
            { git clone -q --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin" \
                && (cd "$tmp/paru-bin" && makepkg -si --noconfirm); } \
                || echo "! paru non installé (AUR injoignable ?) : relancer install.sh plus tard"
            rm -rf "$tmp"
        fi
    fi
}

# --- 2. Configs du compte ----------------------------------------------------------------------------------------------

host_file() {   # dossier-du-dépôt extension → hosts/<machine>.<ext> s'il existe, sinon le défaut donné en $3
    if [[ -f "$repo/$1/hosts/$host.$2" ]]; then echo "$1/hosts/$host.$2"; else echo "$3"; fi
}

# Valeur de premier niveau de la config machine (hosts/default.json puis hosts/<machine>.json, comme config/Settings.qml) ;
# un chemin pointé (doNotDisturb.muteApps) descend dans les objets. Vide si absente.
host_setting() {
    command -v python3 >/dev/null || return 0
    if python3 -I - "$1" "$repo/hosts/default.json" "$repo/hosts/$host.json" <<'EOF'
import json, sys
conf = {}
for p in sys.argv[2:]:
    try: conf.update(json.load(open(p)))
    except FileNotFoundError: pass
v = conf
for k in sys.argv[1].split("."):
    v = v.get(k) if isinstance(v, dict) else None
if isinstance(v, (list, dict)):
    print(json.dumps(v) if v else "")
else:
    print("" if v is None else v)
EOF
    then :; else echo "! hosts/$host.json illisible (JSON invalide ?) : réglage $1 par défaut" >&2; fi
}

dnd_mutes() {   # la machine coupe-t-elle des applications la nuit ? (doNotDisturb.muteApps non vide)
    [[ -n "$(host_setting doNotDisturb.muteApps)" ]]
}

step_configs() {
    section "2. Configs du compte"
    link . "$config/quickshell/desktop"
    link dotfiles/sway "$config/sway"
    link dotfiles/hypr "$config/hypr"
    link dotfiles/fastfetch "$config/fastfetch"
    link dotfiles/starship/starship.toml "$config/starship.toml"
    # Lanceur : entrée « Gammastep Indicator » masquée (veilleuse réglée par la barre).
    link dotfiles/applications/gammastep-indicator.desktop "$data/applications/gammastep-indicator.desktop"
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

theme_sha() { awk -v n="$1" '$1 == n { print $2 }' "$repo/deps/themes.txt"; }   # empreinte d'une archive de deps/themes.txt

# Archive de deps/themes.txt : téléchargée une fois dans le cache, vérifiée, extraite dans un dossier temporaire.
fetch() {       # nom → affiche le dossier extrait
    local name="$1" sha url file dir
    read -r sha url < <(awk -v n="$name" '$1 == n { print $2, $3 }' "$repo/deps/themes.txt")
    [[ -n "$url" ]] || { echo "! $name absent de deps/themes.txt" >&2; return 1; }
    # Simulation : archive déjà vérifiée du cache lue telle quelle ; sinon téléchargement dans un dossier temporaire.
    local store="$cache"
    if [[ -n "$dry" ]] && ! echo "$sha  $cache/$name-${sha:0:12}.${url##*.}" | sha256sum -c --status 2>/dev/null; then
        echo "+ téléchargement de $name (${url##*/}), vérification et installation" >&2
        return 1
    fi
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
    sha="$(theme_sha "$3")"
    if [[ -f "$mark" && "$(cat "$mark")" == "$sha" ]]; then echo "= $2"; return; fi
    if [[ -e "$2" ]]; then
        # Ancienne copie d'install.sh (marquée) : remplacée ; dossier remplacé depuis par le tien : mis de côté, jamais supprimé.
        if recorded "$2" && [[ -f "$mark" ]]; then run rm -rf "$2"
        elif recorded "$2"; then run mv "$2" "$2.bak-$stamp"
        else backup_once link "$2" mv; fi
    else
        recorded "$2" || record link "$2" -
    fi
    run mkdir -p "$(dirname "$2")"
    run cp -r "$1" "$2"
    [[ -n "$dry" ]] || echo "$sha" > "$mark"
}

put_file() {    # source cible : fichier du thème, l'ancien sauvegardé
    if [[ -f "$2" ]] && cmp -s "$1" "$2"; then echo "= $2"; return; fi
    before_write "$2"
    run mkdir -p "$(dirname "$2")"
    run cp "$1" "$2"
    written "$2"
}

# Dossiers Catppuccin lavande (ton choix : comme sur le desktop de référence) sans toucher au thème du système : surcouche Papirus dans le compte (mêmes noms de dossiers, les autres icônes
# viennent toujours de /usr/share/icons/Papirus). Les noms génériques (folder.svg, user-home.svg…) pointent vers $folders.
papirus_overlay() {     # dossier src/ de catppuccin/papirus-folders
    local src="$1" top="$data/icons" sys=/usr/share/icons/Papirus folders=cat-mocha-lavender color size f t new
    [[ -d "$sys" ]] || { echo "- Papirus absent (papirus-icon-theme) : couleur des dossiers ignorée"; return; }
    color="$(readlink "$sys/48x48/places/folder.svg" || true)"; color="${color#folder-}"; color="${color%.svg}"
    [[ -n "$color" ]] || { echo "- Papirus sans couleur de dossier lisible (folder.svg n'est pas un lien) : couleur des dossiers ignorée"; return; }
    local tree; tree="$(mktemp -d)"
    for size in 22x22 24x24 32x32 48x48 64x64; do
        mkdir -p "$tree/Papirus/$size/places"
        cp "$src/$size/places/"*-"$folders"* "$tree/Papirus/$size/places/" 2>/dev/null || { echo "- papirus-folders : pas de $folders en $size"; continue; }
        for f in "$sys/$size/places/"*; do
            [[ -L "$f" ]] || continue
            t="$(readlink "$f")"
            [[ "$t" == *"-$color"* && "$t" != */* ]] || continue
            new="${t/-$color/-$folders}"
            if [[ -e "$tree/Papirus/$size/places/$new" ]]; then ln -sfn "$new" "$tree/Papirus/$size/places/$(basename "$f")"
            elif [[ -e "$sys/$size/places/$new" ]]; then ln -sfn "$sys/$size/places/$new" "$tree/Papirus/$size/places/$(basename "$f")"; fi
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

# Dossiers du thème déjà installés depuis cette archive (marque = son empreinte) : rien à télécharger ni à extraire.
theme_current() {   # nom-de-l'archive dossier…
    local sha d
    sha="$(theme_sha "$1")"; shift
    for d in "$@"; do [[ "$(cat "$d/.qs-desktop" 2>/dev/null)" == "$sha" ]] || return 1; done
    for d in "$@"; do echo "= $d"; done
}

step_theme() {
    section "3. Thème (Catppuccin Mocha, accent green)"
    local d v theme=catppuccin-mocha-green-standard+default cursor=catppuccin-mocha-green-cursors
    command -v curl >/dev/null && command -v unzip >/dev/null || { echo "! curl ou unzip absent : thème non installé"; return; }

    if theme_current gtk "$data/themes/$theme"; then :
    elif d="$(fetch gtk)"; then
        for v in "" -hdpi -xhdpi; do [[ -d "$d/$theme$v" ]] && put_dir "$d/$theme$v" "$data/themes/$theme$v" gtk; done
        rm -rf "$d"
    fi
    # GTK 4 / libadwaita n'a pas de thème : feuilles du thème liées dans ~/.config/gtk-4.0.
    if [[ -d "$data/themes/$theme/gtk-4.0" || -n "$dry" ]]; then
        for f in gtk.css gtk-dark.css assets; do link "$data/themes/$theme/gtk-4.0/$f" "$config/gtk-4.0/$f"; done
    fi

    if theme_current cursors "$data/icons/$cursor"; then :
    elif d="$(fetch cursors)"; then
        put_dir "$d/$cursor" "$data/icons/$cursor" cursors
        rm -rf "$d"
    fi

    if theme_current kvantum "$config/Kvantum/catppuccin-mocha-green"; then :
    elif d="$(fetch kvantum)"; then
        put_dir "$d"/kvantum-*/themes/catppuccin-mocha-green "$config/Kvantum/catppuccin-mocha-green" kvantum
        rm -rf "$d"
    fi

    if theme_current papirus-folders "$data/icons/Papirus" "$data/icons/Papirus-Dark"; then :
    elif d="$(fetch papirus-folders)"; then
        papirus_overlay "$(echo "$d"/papirus-folders-*/src)"
        rm -rf "$d"
    fi

    # Geany : un seul fichier ; marque = empreinte de l'archive dont il vient (dans l'état d'install.sh).
    local geany_cs="$config/geany/colorschemes/catppuccin-mocha.conf" geany_sha
    geany_sha="$(theme_sha geany)"
    if [[ -f "$geany_cs" && "$(cat "$state/theme-geany" 2>/dev/null)" == "$geany_sha $(sha256sum < "$geany_cs")" ]]; then
        echo "= $geany_cs"
    elif d="$(fetch geany)"; then
        put_file "$(echo "$d"/geany-*/src/catppuccin-mocha.conf)" "$geany_cs"
        rm -rf "$d"
        [[ -n "$dry" ]] || { mkdir -p "$state"; echo "$geany_sha $(sha256sum < "$geany_cs")" > "$state/theme-geany"; }
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
    python3 -I "$repo/scripts/dconf-keys.py" ${dry:+--dry-run} apply "$repo/$1" "$state/dconf-old.ini" "$HOME" \
        || echo "! dconf : $1 non appliqué (bus de session injoignable ?) ; relancer install.sh depuis la session"
}

step_settings() {
    section "4. Réglages des applications"
    if command -v dconf >/dev/null && python3 -c 'import gi' 2>/dev/null; then
        dconf_apply dotfiles/dconf/desktop.ini
        [[ -f "$repo/dotfiles/dconf/hosts/$host.ini" ]] && dconf_apply "dotfiles/dconf/hosts/$host.ini"
    else
        echo "- dconf ou python-gobject absent : réglages GSettings ignorés"
    fi

    # Applications par défaut.
    # Types encore à régler, en une lecture de ~/.config/mimeapps.list (au lieu d'un xdg-mime par type).
    local mimeapps="$config/mimeapps.list" app types
    while read -r app types; do
        if [[ ! -f "/usr/share/applications/$app" && ! -f "$data/applications/$app" ]]; then
            echo "- $app absent : ses types ne changent pas"; continue
        fi
        if [[ -z "$types" ]]; then echo "= $app par défaut"; continue; fi
        before_write "$mimeapps"
        # shellcheck disable=SC2086
        run xdg-mime default "$app" $types
        written "$mimeapps"
    done < <(python3 -I - "$repo/dotfiles/mime/defaults.list" "$mimeapps" <<'PY'
import configparser, sys
cur = configparser.RawConfigParser(strict=False, interpolation=None, delimiters=("=",))
cur.optionxform = str
try:
    cur.read(sys.argv[2], encoding="utf-8")
except (configparser.Error, UnicodeDecodeError):
    pass
have = dict(cur.items("Default Applications")) if cur.has_section("Default Applications") else {}
for line in open(sys.argv[1], encoding="utf-8"):
    if not line.strip() or line.startswith("#"):
        continue
    app, *types = line.split()
    print(app, *[t for t in types if have.get(t, "").split(";")[0] != app])
PY
)

    # Geany : son fichier de réglages est réécrit par l'application ; seules les clés du thème et des polices changent.
    if running_here '(^|/)geany( |$)'; then
        later "Geany est ouvert : le fermer puis relancer install.sh pour son thème et ses polices"
    else
        ini_set "$config/geany/geany.conf" geany color_scheme catppuccin-mocha.conf editor_font "Inter 16" tagbar_font "Symbols Nerd Font Mono 9"
    fi

    deluge_no_tray
    command -v chromium >/dev/null && chromium_profiles
    if command -v python3 >/dev/null; then step_webapps; else echo "- python3 absent (installé à l'étape 1) : web apps non générées"; fi
    if command -v chromium >/dev/null; then
        python3 "$repo/scripts/browser-links-setup.py" ${dry:+--dry-run} install \
            || later "liens Chromium (scripts/browser-links-setup.py) : non installés, voir le message ci-dessus"
    fi
}

# Deluge sans icône dans la barre (comme sur le desktop de référence). Son fichier : deux objets JSON à la suite (en-tête de
# format, puis réglages) ; Deluge complète les clés absentes par ses valeurs par défaut. Deluge ouvert réécrirait le fichier.
deluge_no_tray() {
    local file="$config/deluge/gtk3ui.conf" content
    command -v python3 >/dev/null || return 0
    content="$(python3 -I - "$file" <<'PY'
import json, sys
try:
    text = open(sys.argv[1], encoding="utf-8").read()
    dec = json.JSONDecoder()
    head, end = dec.raw_decode(text)
    conf, _ = dec.raw_decode(text[end:].lstrip())
except FileNotFoundError:
    head, conf = {"file": 1, "format": 1}, {}
if conf.get("enable_system_tray") is False:
    print("same", end="")
else:
    conf["enable_system_tray"] = False
    print(json.dumps(head, indent=4, sort_keys=True) + json.dumps(conf, indent=4, sort_keys=True), end="")
PY
)" || { echo "! $file illisible : icône de Deluge laissée telle quelle"; return 0; }
    if [[ "$content" == same ]]; then echo "= Deluge sans icône dans la barre"; return; fi
    if running_here '(^|/)deluge(-gtk)?( |$)'; then
        later "Deluge est ouvert : le fermer puis relancer install.sh pour retirer son icône de la barre"; return
    fi
    write_setting "$file" "$content" "enable_system_tray false"
}

# Profils isolés des web apps (--user-data-dir des modèles de lanceurs).
webapp_profiles() {
    grep -ho -- '--user-data-dir=@PROFILES@/[^ "]*' "$repo"/dotfiles/webapps/applications/*.desktop | sed 's|.*/||' | sort -u
}

# Réglages de chaque profil Chromium, le principal et celui de chaque web app, comme sur le desktop de référence :
# - « Thème : GTK » (extensions.theme.system_theme = 1) : le thème GTK du système, Catppuccin Mocha ;
# - « Utiliser la barre de titre et les bordures du système » (browser.custom_chrome_frame = false) : pas de boutons
#   réduire / agrandir / fermer dessinés par Chromium (Sway ne trace qu'une bordure, Hyprland rien) ;
# - web apps seulement : les extensions du navigateur (dotfiles/chromium/extensions.txt, déposées pour tous les profils par
#   l'étape système) refusées comme si elles avaient été désinstallées (extensions.external_uninstalls).
# Un fichier absent est créé avec ces seules clés ; Chromium complète le reste.
chromium_profiles() {
    local profile common='"extensions.theme.system_theme": 1, "browser.custom_chrome_frame": false' ids
    ids="$(grep -oE '^[a-p]{32}' "$repo/dotfiles/chromium/extensions.txt" | sed 's/.*/"&"/' | paste -sd,)"
    chromium_prefs "$config/chromium" Chromium "{$common}"
    for profile in $(webapp_profiles); do
        chromium_prefs "$data/ice/profiles/$profile" "web app ${profile%%[0-9]*}" "{$common, \"extensions.external_uninstalls\": [$ids]}"
    done
}

# Profil Chromium ouvert ? Tant qu'il tourne, Chromium garde dans son dossier de données le lien SingletonLock → « machine-pid » :
# seul ce profil compte (une web app ouverte n'empêche pas de régler le navigateur, et inversement).
chromium_open() {   # dossier de données (--user-data-dir)
    local lock
    [[ -n "${QS_INSTALL_ASSUME_CLOSED:-}" ]] && return 1
    lock="$(readlink "$1/SingletonLock" 2>/dev/null)" || return 1
    [[ "$(ps -o comm= -p "${lock##*-}" 2>/dev/null)" == chrom* ]]
}

chromium_prefs() {  # dossier de données d'un profil, nom affiché, clés voulues (JSON : « a.b.c »: valeur ; liste : ajoutée)
    local file="$1/Default/Preferences" content key old
    command -v python3 >/dev/null || return 0
    # Une lecture : une ligne « clé<TAB>ancienne valeur » par clé à changer (JSON ; « unset » : absente, « nofile » : fichier
    # absent), puis le contenu à écrire sur une seule ligne.
    content="$(python3 -I - "$file" "$3" <<'PY'
import json, sys
try:
    prefs, nofile = json.load(open(sys.argv[1], encoding="utf-8")), False
except FileNotFoundError:
    prefs, nofile = {}, True
changed = []
for key, value in json.loads(sys.argv[2]).items():
    *parents, leaf = key.split(".")
    node = prefs
    for p in parents:
        node = node.setdefault(p, {})
    cur = node.get(leaf)
    if isinstance(value, list) and isinstance(cur, list):
        value = cur + [v for v in value if v not in cur]
    if leaf in node and cur == value:
        continue
    changed.append(f"{key}\t{'nofile' if nofile else json.dumps(cur) if leaf in node else 'unset'}")
    node[leaf] = value
if not changed:
    print("same", end="")
else:
    print("\n".join(changed))
    print(json.dumps(prefs, separators=(",", ":")), end="")
PY
)" || { echo "! $file illisible : réglages de Chromium laissés tels quels"; return 0; }
    if [[ "$content" == same ]]; then echo "= $file : thème GTK, barre de titre du système"; return; fi
    if chromium_open "$1"; then
        later "$2 ouvert : le fermer puis relancer install.sh pour ses réglages (thème GTK, barre de titre)"; return
    fi
    # Tous les réglages du navigateur sont dans ce fichier : le registre ne garde que l'ancienne valeur de chaque clé changée,
    # --uninstall ne remet qu'elles. Ancien registre (« chromium-theme <fichier> ») : la clé du thème y est déjà notée.
    while IFS=$'\t' read -r key old; do
        recorded "$file#$key" || { [[ "$key" == extensions.theme.system_theme ]] && recorded "$file"; } \
            || record chromium-pref "$file#$key" "$old"
    done <<< "${content%$'\n'*}"
    write_setting "$file" "${content##*$'\n'}" "thème GTK, barre de titre du système$([[ "$3" == *external_uninstalls* ]] && echo ", sans les extensions du navigateur")" keep
}

# Application ouverte avec ce même dossier personnel ? Sans HOME dans son environnement (lancée par le compositeur) :
# même compte, considérée comme ouverte, pour ne jamais écrire un réglage qu'elle réécrirait en se fermant.
running_here() {    # motif pgrep -f ; QS_INSTALL_ASSUME_CLOSED : tests (applications de la machine de test ignorées)
    local pid home_of
    [[ -n "${QS_INSTALL_ASSUME_CLOSED:-}" ]] && return 1
    for pid in $(pgrep -u "$EUID" -f "$1"); do
        home_of="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep '^HOME=' || true)"
        [[ -z "$home_of" || "$home_of" == "HOME=$HOME" ]] && return 0
    done
    return 1
}

# Avant d'écrire un fichier de réglages : copie d'origine s'il existe, sinon noté comme créé (retiré par --uninstall).
before_write() {
    if [[ -e "$1" ]]; then backup_once edit "$1" cp
    elif ! recorded "$1"; then record seed "$1" -; fi
}

write_setting() {   # fichier contenu description [keep : déjà noté au registre par l'appelant]
    [[ "${4:-}" == keep ]] || before_write "$1"
    printf '+ %s : %s\n' "$1" "$3"
    [[ -n "$dry" ]] || { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
    written "$1"
}

# Modèle des web apps développé : @PROFILES@ et @WEBAPPS@ remplacés par les chemins tels quels (accents, &, | compris).
# desktop : argument entier entre guillemets dans Exec si un chemin a une espace ; json : chemin échappé pour JSON.
fill_template() {   # modèle desktop|json profils webapps
    python3 -I - "$@" <<'PY'
import json, re, sys
tpl, kind, profiles, webapps = sys.argv[1:]
text = open(tpl, encoding="utf-8").read()
if kind == "json":
    text = text.replace("@WEBAPPS@", json.dumps(webapps, ensure_ascii=False)[1:-1])
else:
    if " " in profiles + webapps:
        text = re.sub(r'(--(?:user-data-dir|load-extension)=@(?:PROFILES|WEBAPPS)@[^ ]*)', r'"\1"', text)
    text = text.replace("@PROFILES@", profiles).replace("@WEBAPPS@", webapps)
print(text, end="")
PY
}

# Web apps (deps/README.md, « Web apps ») : lanceurs et manifestes de l'hôte natif développés depuis dotfiles/webapps.
step_webapps() {
    local webapps="$repo/dotfiles/webapps" profiles="$data/ice/profiles" tpl name out content
    if [[ "$webapps$profiles" == *[\"\`\$\\%]* ]]; then
        echo "! chemin du dépôt ou des profils avec \" \` \$ \\ ou % : web apps non installées"; return
    fi
    for tpl in "$webapps"/applications/*.desktop; do
        name="$(basename "$tpl")"; out="$data/applications/$name"
        content="$(fill_template "$tpl" desktop "$profiles" "$webapps")"
        if [[ -f "$out" ]] && [[ "$(cat "$out")" == "$content" ]]; then echo "= $out"; continue; fi
        backup_once edit "$out" cp
        printf '+ %s (modèle %s)\n' "$out" "$name"
        [[ -n "$dry" ]] || { mkdir -p "$data/applications"; printf '%s\n' "$content" > "$out"; written "$out"; }
    done
    local profile manifest
    content="$(fill_template "$webapps/qs_desktop.open_link.json" json "$profiles" "$webapps")"
    for profile in $(webapp_profiles); do
        manifest="$profiles/$profile/NativeMessagingHosts/qs_desktop.open_link.json"
        if [[ -f "$manifest" ]] && [[ "$(cat "$manifest")" == "$content" ]]; then echo "= $manifest"; continue; fi
        backup_once edit "$manifest" cp
        printf '+ %s\n' "$manifest"
        [[ -n "$dry" ]] || { mkdir -p "$(dirname "$manifest")"; printf '%s\n' "$content" > "$manifest"; written "$manifest"; }
    done
    [[ -x "$webapps/open-link" ]] || run chmod +x "$webapps/open-link"
    if [[ -z "$dry" ]] && command -v update-desktop-database >/dev/null; then
        [[ -e "$data/applications/mimeinfo.cache" ]] || recorded "$data/applications/mimeinfo.cache" || record seed "$data/applications/mimeinfo.cache" -
        update-desktop-database "$data/applications" 2>/dev/null || true
        written "$data/applications/mimeinfo.cache"
    fi
}

# Fonds d'écran : dépôt privé à part (images hors du dépôt du bureau), cloné dans le dossier lu par services/Wallpapers.qml.
# QS_WALLPAPERS_REPO : autre dépôt (« compte/nom » GitHub, adresse git ou chemin), pour les tests.
# Même dossier que services/Wallpapers.qml : wallpapersDir de la config machine, sinon « Wallpapers » dans Images (dossier XDG
# s'il existe, sinon ~/Pictures, comme services/Places.qml).
wallpapers_dir() {
    local dir pictures dummy
    dir="$(host_setting wallpapersDir)"
    [[ -n "$dir" ]] && { echo "$dir"; return; }
    if [[ -n "$dry" && ! -f "$config/user-dirs.dirs" ]] && command -v xdg-user-dirs-update >/dev/null; then
        # Simulation sur un compte neuf : dossiers XDG que créerait xdg-user-dirs-update (sans rien créer).
        dummy="$(mktemp)"
        xdg-user-dirs-update --dummy-output "$dummy" 2>/dev/null || true
        pictures="$(sed -n 's/^XDG_PICTURES_DIR="\$HOME\(.*\)"$/\1/p' "$dummy")"
        rm -f "$dummy"
        echo "$HOME${pictures:-/Pictures}/Wallpapers"
        return
    fi
    pictures="$(xdg-user-dir PICTURES 2>/dev/null || true)"
    # Dossier désactivé (XDG_PICTURES_DIR="$HOME/") ou absent : xdg-user-dir renvoie le dossier personnel, que Places.qml écarte.
    pictures="${pictures%/}"
    [[ -n "$pictures" && "$pictures" != "$HOME" && -d "$pictures" ]] || pictures="$HOME/Pictures"
    echo "$pictures/Wallpapers"
}

step_wallpapers() {
    local src="${QS_WALLPAPERS_REPO:-Crystal4276/wallpapers}" dir
    # Machine neuve : les dossiers XDG (Images…) ne sont créés qu'à la première connexion ; xdg-user-dir renverrait alors $HOME.
    if command -v xdg-user-dirs-update >/dev/null && [[ ! -f "$config/user-dirs.dirs" ]]; then
        recorded "$config/user-dirs.dirs" || record seed "$config/user-dirs.dirs" -
        [[ -e "$config/user-dirs.locale" ]] || recorded "$config/user-dirs.locale" || record seed "$config/user-dirs.locale" -
        run xdg-user-dirs-update
        written "$config/user-dirs.dirs"; written "$config/user-dirs.locale"
    fi
    dir="$(wallpapers_dir)"
    if [[ -d "$dir/.git" ]]; then
        if [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]; then
            echo "= $dir (modifications locales : pas de mise à jour)"
        elif [[ -n "$dry" ]]; then
            echo "+ git -C $dir pull --ff-only"
        else
            GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes" git -C "$dir" pull -q --ff-only 2>/dev/null && echo "= $dir à jour" || echo "! $dir : mise à jour impossible (réseau ou accès GitHub), gardé tel quel"
        fi
        return
    fi
    if [[ -e "$dir" ]]; then echo "= $dir existe déjà (pas un clone : gardé tel quel)"; return; fi
    ask "Cloner tes fonds d'écran ($src, environ 300 Mo) dans $dir ?" oui || { echo "- fonds d'écran non clonés : aucun fond affiché"; return; }
    run mkdir -p "$(dirname "$dir")"
    [[ -n "$dry" ]] && { echo "+ clone de $src dans $dir"; return; }
    if [[ "$src" == */*/* || "$src" == /* || "$src" == *:* ]]; then
        git clone -q "$src" "$dir"
    elif command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
        gh repo clone "$src" "$dir" -- -q
    else
        # Dépôt public : HTTPS sans compte ; sinon clé SSH. Jamais de question de mot de passe (échec immédiat).
        GIT_TERMINAL_PROMPT=0 git clone -q "https://github.com/$src.git" "$dir" 2>/dev/null \
            || GIT_SSH_COMMAND="ssh -o BatchMode=yes" git clone -q "git@github.com:$src.git" "$dir"
    fi || echo "! clonage de $src impossible (réseau, ou dépôt privé : gh auth login / clé SSH GitHub) ; relancer install.sh ensuite"
}

# --- 5. Config machine -------------------------------------------------------------------------------------------------

step_host() {
    section "5. Config machine ($host)"
    # Les fichiers par machine suivent le nom d'hôte : un nom donné par le DHCP (aucun nom fixe) peut changer d'un réseau à l'autre.
    if command -v hostnamectl >/dev/null && [[ -z "$(hostnamectl --static 2>/dev/null)" ]]; then
        echo "! aucun nom de machine fixe (« $host » vient du réseau) : sudo hostnamectl set-hostname <nom>, puis relancer install.sh"
    fi
    local file="$repo/hosts/$host.json"
    if [[ -f "$file" ]]; then echo "= hosts/$host.json"; return; fi
    # Valeurs détectées seulement ; le reste vient de hosts/default.json (écran unique, laptop).
    local session=""
    (. "$repo/scripts/qs-env.sh" && qs_nvidia_only) && session='  "greeter": { "defaultSession": "wayland/sway-vulkan" }'
    # Fichier du dépôt, pas du compte : --uninstall le garde (il peut avoir été modifié ou committé).
    printf '+ hosts/%s.json créé (à committer)\n' "$host"
    [[ -n "$dry" ]] || printf '{\n%s\n}\n' "$session" > "$file"
}

# --- 6. Système (sudo) -------------------------------------------------------------------------------------------------

# Script système : en simulation sur une machine neuve, ses prérequis (paquets de l'étape 1) peuvent manquer.
sub() {
    "$@" && return 0
    if [[ -n "$dry" ]]; then echo "! ${1##*/} : simulation incomplète, prérequis installés à l'étape 1"
    else echo "! ${1##*/} ${*:2} : échec (message ci-dessus) ; la suite continue, relancer install.sh après correction"; fi
}

# Fond de l'écran de connexion avant la première session : le bureau exporte ensuite le sien, écran par écran, à chaque
# changement (services/Wallpapers.qml) ; d'ici là, le fond de la config machine (centre d'un triptyque) copié en
# default.<ext> dans le dossier du compte lu par le greeter (services/Greeter.qml). Dossier à soi : pas de sudo.
greeter_wallpaper() {
    local dest="/var/lib/qs-desktop/${USER:-$(id -un)}" path src ext
    path="$(host_setting wallpaper.path)"
    src="$(wallpapers_dir)/$path"
    [[ -n "$path" && -d "$src" ]] && src="$(find "$src" -maxdepth 1 -type f -iname '*center*' | sort | head -n 1)"
    ext="${src##*.}"; ext="${ext,,}"; [[ "$ext" == jpeg ]] && ext=jpg
    if [[ -z "$path" || ! -f "$src" || ( "$ext" != jpg && "$ext" != png ) ]]; then
        echo "- fond de l'écran de connexion : celui du bureau, après la première session"; return
    fi
    if cmp -s "$src" "$dest/default.$ext"; then echo "= $dest/default.$ext"; return; fi
    if [[ -z "$dry" && ! -w "$dest" ]]; then echo "- $dest absent : fond de l'écran de connexion après la première session"; return; fi
    run rm -f "$dest/default.jpg" "$dest/default.png"
    run cp "$src" "$dest/default.$ext"
}

step_system() {
    section "6. Système (sudo, avec confirmation)"
    if ask "Écran de connexion greetd + greeter Quickshell (remplace le gestionnaire actuel) ?" oui; then
        sub "$repo/scripts/greeter-setup.sh" ${dry:+--dry-run} install
        sub "$repo/scripts/system-setup.sh" ${dry:+--dry-run} cursor
        if [[ -n "$dry" && ! -d /usr/local/share/qs-desktop ]]; then
            echo "+ scripts/greeter-setup.sh enable (après l'installation ci-dessus)"
        else
            sub "$repo/scripts/greeter-setup.sh" ${dry:+--dry-run} enable
        fi
        greeter_wallpaper
    fi
    if ask "Samba, services (réseau, Bluetooth, énergie, VM), groupes et thème Qt du système ?" oui; then
        sub "$repo/scripts/system-setup.sh" ${dry:+--dry-run} install
    fi
    if command -v chromium >/dev/null && ask "Extensions de Chromium (dotfiles/chromium/extensions.txt : Dark Reader, Stylus, nightTab…) ?" oui; then
        sub "$repo/scripts/system-setup.sh" ${dry:+--dry-run} chromium-extensions
    fi
    if ask "Sonde de connectivité NetworkManager (portails captifs Wi-Fi) ?" oui; then
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

# Avant de retirer ou remettre un fichier de réglages : s'il a changé depuis la dernière écriture d'install.sh (une application
# y a enregistré tes réglages), sa version actuelle est gardée à côté (<fichier>.uninstall-<date>).
keep_current() {    # cible sauvegarde|-
    [[ -f "$1" && -s "$1" ]] || return 0   # lien (stow) compris : c'est son contenu qui est comparé et gardé
    [[ "$2" != - && -f "$2" ]] && cmp -s "$1" "$2" && return 0
    [[ "$(cat "$(written_mark "$1")" 2>/dev/null)" == "$(sha256sum < "$1")" ]] && return 0
    run cp -p "$1" "$1.uninstall-$stamp"
}

do_uninstall() {
    section "Retrait des configs du compte"
    if [[ -f "$registry" ]]; then
        local kind target backup
        while IFS=$'\t' read -r kind target backup <&3; do
            case "$kind" in
                edit)
                    keep_current "$target" "$backup"
                    if [[ "$backup" == - ]]; then run rm -f "$target"
                    elif [[ -e "$backup" ]]; then run cp "$backup" "$target"; run rm -f "$backup"
                    else echo "! sauvegarde $backup introuvable : $target laissé tel quel"; fi ;;
                chromium-pref|chromium-theme)
                    # « chromium-theme <fichier> » : ancien registre, clé du thème seule.
                    local key=extensions.theme.system_theme
                    [[ "$kind" == chromium-pref ]] && { key="${target##*#}"; target="${target%#*}"; }
                    # Profil ouvert : Chromium réécrirait le fichier en se fermant (clé remise quand même, signalé).
                    chromium_open "${target%/Default/Preferences}" && echo "! Chromium ouvert ($target) : le fermer, sinon ses réglages restent"
                    printf '+ %s : %s remis (%s)\n' "$target" "$key" "$backup"
                    [[ -n "$dry" || ! -f "$target" ]] || python3 -I - "$target" "$key" "$backup" <<'EOF' || echo "! $target illisible : $key laissé tel quel"
import json, os, sys
path, key, old = sys.argv[1:]
prefs = json.load(open(path, encoding="utf-8"))
*parents, leaf = key.split(".")
nodes = [prefs]
for p in parents:
    nodes.append(nodes[-1].setdefault(p, {}))
if old in ("unset", "nofile"):
    nodes[-1].pop(leaf, None)
    # Dossiers de clés laissés vides retirés (le fichier créé par install.sh redevient vide).
    for parent, p in zip(reversed(nodes[:-1]), reversed(parents)):
        if parent[p] == {}:
            del parent[p]
else:
    nodes[-1][leaf] = json.loads(old)
if old == "nofile" and prefs == {}:
    os.remove(path)
else:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(prefs, f, separators=(",", ":"))
EOF
                    ;;
                link|seed)
                    # Lien remplacé depuis par un vrai fichier ou dossier (sauf dossiers du thème, marqués) : gardé, jamais supprimé.
                    if [[ "$kind" == link && -e "$target" && ! -L "$target" && ! -f "$target/.qs-desktop" ]]; then
                        echo "! $target n'est plus le lien installé : gardé tel quel"; continue
                    fi
                    [[ "$kind" == seed ]] && keep_current "$target" "$backup"
                    # Réglage écrit à travers un lien de l'utilisateur (stow) qui ne menait à rien : fichier créé retiré, lien gardé.
                    if [[ "$kind" == seed && "$backup" == - && -L "$target" ]]; then run rm -f "$(readlink -f "$target")"
                    elif [[ "$backup" == - ]]; then run rm -rf "$target"
                    elif [[ -e "$backup" || -L "$backup" ]]; then run rm -rf "$target"; run mv "$backup" "$target"
                    else echo "! sauvegarde $backup introuvable : $target laissé tel quel"; fi ;;
                block)
                    printf '+ retrait du bloc de %s\n' "$target"
                    [[ -n "$dry" || ! -f "$target" ]] || python3 -I - "$target" "$backup" <<'EOF' || echo "! $target : bloc non retiré"
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
                unit-mask) run systemctl --user unmask "$target" || echo "! $target non démasqué (pas de session utilisateur) : systemctl --user unmask $target" ;;
            esac
        done 3< <(tac "$registry")
        if [[ -f "$state/dconf-old.ini" ]] && ! python3 -I "$repo/scripts/dconf-keys.py" ${dry:+--dry-run} restore "$state/dconf-old.ini"; then
            run cp "$state/dconf-old.ini" "$HOME/qs-desktop-dconf-old.ini-$stamp"
            echo "! dconf : anciennes valeurs non remises (bus de session injoignable ?), gardées dans ~/qs-desktop-dconf-old.ini-$stamp"
        fi
        run rm -rf "$registry" "$state/dconf-old.ini" "$state/dconf-old.ini.written" "$state/written" "$state/theme-geany"
        [[ -L "$repo/dotfiles/mpv/host.conf" ]] && run rm -f "$repo/dotfiles/mpv/host.conf"
    else
        echo "= rien à retirer ($registry absent)"
    fi
    if command -v chromium >/dev/null; then
        python3 "$repo/scripts/browser-links-setup.py" ${dry:+--dry-run} uninstall 2>/dev/null || echo "= liens Chromium : rien à retirer"
    fi
    if [[ -n "$system" ]] && ask "Défaire aussi les étapes système (greeter → ancien gestionnaire, sonde réseau, Samba, services, groupes, extensions Chromium) ?"; then
        sub "$repo/scripts/system-setup.sh" ${dry:+--dry-run} uninstall
        sub "$repo/scripts/network-setup.sh" ${dry:+--dry-run} uninstall
        sub "$repo/scripts/greeter-setup.sh" ${dry:+--dry-run} uninstall
        local own="/var/lib/qs-desktop/${USER:-$(id -un)}"
        [[ -e "$own/default.png" || -e "$own/default.jpg" ]] && run rm -f "$own/default.png" "$own/default.jpg"
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
    if [[ ${#pending[@]} -gt 0 ]]; then
        echo "Pas encore fait :"
        printf '  - %s\n' "${pending[@]}"
    fi
    echo "Terminé. À faire soi-même (README.md) : mot de passe Samba (sudo smbpasswd -a ${USER:-$(id -un)}), première connexion des web apps,"
    echo "thème Catppuccin dans Obsidian / Thunderbird, logiciels hors dépôts (Claude Code, NordVPN, Plex, RustDesk),"
    echo "réglages de nightTab (nouvel onglet de Chromium > roue dentée > Data > Import from file : $repo/dotfiles/chromium/nighttab.json)."
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
section "Fonds d'écran"
step_wallpapers
step_host
[[ -n "$system" ]] && is_arch && step_system
step_check
