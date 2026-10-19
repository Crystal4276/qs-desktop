#!/usr/bin/env bash
# (Re)lance l'instance de dev depuis le dépôt et affiche les erreurs du démarrage.
# Usage : scripts/dev.sh          relance
#         scripts/dev.sh stop     arrête
#         scripts/dev.sh log      suit le journal (Ctrl+C pour quitter)
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
log="${QS_DEV_LOG:-/tmp/qs-dev.log}"

case "${1:-}" in
    log) exec qs log -f -p "$repo" ;;
esac

# Tue les instances de dev précédentes (celles lancées depuis ce dépôt uniquement) : `qs kill` n'en arrête qu'une par appel.
for _ in {1..10}; do
    qs list -p "$repo" >/dev/null 2>&1 || break
    qs kill -p "$repo" >/dev/null 2>&1 || true
    sleep 0.3
done

[[ "${1:-}" == "stop" ]] && exit 0

cd "$repo"
nohup qs -p . >"$log" 2>&1 &
disown

# Laisse le temps au chargement, puis montre ce qui ne va pas.
# Le journal de l'instance (`qs log`) est à jour, contrairement à $log qui est écrit par blocs.
sleep 2
if ! qs list -p "$repo" >/dev/null 2>&1; then
    echo "Échec du démarrage :" >&2
    cat "$log" >&2
    exit 1
fi
qs log -p "$repo" | grep -E "WARN|ERROR" || echo "Démarré sans erreur."
# Avertissement attendu à chaque démarrage sous Sway, sans effet : « I3 event socket disconnected. »
