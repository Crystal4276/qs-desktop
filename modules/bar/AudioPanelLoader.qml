import QtQuick
import Quickshell

// Panneau audio chargé seulement à sa première ouverture (LazyLoader, ARCHITECTURE § 12), pour chaque module qui l'ouvre.
LazyLoader {
    id: root

    function toggle(item: Item): void {
        active = true;
        root.item.toggle(item);
    }

    AudioPanel {}
}
