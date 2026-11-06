#!/usr/bin/env bash
# Sonde HTTP partagée avec la carte Wi-Fi. Aucun redémarrage du réseau.
# --root DIR installe dans une arborescence de préparation, sans sudo ni rechargement.
set -euo pipefail
repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
dry=false
root=""
usage() { echo 'Usage : network-setup.sh [--dry-run] [--root DIR] {install|uninstall}' >&2; exit 2; }
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) dry=true; shift ;;
        --root) [[ $# -ge 2 && -n $2 && $2 != / ]] || usage; root=$(realpath -m "$2"); [[ $root != / ]] || usage; shift 2 ;;
        *) break ;;
    esac
done
[[ $# -eq 1 && ( $1 == install || $1 == uninstall ) ]] || usage
action=$1
source_conf="$repo/dotfiles/NetworkManager/conf.d/90-qs-desktop-connectivity.conf"
target="$root/etc/NetworkManager/conf.d/90-qs-desktop-connectivity.conf"
state="$root/var/lib/qs-desktop/network-setup"
fail() { echo "$*" >&2; exit 1; }
run() {
    printf '+'; printf ' %q' "$@"; printf '\n'
    if ! "$dry"; then
        if [[ -n $root ]]; then "$@"; else sudo -- "$@"; fi
    fi
}
reload() {
    if [[ -z $root ]]; then
        # conf = relire les fichiers uniquement ; ni DNS, ni redémarrage du service.
        run nmcli general reload conf
    fi
}
if [[ -z $root ]]; then
    [[ $EUID -ne 0 ]] || fail 'À lancer sans sudo : le script appelle sudo pour les opérations système.'
    command -v nmcli >/dev/null || fail 'NetworkManager (nmcli) est requis.'
fi
[[ ! -L $target && ! -L $state ]] || fail 'Lien symbolique sur la destination ou la sauvegarde : vérifier avant installation.'
case "$action" in
    install)
        [[ -f $source_conf ]] || fail "Configuration absente : $source_conf"
        if [[ -e $state ]]; then
            [[ -f $state/ready ]] || fail "Sauvegarde incomplète dans $state : vérifier avant de continuer."
        else
            run install -d -m 755 "$state"
            if [[ -e $target ]]; then run cp -p "$target" "$state/original"; fi
            run touch "$state/ready"
        fi
        if [[ ! -f $target ]] || ! cmp -s "$source_conf" "$target"; then
            run install -D -m 644 "$source_conf" "$target"
        fi
        # Refaire le rechargement sur une seconde installation permet de reprendre après un refus polkit/sudo.
        reload
        if "$dry"; then echo 'Simulation terminée ; aucun fichier modifié.';
        else echo 'Configuration installée ; aucun réglage de VPN ni connexion modifiés.'; fi
        ;;
    uninstall)
        [[ -f $state/ready ]] || fail 'Aucune installation sauvegardée.'
        if [[ -f $target ]] && ! cmp -s "$source_conf" "$target"; then
            run cp -p "$target" "$target.before-restore-$(date +%Y%m%d-%H%M%S-%N)"
        fi
        if [[ -f $state/original ]]; then
            run cp -p "$state/original" "$target"
        else
            run rm -f "$target"
        fi
        reload
        run rm -rf "$state"
        if "$dry"; then echo 'Simulation terminée ; aucun fichier modifié.';
        else echo 'Configuration précédente restaurée.'; fi
        ;;
esac
