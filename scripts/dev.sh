#!/usr/bin/env bash
# Depuis la bascule (phase 10), l'instance de dev est le bureau lui-même : scripts/desktop.sh, lancé par l'autostart du compositeur.
# Usage : scripts/dev.sh          relance et affiche les erreurs du démarrage
#         scripts/dev.sh stop     arrête
#         scripts/dev.sh log      suit le journal (Ctrl+C pour quitter)
exec "$(dirname "$(readlink -f "$0")")/desktop.sh" "${1:-restart}"
