#!/usr/bin/env bash
# Écran de démarrage Plymouth « Core Lab » (docs/PLYMOUTH.md), profil travail seulement. À lancer en utilisateur : chaque
# commande système passe par sudo. Idempotent ; repris par install.sh (étape système).
#
# Usage : plymouth-setup.sh [--dry-run] install     thème (version committée) dans /usr/share/plymouth/themes, thème par défaut,
#                                                  hook `plymouth` dans l'initramfs, `splash` dans GRUB, passage au greeter
#                                                  (surcharges de plymouth-quit-wait et plymouth-quit), initramfs et GRUB refaits
#         plymouth-setup.sh [--dry-run] uninstall   chaque changement défait (hook, splash, thème précédent, surcharges, thème)
#         plymouth-setup.sh status                  état de chaque élément
#         --dry-run : affiche les commandes sans rien modifier.
# Retour arrière à la main (machine qui ne démarre plus) : docs/ROLLBACK.md, section Plymouth.
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
theme=qs-corelab
dest=/usr/share/plymouth/themes/$theme
var=/var/lib/qs-desktop/plymouth
state="$var/state"            # ce qui a été ajouté par nous (défait par uninstall) : hooks=<fichier>, splash=1, previous-theme=<nom>,
                              # ou plymouthd-conf=<copie> (fichier d'origine sans thème explicite, remis tel quel ; « - » : absent)
conf=/etc/plymouth/plymouthd.conf
grub=/etc/default/grub
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
    check_bootloader
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

    if has_splash; then
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
    if [[ -n "$(noted splash)" ]] && has_splash; then
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
    echo "! initramfs et GRUB non refaits au dernier passage : refaits maintenant"
    initramfs=1 bootloader=1
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
    echo "splash (GRUB)       : $([[ -f "$grub" ]] && has_splash && echo oui || echo non) ; noyau en cours : $(grep -qw splash /proc/cmdline && echo splash || echo 'sans splash')"
    local entry src target
    for entry in "${dropins[@]}"; do
        read -r src target <<<"$entry"
        echo "surcharge           : $([[ -f "$target" ]] && echo oui || echo non) ($target)"
    done
    echo "changements notés   : $([[ -f "$state" ]] && tr '\n' ' ' <"$state" || echo aucun)"
}

[[ "${1:-}" == --dry-run ]] && { dry=1; shift; }
case "${1:-}" in
    install) do_install ;;
    uninstall) do_uninstall ;;
    status) do_status ;;
    *) sed -n '5,11p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
