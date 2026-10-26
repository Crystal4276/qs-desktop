pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
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

    // Un popup inscrit est épinglé, sauf l'aperçu d'une carte du tray (`previewing` vrai, Panel.qml) : pas d'aperçu par-dessus.
    readonly property bool popupPinned: openList.some(p => p.previewing !== true)
    // Bouton du tray (TrayButton.qml) ou engrenage (SettingsButton.qml) sous le pointeur : un aperçu reste ouvert tant que le
    // pointeur est sur l'un d'eux, jusqu'à ce que l'aperçu du bouton survolé le remplace.
    property Item hoveredTrayButton: null

    function setTrayHover(button: Item, hovered: bool): void {
        if (hovered)
            hoveredTrayButton = button;
        else if (hoveredTrayButton === button)
            hoveredTrayButton = null;
    }

    // Fermeture des popups (ouverture d'un autre, appui sur une barre), sauf ceux de `keep`.
    signal closePopups(var keep)

    // Appui sur une barre, popup ouvert (Bar.qml) : les popups se ferment, sauf celui dont le bouton (`owner`) est sous l'appui et
    // gère ce bouton de souris (`ownerButtons`) : ce bouton le ferme lui-même. L'appui continue vers le module visé.
    function closeFromBarPress(area: Item, x: real, y: real, button: int): void {
        closePopups(openList.filter(p => p.owner && (p.ownerButtons & button) && p.owner.QsWindow.window === area.QsWindow.window
            && p.owner.contains(p.owner.mapFromItem(area, x, y))));
    }

    function setPopupOpen(popup: QtObject, open: bool): void {
        const others = openList.filter(p => p !== popup);
        openList = open ? [...others, popup] : others;
    }

    // Panneaux ouverts par un bouton de barre ("menu", "settings") : un exemplaire de chacun, placé sous le bouton qui l'ouvre ;
    // LazyLoader inscrits par modules/menus/Panels.qml (ce module n'importe pas celui des menus).
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

    // Bord gauche d'un panneau de largeur `width` voulu en `x`, gardé dans les marges de la barre d'une fenêtre de `available` px.
    function panelLeft(x: real, width: real, available: real): real {
        return Math.max(Theme.bar.marginSide, Math.min(x, available - Theme.bar.marginSide - width));
    }

    function toggle(kind: string, button: Item): void {
        const loader = loaders[kind];
        if (!loader || !button)
            return;
        loader.active = true;
        // Bouton à aperçu (engrenage : panneau Panel.qml) : ses boutons de souris en plus.
        if (button.buttons !== undefined)
            loader.item.toggle(button, button.buttons);
        else
            loader.item.toggle(button);
    }

    // Aperçu au survol d'un bouton à aperçu (SettingsButton.qml), comme les icônes du tray.
    function preview(kind: string, button: Item): void {
        const loader = loaders[kind];
        if (!loader || !button)
            return;
        loader.active = true;
        loader.item.preview(button, button.buttons);
    }

    // Raccourcis `qs ipc call settings toggle` (`$mod+Escape`, phase 10) et `qs ipc call menu toggle` : bouton de l'écran focalisé,
    // sinon celui de l'écran principal (sa barre en a un, hosts/*.json), sinon le premier. Un panneau ouvert se ferme, quel que soit
    // son écran.
    function toggleFromShortcut(kind: string): void {
        const list = buttons[kind] ?? [];
        const on = name => list.find(b => b.QsWindow.window?.screen?.name === name);
        toggle(kind, on(Compositor.focusedOutput) ?? on(Outputs.primary?.name) ?? list[0] ?? null);
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
