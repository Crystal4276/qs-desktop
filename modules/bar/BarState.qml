pragma Singleton

import QtQuick
import Quickshell

// État partagé entre les barres de tous les écrans (calendrier de l'horloge, CalendarPopup.qml).
Singleton {
    // Un calendrier est épinglé.
    property bool calendarPinned: false
    // Écran dont la barre accepte le clavier « à la demande » ("" : aucune) : celle de l'horloge survolée ou du calendrier épinglé.
    property string keyboardScreen: ""

    // Appui sur une barre pendant que le calendrier est épinglé : il se ferme, et le clic continue vers le module visé.
    signal closeCalendar
}
