//@ pragma IconTheme Papirus-Dark
//@ pragma ShellId desktop
//@ pragma NativeTextRendering

// Point d'entrée. ShellId fixe : la config est lancée depuis le dépôt (dev) ou via
// ~/.config/quickshell/desktop, et `qs ipc` doit trouver la même instance dans les deux cas.
// NativeTextRendering : texte rendu par FreeType, comme Pango dans Waybar (mesuré en phase 2).

import Quickshell
import qs.modules.bar
import qs.modules.launcher
import qs.modules.lock
import qs.modules.menus
import qs.modules.monitor
import qs.modules.notifications
import qs.modules.osd
import qs.modules.polkit
import qs.modules.screenshot
import qs.modules.wallpaper
import qs.services

ShellRoot {
    // Services qui travaillent sans être affichés : créés dès le démarrage (un singleton ne l'est qu'à sa première lecture).
    // Apps : applications lues et filtrées avant la première ouverture du menu ou du lanceur. Audio : « ne pas déranger ».
    // Disks : montage automatique et notifications, même sans tray (config machine, aucun écran actif). Displays : `$mod+d` avant la
    // première ouverture du panneau de réglages.
    readonly property var background: [NightLight, Idle, Lid, Apps, Audio, Disks, Displays]

    Background {}
    Bar {}
    NotificationPopups {}
    Osd {}
    Launcher {}
    Panels {}
    WallpaperPicker {}
    LockScreen {}
    PolkitDialog {}
    ScreenshotTool {}
    SystemMonitor {}
}
