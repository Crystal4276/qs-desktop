#!/usr/bin/env bash
# Capture d'écran dans .shots/ (ignoré par git).
# Usage : scripts/shot.sh <nom> [sortie | "x,y wxh"]
#   sans 2e argument : tous les écrans ; une sortie (ex. DP-2) ; ou une géométrie logique grim.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
name="${1:?Usage : shot.sh <nom> [sortie|géométrie]}"
target="${2:-}"
out="$repo/.shots/$name.png"
mkdir -p "$repo/.shots"

if [[ -z "$target" ]]; then
    grim "$out"
elif [[ "$target" == *,* ]]; then
    grim -g "$target" "$out"
else
    grim -o "$target" "$out"
fi
echo "$out"
