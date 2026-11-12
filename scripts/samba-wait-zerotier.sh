#!/usr/bin/env bash
# Courte attente au démarrage de smbd ; aucun processus permanent.
set -euo pipefail
systemctl is-active --quiet zerotier-one.service || exit 0
for ((attempt=0; attempt<30; attempt++)); do
    if ip -o -4 addr show scope global | awk '$2 ~ /^zt/ { found=1 } END { exit !found }'; then
        exit 0
    fi
    sleep 1
done
echo 'ZeroTier sans adresse après 30 s : Samba sert les VM ; relancer la commande samba après autorisation du réseau.' >&2
