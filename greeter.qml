//@ pragma ShellId greeter
//@ pragma NativeTextRendering

// Point d'entrée de l'écran de connexion (greetd, ARCHITECTURE § 9) : lancé par dotfiles/greetd/sway.conf sous l'utilisateur
// `greeter`, depuis la copie système du dépôt (scripts/greeter-setup.sh). Mêmes config, services et modules que le bureau
// (shell.qml), seuls l'écran de connexion et les services qu'il lit sont créés.

import Quickshell
import qs.modules.greeter

ShellRoot {
    GreeterScreen {}
}
