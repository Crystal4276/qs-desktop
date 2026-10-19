import QtQuick

// Relecture d'un service du panneau réseau (Tailscale, ZeroTier) : toutes les 5 s quand son onglet (`tab`) est affiché
// (`fast`), 60 s sinon, seulement si `active`. Lu aussi à l'ouverture du panneau (onglets à jour) ; `panelClosed` à sa
// fermeture. `request()` : demande de lecture ; regroupées dans un même tour de boucle (ouverture, activation, passage en
// rapide arrivent ensemble), et refaite à la fin d'une lecture en cours (`busy`) pour voir l'effet d'une action qui vient de
// finir. Le service lit dans `read`.
Timer {
    id: root

    required property string tab
    readonly property bool fast: Network.networkPanelOpen && Network.networkTab === tab
    property bool active: false
    property bool busy: false
    property bool again: false
    signal read
    signal panelClosed

    function request(): void {
        Qt.callLater(trigger);
    }

    // Pas `start` : ce serait masquer Timer.start().
    function trigger(): void {
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

    property Connections panel: Connections {
        target: Network
        function onNetworkPanelOpenChanged() {
            if (Network.networkPanelOpen)
                root.request();
            else
                root.panelClosed();
        }
    }
    onBusyChanged: {
        if (!busy && again) {
            again = false;
            request();
        }
    }
}
