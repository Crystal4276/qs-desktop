import QtQuick

// Relecture d'un service (Tailscale, ZeroTier) : toutes les 5 s quand `fast` (onglet affiché), 60 s sinon, seulement si
// `active`. `request()` : demande de lecture ; regroupées dans un même tour de boucle (ouverture du panneau, activation, passage
// en rapide arrivent ensemble), et refaite à la fin d'une lecture en cours (`busy`) pour voir l'effet d'une action qui vient de
// finir. Le service lit dans `read`.
Timer {
    id: root

    property bool fast: false
    property bool active: false
    property bool busy: false
    property bool again: false
    signal read

    function request(): void {
        Qt.callLater(start);
    }

    function start(): void {
        if (busy)
            again = true;
        else
            read();
    }

    interval: fast ? 5000 : 60000
    running: active
    repeat: true
    triggeredOnStart: true
    onTriggered: request()
    onFastChanged: if (fast && active) request()
    onBusyChanged: {
        if (!busy && again) {
            again = false;
            request();
        }
    }
}
