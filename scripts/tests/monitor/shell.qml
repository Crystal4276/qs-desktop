import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.monitor
ShellRoot {
    id: root
    property var animatedKnob: null
    property real initialKnobX: 0
    MonitorPanel { id: panel }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children ?? []) {
            const found = find(child, name);
            if (found) return found;
        }
        return null;
    }
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
                check(Monitor.users === 1, "one visible monitor samples once");
                panel.visibleChanged();
                panel.visibleChanged();
                check(Monitor.users === 1, "repeated visibility notifications do not duplicate sampling");
                const control = find(panel.frameItem, "monitor-view-toggle");
                const hit = find(control, "monitor-view-toggle-hit");
                check(hit.width === control.width && hit.height === control.height, "whole pill is clickable");
                hit.clicked(null);
                check(!panel.applicationView, "click switches to processes");
                hit.clicked(null);
                check(panel.applicationView, "same hit area switches back to applications");
                panel.close();
                check(Monitor.users === 0, "closing the window stops sampling");
                panel.select("chat");
                Monitor.applicationGroups = [];
                Qt.callLater(() => {
                    check(panel.selectedKey === "", "selection disappears with application");
                    console.log("MONITOR_TEST_PASS");
                });
            } catch (error) { console.error("MONITOR_TEST_FAIL", error); }
        }
    }
    Timer {
        interval: 1000
        running: true
        onTriggered: {
            panel.toggle(null);
            Qt.callLater(() => {
                const control = find(panel.frameItem, "monitor-view-toggle");
                root.animatedKnob = control.children[0];
                root.initialKnobX = root.animatedKnob.x;
                find(control, "monitor-view-toggle-hit").clicked(null);
                animationMiddle.start();
                animationEnd.start();
            });
        }
    }
    Timer {
        id: animationMiddle
        interval: 80
        onTriggered: {
            const offset = root.animatedKnob.x - root.initialKnobX;
            if (!(offset > 0 && offset < root.animatedKnob.width))
                console.error("MONITOR_TEST_FAIL: animation must interpolate between positions", offset);
        }
    }
    Timer {
        id: animationEnd
        interval: 400
        onTriggered: {
            const offset = root.animatedKnob.x - root.initialKnobX;
            if (Math.abs(offset - root.animatedKnob.width) > 0.1)
                console.error("MONITOR_TEST_FAIL: animation must reach the process position", offset);
            else
                console.log("MONITOR_ANIMATION_PASS");
            panel.close();
        }
    }
}
