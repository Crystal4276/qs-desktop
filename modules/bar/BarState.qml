pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.menus

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

    // Panneau de réglages et menu d'applications : un seul exemplaire de chacun pour toutes les barres, placé sous le bouton qui
    // l'ouvre (sur son écran), chargé à la première ouverture. Ouvrir l'un sur un autre écran le déplace ; jamais deux à la fois.
    LazyLoader {
        id: settingsLoader

        SettingsPanel {}
    }

    LazyLoader {
        id: menuLoader

        AppMenu {}
    }

    // Bouton sous lequel chaque panneau est ouvert (null : fermé) : le bouton se colore tant que son panneau est ouvert.
    readonly property Item settingsButton: settingsLoader.item?.visible ? settingsLoader.item.button : null
    readonly property Item menuButton: menuLoader.item?.visible ? menuLoader.item.button : null

    // `fromPress` : appui sur le bouton (la barre a déjà fermé le panneau ouvert sous ce même bouton : il ne se rouvre pas).
    function toggleSettings(button: Item, fromPress: bool): void {
        settingsLoader.active = true;
        settingsLoader.item.toggle(button, fromPress);
    }

    function toggleMenu(button: Item, fromPress: bool): void {
        menuLoader.active = true;
        menuLoader.item.toggle(button, fromPress);
    }

    // Boutons des barres : `qs ipc call settings toggle` (`$mod+Escape`, phase 10) et `qs ipc call menu toggle` passent par celui de
    // l'écran focalisé, sinon par le premier (la barre principale en a un, hosts/*.json). Un panneau ouvert se ferme, quel que
    // soit son écran (un seul exemplaire).
    property var settingsButtons: []
    property var menuButtons: []

    function focusedButton(buttons: var): Item {
        return buttons.find(b => b.QsWindow.window?.screen?.name === Compositor.focusedOutput) ?? buttons[0] ?? null;
    }

    function registerSettings(button: Item): void {
        settingsButtons = [...settingsButtons, button];
    }

    function unregisterSettings(button: Item): void {
        settingsButtons = settingsButtons.filter(b => b !== button);
    }

    function registerMenu(button: Item): void {
        menuButtons = [...menuButtons, button];
    }

    function unregisterMenu(button: Item): void {
        menuButtons = menuButtons.filter(b => b !== button);
    }

    // Tests (scripts/test-outputs.sh) : popups inscrits et écran au clavier « à la demande », en JSON.
    IpcHandler {
        target: "bar"

        function state(): string {
            return JSON.stringify({ openPopups: root.openPopups, keyboardScreen: root.keyboardScreen });
        }
    }

    IpcHandler {
        target: "menu"

        function toggle(): void {
            const button = root.focusedButton(root.menuButtons);
            if (button)
                root.toggleMenu(button, false);
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            const button = root.focusedButton(root.settingsButtons);
            if (button)
                root.toggleSettings(button, false);
        }
    }
}
