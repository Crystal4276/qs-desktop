import QtQuick
import Quickshell
import qs.modules.bar

// Panneaux ouverts par un bouton de barre : un seul exemplaire de chacun pour toutes les barres, chargé à la première ouverture,
// inscrit dans BarState qui le pilote (boutons, raccourcis `qs ipc call menu|settings toggle`). Créés ici, depuis shell.qml, pour
// que le module de la barre n'importe pas celui des menus, qui dépend de lui.
Scope {
    LazyLoader {
        id: menu

        AppMenu {}
    }

    LazyLoader {
        id: settings

        SettingsPanel {}
    }

    Component.onCompleted: {
        BarState.registerLoader("menu", menu);
        BarState.registerLoader("settings", settings);
    }
}
