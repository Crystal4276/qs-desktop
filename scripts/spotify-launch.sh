#!/usr/bin/env bash
# Spotify : client direct s'il existe, sinon lanceur des dépôts officiels Arch.
for program in spotify spotify-launcher; do
    if command -v "$program" >/dev/null 2>&1; then
        exec "$program" "$@"
    fi
done
printf '%s\n' 'Spotify : aucune commande spotify ou spotify-launcher disponible.' >&2
exit 127
