import QtQuick
import Quickshell
import qs.modules.bar

// Menu d'applications : un seul exemplaire pour toutes les barres, chargé à la première ouverture et piloté par BarState
// (bouton Arch, `qs ipc call menu toggle`). Créé ici, depuis shell.qml, pour que le module de la barre n'importe pas celui des
// menus, qui dépend de lui.
Scope {
    LazyLoader {
        id: loader

        AppMenu {}
    }

    Component.onCompleted: BarState.registerLoader("menu", loader)
}
