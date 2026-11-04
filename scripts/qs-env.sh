# Réglages du processus Quickshell, à sourcer avant de le lancer (scripts/dev.sh ; autostart en phase 10).
# Chaque valeur est mesurée sur le bureau réel : docs/PERFORMANCE.md. Une valeur déjà présente dans l'environnement l'emporte
# (scripts/perf.sh ab). Aucune n'est transmise aux applications lancées depuis le bureau (Launch.environment) : à tenir à jour
# avec cette liste.

# Allocateur de Quickshell (jemalloc, lu au démarrage du processus, pas de `pragma Env` possible) : 2 zones au lieu de 64 par défaut
# ici (4 par cœur), -100 Mo de mémoire résidente.
export MALLOC_CONF="${MALLOC_CONF-narenas:2}"

# Atlas de petites images plus petit que celui par défaut : -29 Mo.
export QSG_ATLAS_WIDTH="${QSG_ATLAS_WIDTH-1024}"
export QSG_ATLAS_HEIGHT="${QSG_ATLAS_HEIGHT-1024}"

# Vrai si toutes les cartes graphiques (au moins une) sont Nvidia. Aussi pour le Sway de l'écran de connexion (scripts/greeter.sh).
qs_nvidia_only() {
    qs_card=
    for qs_driver in /sys/class/drm/card?/device/driver; do
        case "$(readlink -f "$qs_driver")" in
            */nvidia) qs_card=1 ;;
            *) unset qs_card qs_driver; return 1 ;;
        esac
    done
    unset qs_driver
    [ -n "$qs_card" ] && unset qs_card
}

# Nvidia seule carte de la machine : ne charge pas aussi Mesa et LLVM, inutilisés (-34 Mo). Jamais à côté d'une autre carte (laptop
# hybride) : le compositeur peut tourner dessus, et Quickshell n'aurait plus le bon pilote.
nvidia_egl=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
if qs_nvidia_only && [ -e "$nvidia_egl" ]; then
    export __EGL_VENDOR_LIBRARY_FILENAMES="${__EGL_VENDOR_LIBRARY_FILENAMES-$nvidia_egl}"
fi
unset nvidia_egl
