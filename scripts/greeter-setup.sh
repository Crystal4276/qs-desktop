#!/usr/bin/env bash
# Mise en place système de l'écran de connexion (greetd + greeter Quickshell, docs/ARCHITECTURE.md § 9). À lancer en utilisateur :
# chaque commande système passe par sudo. Idempotent ; repris par install.sh (phase 12).
#
# Usage : greeter-setup.sh [--dry-run] install     copie du dépôt (version committée) dans /usr/local/share/qs-desktop, fichiers greetd
#                                                  et PAM (dotfiles/greetd, ancien fichier sauvegardé), dossiers de /var/lib/qs-desktop ;
#                                                  aucun service touché. À relancer après un changement du greeter.
#         greeter-setup.sh [--dry-run] enable      greetd devient le gestionnaire de connexion au prochain démarrage (l'ancien,
#                                                  ex. sddm, est désactivé et noté pour `uninstall`)
#         greeter-setup.sh [--dry-run] uninstall   ancien gestionnaire réactivé, fichiers d'origine restaurés, copie et dossiers retirés
#         --dry-run : affiche les commandes sans rien modifier.
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
dest=/usr/local/share/qs-desktop
var=/var/lib/qs-desktop
backups="$var/backups"        # « fichier sauvegarde » par ligne ; « fichier - » : absent avant nous (retiré par uninstall)
previous_dm="$var/previous-dm"
[[ $EUID -ne 0 ]] || { echo "À lancer en utilisateur, sans sudo (sudo est appelé pour chaque commande)." >&2; exit 1; }
user="$USER"
stamp="$(date +%Y%m%d-%H%M%S)"
dry=""

files=(
    "dotfiles/greetd/config.toml /etc/greetd/config.toml"
    "dotfiles/greetd/pam-greetd /etc/pam.d/greetd"
    "dotfiles/greetd/pam-greetd-greeter /etc/pam.d/greetd-greeter"
)
# Session Sway sur Nvidia (Sway refuse de démarrer sans --unsupported-gpu ; config machine `greeter.defaultSession`) : copie du
# fichier fait à la main pour SDDM, dans /usr/local/share (avant /usr/share dans XDG_DATA_DIRS, hors des fichiers des paquets).
# Nvidia seule carte (comme le Sway du greeter, scripts/greeter.sh) ; laptop hybride : à traiter en phase 12.
if (. "$repo/scripts/qs-env.sh" && qs_nvidia_only); then
    files+=("dotfiles/greetd/sway-vulkan.desktop /usr/local/share/wayland-sessions/sway-vulkan.desktop")
fi

run() {
    printf '+ %s\n' "$*"
    [[ -n "$dry" ]] || sudo "$@"
}

# Ligne enregistrée pour `file` dans $backups ("" : aucune).
recorded() {
    [[ -f "$backups" ]] && awk -v f="$1" '$1 == f { print $2; exit }' "$backups" || true
}

record() {
    run sh -c "echo '$1 $2' >> '$backups'"
}

# Sauvegarde d'un fichier système, hors de son dossier (une copie dans /etc/pam.d serait un service PAM de plus).
backup_of() {
    echo "$var/backup/$(echo "${1#/}" | tr / _).bak-$stamp"
}

# Fichier `$1` de la version committée (extraite dans $tree par install) vers `$2`.
install_file() {
    local src="$tree/$1" target="$2"
    if [[ -f "$target" ]] && cmp -s "$src" "$target"; then
        echo "= $target à jour"
        # Déjà là sans être noté (registre perdu, copie à la main) : sauvegardé tel quel, pour qu'uninstall le remette au lieu de
        # le supprimer (il peut appartenir à un paquet).
        if [[ -z "$(recorded "$target")" ]]; then
            run cp -a "$target" "$(backup_of "$target")"
            record "$target" "$(backup_of "$target")"
        fi
        return
    fi
    if [[ -z "$(recorded "$target")" ]]; then
        if [[ -e "$target" ]]; then
            run cp -a "$target" "$(backup_of "$target")"
            record "$target" "$(backup_of "$target")"
        else
            record "$target" -
        fi
    fi
    run install -D -m 644 -o root -g root "$src" "$target"
}

do_install() {
    # Prérequis : en simulation (machine neuve, conteneur), signalés sans arrêter la liste des commandes.
    command -v greetd >/dev/null || { echo "! greetd n'est pas installé (paquets : deps/arch-pacman.txt)." >&2; [[ -n "$dry" ]] || exit 1; }
    getent passwd greeter >/dev/null || { echo "! utilisateur « greeter » absent (créé par le paquet greetd)." >&2; [[ -n "$dry" ]] || exit 1; }
    [[ -z "$(git -C "$repo" status --porcelain)" ]] || echo "! modifications non committées : seule la version committée est copiée"

    # Dossiers d'état : greeter (dernier choix, caches), fond d'écran exporté par le bureau de l'utilisateur (lisible par greeter).
    run install -d -m 755 -o root -g root "$var"
    run install -d -m 700 -o greeter -g greeter "$var/greeter"
    run install -d -m 755 -o root -g root "$var/backup"
    # Fonds exportés : lisibles par greeter seul, quel que soit l'umask de la session (ACL par défaut du dossier).
    run install -d -m 750 -o "$user" -g greeter "$var/$user"
    run setfacl -m g:greeter:rx -d -m g:greeter:r "$var/$user"

    # Version committée, extraite à part : copie du dépôt lisible par greeter (ton dossier personnel ne l'est pas), remplacée d'un
    # bloc, et source des fichiers système.
    tree="$(mktemp -d)"
    trap 'rm -rf "$tree"' EXIT
    git -C "$repo" archive --format=tar HEAD | tar -x -C "$tree"
    run rm -rf "$dest.new"
    run install -d -m 755 -o root -g root "$dest.new"
    run cp -r --no-preserve=ownership "$tree/." "$dest.new/"
    run chmod -R u=rwX,go=rX "$dest.new"
    run rm -rf "$dest"
    run mv "$dest.new" "$dest"

    for entry in "${files[@]}"; do
        # shellcheck disable=SC2086
        install_file $entry
    done
    [[ -n "$dry" ]] && return
    echo "Écran de connexion installé. Le bureau y dépose son fond au prochain démarrage de Quickshell (\$mod+Ctrl+W)."
    echo "Pour le rendre actif au prochain démarrage de la machine : $0 enable"
}

do_enable() {
    [[ -d "$dest" && -d "$var" ]] || { echo "Écran de connexion pas installé : $0 install d'abord." >&2; exit 1; }
    local link=/etc/systemd/system/display-manager.service current=""
    [[ -L "$link" ]] && current="$(basename "$(readlink -f "$link")")"   # absent : aucun gestionnaire (ex. connexion en console)
    if [[ "$current" == greetd.service ]]; then
        echo "= greetd est déjà le gestionnaire de connexion"
        return
    fi
    if [[ -n "$current" ]]; then
        [[ -f "$previous_dm" ]] || run sh -c "echo '$current' > '$previous_dm'"
        run systemctl disable "$current"
    fi
    run systemctl enable greetd.service
    echo "greetd prendra la main au prochain démarrage (retour : $0 uninstall, ou docs/ROLLBACK.md)."
}

# greetd toujours désactivé (sa config va être retirée) ; l'ancien gestionnaire réactivé s'il y en avait un. Une sauvegarde
# introuvable est signalée sans arrêter le reste.
do_uninstall() {
    local greetd_enabled=""
    if systemctl is-enabled --quiet greetd.service 2>/dev/null; then
        greetd_enabled=1
        run systemctl disable greetd.service
    fi
    if [[ -f "$previous_dm" ]]; then
        run systemctl enable "$(cat "$previous_dm")"
    elif [[ -n "$greetd_enabled" ]]; then
        echo "! aucun ancien gestionnaire de connexion noté : connexion en console au prochain démarrage"
    fi
    # greetd encore en marche (session ouverte par lui) : il garde sa config en mémoire et relancerait l'écran de connexion à la
    # déconnexion. Fichiers et copie gardés jusqu'au redémarrage ; la seconde exécution les retire.
    if [[ -z "$dry" ]] && systemctl is-active --quiet greetd.service 2>/dev/null; then
        echo "Gestionnaire de connexion rebasculé. greetd tourne encore : redémarre, puis relance $0 uninstall pour finir."
        return
    fi
    local missing=""
    if [[ -f "$backups" ]]; then
        while read -r target backup <&3; do
            if [[ "$backup" == - ]]; then
                run rm -f "$target"
            elif [[ -f "$backup" ]]; then
                run mv -f "$backup" "$target"
            else
                echo "! sauvegarde $backup introuvable : $target laissé tel quel"
                missing=1
            fi
        done 3<"$backups"   # pas sur l'entrée standard : sudo la transmettrait à la commande
    fi
    run rm -rf "$dest"
    if [[ -n "$missing" ]]; then
        echo "! $var gardé : registre des sauvegardes ($backups) et ancien gestionnaire ($previous_dm)"
    else
        run rm -rf "$var"
    fi
}

[[ "${1:-}" == --dry-run ]] && { dry=1; shift; }
case "${1:-}" in
    install) do_install ;;
    enable) do_enable ;;
    uninstall) do_uninstall ;;
    *) sed -n '5,11p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
