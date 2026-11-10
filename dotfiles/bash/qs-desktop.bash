# Ajouts du dépôt au ~/.bashrc, chargés par un bloc « qs-desktop » qu'install.sh ajoute à la fin du fichier
# (le reste du ~/.bashrc, alias personnels compris, n'est pas touché). Shell interactif seulement.
[[ $- == *i* ]] || return 0
# ~/.local/bin : Claude Code (script officiel, install.sh) et autres outils installés dans le compte
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
# -i : nouvelle fenêtre attendue jusqu'à sa fermeture (git commit, crontab -e), même si Geany est déjà ouvert
export EDITOR="geany -i"
export BROWSER=chromium
command -v starship >/dev/null && eval "$(starship init bash)"
