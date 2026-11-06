import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.monitor
ShellRoot {
    MonitorPanel { id: panel }
    function check(ok, message) { if (!ok) throw new Error(message); }
    Timer {
        interval: 500
        running: true
        onTriggered: {
            try {
                Monitor.processes = [
                    { key: "1:10", pid: 1, user: Monitor.me, name: "browser", cpu: 20, memory: 1024, gpu: 2 },
                    { key: "2:10", pid: 2, user: Monitor.me, name: "worker", cpu: 30, memory: 2048, gpu: 3 },
                    { key: "3:10", pid: 3, user: Monitor.me, name: "chat", cpu: 10, memory: 4096, gpu: 1 }
                ];
                Monitor.applicationGroups = [
                    { id: "browser", name: "Browser", members: ["1:10", "2:10"], roots: ["1:10"] },
                    { id: "chat", name: "Chat", members: ["3:10"], roots: ["3:10"] }
                ];
                check(panel.applicationView, "default view");
                check(Monitor.applications[0].cpu === 50 && Monitor.applications[0].memory === 3072
                    && Monitor.applications[0].gpu === 5 && Monitor.applications[0].count === 2, "resource sums");
                check(panel.rows[0] === "browser", "CPU sorting");
                panel.select("chat");
                const frozen = panel.rows.join();
                Monitor.processes = Monitor.processes.map(p => Object.assign({}, p, {cpu: p.pid === 3 ? 100 : 0}));
                check(panel.rows.join() === frozen, "stable selection");
                panel.confirm = "end";
                panel.changeView("processes");
                check(panel.selectedKey === "" && panel.confirm === "" && panel.rows.length === 3, "view transition");
                panel.sortBy("pid");
                panel.changeView("applications");
                check(panel.sortKey === "cpu", "PID sort reset");
                panel.changeView("processes");
                panel.toggle(null);
                check(panel.applicationView, "applications on every opening");
                panel.close();
                panel.select("chat");
                Monitor.applicationGroups = [];
                Qt.callLater(() => {
                    check(panel.selectedKey === "", "selection disappears with application");
                    console.log("MONITOR_TEST_PASS");
                });
            } catch (error) { console.error("MONITOR_TEST_FAIL", error); }
        }
    }
}
