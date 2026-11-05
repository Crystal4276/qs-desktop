#!/usr/bin/env bash
# Configuration du service fourni par le paquet ; aucun lancement par le compositeur.
# install DIR [PROFILE] : configuration validée, sans démarrer le service.
# enable : démarrer et activer ; uninstall : restaurer l'état précédant install.
# --dry-run affiche les opérations sans rien écrire. À lancer sans sudo.
set -euo pipefail
repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
state=/var/lib/qs-desktop/openrgb-setup
conf=/etc/openrgb
override=/etc/systemd/system/openrgb.service.d/qs-desktop.conf
dry=false
if [[ ${1:-} == --dry-run ]]; then dry=true; shift; fi
action=${1:-}
[[ $# -eq 0 ]] || shift
fail() { echo "$*" >&2; exit 1; }
run() {
    printf '+'; printf ' %q' "$@"; printf '\n'
    if ! "$dry"; then sudo -- "$@"; fi
}
[[ $EUID -ne 0 ]] || fail 'À lancer sans sudo : le script appelle sudo pour les opérations système.'
case "$action" in
install)
    [[ $# -ge 1 && $# -le 2 ]] || fail 'Usage : openrgb-setup.sh [--dry-run] install DIR [PROFILE]'
    src=$(realpath "$1")
    profile=${2:-purple}
    [[ $profile =~ ^[a-zA-Z0-9_-]+$ ]] || fail 'Nom de profil invalide.'
    command -v openrgb >/dev/null || fail 'Paquet openrgb requis.'
    systemctl cat openrgb.service >/dev/null || fail 'Service openrgb.service du paquet requis.'
    [[ $(systemctl is-enabled openrgb.service 2>/dev/null || true) != masked ]] || fail 'Service masqué : résoudre le masquage avant installation.'
    if systemctl is-active --quiet openrgb.service; then fail 'Arrêter explicitement le service avant de remplacer sa configuration.'; fi
    # Valider avant toute écriture privilégiée ; ne jamais copier une ancienne Configuration.json.
    python3 - "$src" "$profile" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
json.loads((root / 'OpenRGB.json').read_text())
p = json.loads((root / 'profiles' / (sys.argv[2] + '.json')).read_text())
assert p['profile_name'] == sys.argv[2], 'Nom interne du profil différent'
assert p['controllers'], 'Profil vide'
for c in p['controllers']:
    assert 0 <= c['active_mode'] < len(c['modes']), 'Mode actif invalide'
PY
    if [[ ! -d $state ]]; then
        run install -d -m 755 "$state"
        if [[ -d $conf ]]; then run cp -a "$conf" "$state/config"; fi
        if [[ -e $override ]]; then run cp -a "$override" "$state/override"; fi
        if systemctl is-enabled --quiet openrgb.service; then run touch "$state/enabled"; fi
        run touch "$state/ready"
    else
        [[ -f $state/ready ]] || fail "Sauvegarde incomplète dans $state : vérifier avant de continuer."
    fi
    if "$dry"; then
        echo "+ préparer OpenRGB.json : service_startup_profile=$profile, autostarts et profils de fermeture désactivés"
    else
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        python3 - "$src/OpenRGB.json" "$tmp/OpenRGB.json" "$profile" <<'PY'
import json, pathlib, sys
s = json.loads(pathlib.Path(sys.argv[1]).read_text())
s.setdefault('AutoStart', {})['enabled'] = False
p = s.setdefault('ProfileManager', {})
for key in ('open_profile', 'exit_profile', 'service_shutdown_profile', 'suspend_profile'):
    p[key] = {'enabled': False, 'name': ''}
p['service_startup_profile'] = {'enabled': True, 'name': sys.argv[3]}
pathlib.Path(sys.argv[2]).write_text(json.dumps(s, indent=2) + '\n')
PY
    fi
    run install -d -m 755 "$conf/profiles"
    if "$dry"; then
        echo "+ installer les réglages préparés dans $conf/OpenRGB.json"
    else
        run install -m 644 "$tmp/OpenRGB.json" "$conf/OpenRGB.json"
    fi
    run install -m 644 "$src/profiles/$profile.json" "$conf/profiles/$profile.json"
    run install -D -m 644 "$repo/dotfiles/openrgb/service.conf" "$override"
    run systemctl daemon-reload
    echo 'Configuration installée. Activation séparée : openrgb-setup.sh enable.'
    ;;
enable)
    [[ $# -eq 0 ]] || fail 'enable ne prend pas d’argument.'
    [[ -f $state/ready && -f $override ]] || fail 'Exécuter install avant enable.'
    # Une instance de test ou autonome prendrait aussi le matériel ou le port SDK.
    if ! systemctl is-active --quiet openrgb.service && pgrep -x openrgb >/dev/null; then
        fail 'Une instance OpenRGB tourne déjà : l’arrêter avant enable.'
    fi
    run systemctl enable --now openrgb.service
    ;;
uninstall)
    [[ $# -eq 0 ]] || fail 'uninstall ne prend pas d’argument.'
    [[ -f $state/ready ]] || fail 'Aucune installation sauvegardée.'
    run systemctl disable --now openrgb.service
    # Garder également les profils créés après installation, sans les perdre au retour arrière.
    if [[ -d $conf ]]; then run mv "$conf" "$conf.before-restore-$(date +%Y%m%d-%H%M%S)"; fi
    if [[ -d $state/config ]]; then run cp -a "$state/config" "$conf"; fi
    run rm -f "$override"
    if [[ -f $state/override ]]; then run cp -a "$state/override" "$override"; fi
    run systemctl daemon-reload
    if [[ -f $state/enabled ]]; then run systemctl enable openrgb.service; fi
    run rm -rf "$state"
    echo 'État système précédent restauré. Restaurer aussi les autostarts si nécessaire (docs/OPENRGB.md).'
    ;;
*) fail 'Usage : openrgb-setup.sh [--dry-run] {install DIR [PROFILE]|enable|uninstall}' ;;
esac
