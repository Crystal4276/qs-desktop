import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking as NM
import qs.config
import qs.services

// Panneau Wi-Fi (ta demande du 2026-10-19 : sorti du panneau réseau ; THEME.md § 3 « Module Wi-Fi », ARCHITECTURE § 7.6) :
// interrupteur ; carte du réseau courant (WifiCard.qml : qualité du signal et détails, comme KDE) ; autres réseaux visibles
// avec force, bande et état (GNOME, Cinnamon) ; mot de passe demandé sous la liste pour un réseau protégé inconnu, redemandé en
// rouge s'il est refusé (réseau entreprise : identifiant aussi, méthode et domaine à la création) ; échec de connexion signalé ;
// édition des connexions.
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
    // Réseau entreprise : identifiant demandé ; profil à créer (`newProfile`) : méthode (PEAP / TTLS) et domaine aussi.
    readonly property bool enterprise: passwordFor !== null && Network.isEnterprise(passwordFor.security)
    readonly property bool newProfile: enterprise && !passwordFor.known
    property string method: "peap"
    // Champs requis remplis : bouton « Connect » actif, Entrée acceptée.
    readonly property bool formReady: password.text !== "" && (!enterprise || identity.text.trim() !== "")
    // Texte tapé, même si le focus a quitté le champ, ou connexion entreprise en cours (son issue s'affiche ici) : pas de
    // fermeture automatique.
    holdOpen: [identity, password, domain].some(field => field.text !== "") || Network.signingIn
    // Dernier réseau dont la connexion a été demandée ici, et message de son échec.
    property var pending: null
    property string failText: ""

    readonly property var others: Network.wifiNetworks.filter(n => n !== Network.currentWifi)

    // Fermé : demandes en cours oubliées (un échec plus tard, panneau fermé, n'est pas annoncé à la réouverture), sauf l'échec
    // d'une connexion entreprise, gardé par le service et montré à l'ouverture.
    onVisibleChanged: {
        Network.setPanelOpen("wifi", root, visible);
        if (!visible) {
            passwordFor = null;
            passwordRefused = false;
            pending = null;
            failText = "";
        } else {
            showSignInFailure();
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
            failText = `${network.name} needs a certificate, LEAP or WEP setup: use Network settings…`;
            return;
        }
        if (!network.known && (Network.needsPsk(network.security) || Network.isEnterprise(network.security))) {
            passwordRefused = false;
            passwordFor = network;
            return;
        }
        if (Network.isEnterprise(network.security) && Network.passwordProfile(network) !== null) {
            Network.connectEnterprise(network);   // suivie par le service, échec repris par showSignInFailure
            return;
        }
        pending = network;
        network.connect();
    }

    // « Connect » ou Entrée dans un champ du formulaire, une fois les champs requis remplis.
    function submit(): void {
        const network = passwordFor;
        if (!network || !formReady)
            return;
        const values = [identity.text.trim(), password.text, method, domain.text.trim()];
        const isEnterprise = enterprise;
        passwordFor = null;
        passwordRefused = false;
        failText = "";
        if (isEnterprise) {
            Network.signInEnterprise(network, ...values);
        } else {
            pending = network;
            network.connectWithPsk(values[1]);
        }
    }

    // Échec d'une connexion entreprise (même survenu panneau fermé) : formulaire repris avec ce qui avait été saisi, mot de passe
    // vide ; refus en rouge dans le titre, autre échec en message.
    function showSignInFailure(): void {
        const failure = Network.signInFailure;
        if (!visible || !failure)
            return;
        Network.signInFailure = null;
        passwordFor = failure.network;
        passwordRefused = failure.kind === "refused";
        failText = failure.kind === "failed" ? `Could not connect to ${failure.network.name} — weak signal or wrong username or password`
            : failure.kind === "profile" ? `Could not connect to ${failure.network.name}` : "";
        identity.text = failure.identity;
        method = failure.method || "peap";
        domain.text = failure.domain;
    }

    Connections {
        target: Network
        function onSignInFailureChanged() {
            root.showSignInFailure();
        }
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
            // Clé WPA attendue, ou sécurité non reconnue (drapeaux inhabituels) : le mot de passe peut être proposé. Réseau
            // entreprise ici : profil sans mot de passe (certificats, éditeur) ; ceux à mot de passe passent par le service.
            const secured = !Network.isOpen(network.security) && !Network.needsEditor(network.security)
                && !Network.isEnterprise(network.security);
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
        onPortalRequested: network => {
            root.close();   // libérer le clavier exclusif avant d'ouvrir le navigateur
            Network.openCaptivePortal(network);
        }
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

    // Mot de passe d'un réseau protégé inconnu (ou refusé) ; réseau entreprise : identifiant, et à la création méthode et
    // domaine du serveur (facultatif : certificat vérifié s'il est rempli).
    PanelSection {
        readonly property string name: root.passwordFor?.name ?? ""

        visible: root.passwordFor !== null
        text: root.enterprise ? (root.passwordRefused ? `Wrong username or password for ${name}` : `Sign in to ${name}`)
            : root.passwordRefused ? `Wrong password for ${name}` : `Password for ${name}`
        color: root.passwordRefused ? Theme.panel.warning : Theme.panel.secondaryText
    }

    // Autre réseau demandé : champs vidés (le texte tapé n'est pas pour lui), identifiant enregistré repris, focus au premier
    // champ à remplir une fois le formulaire affiché.
    onPasswordForChanged: {
        identity.text = Network.savedIdentity(passwordFor);
        password.text = "";
        domain.text = "";
        method = "peap";
        if (passwordFor !== null)
            Qt.callLater(() => (identity.visible && identity.text === "" ? identity : password).focusInput());
    }

    PanelTabs {
        visible: root.newProfile
        model: [{ key: "peap", text: "PEAP" }, { key: "ttls", text: "TTLS" }]
        current: root.method
        onPicked: key => root.method = key
    }

    PanelField {
        id: identity
        visible: root.enterprise
        error: root.passwordRefused
        placeholder: "Username"
        onAccepted: root.submit()
    }

    PanelField {
        id: password
        visible: root.passwordFor !== null
        password: true
        error: root.passwordRefused
        placeholder: "Password"
        onAccepted: root.submit()
    }

    PanelField {
        id: domain
        visible: root.newProfile
        placeholder: "Server domain (optional)"
        onAccepted: root.submit()
    }

    RowLayout {
        visible: root.passwordFor !== null
        Layout.fillWidth: true

        Item {
            Layout.fillWidth: true
        }

        PanelButton {
            text: "Connect"
            enabled: root.formReady
            onClicked: root.submit()
        }
    }

    NetworkSettingsButton {
        panel: root
    }
}
