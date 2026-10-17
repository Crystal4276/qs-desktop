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

    // Fermeture de tous les popups (ouverture d'un autre, appui sur une barre).
    signal closePopups

    // Appui sur une barre pendant qu'un popup est ouvert (Bar.qml) : tous se ferment, et l'appui continue vers le module visé.
    // `pressClosed` garde, le temps de cet appui, les popups qu'il a fermés : le bouton d'un panneau qu'il vient de fermer ne le
    // rouvre pas (OverlayPopup.beginOpen) ; un appui suivant, un raccourci ou un autre bouton l'ouvrent normalement.
    property var pressClosed: []

    function closeFromBarPress(): void {
        pressClosed = [...openList];
        closePopups();
        Qt.callLater(() => pressClosed = []);
    }

    function setPopupOpen(popup: QtObject, open: bool): void {
        const others = openList.filter(p => p !== popup);
        openList = open ? [...others, popup] : others;
    }

    // Panneaux ouverts par un bouton de barre ("menu", "settings") : un seul exemplaire de chacun pour toutes les barres, placé sous
    // le bouton qui l'ouvre (sur son écran) ; ouvrir l'un sur un autre écran le déplace. Leurs LazyLoader sont créés et inscrits par
    // modules/menus/Panels.qml : ce module n'importe pas celui des menus, qui dépend de lui.
    property var loaders: ({})
    // Boutons des barres par panneau (inscrits par SettingsButton.qml et MenuButton.qml).
    property var buttons: ({})

    function registerLoader(kind: string, loader: var): void {
        loaders = Object.assign({}, loaders, { [kind]: loader });
    }

    function register(kind: string, button: Item): void {
        buttons = Object.assign({}, buttons, { [kind]: [...(buttons[kind] ?? []), button] });
    }

    function unregister(kind: string, button: Item): void {
        buttons = Object.assign({}, buttons, { [kind]: (buttons[kind] ?? []).filter(b => b !== button) });
    }

    // Bouton sous lequel le panneau est ouvert (null : fermé) : le bouton Arch se colore tant que le menu est ouvert sous lui.
    function openedUnder(kind: string): Item {
        const item = loaders[kind]?.item;
        return item?.visible ? item.button : null;
    }

    // `fromPress` : appui sur le bouton (OverlayPopup.beginOpen) ; false pour un raccourci.
    function toggle(kind: string, button: Item, fromPress: bool): void {
        const loader = loaders[kind];
        if (!loader || !button)
            return;
        loader.active = true;
        loader.item.toggle(button, fromPress);
    }

    // Raccourcis `qs ipc call settings toggle` (`$mod+Escape`, phase 10) et `qs ipc call menu toggle` : bouton de l'écran focalisé,
    // sinon le premier (la barre principale en a un, hosts/*.json). Un panneau ouvert se ferme, quel que soit son écran.
    function toggleFromShortcut(kind: string): void {
        const list = buttons[kind] ?? [];
        toggle(kind, list.find(b => b.QsWindow.window?.screen?.name === Compositor.focusedOutput) ?? list[0] ?? null, false);
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
            root.toggleFromShortcut("menu");
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            root.toggleFromShortcut("settings");
        }
    }
}
