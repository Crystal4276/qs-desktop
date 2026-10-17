pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Actions de session du panneau de réglages (remplacent le power menu Rofi, SCRIPTS.md) : verrouiller, se déconnecter,
// redémarrer, éteindre — sans confirmation, comme Rofi. Plus la capture d'écran et « garder l'écran allumé ».
// Capture : commande actuelle en attendant l'outil natif de la phase 8b.
Singleton {
    id: root

    // Garder l'écran allumé : IdleInhibitor des barres (Bar.qml). Gardé au rechargement, pas d'une session à l'autre.
    property alias keepAwake: persist.keepAwake

    PersistentProperties {
        id: persist
        reloadableId: "session"
        property bool keepAwake: false
    }

    // Verrouillage natif (modules/lock/LockScreen.qml, qui écoute ce signal et tient `locked` à jour) ; aussi `qs ipc call lock lock`.
    signal lockRequested
    property bool locked: false   // écran verrouillé et confirmé par le compositeur

    function lock(): void {
        lockRequested();
    }

    function logout(): void {
        Compositor.exit();
    }

    function reboot(): void {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function poweroff(): void {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    // Capture d'une zone, comme ta touche Impr. (grim + slurp, fichier dans Images/screenshot et presse-papiers).
    // Lancée après un court délai : le panneau qui vient de se fermer ne doit pas apparaître dessus.
    function screenshot(): void {
        shotDelay.restart();
    }

    // Couleur au format de slurp : RRGGBBAA.
    function rgba(c: color): string {
        return [c.r, c.g, c.b, c.a].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join("");
    }

    Timer {
        id: shotDelay
        interval: 300
        onTriggered: Quickshell.execDetached(["sh", "-c", `dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/screenshot"; mkdir -p "$dir"
            area="$(slurp -b ${root.rgba(Theme.slurpBackground)} -c ${root.rgba(Theme.slurpSelection)} -w ${Theme.slurpBorder})" || exit 0
            grim -g "$area" - | tee "$dir/$(date +%Y-%m-%d-%H%M%S).png" | wl-copy`])
    }
}
