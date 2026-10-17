import QtQuick
import Quickshell
import Quickshell.Io

// Utilitaire de changement de fond : `qs ipc call wallpaper-picker toggle|open|close`, chargé à la première ouverture.
Scope {
    LazyLoader {
        id: loader

        PickerWindow {}
    }

    IpcHandler {
        target: "wallpaper-picker"

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
