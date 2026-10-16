pragma Singleton

import QtQuick
import Quickshell

// État partagé entre les barres de tous les écrans : popups ouverts depuis la barre (calendrier, menus du tray, panneaux).
Singleton {
    id: root

    // Popups ouverts (chacun s'inscrit à l'ouverture et se retire à la fermeture).
    property int openPopups: 0
    // Écran dont la barre accepte le clavier « à la demande » ("" : aucune) : celle de l'horloge survolée ou du calendrier épinglé.
    property string keyboardScreen: ""

    // Appui sur une barre pendant qu'un popup est ouvert : tous se ferment, et le clic continue vers le module visé.
    signal closePopups

    function popupOpened(): void {
        openPopups++;
    }

    function popupClosed(): void {
        openPopups = Math.max(0, openPopups - 1);
    }
}
