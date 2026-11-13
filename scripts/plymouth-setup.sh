#!/usr/bin/env bash
# Écran de démarrage Plymouth « Core Lab » (docs/PLYMOUTH.md), profil travail seulement. À lancer en utilisateur : chaque
# commande système passe par sudo. Idempotent ; repris par install.sh (étape système).
#
# Usage : plymouth-setup.sh [--dry-run] install     thème (version committée) dans /usr/share/plymouth/themes, thème par défaut,
#                                                  hook `plymouth` dans l'initramfs, `splash` sur la ligne de commande du noyau,
#                                                  passage au greeter (surcharges de plymouth-quit-wait et plymouth-quit) ;
#                                                  UKI : image de secours sans Plymouth par noyau, logo de systemd-stub
#                                                  retiré ; initramfs (et GRUB) refaits
#         plymouth-setup.sh [--dry-run] uninstall   chaque changement défait (hook, splash, secours, thème précédent, surcharges,
#                                                  thème)
#         plymouth-setup.sh status                  état de chaque élément
#         --dry-run : affiche les commandes sans rien modifier.
# Deux modes de démarrage (docs/PLYMOUTH.md, « Intégration système ») :
# - UKI (archinstall « Unified kernel images ») : un preset de mkinitcpio porte default_uki= ; la ligne de commande est intégrée
#   à l'UKI (/etc/kernel/cmdline + /etc/cmdline.d) ; le chargeur (GRUB et /etc/grub.d/15_uki, systemd-boot) la lance tel quel.
#   GRUB n'est pas touché.
# - GRUB classique (initramfs à part) : `splash` dans GRUB_CMDLINE_LINUX_DEFAULT, grub.cfg refait.
# Les mises à jour du noyau, de plymouth ou de systemd refont les images par le hook pacman de mkinitcpio, avec ces réglages.
# Retour arrière à la main (machine qui ne démarre plus) : docs/ROLLBACK.md, section Plymouth.
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
theme=qs-corelab
dest=/usr/share/plymouth/themes/$theme
var=/var/lib/qs-desktop/plymouth
state="$var/state"            # ce qui a été ajouté par nous (défait par uninstall) : hooks=<fichier>, splash=1 (GRUB),
                              # cmdline=<fichier de /etc/cmdline.d>, rescue=<preset>, stub-splash=<preset> <bmp>,
                              # previous-theme=<nom>, ou
                              # plymouthd-conf=<copie> (fichier d'origine sans thème explicite, remis tel quel ; « - » : absent)
conf=/etc/plymouth/plymouthd.conf
grub=/etc/default/grub
presets_dir=/etc/mkinitcpio.d
dropin=/etc/cmdline.d/qs-corelab.conf
# Image de secours (UKI) : preset « rescue » ajouté à chaque preset UKI, sans le hook plymouth (phrase de passe LUKS en mode
# texte). Titre propre dans le menu (GRUB : PRETTY_NAME de l'os-release intégré, $var/os-release-rescue-<noyau>). Nom
# <image>.bak.efi : nom compatible BLS ; filevercmp place .bak.efi après .efi en ordre décroissant, chaque secours
# juste sous son image normale ; la première entrée (par défaut) reste une image normale. Lignes repérées par $mark.
mark="# qs-corelab : image de secours sans Plymouth (scripts/plymouth-setup.sh)"
dropins=(
    "dotfiles/plymouth/plymouth-quit-wait.conf /etc/systemd/system/plymouth-quit-wait.service.d/qs-corelab.conf"
    "dotfiles/plymouth/plymouth-quit.conf /etc/systemd/system/plymouth-quit.service.d/qs-corelab.conf"
)
[[ $EUID -ne 0 ]] || { echo "À lancer en utilisateur, sans sudo (sudo est appelé pour chaque commande)." >&2; exit 1; }
stamp="$(date +%Y%m%d-%H%M%S)"
dry=""
initramfs="" bootloader="" units=""   # à refaire en fin d'étape

run() {
    printf '+ %s\n' "$*"
    [[ -n "$dry" ]] || sudo "$@"
}

noted() { [[ -f "$state" ]] && grep -m1 "^$1=" "$state" | cut -d= -f2- || true; }
note() { run sh -c "mkdir -p '$var' && echo '$1=$2' >> '$state'"; }

# Copie d'origine, une fois, pour un retour à la main (docs/ROLLBACK.md) ; uninstall défait les changements eux-mêmes.
keep_original() {
    local copy
    copy="$var/backup/$(echo "${1#/}" | tr / _).bak-$stamp"
    ls "$var/backup/$(echo "${1#/}" | tr / _).bak-"* >/dev/null 2>&1 && return
    run install -d -m 755 "$var/backup"
    run cp -a "$1" "$copy"
}

# Fichier qui fixe HOOKS en dernier (mkinitcpio lit /etc/mkinitcpio.conf puis /etc/mkinitcpio.conf.d/*.conf).
hooks_file() {
    local f last=""
    for f in /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/*.conf; do
        [[ -f "$f" ]] && grep -qE '^HOOKS=' "$f" && last="$f"
    done
    echo "$last"
}

# Tableau HOOKS=( … ), sur une ou plusieurs lignes (le hook a pu être ajouté à la main).
has_hook() { awk '/^HOOKS=\(/{f=1} f{print} f&&/\)/{exit}' "$1" | grep -qw plymouth; }
has_splash() { grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\bsplash\b' "$grub"; }
# Thème par défaut ; Theme= lu et écrit directement si l'outil manque (paquet retiré avant uninstall).
theme_now() { plymouth-set-default-theme 2>/dev/null || sed -n 's/^Theme=//p' "$conf" 2>/dev/null | tail -n1; }
set_theme() {   # <nom> | --reset
    if command -v plymouth-set-default-theme >/dev/null; then run plymouth-set-default-theme "$1"
    elif [[ "$1" == --reset ]]; then run sed -i '/^Theme=/d' "$conf"
    else run sed -i "s/^Theme=.*/Theme=$1/" "$conf"; fi
}

noted_all() { [[ -f "$state" ]] && grep "^$1=" "$state" | cut -d= -f2- || true; }
unnote() { run sed -i "\\|^$1=$2\$|d" "$state"; }

# --- Mode UKI ---------------------------------------------------------------------------------------------------------

uki_presets() { grep -lE '^default_uki=' "$presets_dir"/*.preset 2>/dev/null || true; }
stub_splash() { sed -nE 's/^default_options=".*--splash[[:space:]]+([^[:space:]"]+).*/\1/p' "$1"; }   # BMP du logo de systemd-stub
preset_value() { bash -c 'source "$1" && printf %s "${!2}"' _ "$1" "$2"; }   # $1 = preset, $2 = variable

# Fichiers de la ligne de commande intégrée par mkinitcpio (sans --cmdline) : /etc/kernel/cmdline (sinon
# /usr/lib/kernel/cmdline), puis /etc/cmdline.d/*.conf. Aucun : mkinitcpio reprend /proc/cmdline (refusé ici).
cmdline_files() {
    local f
    for f in /etc/kernel/cmdline /usr/lib/kernel/cmdline; do [[ -f "$f" ]] && { echo "$f"; break; }; done
    find /etc/cmdline.d -xtype f -name '*.conf' 2>/dev/null | LC_ALL=C sort -V
}
cmdline_splash() {
    local files
    mapfile -t files < <(cmdline_files)
    (( ${#files[@]} )) && grep -h -- '^[^#]' "${files[@]}" | grep -qw splash
}

# Vérifications du mode UKI, avant tout changement.
check_uki() {
    local p
    if grep -qE '^(ALL|[a-z]+)_cmdline=' $(uki_presets); then
        echo "! un preset de $presets_dir fixe sa propre ligne de commande (*_cmdline=) : ajouter « splash » à la main ; rien n'est modifié." >&2
        exit 1
    fi
    if [[ -z "$(cmdline_files)" ]]; then
        echo "! UKI sans /etc/kernel/cmdline ni /etc/cmdline.d : mkinitcpio reprendrait /proc/cmdline ; rien n'est modifié." >&2
        exit 1
    fi
    for p in $(uki_presets); do
        grep -qxF "$mark" "$p" && continue
        grep -qE "^PRESETS=\([^)]*\)[[:space:]]*$" "$p" && ! grep -qE "^rescue_|'rescue'" "$p" \
            || { echo "! $p : PRESETS=( … ) sur une ligne attendu, sans preset « rescue » ; rien n'est modifié." >&2; exit 1; }
    done
}

# Os-release intégré à l'image de secours d'un preset : seul son PRETTY_NAME change (titre de l'entrée du menu).
osrel_of() { echo "$var/os-release-rescue-$(basename "$1" .preset)"; }
rescue_osrel() {   # $1 = preset
    local kernel src=/etc/os-release tmp out
    kernel="$(basename "$1" .preset)" out="$(osrel_of "$1")"
    [[ -f "$src" ]] || src=/usr/lib/os-release
    tmp="$(mktemp)"
    sed -E "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Arch Linux ($kernel rescue, no splash)\"/" "$src" >"$tmp"
    grep -q '^PRETTY_NAME=' "$tmp" || echo "PRETTY_NAME=\"Arch Linux ($kernel rescue, no splash)\"" >>"$tmp"
    if cmp -s "$tmp" "$out"; then rm -f "$tmp"; return; fi
    rebuild initramfs
    run install -D -m 644 "$tmp" "$out"
    rm -f "$tmp"
}

install_uki() {
    local p uki
    if cmdline_splash; then
        echo "= splash dans la ligne de commande du noyau ($(cmdline_files | tr '\n' ' '))"
    else
        rebuild initramfs
        [[ -n "$(noted cmdline)" ]] || note cmdline "$dropin"
        run install -D -m 644 /dev/stdin "$dropin" <<<"splash"
    fi
    for p in $(uki_presets); do
        rescue_osrel "$p"
        if grep -qxF "$mark" "$p"; then
            echo "= image de secours sans Plymouth dans $p"
            continue
        fi
        uki="$(preset_value "$p" default_uki)"
        rebuild initramfs
        keep_original "$p"
        [[ -n "$(noted_all rescue | grep -xF "$p")" ]] || note rescue "$p"
        run sed -i -E "s/^PRESETS=\(([^)]*)\)/PRESETS=(\1 'rescue')/" "$p"
        # Dernière ligne sans saut de ligne : ajouté d'abord (le bloc se collerait sinon à la ligne précédente).
        run sh -c "[ -z \"\$(tail -c 1 '$p')\" ] || echo >> '$p'; printf '%s\n%s\n%s\n' '$mark' 'rescue_uki=\"${uki%.efi}.bak.efi\"' 'rescue_options=(-S plymouth --osrelease $(osrel_of "$p"))' >> '$p'"
    done
    # Logo de systemd-stub (« --splash <bmp> » mis par archinstall dans default_options) : affiché avant Plymouth, retiré ;
    # le BMP est noté pour uninstall. Un *_splash= du preset n'est pas touché.
    local bmp
    for p in $(uki_presets); do
        bmp="$(stub_splash "$p")"
        if [[ -z "$bmp" ]]; then
            echo "= pas de logo de systemd-stub dans $p"
            continue
        fi
        rebuild initramfs
        keep_original "$p"
        [[ -n "$(noted_all stub-splash | grep -F "$p ")" ]] || note stub-splash "$p $bmp"
        run sed -i -E -e 's/^(default_options=".*)--splash[[:space:]]+[^[:space:]"]+[[:space:]]?/\1/' \
            -e '/^default_options=/s/[[:space:]]+"$/"/' "$p"
    done
    # Reprise : « splash » ajouté dans GRUB par une version précédente, sans effet sur une UKI ; défait sans grub-mkconfig.
    if [[ -n "$(noted splash)" ]]; then
        has_splash && run sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT="/{s/ splash\b//;s/"splash /"/;s/"splash"/""/}' "$grub"
        unnote splash 1
    fi
}

uninstall_uki() {
    local p uki
    for p in $(noted_all rescue); do
        if [[ -f "$p" ]] && grep -qxF "$mark" "$p"; then
            uki="$(preset_value "$p" rescue_uki)"
            rebuild initramfs
            run sed -i -e "\\|^$mark\$|d" -e '/^rescue_uki=/d' -e '/^rescue_options=/d' \
                -e "s/^PRESETS=(\(.*\) 'rescue')/PRESETS=(\1)/" "$p"
            [[ -n "$uki" ]] && run rm -f "$uki"
        fi
        [[ -f "$(osrel_of "$p")" ]] && run rm -f "$(osrel_of "$p")"
        unnote rescue "$p"
    done
    local entries entry bmp
    mapfile -t entries < <(noted_all stub-splash)
    for entry in "${entries[@]}"; do
        read -r p bmp <<<"$entry"
        if [[ -f "$p" && -z "$(stub_splash "$p")" ]]; then
            rebuild initramfs
            run sed -i -E -e "s|^default_options=\"(.*)\"|default_options=\"--splash $bmp \\1\"|" \
                -e '/^default_options=/s/[[:space:]]+"$/"/' "$p"
        fi
        unnote stub-splash "$entry"
    done
    if [[ -n "$(noted cmdline)" ]]; then
        rebuild initramfs
        run rm -f "$(noted cmdline)"
        run rmdir --ignore-fail-on-non-empty "$(dirname "$(noted cmdline)")"
        unnote cmdline "$(noted cmdline)"
    fi
    if [[ -n "$(noted splash)" ]]; then
        has_splash && run sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT="/{s/ splash\b//;s/"splash /"/;s/"splash"/""/}' "$grub"
        unnote splash 1
    fi
}

# --- Mode GRUB classique ----------------------------------------------------------------------------------------------

# Chargeur : GRUB dans /boot/grub seulement (le laptop) ; autre chose → rien n'est modifié (code 3 : non pris en charge).
# /boot (ESP en vfat, dmask=0077 par archinstall) peut être illisible en utilisateur : vérifié par sudo (un refus de sudo
# est un échec, pas un chargeur non pris en charge) ; en simulation, sans sudo, supposé bon.
grub_dir() {
    [[ -d /boot/grub ]] && return 0
    [[ -x /boot ]] && return 1
    [[ -n "$dry" ]] && return 0
    local r
    r="$(sudo sh -c 'test -d /boot/grub && echo yes || echo no')" || { echo "! sudo : échec" >&2; exit 1; }
    [[ "$r" == yes ]]
}

check_bootloader() {
    if [[ -f "$grub" ]] && grub_dir && command -v grub-mkconfig >/dev/null \
        && grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT="' "$grub"; then
        return 0
    fi
    echo "! chargeur de démarrage non pris en charge (GRUB attendu : $grub, /boot/grub, grub-mkconfig) ; rien n'est modifié." >&2
    echo "  systemd-boot / UKI : ajouter « splash » à la ligne de commande du noyau à la main (docs/PLYMOUTH.md)." >&2
    exit 3
}

install_theme() {
    local tree
    tree="$(mktemp -d)"
    git -C "$repo" archive --format=tar HEAD dotfiles/plymouth | tar -x -C "$tree"
    [[ -z "$(git -C "$repo" status --porcelain -- dotfiles/plymouth)" ]] \
        || echo "! dotfiles/plymouth : modifications non committées, seule la version committée est installée"
    if diff -rq "$tree/dotfiles/plymouth/$theme" "$dest" >/dev/null 2>&1; then
        echo "= $dest à jour"
    else
        rebuild initramfs
        run rm -rf "$dest.new"
        run cp -r --no-preserve=ownership "$tree/dotfiles/plymouth/$theme" "$dest.new"
        run chmod -R u=rwX,go=rX "$dest.new"
        run rm -rf "$dest"
        run mv "$dest.new" "$dest"
    fi
    local entry src target
    for entry in "${dropins[@]}"; do
        read -r src target <<<"$entry"
        if cmp -s "$tree/$src" "$target"; then
            echo "= $target à jour"
        else
            run install -D -m 644 -o root -g root "$tree/$src" "$target"
            units=1
        fi
    done
    rm -rf "$tree"
}

do_install() {
    command -v plymouthd >/dev/null || { echo "! plymouth n'est pas installé (paquets : deps/work.txt)." >&2; [[ -n "$dry" ]] || exit 1; }
    command -v mkinitcpio >/dev/null || { echo "! mkinitcpio absent : initramfs non pris en charge ; rien n'est modifié." >&2; exit 3; }
    if [[ "$mode" == uki ]]; then check_uki; else check_bootloader; fi
    local hf
    hf="$(hooks_file)"
    [[ -n "$hf" ]] || { echo "! HOOKS introuvable dans /etc/mkinitcpio.conf(.d) ; rien n'est modifié." >&2; exit 1; }
    # Le sed du hook ne traite que HOOKS=( … ) sur une ligne.
    has_hook "$hf" || grep -qE '^HOOKS=\(.*\)' "$hf" \
        || { echo "! HOOKS de $hf hors de la forme HOOKS=( … ) sur une ligne : ajouter « plymouth » avant block / encrypt à la main ; rien n'est modifié." >&2; exit 1; }
    pending

    install_theme

    local current
    current="$(theme_now || true)"
    if [[ "$current" == "$theme" ]]; then
        echo "= thème Plymouth par défaut : $theme"
    else
        rebuild initramfs
        if [[ -n "$(noted previous-theme)$(noted plymouthd-conf)" ]]; then
            :
        elif grep -qE '^Theme=' "$conf" 2>/dev/null; then
            note previous-theme "$current"
        elif [[ -f "$conf" ]]; then          # thème par défaut de la distribution : fichier remis tel quel au retrait
            run install -D -m 644 "$conf" "$var/plymouthd.conf.orig"
            note plymouthd-conf "$var/plymouthd.conf.orig"
        else
            note plymouthd-conf -
        fi
        [[ -f "$conf" ]] && keep_original "$conf"
        set_theme "$theme"
    fi

    # Hook juste avant le premier de block / sd-encrypt / encrypt / filesystems : Plymouth affiché avant la phrase de passe.
    if has_hook "$hf"; then
        echo "= hook plymouth dans $hf"
    else
        rebuild initramfs
        keep_original "$hf"
        [[ -n "$(noted hooks)" ]] || note hooks "$hf"
        run sed -i -E '/^HOOKS=\(/{s/\b(block|sd-encrypt|encrypt|filesystems)\b/plymouth \1/;t;s/\)/ plymouth)/}' "$hf"
    fi

    if [[ "$mode" == uki ]]; then
        install_uki
    elif has_splash; then
        echo "= splash dans $grub"
    else
        rebuild bootloader
        keep_original "$grub"
        [[ -n "$(noted splash)" ]] || note splash 1
        run sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=")([^"]*)"/\1\2 splash"/; s/^(GRUB_CMDLINE_LINUX_DEFAULT=") /\1/' "$grub"
    fi
    finish
    [[ -n "$dry" || -n "$initramfs$bootloader$units" ]] && echo "Écran de démarrage Core Lab au prochain démarrage (retour : $0 uninstall, docs/ROLLBACK.md)."
    return 0
}

do_uninstall() {
    local hf previous original entry src target
    pending
    hf="$(noted hooks)"
    if [[ -n "$hf" && -f "$hf" ]] && has_hook "$hf"; then
        rebuild initramfs
        run sed -i -E '/^HOOKS=\(/{s/\bplymouth //;s/ plymouth\)/)/}' "$hf"
    fi
    if [[ "$mode" == uki ]]; then
        uninstall_uki
    elif [[ -n "$(noted splash)" ]] && has_splash; then
        rebuild bootloader
        run sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT="/{s/ splash\b//;s/"splash /"/;s/"splash"/""/}' "$grub"
    fi
    previous="$(noted previous-theme)" original="$(noted plymouthd-conf)"
    if [[ "$(theme_now || true)" == "$theme" ]]; then
        rebuild initramfs
        if [[ "$original" == - ]]; then
            run rm -f "$conf"
        elif [[ -n "$original" && -f "$original" ]]; then
            run install -m 644 "$original" "$conf"
        elif [[ -n "$previous" ]]; then
            set_theme "$previous"
        else
            set_theme --reset
        fi
    fi
    for entry in "${dropins[@]}"; do
        read -r src target <<<"$entry"
        if [[ -f "$target" ]]; then
            run rm -f "$target"
            run rmdir --ignore-fail-on-non-empty "$(dirname "$target")"
            units=1
        fi
    done
    if [[ -d "$dest" ]]; then
        rebuild initramfs
        run rm -rf "$dest"
    fi
    finish
    [[ -f "$state" ]] && run rm -f "$state" "$var/plymouthd.conf.orig"
    [[ -d "$var/backup" ]] && echo "- copies d'origine gardées dans $var/backup (retour à la main)"
    return 0
}

# Marque $var/rebuild posée avant le premier changement qui demande de refaire l'initramfs ou GRUB, retirée quand les deux
# sont refaits : un passage interrompu (sudo refusé, mkinitcpio ou grub-mkconfig en échec) est repris au suivant, même si
# rien d'autre n'a changé depuis.
rebuild() {   # initramfs | bootloader
    [[ -n "$initramfs$bootloader" || -f "$var/rebuild" ]] || run sh -c "mkdir -p '$var' && touch '$var/rebuild'"
    printf -v "$1" 1
}

pending() {
    [[ -f "$var/rebuild" ]] || return 0
    echo "! initramfs (et GRUB) non refaits au dernier passage : refaits maintenant"
    initramfs=1
    [[ "$mode" == uki ]] || bootloader=1
}

finish() {
    [[ -n "$units" ]] && run systemctl daemon-reload
    [[ -n "$initramfs" ]] && run mkinitcpio -P
    [[ -n "$bootloader" ]] && run grub-mkconfig -o /boot/grub/grub.cfg
    [[ -n "$initramfs$bootloader" ]] && run rm -f "$var/rebuild"
    return 0
}

do_status() {
    local hf
    hf="$(hooks_file)"
    echo "thème installé      : $([[ -f "$dest/$theme.plymouth" ]] && echo oui || echo non) ($dest)"
    echo "thème par défaut    : $(theme_now || true)"
    [[ -f "$var/rebuild" ]] && echo "! initramfs et GRUB à refaire (passage interrompu) : relancer install ou uninstall"
    echo "hook plymouth       : $([[ -n "$hf" ]] && has_hook "$hf" && echo "oui ($hf)" || echo non)"
    local running
    running="$(grep -qw splash /proc/cmdline && echo splash || echo 'sans splash')"
    if [[ "$mode" == uki ]]; then
        echo "démarrage           : UKI ($(uki_presets | tr '\n' ' '))"
        echo "splash (UKI)        : $(cmdline_splash && echo oui || echo non) ($(cmdline_files | tr '\n' ' ')) ; noyau en cours : $running"
        local p
        for p in $(uki_presets); do
            echo "image de secours    : $(grep -qxF "$mark" "$p" && echo "oui ($(preset_value "$p" rescue_uki))" || echo non) ($p)"
            echo "logo systemd-stub   : $([[ -n "$(stub_splash "$p")" ]] && echo "oui ($(stub_splash "$p"))" || echo non) ($p)"
        done
        [[ -f "$grub" ]] && has_splash && echo "splash (GRUB)       : oui, sans effet sur une UKI"
    else
        echo "démarrage           : GRUB classique"
        echo "splash (GRUB)       : $([[ -f "$grub" ]] && has_splash && echo oui || echo non) ; noyau en cours : $running"
    fi
    local entry src target
    for entry in "${dropins[@]}"; do
        read -r src target <<<"$entry"
        echo "surcharge           : $([[ -f "$target" ]] && echo oui || echo non) ($target)"
    done
    echo "changements notés   : $([[ -f "$state" ]] && tr '\n' ' ' <"$state" || echo aucun)"
}

[[ "${1:-}" == --dry-run ]] && { dry=1; shift; }
mode=grub
[[ -z "$(uki_presets)" ]] || mode=uki
case "${1:-}" in
    install) do_install ;;
    uninstall) do_uninstall ;;
    status) do_status ;;
    *) sed -n '5,13p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
