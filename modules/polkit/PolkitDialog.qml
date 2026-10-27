import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.modules.bar

// Agent polkit natif (remplace polkit-gnome, ARCHITECTURE § 10.1 R4) : fenêtre au style des panneaux, centrée sur l'écran focalisé,
// au clavier exclusif — icône et message de l'application, invite et champ (masqué si polkit le demande), message
// d'erreur, Cancel / Authenticate. Entrée valide, Échap annule. Un seul agent par session : tant que polkit-gnome tourne (avant
// la bascule), c'est lui qui reste enregistré.
Scope {
    id: root

    // Agent enregistré auprès de polkit. Échec (place prise par polkit-gnome, ou par l'instance d'avant un plantage, pas encore
    // partie) : Quickshell ne réessaie pas ; l'agent est recréé, de plus en plus rarement.
    LazyLoader {
        id: agentLoader
        active: true

        PolkitAgent {}
    }

    readonly property PolkitAgent agent: agentLoader.item
    readonly property AuthFlow flow: agent?.flow ?? null
    property int failedRegistrations: 0

    Timer {
        running: !agentLoader.active || (root.agent !== null && !root.agent.isRegistered)
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

    // Demande déjà en cours à la création de l'agent (rechargement de la config : il reprend celui d'avant et sa demande) :
    // affichée.
    onAgentChanged: {
        if (agent?.isActive && !window.visible)
            window.show();
    }

    // Demande en cours affichée ; terminée (réussie, refusée, annulée) : fenêtre fermée.
    Connections {
        target: root.agent
        function onAuthenticationRequestStarted() {
            window.show();
        }
        // Demande retirée par polkit sans fin signalée sur le flux : fenêtre fermée quand même.
        function onIsActiveChanged() {
            if (!root.agent.isActive && window.visible)
                window.close();
            Qt.callLater(root.cancelDisplaced);
        }
    }

    // Quickshell 0.3.2 : une demande arrivée pendant une autre la remplace (sa file d'attente ne sert pas) ; la première, sans
    // fenêtre, ferait attendre son application indéfiniment. Annulée une fois l'agent libre (pas avant : sa fin terminerait aussi
    // la demande en cours) ; l'application peut redemander.
    property var displaced: []
    property AuthFlow lastFlow: null
    onFlowChanged: {
        if (lastFlow && flow && !lastFlow.isCompleted)
            displaced = [...displaced, lastFlow];
        lastFlow = flow;
    }

    function cancelDisplaced(): void {
        if (agent?.isActive)
            return;
        const flows = displaced;
        displaced = [];
        for (const f of flows) {
            if (f && !f.isCompleted)
                f.cancelAuthenticationRequest();
        }
    }

    Connections {
        target: Session
        function onLockActiveChanged() {
            if (!Session.lockActive)
                window.reopen();
        }
    }

    // Mot de passe refusé (comme l'écran de verrouillage) : champ rouge et « Wrong password », jusqu'à la saisie suivante.
    property bool wrong: false

    Connections {
        target: root.flow
        function onIsCompletedChanged() {
            if (root.flow.isCompleted)
                window.close();
        }
        function onAuthenticationFailed() {
            root.wrong = true;
        }
        // Vérification en cours, champ désactivé : le cadre garde le clavier (Échap annule) ; nouvel essai : le champ le reprend.
        function onIsResponseRequiredChanged() {
            if (!window.visible)
                return;
            if (root.flow.isResponseRequired)
                field.focusInput();
            else
                frame.forceActiveFocus();
        }
    }

    // Identité dont le mot de passe est demandé, si ce n'est pas toi (plusieurs administrateurs : polkit propose le premier).
    readonly property string otherIdentity: {
        const identity = flow?.selectedIdentity ?? null;
        return identity && identity.string !== Quickshell.env("USER") ? identity.displayName || identity.string : "";
    }

    OverlayPopup {
        id: window

        WlrLayershell.namespace: "quickshell-polkit"
        frameItem: frame

        // Écran verrouillé : affichée seulement au déverrouillage (Session.lockActive).
        function show(): void {
            if (Session.lockActive)
                return;
            screen = Outputs.focusedScreen();
            field.text = "";
            root.wrong = false;
            prepareOpen(null);
            visible = true;
            field.focusInput();
        }

        // Fermée par toi (clic à côté, une barre, un autre popup) : demande annulée, une fois la fenêtre fermée (l'annulation
        // termine aussitôt la demande, et la suivante en attente s'ouvre : pas dans la fenêtre qui se ferme). Fermée sans toi
        // (écran disparu, verrouillage) : demande gardée, rouverte sur l'écran focalisé (au déverrouillage, s'il y a lieu).
        // Saisie effacée dans les deux cas (pas de mot de passe gardé en mémoire).
        property AuthFlow abandoned: null

        onClosing: {
            field.text = "";
            if (closingLost) {
                Qt.callLater(window.reopen);
            } else {
                abandoned = root.flow;
                Qt.callLater(window.cancelAbandoned);
            }
        }

        function reopen(): void {
            if (root.agent?.isActive && !visible)
                show();
        }

        function cancelAbandoned(): void {
            const flow = abandoned;
            abandoned = null;
            if (flow && !flow.isCompleted && !(visible && root.flow === flow))
                flow.cancelAuthenticationRequest();
        }

        // Champ vide : rien envoyé (un essai vide compterait comme un échec pour faillock).
        function submit(): void {
            if (root.flow?.isResponseRequired && field.text !== "") {
                root.flow.submit(field.text);
                field.text = "";
            }
        }

        PanelFrame {
            id: frame

            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            width: Theme.panel.width
            title: "Authentication Required"
            onCloseRequested: root.flow?.cancelAuthenticationRequest()

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.panel.spacing

                IconImage {
                    visible: (root.flow?.iconName ?? "") !== ""
                    implicitSize: Theme.notification.iconSize / 2
                    source: Icons.iconSource(root.flow?.iconName ?? "")
                }

                // Texte brut : le message reprend la commande de l'application (pkexec), qui pourrait y glisser du HTML.
                Text {
                    Layout.fillWidth: true
                    text: root.flow?.message ?? ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    font.family: Theme.font.text
                    font.pixelSize: Theme.panel.fontSize
                    color: Theme.panel.text
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.otherIdentity !== ""
                text: `Password for ${root.otherIdentity}`
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                font.family: Theme.font.text
                font.pixelSize: Theme.panel.smallFontSize
                color: Theme.panel.secondaryText
            }

            PanelField {
                id: field
                enabled: root.flow?.isResponseRequired ?? false
                password: !(root.flow?.responseVisible ?? false)
                placeholder: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "")
                error: root.wrong
                onTextChanged: {
                    if (text !== "")
                        root.wrong = false;
                }
                onAccepted: window.submit()
                Keys.onEscapePressed: root.flow?.cancelAuthenticationRequest()
            }

            // Message de polkit (une information, ex. « posez le doigt », ou une erreur, ex. compte bloqué) ; refusé : l'erreur de
            // polkit s'il y en a une, sinon « Wrong password » (une information d'avant n'a plus cours). Le message n'est pas remis
            // à zéro d'un essai à l'autre.
            Text {
                readonly property string supplementary: root.flow?.supplementaryMessage ?? ""
                readonly property bool isError: root.flow?.supplementaryIsError ?? false

                Layout.fillWidth: true
                visible: text !== ""
                text: root.wrong && !(isError && supplementary !== "") ? "Wrong password" : supplementary
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                font.family: Theme.font.text
                font.pixelSize: Theme.panel.smallFontSize
                color: root.wrong || isError ? Theme.panel.warning : Theme.panel.secondaryText
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.panel.spacing

                Item {
                    Layout.fillWidth: true
                }

                PanelButton {
                    text: "Cancel"
                    onClicked: root.flow?.cancelAuthenticationRequest()
                }

                PanelButton {
                    text: "Authenticate"
                    checked: true
                    enabled: root.flow?.isResponseRequired ?? false
                    onClicked: window.submit()
                }
            }
        }
    }
}
