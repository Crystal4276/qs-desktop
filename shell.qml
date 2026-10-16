//@ pragma IconTheme Papirus-Dark
//@ pragma ShellId desktop
//@ pragma NativeTextRendering

// Point d'entrée. ShellId fixe : la config est lancée depuis le dépôt (dev) ou via
// ~/.config/quickshell/desktop, et `qs ipc` doit trouver la même instance dans les deux cas.
// NativeTextRendering : texte rendu par FreeType, comme Pango dans Waybar (mesuré en phase 2).

import Quickshell
import qs.modules.bar
import qs.modules.notifications

ShellRoot {
    Bar {}
    NotificationPopups {}
}
