#!/usr/bin/env bash
# Réglages système de la machine, hors écran de connexion (greeter-setup.sh), sonde réseau (network-setup.sh) et OpenRGB.
# Repris par install.sh. À lancer en utilisateur : chaque commande système passe par sudo. Idempotent.
#
# Usage : system-setup.sh [--dry-run] multilib    active le dépôt [multilib] de /etc/pacman.conf (Steam, lib32) ; pas de -Sy ici
#         system-setup.sh [--dry-run] install     Samba (partages utilisateur, dotfiles/samba/smb.conf), QT_QPA_PLATFORMTHEME dans
#                                                 /etc/environment, groupes (libvirt, kvm, sambashare), services (réseau, Bluetooth,
#                                                 profils d'énergie, Samba, libvirt), réseau « default » des VM démarré au boot
#         system-setup.sh [--dry-run] uninstall   tout ce qui a été changé est remis comme avant (fichiers, groupes, services)
#         --dry-run : affiche les commandes sans rien modifier.
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
state=/var/lib/qs-desktop/system-setup
registry="$state/registry"    # une ligne par changement : file <cible> <sauvegarde|->, group <groupe>, unit <service>, net <réseau>
[[ $EUID -ne 0 ]] || { echo "À lancer en utilisateur, sans sudo (sudo est appelé pour chaque commande)." >&2; exit 1; }
user="$USER"
stamp="$(date +%Y%m%d-%H%M%S)"
dry=""

run() {
    printf '+ %s\n' "$*"
    [[ -n "$dry" ]] || sudo "$@"
}

recorded() {    # $1 = genre, $2 = cible : ligne déjà notée ?
    [[ -f "$registry" ]] && awk -v k="$1" -v t="$2" '$1 == k && $2 == t { found = 1 } END { exit !found }' "$registry"
}

record() {
    run install -d -m 755 "$state"
    run sh -c "echo '$*' >> '$registry'"
}

# Avant de modifier un fichier système : copie d'origine dans $state (« - » s'il n'existait pas), une seule fois.
backup_once() {
    local target="$1" backup
    recorded file "$target" && return
    if [[ -e "$target" ]]; then
        backup="$state/$(echo "${target#/}" | tr / _).bak-$stamp"
        run install -d -m 755 "$state"
        run cp -a "$target" "$backup"
        record file "$target" "$backup"
    else
        record file "$target" -
    fi
}

do_multilib() {
    local conf=/etc/pacman.conf
    if grep -q '^\[multilib\]' "$conf"; then
        echo "= [multilib] déjà actif dans $conf"
        return
    fi
    grep -q '^#\[multilib\]' "$conf" || { echo "! section [multilib] introuvable dans $conf : à ajouter à la main" >&2; exit 1; }
    backup_once "$conf"
    # La section commentée du fichier d'Arch : « #[multilib] » puis « #Include = … » sur la ligne suivante.
    run sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' "$conf"
}

install_file() {    # $1 = fichier du dépôt, $2 = cible
    if [[ -f "$2" ]] && cmp -s "$repo/$1" "$2"; then
        echo "= $2 à jour"
        return
    fi
    backup_once "$2"
    run install -D -m 644 -o root -g root "$repo/$1" "$2"
}

add_group() {
    getent group "$1" >/dev/null || run groupadd -r "$1"
    if id -nG "$user" | tr ' ' '\n' | grep -qx "$1"; then
        echo "= $user déjà dans le groupe $1"
        return
    fi
    run usermod -aG "$1" "$user"
    record group "$1"
}

enable_unit() {
    systemctl cat "$1" >/dev/null 2>&1 || { echo "- $1 absent (paquet non installé) : ignoré"; return; }
    if systemctl is-enabled --quiet "$1" 2>/dev/null; then
        echo "= $1 déjà activé"
        return
    fi
    run systemctl enable --now "$1"
    record unit "$1"
}

# Lecture de l'état libvirt du système : sudo (le groupe libvirt n'est effectif qu'après reconnexion), sauf en simulation.
virsh_sys() {
    if [[ -n "$dry" ]]; then virsh -c qemu:///system "$@"; else sudo virsh -c qemu:///system "$@"; fi
}

do_install() {
    if command -v smbd >/dev/null; then
        install_file dotfiles/samba/smb.conf /etc/samba/smb.conf
        add_group sambashare
        # Dossier des partages utilisateur (Arch wiki, Samba « usershares ») : écrit par les membres du groupe, sticky.
        if [[ "$(stat -c '%a %G' /var/lib/samba/usershares 2>/dev/null)" == "1770 sambashare" ]]; then
            echo "= /var/lib/samba/usershares prêt"
        else
            [[ -d /var/lib/samba/usershares ]] || record file /var/lib/samba/usershares -
            run install -d -m 1770 -o root -g sambashare /var/lib/samba/usershares
        fi
    else
        echo "- samba absent : partages ignorés (deps/apps.txt)"
    fi

    # Thème des applications Qt (Kvantum + Papirus via qt6ct) : lu à l'ouverture de session, Quickshell en hérite.
    if grep -qx 'QT_QPA_PLATFORMTHEME=qt6ct' /etc/environment 2>/dev/null; then
        echo "= QT_QPA_PLATFORMTHEME=qt6ct déjà dans /etc/environment"
    else
        backup_once /etc/environment
        run sh -c "echo 'QT_QPA_PLATFORMTHEME=qt6ct' >> /etc/environment"
    fi

    # Curseur du thème pour l'écran de connexion (l'utilisateur greeter ne lit pas le compte) : copie de celui installé par
    # install.sh dans le compte, si aucun paquet ne le fournit.
    local cursor=catppuccin-mocha-green-cursors home_cursor="${XDG_DATA_HOME:-$HOME/.local/share}/icons/catppuccin-mocha-green-cursors"
    if [[ -d "/usr/share/icons/$cursor" ]]; then
        echo "= curseur $cursor fourni par un paquet"
    elif [[ -d "$home_cursor" ]]; then
        if diff -rq "$home_cursor" "/usr/local/share/icons/$cursor" >/dev/null 2>&1; then
            echo "= /usr/local/share/icons/$cursor à jour"
        else
            recorded file "/usr/local/share/icons/$cursor" || record file "/usr/local/share/icons/$cursor" -
            run rm -rf "/usr/local/share/icons/$cursor"
            run install -d -m 755 /usr/local/share/icons
            run cp -r --no-preserve=ownership "$home_cursor" "/usr/local/share/icons/$cursor"
            run chmod -R u=rwX,go=rX "/usr/local/share/icons/$cursor"
        fi
    fi

    getent group libvirt >/dev/null && add_group libvirt
    getent group kvm >/dev/null && add_group kvm
    for unit in NetworkManager.service bluetooth.service power-profiles-daemon.service smb.service libvirtd.service; do
        enable_unit "$unit"
    done
    # Réseau NAT des VM (fourni par libvirt) démarré au boot, comme ici.
    if command -v virsh >/dev/null; then
        # libvirtd vient peut-être d'être démarré : quelques secondes avant qu'il réponde.
        local tries=0
        if [[ -z "$dry" ]]; then
            until virsh_sys net-info default >/dev/null 2>&1 || (( ++tries >= 10 )); do sleep 1; done
        fi
        if virsh_sys net-info default 2>/dev/null | grep -q '^Autostart: *yes'; then
            echo "= réseau libvirt « default » déjà démarré au boot"
        elif virsh_sys net-info default >/dev/null 2>&1; then
            run virsh -c qemu:///system net-autostart default
            run virsh -c qemu:///system net-start default || true
            record net default
        fi
    fi
    [[ -n "$dry" ]] && return
    echo "Groupes ajoutés : effectifs à la prochaine connexion. Mot de passe Samba (demandé par Windows) : sudo smbpasswd -a $user"
}

do_uninstall() {
    [[ -f "$registry" ]] || { echo "= rien à défaire ($registry absent)"; return; }
    local kind target backup
    # Ordre inverse de l'installation.
    while read -r kind target backup <&3; do
        case "$kind" in
            file)
                if [[ "$backup" == - ]]; then run rm -rf "$target"
                elif [[ -e "$backup" ]]; then run mv -f "$backup" "$target"
                else echo "! sauvegarde $backup introuvable : $target laissé tel quel"; fi ;;
            group) run gpasswd -d "$user" "$target" || true ;;
            unit) run systemctl disable "$target" || true ;;
            net) run virsh -c qemu:///system net-autostart --disable "$target" || true ;;
        esac
    done 3< <(tac "$registry")
    run rm -f "$registry"
}

[[ "${1:-}" == --dry-run ]] && { dry=1; shift; }
case "${1:-}" in
    multilib) do_multilib ;;
    install) do_install ;;
    uninstall) do_uninstall ;;
    *) sed -n '5,12p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
