import QtQuick
import Quickshell
import qs.services

// Panneau de statistiques système : chargé à la première ouverture ; ouvert ou fermé par les modules CPU, mémoire et GPU de la barre
// et `qs ipc call monitor toggle` (Monitor.toggle).
Scope {
    LazyLoader {
        id: loader

        MonitorPanel {}
    }

    Connections {
        target: Monitor
        function onToggleRequested(from: Item) {
            loader.active = true;
            loader.item.toggle(from);
        }
    }
}
