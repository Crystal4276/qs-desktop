import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking as NM
import qs.config
import qs.services

// Panneau Wi-Fi (ta demande du 2026-10-19 : sorti du panneau réseau ; THEME.md § 3 « Module Wi-Fi », ARCHITECTURE R5) :
// interrupteur ; carte du réseau courant (WifiCard.qml : qualité du signal et détails, comme KDE) ; autres réseaux visibles
// avec force, bande et état (GNOME, Cinnamon) ; mot de passe demandé sous la liste pour un réseau protégé inconnu, redemandé en
// rouge s'il est refusé ; échec de connexion signalé ; réseaux privés si l'icône réseau est masquée ; édition des connexions.
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
    // Dernier réseau dont la connexion a été demandée ici, et message de son échec.
    property var pending: null
    property string failText: ""

    readonly property var others: Network.wifiNetworks.filter(n => n !== Network.currentWifi)

    onVisibleChanged: {
        Network.wifiPanelOpen = visible;
        if (!visible) {
            passwordFor = null;
            passwordRefused = false;
            failText = "";
        }
    }
    Component.onDestruction: Network.wifiPanelOpen = false

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
            root.stateText(network) || (network.known ? "Saved" : network.security === NM.WifiSecurityType.Open ? "Open" : ""),
            ap?.band ?? "",
            `${Math.round(network.signalStrength * 100)} %`
        ].filter(s => s).join(" · ");
    }

    function activate(network): void {
        if (network.connected || network.stateChanging)
            return;
        failText = "";
        if (!network.known && network.security !== NM.WifiSecurityType.Open) {
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
        function onConnectionFailed(reason) {
            const network = root.pending;
            root.pending = null;
            if (reason === NM.ConnectionFailReason.NoSecrets && network.security !== NM.WifiSecurityType.Open) {
                root.passwordRefused = true;
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
    }

    PanelSection {
        visible: root.failText !== ""
        text: root.failText
        color: Theme.panel.warning
    }

    PanelSection {
        visible: Network.wifiHardwareEnabled && !Network.wifiEnabled
        text: "Wi-Fi is off"
    }

    // --- Réseau courant ---
    WifiCard {
        visible: Network.wifiEnabled && network !== null
        network: Network.currentWifi
    }

    // --- Autres réseaux ---
    PanelSection {
        visible: Network.wifiEnabled
        text: root.others.length === 0 ? "Networks · searching…" : Network.currentWifi ? "Other networks" : "Networks"
    }

    Flickable {
        visible: Network.wifiEnabled && root.others.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(wifiList.implicitHeight, Theme.panel.maxListHeight)
        contentHeight: wifiList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: wifiList
            width: parent.width
            spacing: 0

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
                        secure: modelData.security !== NM.WifiSecurityType.Open
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
        onAccepted: text => {
            const network = root.passwordFor;
            root.passwordFor = null;
            root.passwordRefused = false;
            if (text !== "" && network) {
                root.pending = network;
                network.connectWithPsk(text);
            }
        }
    }

    PrivateNetworks {
        wanted: !Network.wiredShown
    }

    RowLayout {
        Layout.fillWidth: true

        Item {
            Layout.fillWidth: true
        }

        PanelButton {
            text: "Network settings…"
            onClicked: {
                root.visible = false;
                Network.openEditor();
            }
        }
    }
}
