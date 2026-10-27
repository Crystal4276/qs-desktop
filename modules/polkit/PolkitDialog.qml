import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.modules.bar

// Fenêtre de l'agent polkit (services/Polkit.qml ; ARCHITECTURE § 10.1 R4) : style des panneaux, centrée sur l'écran focalisé,
// au clavier exclusif — icône et message de l'application, invite et champ (masqué si polkit le demande), message
// d'erreur, Cancel / Authenticate. Entrée valide, Échap annule.
Scope {
    id: root

    readonly property AuthFlow flow: Polkit.flow

    // Demande en cours affichée (aussi celle reprise au rechargement) ; terminée (réussie, refusée, annulée) : fenêtre fermée.
    Component.onCompleted: {
        if (Polkit.isActive)
            window.show();
    }
    Connections {
        target: Polkit
        function onRequestStarted() {
            window.show();
        }
        // Demande retirée par polkit sans fin signalée sur le flux : fenêtre fermée quand même.
        function onIsActiveChanged() {
            if (!Polkit.isActive && window.visible)
                window.close();
        }
    }

    Connections {
        target: Session
        function onLockActiveChanged() {
            if (!Session.lockActive)
                window.reopen();
        }
    }

    // Mot de passe refusé (comme l'écran de verrouillage) : champ rouge et « Wrong password », jusqu'à la saisie suivante ou la
    // demande suivante (même arrivée pendant le verrouillage, fenêtre fermée).
    property bool wrong: false
    onFlowChanged: wrong = false

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

        // Champ vide ; clavier au champ, ou au cadre pendant une vérification (Échap annule). Écran verrouillé : affichée
        // seulement au déverrouillage (Session.lockActive).
        function show(): void {
            if (Session.lockActive)
                return;
            screen = Outputs.focusedScreen();
            field.text = "";
            prepareOpen(null);
            visible = true;
            if (root.flow?.isResponseRequired)
                field.focusInput();
            else
                frame.forceActiveFocus();
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
            if (Polkit.isActive && !visible)
                show();
        }

        function cancelAbandoned(): void {
            const flow = abandoned;
            abandoned = null;
            if (!visible)
                Polkit.cancel(flow);
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
                onAccepted: window.submit()   // Échap : remonte au cadre (annulation)
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
