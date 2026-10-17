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

    readonly property AuthFlow flow: agent.flow

    PolkitAgent {
        id: agent
    }

    // Demande en cours affichée ; terminée (réussie, refusée, annulée) : fenêtre fermée.
    Connections {
        target: agent
        function onAuthenticationRequestStarted() {
            window.show();
        }
    }

    Connections {
        target: root.flow
        function onIsCompletedChanged() {
            if (root.flow.isCompleted)
                window.close();
        }
    }

    OverlayPopup {
        id: window

        WlrLayershell.namespace: "quickshell-polkit"
        frameItem: frame

        function show(): void {
            screen = Quickshell.screens.find(s => s.name === Compositor.focusedOutput) ?? Quickshell.screens[0];
            field.text = "";
            prepareOpen(null);
            visible = true;
            field.focusInput();
        }

        // Fermeture par un clic à côté, une barre ou un autre écran : la demande est annulée.
        onClosing: {
            if (root.flow && !root.flow.isCompleted)
                root.flow.cancelAuthenticationRequest();
        }

        function submit(): void {
            if (root.flow?.isResponseRequired) {
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

                Text {
                    Layout.fillWidth: true
                    text: root.flow?.message ?? ""
                    wrapMode: Text.Wrap
                    font.family: Theme.font.text
                    font.pixelSize: Theme.panel.fontSize
                    color: Theme.panel.text
                }
            }

            PanelField {
                id: field
                enabled: root.flow?.isResponseRequired ?? false
                password: !(root.flow?.responseVisible ?? false)
                placeholder: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "")
                onAccepted: window.submit()
                Keys.onEscapePressed: root.flow?.cancelAuthenticationRequest()
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.flow?.supplementaryMessage ?? ""
                wrapMode: Text.Wrap
                font.family: Theme.font.text
                font.pixelSize: Theme.panel.smallFontSize
                color: root.flow?.supplementaryIsError ? Theme.panel.warning : Theme.panel.secondaryText
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
