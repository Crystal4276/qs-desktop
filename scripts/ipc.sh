#!/bin/sh
# `qs ipc call` vers le bureau de cette session (instance lancée par scripts/desktop.sh, désignée par son PID) : utilisé par les
# raccourcis des configs compositeur (dotfiles/). Jamais `-c desktop` : les copies du dépôt (bancs de test) ont le même identifiant
# et pourraient recevoir l'appel. Sans instance (relance en cours, lancée à la main) : échec, et `$mod+N` retombe sur la commande
# native.
# Usage : ipc.sh <cible> <fonction> [arguments…]      code de sortie non nul si l'instance ne répond pas
pid="$("$(dirname "$(readlink -f "$0")")/desktop.sh" pid)" || exit 1
exec qs ipc --pid "$pid" call "$@"
