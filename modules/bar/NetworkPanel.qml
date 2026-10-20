import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Panneau réseau (remplace le menu de nm-applet, ARCHITECTURE R5 ; refonte du 2026-10-19, ta demande — THEME.md § 3
// « Panneau réseau ») : onglets Wired / Tailscale / ZeroTier (seulement ceux qui existent ; pas d'onglets s'il n'y en a qu'un),
// boutons cochés comme le sélecteur de fonds. Filaire : une carte par câble (WiredCard.qml) ; Tailscale et ZeroTier : leurs
// vues. Le Wi-Fi a son propre module (WifiPanel.qml). Libellés en anglais, comme nm-applet et la locale du système.
Panel {
    id: root

    title: "Network"

    property string tab: "wired"
    property bool autoTab: false   // onglet privé choisi par le panneau (pas par un clic)
    property bool picked: false    // onglet choisi à la main : plus jamais changé par le panneau
    readonly property var tabs: [
        { key: "wired", text: "Wired", shown: Network.wiredDevices.length > 0 },
        { key: "tailscale", text: "Tailscale", shown: Tailscale.installed },
        { key: "zerotier", text: "ZeroTier", shown: ZeroTier.present }
    ].filter(t => t.shown)
    readonly property string current: tabs.some(t => t.key === tab) ? tab : (tabs[0]?.key ?? "")

    // Onglet affiché, pour que Tailscale / ZeroTier ne soient relus souvent que sur le leur.
    onVisibleChanged: {
        // Bouton servant d'entrée aux réseaux privés : leur onglet d'abord ; redevenu filaire (câble rebranché), l'onglet choisi
        // ainsi revient au filaire (un onglet choisi à la main est gardé).
        if (visible && Network.privateEntry) {
            const privateTab = tabs.find(t => t.key !== "wired")?.key;
            if (privateTab && tab === "wired" && !picked) {
                tab = privateTab;
                autoTab = true;
            }
        } else if (visible && autoTab && !picked) {
            tab = "wired";
            autoTab = false;
        }
        if (visible)
            Network.networkTab = current;
        Network.setPanelOpen("network", root, visible);
    }
    onCurrentChanged: if (visible) Network.networkTab = current
    Component.onDestruction: Network.setPanelOpen("network", root, false)

    PanelTabs {
        visible: root.tabs.length > 1
        model: root.tabs
        current: root.current
        onPicked: key => {
            root.tab = key;
            root.autoTab = false;
            root.picked = true;
        }
    }

    // --- Filaire ---
    Repeater {
        model: ScriptModel {
            values: root.current === "wired" ? Network.wiredDevices : []
        }

        WiredCard {
            required property var modelData
            device: modelData
        }
    }

    // Vues construites seulement panneau ouvert sur leur onglet (des centaines de nœuds de sortie possibles, une barre par
    // écran).
    Loader {
        Layout.fillWidth: true
        active: root.visible && root.current === "tailscale"
        visible: active
        sourceComponent: TailscaleView {}
    }

    Loader {
        Layout.fillWidth: true
        active: root.visible && root.current === "zerotier"
        visible: active
        sourceComponent: ZeroTierView {}
    }

    NetworkSettingsButton {
        panel: root
    }
}
