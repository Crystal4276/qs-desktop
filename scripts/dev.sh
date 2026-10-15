#!/usr/bin/env bash
# (Re)lance l'instance de dev depuis le dépôt et affiche les erreurs du démarrage.
# Usage : scripts/dev.sh [stop]
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
log="${QS_DEV_LOG:-/tmp/qs-dev.log}"

# Tue l'instance de dev précédente (celle lancée depuis ce dépôt uniquement).
qs kill -p "$repo" >/dev/null 2>&1 || true

[[ "${1:-}" == "stop" ]] && exit 0

cd "$repo"
nohup qs -p . >"$log" 2>&1 &
disown

# Laisse le temps au chargement, puis montre ce qui ne va pas.
sleep 2
if ! qs list -p "$repo" >/dev/null 2>&1; then
    echo "Échec du démarrage :" >&2
    cat "$log" >&2
    exit 1
fi
grep -E "WARN|ERROR|error|Failed|failed" "$log" || echo "Démarré sans erreur (log : $log)"
