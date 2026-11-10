#!/usr/bin/env bash
# Profil de cette machine (`jeux` ou `travail`) : clé « profile » de hosts/default.json, puis hosts/<hostname>.json par-dessus
# (comme config/Settings.qml). Lu par Sway (include profiles/<profil>.conf), Hyprland (lua/profile.lua) et install.sh.
# Valeur absente, inconnue ou illisible : travail.
repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
profile="$(python3 -I - "$repo/hosts/default.json" "$repo/hosts/$(cat /proc/sys/kernel/hostname).json" 2>/dev/null <<'EOF'
import json, sys
value = ""
for path in sys.argv[1:]:
    try:
        value = json.load(open(path)).get("profile", value)
    except (OSError, ValueError, AttributeError):
        pass
print(value)
EOF
)"
case "$profile" in
    jeux|travail) echo "$profile" ;;
    *) echo travail ;;
esac
