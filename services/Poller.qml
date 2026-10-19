import QtQuick

// Calendrier de relecture d'un service (Tailscale, ZeroTier) : toutes les 5 s quand `fast` (onglet affiché), 60 s sinon,
// seulement si `active` ; `poll` dès l'activation et au passage en rapide.
Timer {
    id: root

    property bool fast: false
    property bool active: false
    signal poll

    interval: fast ? 5000 : 60000
    running: active
    repeat: true
    triggeredOnStart: true
    onTriggered: poll()
    onFastChanged: if (fast && active) poll()
}
