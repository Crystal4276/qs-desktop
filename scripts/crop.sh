#!/usr/bin/env bash
# Recadre une capture sur la zone utile (ImageMagick).
# Usage : scripts/crop.sh <image> <largeur>x<hauteur>+<x>+<y> [sortie]
#   ex. scripts/crop.sh .shots/bar.png 3440x65+0+0   → .shots/bar-crop.png
# Coordonnées en pixels de l'image (physiques : ×1.5 sur un écran en scale 1.5).
set -euo pipefail

in="${1:?Usage : crop.sh <image> <géométrie> [sortie]}"
geometry="${2:?Géométrie attendue, ex. 3440x65+0+0}"
out="${3:-${in%.png}-crop.png}"

magick "$in" -crop "$geometry" +repage "$out"
echo "$out"
