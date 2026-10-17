//@ pragma IconTheme Papirus-Dark
//@ pragma ShellId desktop
//@ pragma NativeTextRendering

// Point d'entrée. ShellId fixe : la config est lancée depuis le dépôt (dev) ou via
// ~/.config/quickshell/desktop, et `qs ipc` doit trouver la même instance dans les deux cas.
// NativeTextRendering : texte rendu par FreeType, comme Pango dans Waybar (mesuré en phase 2).

import Quickshell
import qs.modules.bar
import qs.modules.launcher
import qs.modules.menus
import qs.modules.notifications
import qs.modules.osd
import qs.modules.wallpaper
import qs.services

ShellRoot {
    // Services qui travaillent sans être affichés : créés dès le démarrage (un singleton ne l'est qu'à sa première lecture).
    readonly property var background: [NightLight]

    Background {}
    Bar {}
    NotificationPopups {}
    Osd {}
    Launcher {}
    Panels {}
    WallpaperPicker {}
}
