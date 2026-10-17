import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Utilitaire de changement de fond : `qs ipc call wallpaper-picker toggle|open|close`, chargé à la première ouverture.
Scope {
    LazyLoader {
        id: loader

        PickerWindow {}
    }

    // Bouton du panneau de réglages.
    Connections {
        target: Wallpapers
        function onPickerRequested() {
            loader.active = true;
            loader.item.open();
        }
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
