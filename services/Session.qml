pragma Singleton

import QtQuick
import Quickshell

// Actions de session du panneau de réglages (remplacent le power menu Rofi) : verrouiller, se déconnecter,
// redémarrer, éteindre — sans confirmation, comme Rofi ; mise en veille depuis l'écran de verrouillage et l'écran de connexion. Plus la capture d'écran et « garder l'écran allumé ».
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
    // Verrouillage demandé (dès la demande, avant la confirmation du compositeur) jusqu'au déverrouillage : aucun popup à clavier
    // ne s'ouvre (il prendrait le clavier de l'écran de verrouillage, et le mot de passe tapé pour déverrouiller avec).
    property bool lockActive: false

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

    // Écran de verrouillage et écran de connexion (modules/lock/PowerRow.qml).
    function suspend(): void {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    // Outil de capture natif (Screenshot.qml), en mode zone comme ta touche Impr. ; ouvert après un court délai : le panneau qui
    // vient de se fermer ne doit pas apparaître sur l'image figée.
    function screenshot(): void {
        shotDelay.restart();
    }

    Timer {
        id: shotDelay
        interval: 300
        onTriggered: Screenshot.open("area")
    }
}
