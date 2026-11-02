# Réglages du processus Quickshell, à sourcer avant de le lancer (scripts/dev.sh ; autostart en phase 10).
# Chaque valeur est mesurée sur le bureau réel : docs/PERFORMANCE.md. Aucune n'est transmise aux applications lancées depuis le
# bureau (Apps.launchEnvironment) : à tenir à jour avec cette liste.

# Allocateur de Quickshell (jemalloc, lu au démarrage du processus, pas de `pragma Env` possible) : 2 zones au lieu de 64 par défaut
# ici (4 par cœur), -100 Mo de mémoire résidente.
export MALLOC_CONF=narenas:2

# Atlas de petites images plus petit que celui par défaut : -29 Mo.
export QSG_ATLAS_WIDTH=1024
export QSG_ATLAS_HEIGHT=1024

# Rendu dans le thread principal, un seul contexte graphique pour toutes les fenêtres : -100 Mo, et ouverture d'une fenêtre en 95 ms au
# lieu de 230 ms (le rendu par fil recrée un contexte à chaque affichage).
export QSG_RENDER_LOOP=basic

# Pilote Nvidia actif : ne charge pas aussi Mesa et LLVM, inutilisés (-34 Mo). Jamais sur une autre carte.
nvidia_egl=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
if [ -e /proc/driver/nvidia/version ] && [ -e "$nvidia_egl" ]; then
    export __EGL_VENDOR_LIBRARY_FILENAMES="$nvidia_egl"
fi
unset nvidia_egl
