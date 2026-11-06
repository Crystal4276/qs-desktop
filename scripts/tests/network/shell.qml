import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking as NM
import qs.services
import qs.modules.bar
import qs.config
ShellRoot {
    id: root
    property bool closedBeforeLaunch: false
    property QtObject firstPanel: QtObject { property bool pinned: false }
    property QtObject secondPanel: QtObject { property bool pinned: false }
    property WifiPanel panel: null
    Component { id: panelComponent; WifiPanel {} }
    Connections {
        target: Launch
        function onCommandsChanged() { root.closedBeforeLaunch = root.panel !== null && !root.panel.visible; }
    }
    function findPortal(item) {
        if (item.text === "Open Captive Portal") return item;
        for (const child of item.children ?? []) {
            const found = findPortal(child);
            if (found) return found;
        }
        return null;
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: Theme.panel.width
        implicitHeight: column.implicitHeight + 2 * Theme.panel.padding
        color: Theme.panel.background
        Item { id: anchor; property bool hovered: false }
        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.panel.padding }
            WifiCard {
                id: card
                network: Network.currentWifi
            }
        }
    }
    IpcHandler {
        target: "test"
        function configure(json: string): void {
            const values = JSON.parse(json);
            for (const key of Object.keys(values)) {
                if (key === "interfaceName") Network.interfaceName = values[key];
                else Backend[key] = values[key];
            }
        }
        function panels(pinned: bool, count: int): void {
            root.firstPanel.pinned = root.secondPanel.pinned = pinned;
            Network.setPanelOpen("wifi", root.firstPanel, count > 0);
            Network.setPanelOpen("wifi", root.secondPanel, count > 1);
        }
        function snapshot(): string {
            const button = root.findPortal(card);
            return JSON.stringify({portal: Network.wifiCaptivePortal, limited: Network.wifiLimited,
                connectivity: Network.connectivity, checks: Backend.checks, commands: Launch.commands,
                buttonVisible: button !== null && button.visible, closedBeforeLaunch: root.closedBeforeLaunch});
        }
        function openPanel(): void {
            root.panel = panelComponent.createObject(root);
            root.panel.toggle(anchor, Qt.LeftButton);
        }
        function activate(): void {
            root.findPortal(root.panel.contentItem).clicked();
            root.panel.destroy();
            root.panel = null;
        }
        function stale(): void { Network.openCaptivePortal(null); }
        function capture(path: string): void { column.grabToImage(result => result.saveToFile(path)); }
    }
}
