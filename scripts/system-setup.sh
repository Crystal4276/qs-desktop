#!/usr/bin/env bash
# Réglages système de la machine, hors écran de connexion (greeter-setup.sh), sonde réseau (network-setup.sh) et OpenRGB.
# Repris par install.sh. À lancer en utilisateur : chaque commande système passe par sudo. Idempotent.
#
# Usage : system-setup.sh [--dry-run] multilib    active le dépôt [multilib] de /etc/pacman.conf (Steam, lib32) ; pas de -Sy ici
#         system-setup.sh [--dry-run] install     Samba (partages utilisateur, dotfiles/samba/smb.conf), QT_QPA_PLATFORMTHEME dans
#                                                 /etc/environment, groupes (libvirt, kvm, sambashare), services (réseau, Bluetooth,
#                                                 profils d'énergie, Samba, libvirt), réseau « default » des VM démarré au boot,
#                                                 hook pacman gardant 10_linux de GRUB désactivé (machine GRUB + UKI)
#         system-setup.sh [--dry-run] cursor      curseur du thème copié pour l'écran de connexion (/usr/local/share/icons)
#         system-setup.sh [--dry-run] chromium-extensions
#                                                 extensions de Chromium (dotfiles/chromium/extensions.txt), installées depuis le
#                                                 Chrome Web Store au démarrage du navigateur (/usr/share/chromium/extensions)
#         system-setup.sh [--dry-run] thunderbird-theme <xpi>
#                                                 thème Catppuccin de Thunderbird pour tout profil (/etc/thunderbird/policies)
#         system-setup.sh [--dry-run] uninstall   tout ce qui a été changé est remis comme avant (fichiers, groupes, services)
#         --dry-run : affiche les commandes sans rien modifier.
#         system-setup.sh [--dry-run] intel-gpu   CAP_PERFMON pour intel_gpu_top, hook de mise à jour et retrait
#         system-setup.sh [--dry-run] pacman-sudo accès pacman sans mot de passe pour wheel (paru reste lancé en utilisateur)
#         system-setup.sh [--dry-run] reflector   miroirs Arch rapides et récents, renouvelés chaque semaine
#         system-setup.sh [--dry-run] samba       partages personnels et Nemo via libvirt et ZeroTier ; UFW si actif
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
state=/var/lib/qs-desktop/system-setup
registry="$state/registry"    # une ligne par changement : file <cible> <sauvegarde|->, group <groupe>, unit <service>, net <réseau>
user="${USER:-$(id -un)}"
if [[ $EUID -eq 0 ]]; then
    # Commande ciblée également utilisable avec pkexec (une seule authentification).
    [[ -n "${PKEXEC_UID:-}" && ( "${1:-}" == samba || ( "${1:-}" == --dry-run && "${2:-}" == samba ) ) ]] || {
        echo 'À lancer en utilisateur ; seul samba accepte une exécution directe par pkexec.' >&2; exit 1;
    }
    user="$(id -un "$PKEXEC_UID")"
fi
stamp="$(date +%Y%m%d-%H%M%S)"
dry=""

as_root() {
    if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

run() {
    printf '+ %s\n' "$*"
    [[ -n "$dry" ]] || as_root "$@"
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

# Une seule transaction root : une erreur de validation ne doit pas empêcher la restauration.
do_pacman_sudo() {
    # « + » annoncé par l'étape root, après la comparaison : un second passage n'affiche que « = … à jour ».
    [[ -n "$dry" ]] && { echo "+ /etc/sudoers.d/90-qs-desktop-pacman : wheel, pacman sans mot de passe (paru compris)"; return 0; }
    sudo bash -s -- "$repo/dotfiles/sudoers/90-qs-desktop-pacman" "$state" "$stamp" <<'ROOT'
set -euo pipefail
source=$1 state=$2 stamp=$3
target=/etc/sudoers.d/90-qs-desktop-pacman
registry="$state/registry"
visudo -c
# Ne pas modifier le fichier principal ni créer une règle qui serait ignorée.
grep -Eq '^[[:space:]]*(@|#)includedir[[:space:]]+/etc/sudoers[.]d/?[[:space:]]*(#.*)?$' /etc/sudoers || {
    echo '! /etc/sudoers.d non inclus dans /etc/sudoers' >&2; exit 1;
}
[[ ! -L "$target" && ( ! -e "$target" || -f "$target" ) ]] || {
    echo "! $target : fichier ordinaire attendu" >&2; exit 1;
}
if cmp -s "$source" "$target" && [[ "$(stat -c '%a %u:%g' "$target")" == '440 0:0' ]]; then
    echo "= $target à jour"; exit 0
fi
echo "+ $target : wheel, pacman sans mot de passe (paru compris)"
staged=$(mktemp /etc/sudoers.d/.qs-desktop-pacman.XXXXXX)
previous="" replaced="" existed=""
cleanup() {
    local status=$?
    if [[ -n "$replaced" ]]; then
        if [[ -n "$existed" ]]; then mv -f "$previous" "$target"; else rm -f "$target"; fi
    fi
    rm -f "$staged" ${previous:+"$previous"}
    return "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
install -m 440 -o root -g root "$source" "$staged"
visudo -cf "$staged"
if [[ -e "$target" ]]; then
    existed=1
    previous=$(mktemp /etc/sudoers.d/.qs-desktop-pacman.XXXXXX)
    cp -p "$target" "$previous"
fi
if [[ ! -f "$registry" ]] || ! awk -v t="$target" '$1 == "file" && $2 == t { found=1 } END { exit !found }' "$registry"; then
    install -d -m 755 "$state"
    backup=-
    if [[ -n "$existed" ]]; then
        backup="$state/etc_sudoers.d_90-qs-desktop-pacman.bak-$stamp"
        cp -p "$target" "$backup"
    fi
    printf 'file %s %s\n' "$target" "$backup" >> "$registry"
fi
replaced=1
mv -f "$staged" "$target"
visudo -c
replaced=""
ROOT
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

do_samba() {
    local changed="" rules
    if command -v smbd >/dev/null; then
        # Ajouts propres à la machine (réseau local de terrier…), inclus par smb.conf : validés avec lui.
        local host_conf="dotfiles/samba/hosts/$(cat /proc/sys/kernel/hostname).conf" check
        [[ -f "$repo/$host_conf" ]] || host_conf=""
        check="$(mktemp)"
        sed "s|^\( *include = \).*/smb\.host\.conf$|\1${host_conf:+$repo/$host_conf}|" \
            "$repo/dotfiles/samba/smb.conf" >"$check"
        testparm -s "$check" >/dev/null || { rm -f "$check"; return 1; }
        rm -f "$check"
        cmp -s "$repo/dotfiles/samba/smb.conf" /etc/samba/smb.conf || changed=1
        install_file dotfiles/samba/smb.conf /etc/samba/smb.conf
        if [[ -n "$host_conf" ]]; then
            cmp -s "$repo/$host_conf" /etc/samba/smb.host.conf || changed=1
            install_file "$host_conf" /etc/samba/smb.host.conf
        fi
        local source target systemd_changed=""
        for source in dotfiles/samba/zerotier-order.conf scripts/samba-wait-zerotier.sh; do
            if [[ "$source" == *.conf ]]; then
                target=/etc/systemd/system/smb.service.d/50-qs-zerotier.conf
            else
                target=/usr/local/libexec/qs-samba-wait-zerotier
            fi
            cmp -s "$repo/$source" "$target" || systemd_changed=1
            install_file "$source" "$target"
        done
        if [[ -n "$systemd_changed" ]]; then
            run systemctl daemon-reload
            changed=1
        fi
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
        return
    fi

    # Ne pas activer un pare-feu ni modifier les règles des VM ou d'autres services.
    if command -v ufw >/dev/null && grep -qx 'ENABLED=yes' /etc/ufw/ufw.conf; then
        if [[ -n "$dry" ]]; then
            echo '+ UFW actif : autoriser TCP 445 entrant sur zt+ si la règle manque'
        else
            rules="$(as_root env LC_ALL=C ufw show added)" || return 1
            if ! grep -Eq '^ufw allow in on zt\+ to any port 445 proto tcp( comment .*)?$' <<<"$rules"; then
                run ufw allow in on zt+ to any port 445 proto tcp comment qs-desktop-samba-zerotier
                recorded ufw-samba zt+ || record ufw-samba zt+
            else
                echo '= UFW : accès SMB ZeroTier déjà autorisé'
            fi
        fi
    fi
    if ! systemctl is-enabled --quiet smb.service; then
        run systemctl enable smb.service
        recorded unit-enable smb.service || record unit-enable smb.service
    fi
    # Réessai après autorisation tardive : la config peut être identique mais l'écoute manquer.
    local address
    for address in $(ip -o -4 addr show scope global | awk '$2 ~ /^zt/ { split($4,a,"/"); print a[1] }'); do
        if ! ss -H -ltn 'sport = :445' | awk -v endpoint="$address:445" '$4 == endpoint { found=1 } END { exit !found }'; then
            changed=1
        fi
    done
    if ! systemctl is-active --quiet smb.service; then
        run systemctl start smb.service
        recorded unit-start smb.service || record unit-start smb.service
    elif [[ -n "$changed" ]]; then
        run systemctl restart smb.service
    fi
    if [[ -z "$dry" ]] && ! as_root pdbedit -L -u "$user" 2>/dev/null | grep -q "^$user:"; then
        echo "! Compte Samba absent : lancer dans un terminal : sudo smbpasswd -a $user"
    fi
    echo '= Accès Nemo : smb://<IP ZeroTier de cette machine>/'"$user"
}

do_install() {
    do_samba

    # Thème des applications Qt (Kvantum + Papirus via qt6ct) : lu à l'ouverture de session, Quickshell en hérite.
    if grep -qx 'QT_QPA_PLATFORMTHEME=qt6ct' /etc/environment 2>/dev/null; then
        echo "= QT_QPA_PLATFORMTHEME=qt6ct déjà dans /etc/environment"
    else
        backup_once /etc/environment
        # Dernière ligne sans saut de ligne : ajouté d'abord (sinon la variable se collerait à la précédente).
        run sh -c "[ ! -s /etc/environment ] || [ -z \"\$(tail -c 1 /etc/environment)\" ] || echo >> /etc/environment; echo 'QT_QPA_PLATFORMTHEME=qt6ct' >> /etc/environment"
    fi

    # GRUB + UKI (archinstall) : 10_linux désactivé, que chaque mise à jour du paquet grub réactive ; un hook pacman le
    # désactive à nouveau (dotfiles/pacman/hooks/90-qs-grub-uki.hook). Machine dans cet état seulement.
    if [[ -f /etc/grub.d/15_uki && -f /etc/grub.d/10_linux && ! -x /etc/grub.d/10_linux ]] \
        || [[ -f /etc/pacman.d/hooks/90-qs-grub-uki.hook ]]; then
        install_file dotfiles/pacman/hooks/90-qs-grub-uki.hook /etc/pacman.d/hooks/90-qs-grub-uki.hook
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

# Thème Catppuccin Mocha Green de Thunderbird (fichier de deps/themes.txt, vérifié par install.sh, qui en passe le chemin) :
# politique ExtensionSettings dans /etc/thunderbird/policies, lue par tous les profils, même créés plus tard. Thunderbird
# l'installe au démarrage depuis la copie système et en fait le thème actif ; désactivable, pas supprimable (normal_installed).
# Nom de la copie = empreinte : une nouvelle version change l'adresse, Thunderbird la réinstalle. Une politique à toi (fichier
# déjà là, pas d'install.sh) n'est jamais écrasée. Retrait : politique et copie retirées ; le thème reste dans les profils.
do_thunderbird_theme() {
    local xpi="${1:-}" dir=/usr/local/share/catppuccin-thunderbird policy=/etc/thunderbird/policies/policies.json dest tmp
    local id='{3782e2b5-f78b-54d6-9475-20d4fab2c92c}'
    command -v thunderbird >/dev/null || { echo "- thunderbird absent : thème ignoré"; return; }
    [[ -f "$xpi" ]] || { echo "! thème Thunderbird : fichier $xpi introuvable" >&2; return 1; }
    if [[ -f "$policy" ]] && ! recorded file "$policy"; then
        echo "! $policy existe déjà (politiques à toi) : gardé ; y ajouter l'entrée $id d'ExtensionSettings à la main"
        return
    fi
    dest="$dir/mocha-green-$(sha256sum < "$xpi" | cut -c1-12).xpi"
    tmp="$(mktemp)"
    printf '{\n  "policies": {\n    "ExtensionSettings": {\n      "%s": {\n        "installation_mode": "normal_installed",\n        "install_url": "file://%s"\n      }\n    }\n  }\n}\n' "$id" "$dest" > "$tmp"
    if [[ -f "$dest" ]] && cmp -s "$xpi" "$dest" && cmp -s "$tmp" "$policy"; then
        echo "= thème Thunderbird ($dest) à jour"; rm -f "$tmp"; return
    fi
    backup_once "$dir"
    run rm -rf "$dir"
    run install -D -m 644 -o root -g root "$xpi" "$dest"
    [[ -e /etc/thunderbird ]] || backup_once /etc/thunderbird     # créé ici : retiré avec la politique
    backup_once "$policy"
    run install -D -m 644 -o root -g root "$tmp" "$policy"
    rm -f "$tmp"
}

do_zerotier() {
    local id="${1:-}" dir=/var/lib/zerotier-one/networks.d ready="" output deadline
    [[ "$id" =~ ^[0-9a-f]{16}$ ]] || return 2
    if [[ -n "$dry" ]]; then
        echo "+ ZeroTier : réseau $id, service activé et démarré ; DNS et route par défaut désactivés"
        return
    fi
    command -v zerotier-cli >/dev/null || { echo '! zerotier-one absent' >&2; return 1; }
    # Ne jamais tronquer une adhésion existante ni toucher à son identité.
    if ! sudo test -e "$dir/$id.conf"; then
        run install -d -m 700 "$dir"
        printf 'allowManaged=1\nallowGlobal=0\nallowDefault=0\nallowDNS=0\n' | sudo tee "$dir/$id.local.conf" >/dev/null
        run touch "$dir/$id.conf"
    fi
    systemctl is-enabled --quiet zerotier-one.service || run systemctl enable zerotier-one.service || return 1
    systemctl is-active --quiet zerotier-one.service || run systemctl start zerotier-one.service || return 1
    deadline=$((SECONDS + 60))
    while (( SECONDS < deadline )); do
        if output="$(sudo timeout 5 zerotier-cli -j listnetworks)"; then
            ready="$(printf '%s' "$output" | python3 -c 'import json,sys; n=next((n for n in json.load(sys.stdin) if n.get("nwid",n.get("id"))==sys.argv[1]),{}); print(n.get("status","ABSENT")); print(",".join(n.get("assignedAddresses",[])))' "$id")" || return 1
            echo "ZeroTier $id : $ready"
            case "${ready%%$'\n'*}" in
                OK)
                    if [[ -n "${ready#*$'\n'}" ]] && sudo timeout 5 zerotier-cli -j info | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin).get("online") is True else 1)'; then
                        return 0
                    fi ;;
                ACCESS_DENIED|AUTHENTICATION_REQUIRED)
                    sudo timeout 5 zerotier-cli status || true
                    echo '! Autoriser ce Node ID dans ZeroTier Central (Members).'; return 3 ;;
                NOT_FOUND|PORT_ERROR|CLIENT_TOO_OLD) return 1 ;;
                ABSENT) sudo timeout 5 zerotier-cli join "$id" || true ;;
            esac
        fi
        sleep 2
    done
    echo '! ZeroTier indisponible ou configuration en attente ; adhésion conservée, nouvelle tentative native après rétablissement.'
    return 3
}

do_uninstall() {
    if [[ -x "$repo/scripts/intel-gpu-setup.sh" ]]; then
        "$repo/scripts/intel-gpu-setup.sh" ${dry:+--dry-run} uninstall || echo "! Retrait des droits GPU Intel incomplet ; poursuite des autres étapes" >&2
    fi
    [[ -f "$registry" ]] || { echo "= rien à défaire ($registry absent)"; return; }
    local kind target backup samba_changed="" systemd_changed=""
    recorded file /etc/samba/smb.conf && samba_changed=1
    recorded file /etc/samba/smb.host.conf && samba_changed=1
    recorded file /etc/systemd/system/smb.service.d/50-qs-zerotier.conf && systemd_changed=1
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
            timer-start|unit-start) run systemctl stop "$target" || true ;;
            timer-enable|unit-enable) run systemctl disable "$target" || true ;;
            ufw-samba) run ufw --force delete allow in on "$target" to any port 445 proto tcp || return 1 ;;
            net) run virsh -c qemu:///system net-autostart --disable "$target" || true ;;
        esac
    done 3< <(tac "$registry")
    [[ -z "$systemd_changed" ]] || run systemctl daemon-reload
    if [[ -n "$samba_changed" ]] && systemctl is-active --quiet smb.service; then
        run systemctl restart smb.service
    fi
    run rm -f "$registry"
    run rm -f "$state/reflector-ready"
}

[[ "${1:-}" == --dry-run ]] && { dry=1; shift; }
case "${1:-}" in
    intel-gpu) "$repo/scripts/intel-gpu-setup.sh" ${dry:+--dry-run} install ;;
    pacman-sudo) do_pacman_sudo ;;
    multilib) do_multilib ;;
    reflector) do_reflector ;;
    cursor) do_cursor ;;
    zerotier) do_zerotier "${2:-}" ;;
    samba) do_samba ;;
    install) do_install ;;
    chromium-extensions) do_chromium_extensions ;;
    thunderbird-theme) do_thunderbird_theme "${2:-}" ;;
    uninstall) do_uninstall ;;
    *) sed -n '5,19p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
