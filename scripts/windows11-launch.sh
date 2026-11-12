#!/usr/bin/env bash
# URI et domaine viennent de la configuration machine, via l'entrée .desktop.
set -uo pipefail
fail() {
    printf 'Windows 11 : %s\n' "$1" >&2
    notify-send -a 'Windows 11' -i dialog-error 'Windows 11' "$1" || true
    exit 1
}
[[ $# == 2 ]] || fail 'Configuration du lanceur invalide.'
uri="$1" domain="$2"
for program in virsh virt-manager flock; do
    command -v "$program" >/dev/null || fail "Commande absente : $program."
done
[[ -n "${XDG_RUNTIME_DIR:-}" ]] || fail 'Session utilisateur absente.'
# Verrou le temps du démarrage : un double clic ne lance pas la VM deux fois.
exec 9>"$XDG_RUNTIME_DIR/qs-windows11.lock"
flock -n 9 || exit 0
unset DESKTOP_STARTUP_ID XDG_ACTIVATION_TOKEN
state=$(LC_ALL=C virsh --connect "$uri" domstate --domain "$domain" 2>&1) || fail "$state"
case "$state" in
    'shut off')
        result=$(virsh --connect "$uri" start --domain "$domain" 2>&1) || fail "$result" ;;
    running|paused|'in shutdown'|pmsuspended) ;;
    *) fail "État inattendu de la VM : $state" ;;
esac
exec 9>&-
# Console de virt-manager. Instance unique : un nouveau clic réaffiche la même fenêtre, d'où le verrou rendu avant.
# Placement par les règles machine, sur le titre « <domaine> on QEMU/KVM ».
virt-manager --connect "$uri" --show-domain-console "$domain" || fail 'Impossible d’ouvrir la console de la VM.'
