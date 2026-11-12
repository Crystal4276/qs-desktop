#!/usr/bin/env bash
# Installation du bureau sur une machine (README.md). Idempotent : relancé, il ne refait que ce qui manque ou a changé.
#
# Usage : ./install.sh [options]
#   --dry-run          affiche tout ce qui serait fait, sans rien modifier (ni paquet, ni fichier, ni sudo)
#   --profil P         profil de la machine, sans le demander : jeux (Steam, Lutris, Deluge : deps/games.txt) ou travail
#                      (DigitalMicrograph : deps/work.txt) ; écrit dans hosts/<machine>.json (clé « profile »)
#   --no-packages      ne touche pas aux paquets (ni multilib, ni paru)
#   --no-system        aucune étape système (sudo) : sudo pacman, Reflector, greeter, sonde réseau, Samba, services…
#   --yes              ne pose aucune question : étapes système faites, profil de hosts/<machine>.json, sinon travail
#   --uninstall        retire les liens et copies, remet les sauvegardes et les réglages d'origine, étapes système comprises ;
#                      les paquets installés restent
#
# Profil et étapes système ; destination SSH facultative demandée si terrier-zt est absent.
# Étapes : miroirs Reflector · 1 paquets (dépôts officiels, multilib, paru-bin, Claude Code) · 2 configs du compte (liens, sauvegardes
# `<x>.bak-<date>`, identité Git) · 3 thème · 4 réglages (dconf, applications par défaut, barres d'état de Claude Code et Codex, web apps,
# liens Chromium) · 5 config machine · 6 système (sudo) · SSH vers le desktop (compte).
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
[[ $EUID -ne 0 ]] || { echo "À lancer en utilisateur, sans sudo (sudo est demandé pour chaque étape système)." >&2; exit 1; }

dry=""
profile=""      # jeux | travail (choose_profile)
packages=1
system=1
yes=""
uninstall=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) dry=1 ;;
        --profil) [[ "${2:-}" == jeux || "${2:-}" == travail ]] || { echo "Profil inconnu : ${2:-} (jeux ou travail)" >&2; exit 2; }
            profile="$2"; shift ;;
        --no-packages) packages="" ;;
        --no-system) system="" ;;
        --yes) yes=1 ;;
        --uninstall) uninstall=1 ;;
        -h|--help) sed -n '4,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

# --- Questions ---------------------------------------------------------------------------------------------------------

# Profil écrit dans hosts/<machine>.json seulement (pas celui de hosts/default.json) : vide s'il n'y en a pas.
# Sans python3 (Arch minimal : python arrive à l'étape 1), lecture simple de la clé ; sous set -e, un python3 absent
# dans « $(…) » arrêtait tout sans message.
host_profile() {
    if ! command -v python3 >/dev/null; then
        sed -n 's/.*"profile"[[:space:]]*:[[:space:]]*"\(jeux\|travail\)".*/\1/p' "$repo/hosts/$host.json" 2>/dev/null | head -n 1
        return 0
    fi
    python3 -I - "$repo/hosts/$host.json" 2>/dev/null <<'EOF'
import json, sys
try:
    print(json.load(open(sys.argv[1])).get("profile", ""))
except (OSError, ValueError, AttributeError):
    print("")
EOF
}

# Question 1 : profil de la machine (--profil, sinon hosts/<machine>.json, sinon demandé) ; écrit par step_host.
choose_profile() {
    local current
    current="$(host_profile)"
    if [[ -n "$profile" ]]; then
        echo "Profil : $profile (--profil)"
    elif [[ "$current" == jeux || "$current" == travail ]]; then
        profile="$current"
        echo "Profil : $profile (hosts/$host.json)"
    elif [[ -n "$yes" ]]; then
        profile=travail
        echo "Profil : travail (--yes ; --profil jeux pour l'autre)"
    elif [[ -n "$dry" ]]; then
        profile=travail
        echo "? Profil de cette machine (simulation : travail ; --profil jeux pour voir l'autre)"
    elif ask "Profil de cette machine : jeux (Steam, Lutris, Deluge) ? Sinon : travail (DigitalMicrograph)"; then
        profile=jeux
    else
        profile=travail
    fi
}

# Question 2 : étapes système (sudo), toutes ou aucune ; « non » vaut --no-system.
ask_system() {
    [[ -n "$system" ]] || return 0
    is_arch || { system=""; return 0; }
    echo "Étapes système (sudo) : pacman et paru sans mot de passe (wheel), miroirs Reflector,"
    [[ "$profile" == jeux ]] && echo "  dépôt multilib (Steam, jeux 32 bits),"
    echo "  écran de connexion greetd + greeter Quickshell, Samba, services (réseau, Bluetooth, énergie, VM), groupes, thème Qt,"
    echo "  ZeroTier (jonction automatique au réseau configuré dans hosts/zerotier-network),"
    echo "  extensions de Chromium, thème de Thunderbird, sonde de connectivité NetworkManager, mesures GPU Intel (s'il y en a un)."
    [[ "$profile" == travail ]] && echo "  menu GRUB Horizon (UKI, délai 2 s) ; écran de démarrage Plymouth Core Lab (initramfs, ligne de commande du noyau, image de secours : docs/PLYMOUTH.md)."
    ask "Faire ces étapes système ?" oui || { system=""; echo "- étapes système non faites (relancer install.sh pour les faire)"; }
}

# --- 1. Paquets --------------------------------------------------------------------------------------------------------

is_arch() { [[ -f /etc/arch-release ]] || grep -qsE '^ID(_LIKE)?=.*\barch\b' /etc/os-release; }

step_pacman_sudo() {
    is_arch || return 0
    section "Pacman et paru sans mot de passe (wheel)"
    if ! "$repo/scripts/system-setup.sh" ${dry:+--dry-run} pacman-sudo; then
        later "Accès pacman sans mot de passe non configuré : relancer install.sh après correction."
    fi
}

# Reflector utilise les dépôts Arch : ne jamais remplacer les miroirs d'une distribution dérivée.
step_reflector() {
    grep -qxE 'ID="?arch"?' /etc/os-release || return 0
    section "Miroirs Arch (Reflector), maintenant et chaque semaine"
    if ! command -v reflector >/dev/null; then
        if [[ -z "$packages" ]]; then
            later "Reflector absent : installer le paquet reflector puis relancer sans --no-packages."
            return
        fi
        printf '+ sudo pacman -S --needed %sreflector\n' "${yes:+--noconfirm }"
        if [[ -z "$dry" ]] && ! sudo pacman -S --needed ${yes:+--noconfirm} reflector; then
            later "Reflector non installé : miroirs existants gardés ; relancer install.sh après l'installation des paquets."
            return
        fi
    fi
    if ! "$repo/scripts/system-setup.sh" ${dry:+--dry-run} reflector; then
        later "Reflector : configuration incomplète, miroirs existants gardés ; relancer install.sh."
    fi
}

step_packages() {
    section "1. Paquets"
    if ! is_arch; then
        echo "Distribution autre qu'Arch : paquets à installer soi-même (listes Arch de deps/, pas encore de correspondances"
        echo "pour les autres distributions). Suite de l'installation : configs du compte seulement."
        return
    fi
    # Profil jeux : Steam et les paquets lib32 viennent de [multilib], activé avec les étapes système.
    if [[ "$profile" == jeux && -n "$system" ]] && ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        "$repo/scripts/system-setup.sh" ${dry:+--dry-run} multilib || echo "! multilib non activé : Steam et les paquets lib32 resteront indisponibles"
    fi
    local want=() vendors v games=""
    mapfile -t want < <(pkg_list arch-pacman.txt apps.txt)
    if [[ "$profile" == jeux ]]; then
        games=yes
        # Sans [multilib], paquets du profil jeux retirés (pacman échouerait et arrêterait tout).
        if ! grep -q '^\[multilib\]' /etc/pacman.conf && [[ -z "$dry" ]]; then
            later "[multilib] inactif : paquets du profil jeux non installés (relancer install.sh en acceptant les étapes système)"; games=""
        fi
        [[ -n "$games" ]] && mapfile -t -O "${#want[@]}" want < <(pkg_list games.txt)
    else
        mapfile -t -O "${#want[@]}" want < <(pkg_list work.txt)
    fi
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
    step_claude
}

# Claude Code : absent des dépôts officiels ; script officiel d'Anthropic (binaire dans ~/.local/bin, ajouté au PATH par
# dotfiles/bash/qs-desktop.bash ; mises à jour faites par Claude Code lui-même). Déjà là (paquet AUR compris) : rien.
claude_bin() {
    command -v claude || { [[ -x "$HOME/.local/bin/claude" ]] && echo "$HOME/.local/bin/claude"; }
}

step_claude() {
    local bin script
    if bin="$(claude_bin)"; then echo "= $bin"; return; fi
    [[ -n "$dry" ]] && { echo "+ curl -fsSL https://claude.ai/install.sh | bash"; return; }
    # Script entier téléchargé avant de le lancer : une coupure réseau n'en exécute jamais un morceau.
    script="$(mktemp)"
    { curl -fsSL --connect-timeout 15 --max-time 120 --retry 3 --retry-delay 5 -o "$script" https://claude.ai/install.sh \
        && bash "$script" </dev/null; } \
        || later "Claude Code non installé (réseau ? message ci-dessus) : relancer install.sh"
    rm -f "$script"
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

# Entrée native commune au menu et au lanceur ; aucune interrogation libvirt à l'installation.
step_windows11() {
    local uri domain out="$data/applications/qs-windows11.desktop" content
    uri="$(host_setting windows11.uri)"
    domain="$(host_setting windows11.domain)"
    [[ -n "$uri" && -n "$domain" ]] || return 0
    content="$(python3 -I - "$repo" "$uri" "$domain" <<'EOF'
import sys
repo, uri, domain = sys.argv[1:]
# Exec est une liste d'arguments desktop, sans interpréteur shell.
def value(s):
    return s.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r')
def arg(s):
    s = s.replace('%', '%%')
    for char in ('\\', '"', '`', '$'):
        s = s.replace(char, '\\' + char)
    return value('"' + s + '"')
print('[Desktop Entry]\nType=Application\nName=Windows 11\nComment=Ouvrir la machine virtuelle Windows 11\nCategories=System;\nTerminal=false\nStartupNotify=false')
print('Icon=' + value(repo + '/assets/windows11.svg'))
print('Exec=' + ' '.join(arg(s) for s in (repo + '/scripts/windows11-launch.sh', uri, domain)))
EOF
)" || return 1
    if [[ -f "$out" && "$(cat "$out")" == "$content" ]]; then echo "= $out"; return; fi
    backup_once edit "$out" cp
    printf '+ %s (Windows 11)\n' "$out"
    [[ -n "$dry" ]] || { mkdir -p "$(dirname "$out")"; printf '%s\n' "$content" > "$out"; written "$out"; }
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
    step_windows11
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
    git_identity
    # Dunst (ancien démon de notifications) masqué : Quickshell fait les notifications.
    if [[ -f /usr/lib/systemd/user/dunst.service ]] && systemctl --user show-environment >/dev/null 2>&1 \
        && [[ "$(systemctl --user is-enabled dunst.service 2>/dev/null)" != masked ]]; then
        run systemctl --user mask dunst.service
        record unit-mask dunst.service -
    fi
}

# Identité Git (sans elle, chaque commit échoue), sans question : compte GitHub connecté à gh. Nom : identifiant GitHub ;
# adresse : celle du profil si elle est publique, sinon celle des commits de ce compte dans ce dépôt, sinon l'adresse
# « noreply » de GitHub (commits rattachés au compte). Déjà réglée : rien ; --uninstall remet ~/.gitconfig d'origine.
git_identity() {
    local file="$HOME/.gitconfig" name email user login id public
    name="$(git config --global user.name || true)"
    email="$(git config --global user.email || true)"
    if [[ -n "$name" && -n "$email" ]]; then echo "= identité Git : $name <$email>"; return; fi
    if ! user="$(gh api user --jq '[.login, .id, .email // ""] | @tsv' 2>/dev/null)" || [[ -z "$user" ]]; then
        later "identité Git absente : gh auth login, puis relancer install.sh (ou git config --global user.name / user.email)"
        return
    fi
    IFS=$'\t' read -r login id public <<< "$user"
    [[ -n "$email" ]] || email="${public:-$(git -C "$repo" log -1 --format=%ae --author="^$login <" 2>/dev/null || true)}"
    backup_once edit "$file" cp
    run git config --file "$file" user.name "${name:-$login}"
    run git config --file "$file" user.email "${email:-$id+$login@users.noreply.github.com}"
    written "$file"
}

touch_bashrc() {
    block "$HOME/.bashrc" "# qs-desktop (install.sh) : starship, EDITOR, BROWSER" \
        "[ -f \"\${XDG_CONFIG_HOME:-\$HOME/.config}/quickshell/desktop/dotfiles/bash/qs-desktop.bash\" ] && . \"\${XDG_CONFIG_HOME:-\$HOME/.config}/quickshell/desktop/dotfiles/bash/qs-desktop.bash\""
}

# --- 3. Thème ----------------------------------------------------------------------------------------------------------

# Marque des dossiers installés depuis une archive de deps/themes.txt : son empreinte, suivie de la révision de la mise en place
# quand install.sh la construit lui-même (à incrémenter quand celle-ci change : refaite sur les machines déjà installées).
declare -A layout=([papirus-folders]=2)
theme_sha() { echo "$(awk -v n="$1" '$1 == n { print $2 }' "$repo/deps/themes.txt")${layout[$1]:+-r${layout[$1]}}"; }

# Fichier de deps/themes.txt : téléchargé une fois dans le cache et vérifié.
download() {    # nom → affiche le fichier du cache
    local name="$1" sha url file
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
    echo "$file"
}

# Archive de deps/themes.txt : téléchargée et vérifiée (download), extraite dans un dossier temporaire.
fetch() {       # nom → affiche le dossier extrait
    local file dir
    file="$(download "$1")" || return 1
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
# viennent toujours de /usr/share/icons/Papirus). Chaque lien de Papirus qui mène, directement ou par une chaîne de liens
# (folder-videos.svg → folder-video.svg → folder-blue-video.svg), à un dossier de sa couleur pointe vers $folders. GTK cherche
# chaque nom d'abord dans le compte : un nom absent de la surcouche reprend l'icône bleue du système. Les tailles que Papirus
# sert par des liens (96x96/places → 48x48, 128x128 → 64x64, @2x, Papirus-Dark) sont reprises à l'identique dans la surcouche.
papirus_overlay() {     # dossier src/ de catppuccin/papirus-folders
    local src="$1" top="$data/icons" sys="${QS_PAPIRUS_DIR:-/usr/share/icons/Papirus}" folders=cat-mocha-lavender color size f t n new e
    [[ -d "$sys" ]] || { echo "- Papirus absent (papirus-icon-theme) : couleur des dossiers ignorée"; return; }
    color="$(readlink "$sys/48x48/places/folder.svg" || true)"; color="${color#folder-}"; color="${color%.svg}"
    [[ -n "$color" ]] || { echo "- Papirus sans couleur de dossier lisible (folder.svg n'est pas un lien) : couleur des dossiers ignorée"; return; }
    local tree sizes=(); tree="$(mktemp -d)"
    for size in "$src"/*/; do
        size="$(basename "$size")"
        [[ -d "$sys/$size/places" && ! -L "$sys/$size" && ! -L "$sys/$size/places" ]] || continue
        mkdir -p "$tree/Papirus/$size/places"
        cp "$src/$size/places/"*-"$folders"* "$tree/Papirus/$size/places/" 2>/dev/null || { echo "- papirus-folders : pas de $folders en $size"; continue; }
        sizes+=("$size")
        for f in "$sys/$size/places/"*; do
            [[ -L "$f" && "$(basename "$f")" != *"-$color"* ]] || continue   # folder-blue-videos.svg : bleu demandé, gardé
            t="$(readlink "$f")"; n=0
            while [[ "$t" != */* && -L "$sys/$size/places/$t" && $n -lt 8 ]]; do t="$(readlink "$sys/$size/places/$t")"; n=$((n + 1)); done
            [[ "$t" == *"-$color"* && "$t" != */* ]] || continue
            new="${t/-$color/-$folders}"
            if [[ -e "$tree/Papirus/$size/places/$new" ]]; then ln -sfn "$new" "$tree/Papirus/$size/places/$(basename "$f")"
            elif [[ -e "$sys/$size/places/$new" ]]; then ln -sfn "$sys/$size/places/$new" "$tree/Papirus/$size/places/$(basename "$f")"; fi
        done
    done
    [[ ${#sizes[@]} -gt 0 ]] || { rm -rf "$tree"; return; }
    # Liens de Papirus vers les tailles couvertes : dossier entier (48x48@2x → 48x48) ou seulement places (96x96/places → ../48x48/places).
    for e in "$sys"/*/; do
        e="$(basename "$e")"
        if [[ -L "$sys/$e" ]]; then
            t="$(readlink "$sys/$e")"
            if [[ " ${sizes[*]} " == *" $t "* ]]; then ln -sfn "$t" "$tree/Papirus/$e"; fi
        elif [[ -L "$sys/$e/places" ]]; then
            t="$(readlink "$sys/$e/places")"; n="${t#../}"; n="${n%/places}"
            [[ "$t" == "../$n/places" && " ${sizes[*]} " == *" $n "* ]] || continue
            mkdir -p "$tree/Papirus/$e"; ln -sfn "$t" "$tree/Papirus/$e/places"
        fi
    done
    # Papirus-Dark : chaque taille de la surcouche, comme Papirus-Dark/<taille> → ../Papirus/<taille> (ses places sont celles de Papirus).
    mkdir -p "$tree/Papirus-Dark"
    for e in "$tree/Papirus"/*; do
        e="$(basename "$e")"
        if [[ -L "$tree/Papirus/$e" ]]; then ln -sfn "$(readlink "$tree/Papirus/$e")" "$tree/Papirus-Dark/$e"
        else ln -sfn "../Papirus/$e" "$tree/Papirus-Dark/$e"; fi
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

    [[ "$profile" == jeux ]] && deluge_no_tray
    if command -v python3 >/dev/null; then ai_statuslines; else echo "- python3 absent (installé à l'étape 1) : barres d'état de Claude Code et Codex non réglées"; fi
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

# Clés d'un fichier JSON de réglages qu'une application réécrit elle-même (Chromium, Claude Code). Une lecture : une ligne
# « clé<TAB>ancienne valeur » par clé à changer (JSON ; « unset » : absente, « nofile » : fichier absent), une ligne vide, puis
# le contenu à écrire ; « same » si rien ne change. Mise en forme du fichier gardée (compacte ou indentée, saut de ligne final ;
# fichier absent : indentée avec « pretty »). Sortie suivie d'un point (gardé par $(…) avec le saut de ligne final), à retirer.
json_merge() {      # fichier clés-voulues (JSON : « a.b.c »: valeur ; liste : ajoutée) [pretty]
    python3 -I - "$@" <<'PY' || return 1
import json, sys
path, want, style = sys.argv[1], sys.argv[2], (sys.argv[3:] or [""])[0]
try:
    text, nofile = open(path, encoding="utf-8").read(), False
    prefs = json.loads(text)
except FileNotFoundError:
    text, prefs, nofile = "", {}, True
changed = []
for key, value in json.loads(want).items():
    *parents, leaf = key.split(".")
    node = prefs
    for p in parents:
        node = node.setdefault(p, {})
    cur = node.get(leaf)
    if isinstance(value, list) and isinstance(cur, list):
        value = cur + [v for v in value if v not in cur]
    if leaf in node and cur == value:
        continue
    changed.append(f"{key}\t{'nofile' if nofile else json.dumps(cur, ensure_ascii=False) if leaf in node else 'unset'}")
    node[leaf] = value
if not changed:
    print("same", end="")
else:
    pretty = "\n" in text.strip() or (nofile and style == "pretty")
    end = "\n" if text.endswith("\n") or (nofile and style == "pretty") else ""
    print("\n".join(changed) + "\n")
    print(json.dumps(prefs, ensure_ascii=False, **({"indent": 2} if pretty else {"separators": (",", ":")})), end=end)
PY
    echo .
}

# Résultat de json_merge noté (ancienne valeur de chaque clé changée : --uninstall ne remet qu'elles) puis écrit.
json_write() {      # fichier résultat genre-au-registre description
    local key old
    while IFS=$'\t' read -r key old; do
        recorded "$1#$key" || { [[ "$key" == extensions.theme.system_theme ]] && recorded "$1"; } \
            || record "$3" "$1#$key" "$old"
    done <<< "${2%%$'\n\n'*}"
    write_setting "$1" "${2#*$'\n\n'}" "$4" keep
}

chromium_prefs() {  # dossier de données d'un profil, nom affiché, clés voulues (json_merge)
    local file="$1/Default/Preferences" content
    command -v python3 >/dev/null || return 0
    content="$(json_merge "$file" "$3")" || { echo "! $file illisible : réglages de Chromium laissés tels quels"; return 0; }
    content="${content%.}"
    if [[ "$content" == same ]]; then echo "= $file : thème GTK, barre de titre du système"; return; fi
    if chromium_open "$1"; then
        later "$2 ouvert : le fermer puis relancer install.sh pour ses réglages (thème GTK, barre de titre)"; return
    fi
    # Tous les réglages du navigateur sont dans ce fichier : seules les clés changées sont notées et remises au retrait.
    # Ancien registre (« chromium-theme <fichier> ») : la clé du thème y est déjà notée.
    json_write "$file" "$content" chromium-pref \
        "thème GTK, barre de titre du système$([[ "$3" == *external_uninstalls* ]] && echo ", sans les extensions du navigateur")"
}

# Barres d'état de Claude Code et de Codex comme sur le desktop de référence : modèle, contexte utilisé, limites de
# l'abonnement (5 h, semaine). Claude Code : script du dépôt (dotfiles/claude, lit le JSON de Claude Code avec jq) lié dans
# son dossier, déclaré dans settings.json ; Codex : éléments natifs de sa barre ([tui] status_line). Seules ces clés
# changent ; les deux fichiers sont réécrits par leur application (le reste y est gardé).
ai_statuslines() {
    local dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" content cmd
    if claude_bin >/dev/null; then
        link dotfiles/claude/statusline-command.sh "$dir/statusline-command.sh"
        cmd="bash $(printf '%q' "$dir/statusline-command.sh")"
        content="$(json_merge "$dir/settings.json" "{\"statusLine\": {\"type\": \"command\", \"command\": $(printf '%s' "$cmd" | python3 -I -c 'import json, sys; print(json.dumps(sys.stdin.read()))')}}" pretty)" \
            || { echo "! $dir/settings.json illisible : barre d'état de Claude Code non réglée"; content=""; }
        content="${content%.}"
        if [[ "$content" == same ]]; then echo "= $dir/settings.json : barre d'état"
        elif [[ -n "$content" ]]; then json_write "$dir/settings.json" "$content" json-pref "barre d'état (statusLine)"; fi
    else
        echo "- Claude Code absent : barre d'état non réglée"
    fi
    if command -v codex >/dev/null; then
        ini_set "${CODEX_HOME:-$HOME/.codex}/config.toml" tui status_line \
            '["model-with-reasoning", "current-dir", "context-used", "five-hour-limit", "weekly-limit", "context-window-size", "used-tokens"]'
    else
        echo "- Codex absent : barre d'état non réglée"
    fi
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
    local webapps="$repo/dotfiles/webapps" profiles="$data/ice/profiles" tpl name out content dbfile
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
        # intent.cache : écrit aussi par desktop-file-utils ≥ 0.29.
        for dbfile in mimeinfo.cache intent.cache; do
            [[ -e "$data/applications/$dbfile" ]] || recorded "$data/applications/$dbfile" || record seed "$data/applications/$dbfile" -
        done
        update-desktop-database "$data/applications" 2>/dev/null || true
        for dbfile in mimeinfo.cache intent.cache; do written "$data/applications/$dbfile"; done
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

# Dossiers du compte (ton choix) : Applications, Desktop, Documents, Downloads, Music, Pictures, Videos, rien d'autre.
# Modèles, Public et Projets désactivés dans user-dirs.dirs (« $HOME/ » : xdg-user-dirs-update ne les recrée plus à la connexion)
# et retirés s'ils sont vides ; non vides, gardés. Machine neuve : les autres dossiers XDG créés tout de suite (Images pour les fonds).
step_home_dirs() {
    local f="$config/user-dirs.dirs" key dir fresh="" off=()
    if command -v xdg-user-dirs-update >/dev/null; then
        [[ -f "$f" ]] || fresh=1
        for key in TEMPLATES PUBLICSHARE PROJECTS; do
            grep -qx "XDG_${key}_DIR=\"\\\$HOME/\"" "$f" 2>/dev/null || off+=("$key")
        done
        if [[ ${#off[@]} -gt 0 ]]; then
            before_write "$f"
            [[ -e "$config/user-dirs.locale" ]] || recorded "$config/user-dirs.locale" || record seed "$config/user-dirs.locale" -
            for key in "${off[@]}"; do
                dir=""; [[ -n "$fresh" ]] || dir="$(xdg-user-dir "$key" 2>/dev/null || true)"; dir="${dir%/}"
                run xdg-user-dirs-update --set "$key" "$HOME" || echo "! $key : xdg-user-dirs-update --set refusé"
                [[ -n "$dir" && "$dir" != "$HOME" && -d "$dir" && ! -L "$dir" ]] || continue
                if [[ -n "$(ls -A "$dir")" ]]; then echo "! $dir non vide : gardé (plus un dossier XDG)"; continue; fi
                recorded "$dir" || record rmdir "$dir" -     # recréé par --uninstall
                run rmdir "$dir"
            done
            # Machine neuve : les dossiers XDG (Images…) ne sont créés qu'à la première connexion ; xdg-user-dir renverrait alors $HOME.
            [[ -z "$fresh" ]] || run xdg-user-dirs-update
            written "$f"; written "$config/user-dirs.locale"
        else
            echo "= $f (Modèles, Public, Projets désactivés)"
        fi
    fi
    if [[ -d "$HOME/Applications" ]]; then echo "= $HOME/Applications"; else run mkdir -p "$HOME/Applications"; fi
}

# Dépôt GitHub cloné dans le compte (fonds d'écran, DigitalMicrograph), sans question ; déjà cloné : mis à jour s'il n'a aucune
# modification locale. Dossier existant qui n'est pas un clone : gardé. --uninstall ne le retire pas (tes données).
sync_repo() {   # source (propriétaire/dépôt, ou chemin / adresse git) dossier description [options de git clone…]
    local src="$1" dir="$2" what="$3"; shift 3
    if [[ -d "$dir/.git" ]]; then
        if [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]; then
            echo "= $dir (modifications locales : pas de mise à jour)"
        elif [[ -n "$dry" ]]; then
            echo "+ git -C $dir pull --ff-only"
        else
            GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -F "$dir/config" -o BatchMode=yes" git -C "$dir" pull -q --ff-only 2>/dev/null && echo "= $dir à jour" || echo "! $dir : mise à jour impossible (réseau ou accès GitHub), gardé tel quel"
        fi
        return
    fi
    if [[ -e "$dir" ]]; then echo "= $dir existe déjà (pas un clone : gardé tel quel)"; return; fi
    run mkdir -p "$(dirname "$dir")"
    [[ -n "$dry" ]] && { echo "+ clone de $src dans $dir"; return; }
    echo "Téléchargement : $what"
    # Progression de git affichée (objets reçus, Mo, débit).
    if [[ "$src" == */*/* || "$src" == /* || "$src" == *:* ]]; then
        git clone --progress "$@" "$src" "$dir"
    elif command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
        gh repo clone "$src" "$dir" -- --progress "$@"
    else
        # Dépôt public : HTTPS sans compte ; sinon clé SSH. Jamais de question de mot de passe (échec immédiat).
        GIT_TERMINAL_PROMPT=0 git clone --progress "$@" "https://github.com/$src.git" "$dir" \
            || { echo "! HTTPS impossible : essai par SSH"
                 GIT_SSH_COMMAND="ssh -F "$dir/config" -o BatchMode=yes" git clone --progress "$@" "git@github.com:$src.git" "$dir"; }
    fi || { later "clonage de $src impossible (réseau, ou dépôt privé : gh auth login / clé SSH GitHub) ; relancer install.sh ensuite"; return 1; }
}

step_wallpapers() {
    # GitHub : dernière version seulement (--depth 1), sans les images retirées de l'historique ; `git pull` la met à jour ensuite.
    sync_repo "${QS_WALLPAPERS_REPO:-Crystal4276/wallpapers}" "$(wallpapers_dir)" "fonds d'écran (environ 300 Mo)" --depth 1 || true
}

# Profil travail : DigitalMicrograph (Gatan Microscopy Suite sous Wine). Ses paquets viennent de deps/work.txt ; son dépôt (privé)
# est cloné ici ; l'installation elle-même (kit Gatan, étape à la souris, 15 Go) reste à lancer depuis ce dépôt.
step_dm() {
    local dir="$HOME/GMSFreeAnalysis17"
    section "DigitalMicrograph (profil travail)"
    sync_repo "${QS_DM_REPO:-Crystal4276/GMSFreeAnalysis17}" "$dir" "scripts d'installation de DigitalMicrograph" || return 0
    if [[ -x "$HOME/.local/bin/digitalmicrograph" ]]; then
        echo "= DigitalMicrograph installé"
    elif [[ -z "$dry" ]]; then
        later "DigitalMicrograph : copier le kit Gatan décompressé (GMS_FreeAnalysis17.zip) dans $dir, puis $dir/scripts/install-all.sh"
    fi
}

# --- 5. Config machine -------------------------------------------------------------------------------------------------

step_host() {
    section "5. Config machine ($host)"
    # Les fichiers par machine suivent le nom d'hôte : un nom donné par le DHCP (aucun nom fixe) peut changer d'un réseau à l'autre.
    if command -v hostnamectl >/dev/null && [[ -z "$(hostnamectl --static 2>/dev/null)" ]]; then
        echo "! aucun nom de machine fixe (« $host » vient du réseau) : sudo hostnamectl set-hostname <nom>, puis relancer install.sh"
    fi
    local file="$repo/hosts/$host.json"
    # Fichier du dépôt, pas du compte : --uninstall le garde (il peut avoir été modifié ou committé).
    if [[ -f "$file" ]]; then
        if [[ "$(host_profile)" == "$profile" ]]; then echo "= hosts/$host.json (profil $profile)"; return; fi
        printf '+ hosts/%s.json : profil %s (à committer)\n' "$host" "$profile"
        [[ -n "$dry" ]] && return
        # Seule la ligne du profil change (ajoutée en tête si absente) : le reste du fichier garde sa mise en forme.
        python3 -I - "$file" "$profile" <<'EOF' || echo "! hosts/$host.json illisible (JSON invalide ?) : profil non écrit"
import json, re, sys
path, profile = sys.argv[1:]
text = open(path, encoding="utf-8").read()
conf = json.loads(text)
if "profile" in conf:
    text = re.sub(r'("profile"\s*:\s*)"[^"]*"', lambda m: m.group(1) + json.dumps(profile), text, count=1)
elif conf and text.startswith("{\n"):
    text = '{\n  "profile": %s,\n' % json.dumps(profile) + text[2:]
else:
    text = json.dumps({"profile": profile, **conf}, indent=2, ensure_ascii=False) + "\n"
open(path, "w", encoding="utf-8").write(text)
EOF
        return
    fi
    # Valeurs détectées et profil ; le reste vient de hosts/default.json (écran unique, laptop).
    local lines="  \"profile\": \"$profile\""
    (. "$repo/scripts/qs-env.sh" && qs_nvidia_only) && lines+=$',\n  "greeter": { "defaultSession": "wayland/sway-vulkan" }'
    printf '+ hosts/%s.json créé (à committer)\n' "$host"
    [[ -n "$dry" ]] || printf '{\n%s\n}\n' "$lines" > "$file"
}

# --- 6. Système (sudo) -------------------------------------------------------------------------------------------------

# Script système : en simulation sur une machine neuve, ses prérequis (paquets de l'étape 1) peuvent manquer.
# --unsupported-ok : le code 3 du script veut dire « non pris en charge sur cette machine » (rien de modifié, message du
# script), pas un échec à corriger (plymouth-setup.sh seulement).
sub() {
    local rc=0 ok3=""
    [[ "$1" == --unsupported-ok ]] && { ok3=1; shift; }
    "$@" || rc=$?
    (( rc == 0 )) && return 0
    [[ -n "$ok3" ]] && (( rc == 3 )) && return 0
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

# Écran de démarrage Plymouth « Core Lab » (docs/PLYMOUTH.md) : profil travail seulement. Une machine passée en jeux le perd
# (même retrait que --uninstall) ; une machine jeux qui ne l'a jamais eu n'est pas touchée.
plymouth_installed() { [[ -f /var/lib/qs-desktop/plymouth/state || -d /usr/share/plymouth/themes/qs-corelab ]]; }
step_plymouth() {
    if [[ "$profile" == travail ]]; then
        echo "Écran de démarrage Plymouth Core Lab (thème, hook de l'initramfs, splash, image de secours, passage au greeter)"
        sub --unsupported-ok "$repo/scripts/plymouth-setup.sh" ${dry:+--dry-run} install
    elif plymouth_installed; then
        echo "Écran de démarrage Plymouth retiré (profil jeux)"
        sub "$repo/scripts/plymouth-setup.sh" ${dry:+--dry-run} uninstall
    fi
}

# Horizon : profil travail, transaction séparée et réversible (docs/GRUB-HORIZON.md).
grub_horizon_setup() {
    if [[ -n "$dry" ]]; then
        "$repo/scripts/grub-horizon-setup.py" --dry-run "$@"
    else
        sudo "$repo/scripts/grub-horizon-setup.py" "$@"
    fi
}

step_grub_horizon() {
    if [[ "$profile" == travail ]]; then
        if [[ -f /etc/grub.d/15_uki && -f /etc/default/grub ]]; then
            echo "Menu GRUB Horizon (2 s, noyaux standard/LTS et variantes identifiés)"
            grub_horizon_setup install || later "Horizon non installé : voir docs/GRUB-HORIZON.md."
        fi
    elif [[ -f /var/lib/qs-desktop/grub-horizon/state.json ]]; then
        sub grub_horizon_setup uninstall
    fi
}

zerotier_network_file() {
    if [[ -f "$repo/hosts/zerotier-network.local" ]]; then
        echo "$repo/hosts/zerotier-network.local"
    else
        echo "$repo/hosts/zerotier-network"
    fi
}

step_zerotier() {
    local id file rc=0
    file="$(zerotier_network_file)"
    if [[ ! -f "$file" ]]; then
        later "ZeroTier : renseigner hosts/zerotier-network.local puis relancer install.sh."
        return
    fi
    id="$(cat "$file")"
    if [[ ! "$id" =~ ^[[:xdigit:]]{16}$ ]]; then
        later "ZeroTier : Network ID invalide dans $file."
        return 1
    fi
    "$repo/scripts/system-setup.sh" ${dry:+--dry-run} zerotier "${id,,}" || rc=$?
    case "$rc" in
        0) ;;
        3) later "ZeroTier : réseau non opérationnel ; vérifier autorisation Central et connectivité, puis relancer." ;;
        *) later "ZeroTier : provisioning échoué (code $rc)."; return 1 ;;
    esac
}

step_system() {
    section "6. Système (sudo, avec confirmation)"
    # Accord donné une fois pour toutes (ask_system).
    if gpu_vendors | grep -qx intel; then
        echo "Mesures GPU Intel : intel_gpu_top autorisé à lire les compteurs matériels (CAP_PERFMON)"
        sub "$repo/scripts/system-setup.sh" ${dry:+--dry-run} intel-gpu
    fi
    echo "Écran de connexion greetd + greeter Quickshell (remplace le gestionnaire actuel)"
    sub "$repo/scripts/greeter-setup.sh" ${dry:+--dry-run} install
    sub "$repo/scripts/system-setup.sh" ${dry:+--dry-run} cursor
    if [[ -n "$dry" && ! -d /usr/local/share/qs-desktop ]]; then
        echo "+ scripts/greeter-setup.sh enable (après l'installation ci-dessus)"
    else
        sub "$repo/scripts/greeter-setup.sh" ${dry:+--dry-run} enable
    fi
    greeter_wallpaper
    step_zerotier
    step_plymouth
    step_grub_horizon
    echo "Samba (dossier personnel via ZeroTier et VM), services, groupes et thème Qt du système"
    sub "$repo/scripts/system-setup.sh" ${dry:+--dry-run} install
    if command -v chromium >/dev/null; then
        echo "Extensions de Chromium (dotfiles/chromium/extensions.txt : Dark Reader, Stylus, nightTab…)"
        sub "$repo/scripts/system-setup.sh" ${dry:+--dry-run} chromium-extensions
    fi
    if command -v thunderbird >/dev/null; then
        echo "Thème Catppuccin de Thunderbird (Mocha Green, pour tout profil, même neuf)"
        local xpi
        if xpi="$(download thunderbird)"; then sub "$repo/scripts/system-setup.sh" ${dry:+--dry-run} thunderbird-theme "$xpi"
        elif [[ -z "$dry" ]]; then later "thème Thunderbird : téléchargement impossible ; relancer install.sh"; fi
    fi
    # Sonde de connectivité NetworkManager (portails captifs Wi-Fi). Déjà installée : le script rechargerait NetworkManager pour rien.
    if cmp -s "$repo/dotfiles/NetworkManager/conf.d/90-qs-desktop-connectivity.conf" /etc/NetworkManager/conf.d/90-qs-desktop-connectivity.conf \
        && [[ -f /var/lib/qs-desktop/network-setup/ready ]]; then
        echo "= sonde de connectivité installée"
    else
        sub "$repo/scripts/network-setup.sh" ${dry:+--dry-run} install
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
                chromium-pref|chromium-theme|json-pref)
                    # « chromium-theme <fichier> » : ancien registre, clé du thème seule.
                    local key=extensions.theme.system_theme
                    [[ "$kind" != chromium-theme ]] && { key="${target##*#}"; target="${target%#*}"; }
                    # Profil ouvert : Chromium réécrirait le fichier en se fermant (clé remise quand même, signalé).
                    [[ "$kind" != json-pref ]] && chromium_open "${target%/Default/Preferences}" \
                        && echo "! Chromium ouvert ($target) : le fermer, sinon ses réglages restent"
                    printf '+ %s : %s remis (%s)\n' "$target" "$key" "$backup"
                    [[ -n "$dry" || ! -f "$target" ]] || python3 -I - "$target" "$key" "$backup" <<'EOF' || echo "! $target illisible : $key laissé tel quel"
import json, os, sys
path, key, old = sys.argv[1:]
text = open(path, encoding="utf-8").read()
prefs = json.loads(text)
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
        json.dump(prefs, f, ensure_ascii=False, **({"indent": 2} if "\n" in text.strip() else {"separators": (",", ":")}))
        f.write("\n" if text.endswith("\n") else "")
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
                rmdir) [[ -e "$target" || -L "$target" ]] || run mkdir -p "$target" ;;   # dossier XDG vide retiré par step_home_dirs
            esac
        done 3< <(tac "$registry")
        if [[ -f "$state/dconf-old.ini" ]] && ! python3 -I "$repo/scripts/dconf-keys.py" ${dry:+--dry-run} restore "$state/dconf-old.ini"; then
            run cp "$state/dconf-old.ini" "$HOME/qs-desktop-dconf-old.ini-$stamp"
            echo "! dconf : anciennes valeurs non remises (bus de session injoignable ?), gardées dans ~/qs-desktop-dconf-old.ini-$stamp"
        fi
        run rm -rf "$registry" "$state/dconf-old.ini" "$state/dconf-old.ini.written" "$state/written" "$state/theme-geany" "$state/nighttab" "$state/stylus"
        [[ -L "$repo/dotfiles/mpv/host.conf" ]] && run rm -f "$repo/dotfiles/mpv/host.conf"
    else
        echo "= rien à retirer ($registry absent)"
    fi
    if command -v chromium >/dev/null; then
        python3 "$repo/scripts/browser-links-setup.py" ${dry:+--dry-run} uninstall 2>/dev/null || echo "= liens Chromium : rien à retirer"
    fi
    if [[ -n "$system" ]] && ask "Défaire aussi les étapes système (GPU Intel, sudo pacman, Reflector, greeter → ancien gestionnaire, écran de démarrage Plymouth, menu GRUB Horizon, sonde réseau, Samba, services, groupes, extensions Chromium, thème Thunderbird) ?"; then
        [[ -f /var/lib/qs-desktop/grub-horizon/state.json ]] && sub grub_horizon_setup uninstall
        plymouth_installed && sub "$repo/scripts/plymouth-setup.sh" ${dry:+--dry-run} uninstall
        sub "$repo/scripts/system-setup.sh" ${dry:+--dry-run} uninstall
        sub "$repo/scripts/network-setup.sh" ${dry:+--dry-run} uninstall
        sub "$repo/scripts/greeter-setup.sh" ${dry:+--dry-run} uninstall
        local own="/var/lib/qs-desktop/${USER:-$(id -un)}"
        [[ -e "$own/default.png" || -e "$own/default.jpg" ]] && run rm -f "$own/default.png" "$own/default.jpg"
    fi
    echo "Paquets conservés (paru compris)."
}

# --- Vérifications finales ---------------------------------------------------------------------------------------------

# Extensions de Chromium réglées depuis le dépôt, dans le profil principal (scripts/extension-import.py, Chromium sans
# fenêtre) : nightTab (page Nouvel onglet, dotfiles/chromium/nighttab.json) et Stylus (styles, dotfiles/chromium/stylus.json).
# Une fois par version du fichier : tes changements ensuite ne sont pas écrasés tant que le fichier du dépôt ne change pas.
# Il faut l'extension (étape système) et Chromium fermé ; sinon rappelé à la fin.
step_extensions() {
    command -v chromium >/dev/null && command -v python3 >/dev/null || return 0
    section "nightTab et Stylus"
    extension_import nighttab nightTab hdpcadigjkbcpnlcpbcohpafiaefanki réglages "nouvel onglet > roue dentée > Data > Import from file"
    extension_import stylus Stylus clngdbkpkpeebahjckkjfobafhncgmne styles "icône de Stylus > Gérer > Importer"
}

extension_import() {    # clé (fichier dotfiles/chromium/<clé>.json) nom identifiant contenu import-à-la-main
    local key="$1" name="$2" id="$3" what="$4" manual="$5" profile="$config/chromium" src="$repo/dotfiles/chromium/$1.json" sha rc=0
    sha="$(sha256sum < "$src" | cut -c1-64)"
    if [[ "$(cat "$state/$key" 2>/dev/null)" == "$sha" ]]; then echo "= $name : $what du dépôt déjà importés"; return; fi
    if [[ ! -d "$profile/Default/Extensions/$id" && ! -f "/usr/share/chromium/extensions/$id.json" && -z "$dry" ]]; then
        echo "- $name non installé (extensions de Chromium refusées) : $what non importés"; return
    fi
    if chromium_open "$profile"; then later "$name : Chromium ouvert ; le fermer puis relancer install.sh pour importer ses $what"; return; fi
    python3 -I "$repo/scripts/extension-import.py" ${dry:+--dry-run} "$key" "$profile" "$src" || rc=$?
    case "$rc" in
        0) [[ -n "$dry" ]] || { mkdir -p "$state"; echo "$sha" > "$state/$key"; } ;;
        3) later "$name : extension pas encore installée par Chromium (réseau ?) ; relancer install.sh" ;;
        *) later "$name : import impossible (message ci-dessus) ; à la main : $manual : $src" ;;
    esac
}

# SSH du compte : les clés et l'alias survivent au retrait du bureau, comme l'autorisation distante.
step_ssh_desktop() {
    section "SSH vers le desktop"
    local alias=terrier-zt dir="$HOME/.ssh" key="$HOME/.ssh/id_ed25519_terrier"
    local ssh_config=/dev/null
    [[ ! -f "$dir/config" ]] || ssh_config="$dir/config"
    local settings destination="" remote_user="" remote_host="" configured="" program
    for program in ssh ssh-keygen ssh-copy-id python3; do
        command -v "$program" >/dev/null || { later "SSH desktop : $program absent ; relancer après installation d'openssh et python."; return; }
    done
    settings="$(ssh -G -F "$ssh_config" "$alias" 2>/dev/null)" || { later 'SSH desktop : configuration SSH illisible ; corriger avant de relancer.'; return; }
    remote_host="$(awk '$1 == "hostname" { print $2; exit }' <<<"$settings")"
    remote_user="$(awk '$1 == "user" { print $2; exit }' <<<"$settings")"
    if [[ -n "$remote_host" && "$remote_host" != "$alias" ]]; then
        configured=1
        # Ne pas remplacer silencieusement une identité choisie pour cet alias.
        if ! awk -v key="$key" '$1 == "identityfile" && ($2 == key || $2 == "~/.ssh/id_ed25519_terrier") { found=1 } END { exit !found }' <<<"$settings"; then
            later 'SSH desktop : terrier-zt utilise une autre identité ; configuration existante conservée.'; return
        fi
    elif [[ -n "$dry" ]]; then
        echo '? Destination SSH du desktop : utilisateur@hôte, vide pour ignorer (simulation).'
        echo '+ Si renseignée : clé Ed25519 locale sans phrase secrète, alias terrier-zt et autorisation par ssh-copy-id.'
        return
    elif [[ -n "$yes" ]] || ! { : </dev/tty; } 2>/dev/null; then
        later 'SSH desktop : destination absente ; relancer install.sh dans un terminal sans --yes pour la renseigner.'; return
    else
        printf '? Destination SSH du desktop (utilisateur@IP ZeroTier ou nom, vide pour ignorer) : ' >/dev/tty
        read -r destination </dev/tty || destination=""
        [[ -n "$destination" ]] || { echo '- SSH desktop ignoré'; return; }
        if [[ ! "$destination" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*@[a-zA-Z0-9][a-zA-Z0-9.:-]*$ ]]; then
            later 'SSH desktop : destination invalide (utilisateur@hôte, port SSH standard).'; return
        fi
        remote_user="${destination%%@*}" remote_host="${destination#*@}"
    fi
    if [[ -L "$dir" || ( -e "$dir" && ! -d "$dir" ) || -L "$key" || -L "$key.pub" ]]; then
        later 'SSH desktop : chemins de clé inhabituels ; fichiers existants conservés.'; return
    fi
    if [[ -z "$configured" && ( -L "$dir/config" || ( -e "$dir/config" && ! -f "$dir/config" ) ) ]]; then
        later 'SSH desktop : configuration non ordinaire ; fichier existant conservé.'; return
    fi
    if [[ ( -e "$key" && ! -e "$key.pub" ) || ( ! -e "$key" && -e "$key.pub" ) ]]; then
        later 'SSH desktop : paire de clés incomplète ; aucun remplacement automatique.'; return
    fi
    if [[ -n "$dry" ]]; then
        echo '+ SSH desktop : conserver la clé existante ou créer une paire Ed25519 sans phrase secrète ; vérifier les permissions.'
        echo '= Simulation : aucune connexion distante ni autorisation.'
        return
    fi
    run install -d -m 700 "$dir"
    if [[ ! -e "$key" ]]; then
        if ! ssh-keygen -q -t ed25519 -N '' -f "$key" -C "${USER:-$(id -un)}@$host-to-desktop"; then
            later 'SSH desktop : génération de clé échouée.'; return
        fi
    fi
    if [[ ! -f "$key" || ! -f "$key.pub" ]] || ! ssh-keygen -l -f "$key.pub" >/dev/null 2>&1; then
        later 'SSH desktop : paire de clés invalide ; fichiers conservés.'; return
    fi
    run chmod 600 "$key"
    run chmod 644 "$key.pub"
    if [[ -z "$configured" ]]; then
        [[ ! -e "$dir/config" ]] || run cp -p "$dir/config" "$dir/config.bak-$stamp"
        if ! python3 -I - "$dir/config" "$remote_user" "$remote_host" <<'SSHCONFIG'
import os, pathlib, sys, tempfile
path = pathlib.Path(sys.argv[1])
old = path.read_bytes() if path.exists() else b''
block = ("# QS Desktop : accès au desktop\nHost terrier-zt\n"
         f"    HostName {sys.argv[3]}\n    User {sys.argv[2]}\n"
         "    IdentityFile ~/.ssh/id_ed25519_terrier\n    IdentitiesOnly yes\n\nHost *\n").encode()
fd, tmp = tempfile.mkstemp(prefix='.qs-desktop-', dir=path.parent)
try:
    with os.fdopen(fd, 'wb') as out:
        out.write(block + old)
    os.replace(tmp, path)
finally:
    if os.path.exists(tmp):
        os.unlink(tmp)
SSHCONFIG
        then later 'SSH desktop : configuration de l’alias échouée.'; return; fi
    fi
    [[ -L "$dir/config" ]] || run chmod 600 "$dir/config"
    # BatchMode ne demande ni mot de passe ni confirmation de clé du serveur.
    if ssh -F "$dir/config" -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 "$alias" true </dev/null; then
        echo '= SSH desktop opérationnel : ssh terrier-zt'
    elif [[ -n "$yes" ]] || ! { : </dev/tty; } 2>/dev/null; then
        later 'SSH desktop : autoriser la clé dans un terminal : ssh-copy-id -i ~/.ssh/id_ed25519_terrier.pub terrier-zt'
    elif ssh-copy-id -F "$dir/config" -i "$key.pub" -o StrictHostKeyChecking=ask -o ConnectTimeout=5 -o ConnectionAttempts=1 "$alias" </dev/tty >/dev/tty 2>&1 \
        && ssh -F "$dir/config" -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 "$alias" true </dev/null; then
        echo '= SSH desktop opérationnel : ssh terrier-zt'
    else
        later 'SSH desktop : autorisation inachevée ; relancer ssh-copy-id -i ~/.ssh/id_ed25519_terrier.pub terrier-zt dans un terminal.'
    fi
}

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
    echo "thème Catppuccin dans Obsidian, logiciels hors dépôts (NordVPN, Plex, RustDesk), connexion de Claude Code et de Codex."
    echo "Nouveaux groupes et thème Qt : effectifs à la prochaine connexion."
    echo "Partages Nemo : smb://<IP ZeroTier de la machine distante>/<compte distant> (compte et mot de passe Samba)."
}

if [[ -n "$uninstall" ]]; then
    do_uninstall
    exit 0
fi
[[ -n "$dry" ]] && echo "Simulation : rien ne sera modifié."
choose_profile
if [[ -n "$system" ]]; then
    network_id="$(cat "$(zerotier_network_file)")"
    [[ "$network_id" =~ ^[[:xdigit:]]{16}$ ]] || { echo '! Network ID ZeroTier invalide' >&2; exit 2; }
fi
ask_system
[[ -n "$system" ]] && step_pacman_sudo
[[ -n "$system" ]] && step_reflector
[[ -n "$packages" ]] && step_packages
step_configs
step_theme
step_settings
section "Dossiers du compte"
step_home_dirs
section "Fonds d'écran"
step_wallpapers
[[ "$profile" == travail ]] && step_dm
step_host
[[ -n "$system" ]] && is_arch && step_system
step_ssh_desktop
step_extensions
step_check
