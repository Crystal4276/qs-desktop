pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

// Agent polkit (remplace polkit-gnome, ARCHITECTURE § 7.14) : enregistrement auprès de polkit et demande en cours ; fenêtre :
// modules/polkit/PolkitDialog.qml. Un seul agent par session : tant que polkit-gnome tourne (avant la bascule), c'est lui qui
// garde la place.
Singleton {
    id: root

    readonly property PolkitAgent agent: agentLoader.item
    readonly property AuthFlow flow: agent?.flow ?? null

    // Pas d'agent dans l'instance de scripts/test-outputs.sh (QS_TEST) : il s'enregistrerait sur le vrai polkit.
    // Échec de l'enregistrement (place prise par polkit-gnome, ou par l'instance d'avant un plantage, pas encore partie) :
    // Quickshell ne réessaie pas ; l'agent est recréé, de plus en plus rarement.
    LazyLoader {
        id: agentLoader
        active: !Quickshell.env("QS_TEST")

        PolkitAgent {}
    }

    property int failedRegistrations: 0

    Timer {
        running: !Quickshell.env("QS_TEST") && (!agentLoader.active || (root.agent !== null && !root.agent.isRegistered))
        repeat: true
        // Agent retiré : recréé au tick suivant, une fois l'ancien détruit (sinon le nouveau ne reprend pas sa place).
        interval: agentLoader.active ? Math.min(5000 * 2 ** root.failedRegistrations, 300000) : 1000
        onTriggered: {
            if (agentLoader.active) {
                root.failedRegistrations++;
                agentLoader.active = false;
            } else {
                agentLoader.active = true;
            }
        }
    }

    Connections {
        target: root.agent
        function onIsRegisteredChanged() {
            if (root.agent.isRegistered)
                root.failedRegistrations = 0;
        }
    }

    // Quickshell 0.3.2 : une demande arrivée pendant une autre la remplace ; la première est annulée une fois l'agent libre (pas
    // avant : sa fin terminerait aussi l'autre). Limites : ARCHITECTURE § 7.14.
    property var displaced: []
    property AuthFlow lastFlow: null

    onFlowChanged: {
        if (lastFlow && flow && !lastFlow.isCompleted)
            displaced = [...displaced, lastFlow];
        lastFlow = flow;
        if (!flow)
            Qt.callLater(root.cancelDisplaced);
    }

    function cancelDisplaced(): void {
        if (flow)
            return;
        const flows = displaced;
        displaced = [];
        for (const f of flows) {
            if (f && !f.isCompleted)
                f.cancelAuthenticationRequest();
        }
    }

    // Annulation (Échap, Cancel, fenêtre fermée par toi) : seulement la demande en cours (remplacée entre-temps : annulée plus
    // tard, par cancelDisplaced, pas pendant l'autre).
    function cancel(target: AuthFlow): void {
        if (target && !target.isCompleted && target === flow)
            target.cancelAuthenticationRequest();
    }
}
