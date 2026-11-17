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
    // Onglet de l'ouverture choisi : les vues se construisent ensuite (pas une vue de l'onglet précédent, aussitôt détruite).
    property bool ready: false
    readonly property var tabs: [
        { key: "nordvpn", text: "NordVPN", shown: Vpn.available },
        { key: "tailscale", text: "Tailscale", shown: Tailscale.installed },
        { key: "zerotier", text: "ZeroTier", shown: ZeroTier.present }
    ].filter(t => t.shown)
    readonly property string current: tabs.some(t => t.key === tab) ? tab : (tabs[0]?.key ?? "")

    // Recherche des pays NordVPN : focus à l'ouverture sur son onglet, et en y passant.
    initialFocus: nordvpn.item?.searchInput ?? frameItem

    onVisibleChanged: {
        // Onglet choisi à la main (Network.vpnPicked : le même pour toutes les barres), sinon le premier VPN actif.
        if (visible) {
            const active = { nordvpn: Vpn.active, tailscale: Tailscale.running, zerotier: ZeroTier.connectedCount > 0 };
            tab = (tabs.find(t => t.key === Network.vpnPicked) ?? tabs.find(t => active[t.key]) ?? tabs[0])?.key ?? "";
        }
        ready = visible;
        if (visible)
            Network.vpnTab = current;
        Network.setPanelOpen("vpn", root, visible);
    }
    onCurrentChanged: {
        if (!visible)
            return;
        Network.vpnTab = current;
        // La vue quittée emporte le focus : recherche NordVPN, sinon le cadre (Échap, flèches).
        Qt.callLater(() => (nordvpn.item?.searchInput ?? frameItem).forceActiveFocus());
    }
    Component.onDestruction: Network.setPanelOpen("vpn", root, false)

    // Plus aucun service (NordVPN figé, ZeroTier arrêté…) panneau ouvert : fermé, son icône n'est plus là.
    onTabsChanged: if (visible && tabs.length === 0) close()

    PanelTabs {
        visible: root.tabs.length > 1
        model: root.tabs
        current: root.current
        onPicked: key => {
            root.tab = key;
            Network.vpnPicked = key;
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
