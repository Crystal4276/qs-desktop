pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

// Agent polkit (remplace polkit-gnome, ARCHITECTURE § 10.1.9) : enregistrement auprès de polkit et demande en cours ; fenêtre :
// modules/polkit/PolkitDialog.qml. Un seul agent par session : tant que polkit-gnome tourne (avant la bascule), c'est lui qui
// garde la place.
Singleton {
    id: root

    readonly property PolkitAgent agent: agentLoader.item
    readonly property AuthFlow flow: agent?.flow ?? null
    readonly property bool isActive: flow !== null

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
    onIsActiveChanged: Qt.callLater(root.cancelDisplaced)

    // Quickshell 0.3.2 : une demande arrivée pendant une autre la remplace (sa file d'attente ne sert pas) ; la première, sans
    // fenêtre, ferait attendre son application indéfiniment. Annulée une fois l'agent libre (pas avant : sa fin terminerait aussi
    // la demande en cours) ; l'application peut redemander. Limites (défaut de Quickshell) : remplacée pendant la vérification de
    // son mot de passe, sa réussite termine la demande en cours ; les demandes remplacées ne sont jamais libérées.
    property var displaced: []
    property AuthFlow lastFlow: null

    onFlowChanged: {
        if (lastFlow && flow && !lastFlow.isCompleted)
            displaced = [...displaced, lastFlow];
        lastFlow = flow;
    }

    function cancelDisplaced(): void {
        if (isActive)
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
