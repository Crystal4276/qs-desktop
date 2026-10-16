import QtQuick
import Quickshell
import Quickshell.Io

// Lanceur d'applications (remplace `rofi -show drun`, `$mod+w`) : `qs ipc call launcher toggle|open|close`.
// La fenêtre n'est chargée qu'à la première ouverture (LazyLoader, ARCHITECTURE § 12).
Scope {
    LazyLoader {
        id: loader

        LauncherWindow {}
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            loader.active = true;
            loader.item.toggle();
        }

        function open(): void {
            loader.active = true;
            loader.item.open();
        }

        function close(): void {
            loader.item?.close();
        }
    }
}
