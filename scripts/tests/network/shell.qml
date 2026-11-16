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
    function findAll(item, match, found) {
        if (match(item)) found.push(item);
        for (const child of item.children ?? []) root.findAll(child, match, found);
        return found;
    }
    function field(placeholder) {
        return root.findAll(root.panel.contentItem, item => item.placeholder === placeholder, [])[0];
    }
    function button(text) {
        return root.findAll(root.panel.contentItem, item => item.text === text && item.clicked !== undefined, [])[0];
    }
    function openPanelOnce() {
        if (root.panel) return;
        root.panel = panelComponent.createObject(root);
        root.panel.toggle(anchor, Qt.LeftButton);
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
        // Formulaires (WifiPanel) : réseau `enterprise` ou `personal` du faux backend.
        function openForm(name: string): void {
            root.openPanelOnce();
            root.panel.activate(Backend[name]);
        }
        function form(): string {
            const content = root.panel.contentItem;
            const shown = item => item ? { visible: item.visible, text: item.text, error: item.error } : null;
            const titles = root.findAll(content, item => item.visible && /^(Sign in|Wrong|Password for)/.test(item.text ?? ""), []);
            const tabs = root.findAll(content, item => item.current !== undefined && item.picked !== undefined, [])[0];
            const connect = root.button("Connect");
            return JSON.stringify({ title: titles.map(item => item.text), username: shown(root.field("Username")),
                password: shown(root.field("Password")), domain: shown(root.field("Server domain (optional)")),
                tabs: { visible: tabs.visible, current: tabs.current }, connect: { visible: connect.visible, enabled: connect.enabled },
                passwordFor: root.panel.passwordFor?.name ?? "", pending: root.panel.pending?.name ?? "",
                failText: root.panel.failText, holdOpen: root.panel.holdOpen, signingIn: Network.signingIn });
        }
        function fill(json: string): void {
            const values = JSON.parse(json);
            for (const key of Object.keys(values)) root.field(key).text = values[key];
        }
        function pick(key: string): void {
            root.findAll(root.panel.contentItem, item => item.current !== undefined && item.picked !== undefined, [])[0].picked(key);
        }
        function enter(placeholder: string): void {
            const item = root.field(placeholder);
            item.accepted(item.text);
        }
        function click(text: string): void { root.button(text).clicked(); }
        // Échec : signal puis retour à « Disconnected », ou l'inverse (`stateFirst`).
        function fail(name: string, reason: string, stateFirst: bool): void {
            const network = Backend[name];
            if (stateFirst) network.state = NM.ConnectionState.Disconnected;
            network.connectionFailed(NM.ConnectionFailReason[reason]);
            network.state = NM.ConnectionState.Disconnected;
        }
        function setState(name: string, state: string): void { Backend[name].state = NM.ConnectionState[state]; }
        function cancel(): void { Network.cancelWifi(); }
        function closePanel(): void { root.panel.close(); }
        function reopenPanel(): void { root.panel.toggle(anchor, Qt.LeftButton); }
        function profile(name: string, uuid: string, json: string): void { Backend.addProfile(Backend[name], uuid, JSON.parse(json)); }
        function reset(name: string): void { Backend[name].nmSettings = []; }
        function calls(): string { return JSON.stringify(Backend.calls); }
        function capturePanel(path: string): void { root.panel.frameItem.grabToImage(result => result.saveToFile(path)); }
        function stale(): void { Network.openCaptivePortal(null); }
        function capture(path: string): void { column.grabToImage(result => result.saveToFile(path)); }
    }
}
