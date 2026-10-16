pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// État partagé entre les barres de tous les écrans : popups ouverts depuis la barre (calendrier, menus du tray, panneaux).
Singleton {
    id: root

    // Popups ouverts : chacun s'inscrit à l'ouverture et se retire à la fermeture ou à sa destruction (écran retiré pendant
    // qu'il était ouvert) — une liste plutôt qu'un compteur, pour qu'aucun popup disparu ne reste compté.
    property var openList: []
    readonly property int openPopups: openList.length
    // Écran dont la barre accepte le clavier « à la demande » ("" : aucune) : celle de l'horloge survolée ou du calendrier épinglé.
    property string keyboardScreen: ""

    // Appui sur une barre pendant qu'un popup est ouvert : tous se ferment, et le clic continue vers le module visé.
    signal closePopups

    function setPopupOpen(popup: QtObject, open: bool): void {
        const others = openList.filter(p => p !== popup);
        openList = open ? [...others, popup] : others;
    }

    // Boutons des réglages des barres (SettingsButton.qml) : `qs ipc call settings toggle` (`$mod+Escape`, phase 10) ouvre le
    // panneau sous celui de l'écran focalisé, sinon sous le premier (la barre principale en a un, hosts/*.json).
    property var settingsButtons: []

    function registerSettings(button: Item): void {
        settingsButtons = [...settingsButtons, button];
    }

    function unregisterSettings(button: Item): void {
        settingsButtons = settingsButtons.filter(b => b !== button);
    }

    // Tests (scripts/test-outputs.sh) : popups inscrits et écran au clavier « à la demande », en JSON.
    IpcHandler {
        target: "bar"

        function state(): string {
            return JSON.stringify({ openPopups: root.openPopups, keyboardScreen: root.keyboardScreen });
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            const buttons = root.settingsButtons;
            const button = buttons.find(b => b.QsWindow.window?.screen?.name === Compositor.focusedOutput) ?? buttons[0];
            button?.toggle();
        }
    }
}
