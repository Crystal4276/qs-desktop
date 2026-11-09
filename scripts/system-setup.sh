#!/usr/bin/env bash
# Réglages système de la machine, hors écran de connexion (greeter-setup.sh), sonde réseau (network-setup.sh) et OpenRGB.
# Repris par install.sh. À lancer en utilisateur : chaque commande système passe par sudo. Idempotent.
#
# Usage : system-setup.sh [--dry-run] multilib    active le dépôt [multilib] de /etc/pacman.conf (Steam, lib32) ; pas de -Sy ici
#         system-setup.sh [--dry-run] install     Samba (partages utilisateur, dotfiles/samba/smb.conf), QT_QPA_PLATFORMTHEME dans
#                                                 /etc/environment, groupes (libvirt, kvm, sambashare), services (réseau, Bluetooth,
#                                                 profils d'énergie, Samba, libvirt), réseau « default » des VM démarré au boot
#         system-setup.sh [--dry-run] cursor      curseur du thème copié pour l'écran de connexion (/usr/local/share/icons)
#         system-setup.sh [--dry-run] chromium-extensions
#                                                 extensions de Chromium (dotfiles/chromium/extensions.txt), installées depuis le
#                                                 Chrome Web Store au démarrage du navigateur (/usr/share/chromium/extensions)
#         system-setup.sh [--dry-run] uninstall   tout ce qui a été changé est remis comme avant (fichiers, groupes, services)
#         --dry-run : affiche les commandes sans rien modifier.
#         system-setup.sh [--dry-run] reflector   miroirs Arch rapides et récents, renouvelés chaque semaine
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
state=/var/lib/qs-desktop/system-setup
registry="$state/registry"    # une ligne par changement : file <cible> <sauvegarde|->, group <groupe>, unit <service>, net <réseau>
[[ $EUID -ne 0 ]] || { echo "À lancer en utilisateur, sans sudo (sudo est appelé pour chaque commande)." >&2; exit 1; }
user="${USER:-$(id -un)}"
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

do_reflector() {
    grep -qxE 'ID="?arch"?' /etc/os-release || { echo "- Reflector réservé à Arch Linux"; return; }
    local conf=/etc/xdg/reflector/reflector.conf mirrors=/etc/pacman.d/mirrorlist
    local ready="$state/reflector-ready" fingerprint saved existed changed=""
    if [[ -z "$dry" ]] && ! command -v reflector >/dev/null; then
        echo "! paquet reflector absent" >&2; return 1
    fi
    cmp -s "$repo/dotfiles/reflector/reflector.conf" "$conf" || changed=1
    install_file dotfiles/reflector/reflector.conf "$conf"
    fingerprint="$(sha256sum < "$repo/dotfiles/reflector/reflector.conf")"
    if [[ -n "$changed" || "$(cat "$ready" 2>/dev/null)" != "$fingerprint" ]] || ! grep -q '^Server = https://' "$mirrors"; then
        backup_once "$mirrors"
        run rm -f "$ready"   # une tentative échouée doit être retentée même après une ancienne réussite
        if [[ -n "$dry" ]]; then
            run systemctl start reflector.service
            echo "+ validation de $mirrors et enregistrement de l'initialisation"
        else
            # Copie du dernier état utilisable, distincte de la sauvegarde d'origine pour le retrait.
            saved="$(mktemp)"
            existed=""
            if [[ -e "$mirrors" ]]; then
                existed=1
                if ! cp "$mirrors" "$saved"; then rm -f "$saved"; return 1; fi
            else
                run install -D -m 644 /dev/null "$mirrors"
            fi
            if run systemctl start reflector.service && grep -q '^Server = https://' "$mirrors"; then
                run install -d -m 755 "$state"
                printf '%s\n' "$fingerprint" | sudo tee "$ready" >/dev/null
                rm -f "$saved"
            else
                if [[ -n "$existed" ]]; then run cp "$saved" "$mirrors"; else run rm -f "$mirrors"; fi
                rm -f "$saved"
                echo "! Reflector a échoué : liste précédente restaurée" >&2
                return 1
            fi
        fi
    else
        echo "= miroirs initialisés ; renouvellement assuré par reflector.timer"
    fi
    # Activation et activité suivies séparément : retrait fidèle même si le timer était déjà activé mais arrêté.
    if ! systemctl is-enabled --quiet reflector.timer; then
        run systemctl enable reflector.timer
        recorded timer-enable reflector.timer || record timer-enable reflector.timer
    fi
    if ! systemctl is-active --quiet reflector.timer; then
        run systemctl start reflector.timer
        recorded timer-start reflector.timer || record timer-start reflector.timer
    fi
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
    # Sortie en anglais (« Autostart: yes ») quelle que soit la langue de la session.
    if [[ -n "$dry" ]]; then LC_ALL=C virsh -c qemu:///system "$@"; else sudo LC_ALL=C virsh -c qemu:///system "$@"; fi
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
        # Dernière ligne sans saut de ligne : ajouté d'abord (sinon la variable se collerait à la précédente).
        run sh -c "[ ! -s /etc/environment ] || [ -z \"\$(tail -c 1 /etc/environment)\" ] || echo >> /etc/environment; echo 'QT_QPA_PLATFORMTHEME=qt6ct' >> /etc/environment"
    fi

    getent group libvirt >/dev/null && add_group libvirt
    getent group kvm >/dev/null && add_group kvm
    # NetworkManager (module réseau du bureau) : jamais à côté d'un autre gestionnaire de réseau déjà actif.
    local u
    # Chaque autre gestionnaire actif (iwd compris : NetworkManager utilise wpa_supplicant) est désactivé, pas désinstallé, et
    # NetworkManager prend la main **au prochain démarrage** : la connexion de l'installation n'est pas coupée. Les réseaux
    # Wi-Fi enregistrés ailleurs (iwd…) ne sont pas repris. Retrait : réactivé. Cas absent avec archinstall + NetworkManager.
    local switched="" nm_iwd=""
    # NetworkManager absent (paquet non installé) : rien n'est désactivé, la machine garderait sinon aucun réseau au démarrage.
    if ! systemctl cat NetworkManager.service >/dev/null 2>&1; then
        echo "! NetworkManager absent (paquet networkmanager) : gestionnaire de réseau actuel gardé"
    else
    # NetworkManager réglé sur iwd pour le Wi-Fi (archinstall : « NetworkManager (iwd backend) ») : iwd est alors son moteur,
    # gardé actif.
    grep -Eqs '^[[:space:]]*wifi\.backend[[:space:]]*=[[:space:]]*iwd' /etc/NetworkManager/NetworkManager.conf \
        /etc/NetworkManager/conf.d/*.conf /usr/lib/NetworkManager/conf.d/*.conf && nm_iwd=1
    for u in systemd-networkd.service iwd.service dhcpcd.service connman.service netctl.service; do
        systemctl is-enabled --quiet "$u" 2>/dev/null || continue
        [[ "$u" == iwd.service && -n "$nm_iwd" ]] && { echo "= iwd gardé : moteur Wi-Fi de NetworkManager (wifi.backend=iwd)"; continue; }
        run systemctl disable "$u"
        record unit-off "$u"
        switched+="$u "
    done
    if [[ -n "$switched" ]] && ! systemctl is-enabled --quiet NetworkManager.service 2>/dev/null; then
        run systemctl enable NetworkManager.service
        record unit NetworkManager.service
        echo "! réseau : ${switched}désactivé(s), NetworkManager au prochain démarrage ; Wi-Fi à reconnecter (nmtui ou le bureau)"
    else
        enable_unit NetworkManager.service
    fi
    fi
    local libvirt_new=""
    systemctl is-enabled --quiet libvirtd.service 2>/dev/null || libvirt_new=1
    for unit in bluetooth.service power-profiles-daemon.service smb.service libvirtd.service; do
        enable_unit "$unit"
    done
    # Réseau NAT des VM (fourni par libvirt) démarré au boot, comme ici.
    if [[ -n "$dry" ]]; then
        command -v virsh >/dev/null && echo "+ virsh -c qemu:///system net-autostart default (si le réseau n'est pas déjà démarré au boot)"
    elif command -v virsh >/dev/null; then
        # Une seule lecture, réessayée : libvirtd démarré à l'instant met quelques secondes à répondre, et celui déjà là s'arrête
        # seul après 2 min sans client (--timeout 120 d'Arch) : un appel tombé pendant cet arrêt échoue, le suivant le relance.
        local tries=0 max=3 info=""
        [[ -n "$libvirt_new" ]] && max=10
        until info="$(virsh_sys net-info default 2>/dev/null)" || (( ++tries >= max )); do sleep 1; done
        if grep -q '^Autostart: *yes' <<<"$info"; then
            echo "= réseau libvirt « default » déjà démarré au boot"
        elif [[ -n "$info" ]]; then
            run virsh -c qemu:///system net-autostart default
            run virsh -c qemu:///system net-start default || true
            recorded net default || record net default
        fi
    fi
    [[ -n "$dry" ]] && return
    echo "Groupes ajoutés : effectifs à la prochaine connexion. Mot de passe Samba (demandé par Windows) : sudo smbpasswd -a $user"
}

# Curseur du thème pour l'écran de connexion (l'utilisateur greeter ne lit pas le compte) : copie de celui installé par
# install.sh dans le compte, si aucun paquet ne le fournit. Appelé avec l'étape du greeter.
do_cursor() {
    local cursor=catppuccin-mocha-green-cursors home_cursor="${XDG_DATA_HOME:-$HOME/.local/share}/icons/catppuccin-mocha-green-cursors"
    if [[ -d "/usr/share/icons/$cursor" ]]; then
        echo "= curseur $cursor fourni par un paquet"
    elif [[ -d "$home_cursor" ]]; then
        if diff -rq "$home_cursor" "/usr/local/share/icons/$cursor" >/dev/null 2>&1; then
            echo "= /usr/local/share/icons/$cursor à jour"
        else
            backup_once "/usr/local/share/icons/$cursor"   # dossier déjà là (posé à la main) : sauvegardé, remis au retrait
            run rm -rf "/usr/local/share/icons/$cursor"
            run install -d -m 755 /usr/local/share/icons
            run cp -r --no-preserve=ownership "$home_cursor" "/usr/local/share/icons/$cursor"
            run chmod -R u=rwX,go=rX "/usr/local/share/icons/$cursor"
        fi
    fi

}

# Extensions du navigateur (dotfiles/chromium/extensions.txt) : Chromium installe depuis le Chrome Web Store, à son démarrage,
# chaque extension décrite dans /usr/share/chromium/extensions/<identifiant>.json (extensions externes ; sous Linux, activées
# sans question). Valable pour tous les profils : install.sh les refuse dans ceux des web apps. Retirées par l'utilisateur :
# jamais réinstallées ; fichier retiré (--uninstall) : extension désinstallée au démarrage suivant.
do_chromium_extensions() {
    local id
    command -v chromium >/dev/null || { echo "- chromium absent : extensions ignorées"; return; }
    for id in $(grep -oE '^[a-p]{32}' "$repo/dotfiles/chromium/extensions.txt"); do
        install_file dotfiles/chromium/external-extension.json "/usr/share/chromium/extensions/$id.json"
    done
}

do_uninstall() {
    [[ -f "$registry" ]] || { echo "= rien à défaire ($registry absent)"; return; }
    local kind target backup
    # Ordre inverse de l'installation.
    while read -r kind target backup <&3; do
        case "$kind" in
            file)
                # multilib gardé : les paquets lib32 / Steam installés restent (install.sh --uninstall garde les paquets).
                if [[ "$target" == /etc/pacman.conf ]]; then echo "= [multilib] gardé (paquets installés conservés) ; origine : $backup"
                elif [[ "$backup" == - ]]; then run rm -rf "$target"
                elif [[ -e "$backup" ]]; then run rm -rf "$target"; run mv -f "$backup" "$target"
                else echo "! sauvegarde $backup introuvable : $target laissé tel quel"; fi ;;
            group) run gpasswd -d "$user" "$target" || true ;;
            unit) run systemctl disable "$target" || true ;;
            unit-off) run systemctl enable "$target" || true ;;
            timer-start) run systemctl stop "$target" || true ;;
            timer-enable) run systemctl disable "$target" || true ;;
            net) run virsh -c qemu:///system net-autostart --disable "$target" || true ;;
        esac
    done 3< <(tac "$registry")
    run rm -f "$registry"
    run rm -f "$state/reflector-ready"
}

[[ "${1:-}" == --dry-run ]] && { dry=1; shift; }
case "${1:-}" in
    multilib) do_multilib ;;
    reflector) do_reflector ;;
    cursor) do_cursor ;;
    install) do_install ;;
    chromium-extensions) do_chromium_extensions ;;
    uninstall) do_uninstall ;;
    *) sed -n '5,15p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
