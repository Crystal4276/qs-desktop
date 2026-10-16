pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Profils d'énergie (ta demande : trois boutons) : `PowerProfiles` de Quickshell, qui parle à power-profiles-daemon.
// Sans le démon, les boutons sont masqués : sa présence se lit à son fichier d'activation D-Bus, car `PowerProfiles` n'expose
// pas sa disponibilité (et n'est pas touché tant que le démon est absent).
Singleton {
    id: root

    readonly property bool available: daemon.loaded
    readonly property int profile: available ? PowerProfiles.profile : PowerProfile.Balanced
    readonly property bool hasPerformance: available && PowerProfiles.hasPerformanceProfile

    function set(p: int): void {
        if (available)
            PowerProfiles.profile = p;
    }

    FileView {
        id: daemon
        path: "/usr/share/dbus-1/system-services/org.freedesktop.UPower.PowerProfiles.service"
        printErrors: false
    }
}
