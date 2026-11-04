import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking as NM
import qs.config
import qs.services

// Panneau Wi-Fi (ta demande du 2026-10-19 : sorti du panneau réseau ; THEME.md § 3 « Module Wi-Fi », ARCHITECTURE § 7.6) :
// interrupteur ; carte du réseau courant (WifiCard.qml : qualité du signal et détails, comme KDE) ; autres réseaux visibles
// avec force, bande et état (GNOME, Cinnamon) ; mot de passe demandé sous la liste pour un réseau protégé inconnu, redemandé en
// rouge s'il est refusé ; échec de connexion signalé ; édition des connexions.
// Quickshell.Networking importé sous `NM` : son type `Network` masquerait le service du même nom.
Panel {
    id: root

    title: "Wi-Fi"
    hasSwitch: Network.wifiHardwareEnabled
    switchChecked: Network.wifiEnabled
    onSwitchToggled: checked => Network.setWifiEnabled(checked)

    // Réseau protégé inconnu en attente de mot de passe ; `passwordRefused` : le précédent a été refusé.
    property var passwordFor: null
    property bool passwordRefused: false
    holdOpen: password.text !== ""   // mot de passe tapé, même si le focus a quitté le champ : pas de fermeture automatique
    // Dernier réseau dont la connexion a été demandée ici, et message de son échec.
    property var pending: null
    property string failText: ""

    readonly property var others: Network.wifiNetworks.filter(n => n !== Network.currentWifi)

    // Fermé : demandes en cours oubliées (un échec plus tard, panneau fermé, n'est pas annoncé à la réouverture).
    onVisibleChanged: {
        Network.setPanelOpen("wifi", root, visible);
        if (!visible) {
            passwordFor = null;
            passwordRefused = false;
            pending = null;
            failText = "";
        }
    }
    Component.onDestruction: Network.setPanelOpen("wifi", root, false)

    function stateText(network): string {
        switch (network.state) {
        case NM.ConnectionState.Connecting:
            return "Connecting…";
        case NM.ConnectionState.Disconnecting:
            return "Disconnecting…";
        default:
            return "";
        }
    }

    function rowSubtext(network): string {
        const ap = Network.wifiAccessPoints[network.name];
        return [
            root.stateText(network) || (network.known ? "Saved" : Network.isOpen(network.security) ? "Open" : ""),
            ap?.band ?? "",
            `${Math.round(network.signalStrength * 100)} %`
        ].filter(s => s).join(" · ");
    }

    function activate(network): void {
        if (network.connected || network.stateChanging)
            return;
        failText = "";
        if (passwordFor !== network) {   // demande de mot de passe d'un autre réseau : abandonnée
            passwordFor = null;
            passwordRefused = false;
        }
        if (!network.known && Network.needsEditor(network.security)) {
            failText = `${network.name} needs an enterprise or WEP setup: use Network settings…`;
            return;
        }
        if (!network.known && Network.needsPsk(network.security)) {
            passwordRefused = false;
            passwordFor = network;
            return;
        }
        pending = network;
        network.connect();
    }

    Connections {
        target: root.pending
        ignoreUnknownSignals: true
        // Connecté : plus rien à surveiller.
        function onConnectedChanged() {
            if (root.pending?.connected) {
                root.pending = null;
                root.failText = "";
            }
        }
        function onConnectionFailed(reason) {
            const network = root.pending;
            root.pending = null;
            // Clé refusée : NetworkManager le signale par l'absence de secrets (« Wrong password ») ; une déconnexion ou un délai
            // pendant l'authentification peut venir de la clé ou du signal : message neutre et mot de passe proposé. La saisie
            // met à jour le profil enregistré (Quickshell, connectWithPsk), sans en créer un autre.
            // Clé WPA attendue, ou sécurité non reconnue (drapeaux inhabituels) : le mot de passe peut être proposé.
            const secured = !Network.isOpen(network.security) && !Network.needsEditor(network.security);
            if (secured && reason === NM.ConnectionFailReason.NoSecrets) {
                root.passwordRefused = true;
                root.passwordFor = network;
            } else if (secured && [NM.ConnectionFailReason.WifiClientDisconnected, NM.ConnectionFailReason.WifiClientFailed,
                NM.ConnectionFailReason.WifiAuthTimeout].includes(reason)) {
                root.failText = `Could not connect to ${network.name} — weak signal or wrong password`;
                root.passwordRefused = false;
                root.passwordFor = network;
            } else {
                root.failText = `Could not connect to ${network.name}`;
            }
        }
    }

    // --- Avertissements (en `red`, comme les autres panneaux) ---
    PanelSection {
        visible: !Network.wifiHardwareEnabled
        text: "Wi-Fi is disabled by a hardware switch or airplane mode"
        color: Theme.panel.warning
        wrapMode: Text.Wrap
    }

    PanelSection {
        visible: root.failText !== ""
        text: root.failText
        color: Theme.panel.warning
        wrapMode: Text.Wrap
    }

    PanelSection {
        visible: Network.wifiHardwareEnabled && !Network.wifiEnabled
        text: "Wi-Fi is off"
    }

    // --- Réseau courant ---
    WifiCard {
        visible: Network.wifiUsable && network !== null
        network: Network.currentWifi
        onCancelled: {
            root.pending = null;   // annulation : pas un échec à signaler
            root.failText = "";
        }
    }

    // --- Autres réseaux ---
    PanelSection {
        visible: Network.wifiUsable
        text: Network.currentWifi ? (root.others.length === 0 ? "No other networks" : "Other networks")
            : root.others.length === 0 ? "Networks · searching…" : "Networks"
    }

    PanelList {
        visible: Network.wifiUsable && root.others.length > 0

        Repeater {
            model: ScriptModel {
                values: root.others
            }

            PanelRow {
                required property NM.WifiNetwork modelData

                leading: WifiIcon {
                    size: Theme.panel.iconSize
                    color: Theme.panel.text
                    level: Network.wifiLevel(modelData.signalStrength)
                    secure: !Network.isOpen(modelData.security)
                    connecting: modelData.state === NM.ConnectionState.Connecting
                }
                text: modelData.name
                subtext: root.rowSubtext(modelData)
                onClicked: root.activate(modelData)

                PanelButton {
                    visible: modelData.known
                    text: "Forget"
                    onClicked: modelData.forget()
                }
            }
        }
    }

    // Mot de passe d'un réseau protégé inconnu (ou refusé).
    PanelSection {
        visible: root.passwordFor !== null
        text: root.passwordRefused ? `Wrong password for ${root.passwordFor?.name ?? ""}` : `Password for ${root.passwordFor?.name ?? ""}`
        color: root.passwordRefused ? Theme.panel.warning : Theme.panel.secondaryText
    }

    PanelField {
        id: password
        visible: root.passwordFor !== null
        password: true
        error: root.passwordRefused
        placeholder: "Password"
        onVisibleChanged: {
            text = "";
            if (visible)
                focusInput();
        }
        // Autre réseau demandé pendant la saisie : le texte tapé n'est pas pour lui.
        Connections {
            target: root
            function onPasswordForChanged() {
                password.text = "";
            }
        }
        onAccepted: text => {
            const network = root.passwordFor;
            root.passwordFor = null;
            root.passwordRefused = false;
            root.failText = "";
            if (text !== "" && network) {
                root.pending = network;
                network.connectWithPsk(text);
            }
        }
    }

    NetworkSettingsButton {
        panel: root
    }
}
