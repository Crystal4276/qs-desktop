// Copy to the test repository root; run only on an isolated compositor with QS_TEST=1.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.bar
import qs.modules.monitor
import qs.services
ShellRoot {
    id: root
    property string launchOutput: ""
    Bar {}
    SystemMonitor {}
    PanelWindow {
        visible: true
        implicitWidth: 1
        implicitHeight: 1
        screen: Quickshell.screens.find(s => s.name === root.launchOutput) ?? Quickshell.screens[0]
        Item { id: anchor }
    }
    IpcHandler {
        target: "windowcheck"
        function openOn(output: string): void {
            root.launchOutput = output;
            Qt.callLater(() => Monitor.toggle(anchor));
        }
        function state(): string {
            return JSON.stringify({ users: Monitor.users, active: Monitor.active });
        }
    }
}
