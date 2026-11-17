import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Panneau VPN (ARCHITECTURE § 7.9 ; ta demande du 2026-11-17 : NordVPN, Tailscale et ZeroTier réunis) : onglets des services
// présents (pas d'onglets s'il n'y en a qu'un), boutons cochés comme le sélecteur de fonds ; chaque onglet a sa vue
// (NordVpnView, TailscaleView, ZeroTierView). À l'ouverture : l'onglet choisi à la main, sinon le premier VPN actif, sinon le
// premier.
Panel {
    id: root

    title: "VPN"

    property string tab: ""
    property bool picked: false    // onglet choisi à la main : gardé d'une ouverture à l'autre
    // Onglet de l'ouverture choisi : les vues se construisent ensuite (pas une vue de l'onglet précédent, aussitôt détruite).
    property bool ready: false
    readonly property var tabs: [
        { key: "nordvpn", text: "NordVPN", shown: Vpn.available, active: Vpn.connected },
        { key: "tailscale", text: "Tailscale", shown: Tailscale.installed, active: Tailscale.running },
        { key: "zerotier", text: "ZeroTier", shown: ZeroTier.present, active: ZeroTier.connectedCount > 0 }
    ].filter(t => t.shown)
    readonly property string current: tabs.some(t => t.key === tab) ? tab : (tabs[0]?.key ?? "")

    // Recherche des pays NordVPN à l'ouverture sur son onglet.
    initialFocus: nordvpn.item?.searchInput ?? frameItem

    onVisibleChanged: {
        if (visible && !picked)
            tab = (tabs.find(t => t.active) ?? tabs[0])?.key ?? "";
        ready = visible;
        if (visible)
            Network.vpnTab = current;
        Network.setPanelOpen("vpn", root, visible);
    }
    onCurrentChanged: if (visible) Network.vpnTab = current
    Component.onDestruction: Network.setPanelOpen("vpn", root, false)

    // Plus aucun service (NordVPN figé, ZeroTier arrêté…) panneau ouvert : fermé, son icône n'est plus là.
    onTabsChanged: if (visible && tabs.length === 0) close()

    PanelTabs {
        visible: root.tabs.length > 1
        model: root.tabs
        current: root.current
        onPicked: key => {
            root.tab = key;
            root.picked = true;
        }
    }

    // Vues construites seulement panneau ouvert sur leur onglet (~150 pays, des centaines de nœuds de sortie possibles ; une
    // barre par écran).
    Loader {
        id: nordvpn
        Layout.fillWidth: true
        active: root.ready && root.current === "nordvpn"
        visible: active
        sourceComponent: NordVpnView {}
    }

    Loader {
        Layout.fillWidth: true
        active: root.ready && root.current === "tailscale"
        visible: active
        sourceComponent: TailscaleView {}
    }

    Loader {
        Layout.fillWidth: true
        active: root.ready && root.current === "zerotier"
        visible: active
        sourceComponent: ZeroTierView {}
    }
}
