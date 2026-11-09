# Ajouts du dépôt au ~/.bashrc, chargés par un bloc « qs-desktop » qu'install.sh ajoute à la fin du fichier
# (le reste du ~/.bashrc, alias personnels compris, n'est pas touché). Shell interactif seulement.
[[ $- == *i* ]] || return 0
export EDITOR=geany
export BROWSER=chromium
command -v starship >/dev/null && eval "$(starship init bash)"
