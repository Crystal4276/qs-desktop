pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// One policy for both compositors. The bridge owns logind's lid inhibitor only while alive.
Singleton {
    id: root
    property bool ready: false
    property bool present: false
    property bool closed: false
    property bool suspendRequested: false
    readonly property bool enabled: Quickshell.env("QS_TEST") !== "1" && (Compositor.isSway || Compositor.isHyprland)

    PersistentProperties {
        id: persist
        reloadableId: "lid"
        property var disabled: ({}) // output -> restore rule; retained across QML reloads
    }

    Process {
        id: bridge
        running: root.enabled
        command: ["setpriv", "--pdeathsig", "TERM", "python3", Quickshell.shellPath("scripts/lid-state.py")]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const s = JSON.parse(line);
                    if (typeof s.ready !== "boolean" || typeof s.present !== "boolean" || typeof s.closed !== "boolean")
                        return;
                    root.ready = s.ready;
                    root.present = s.present;
                    root.closed = s.closed;
                    root.refresh();
                } catch (error) { console.warn("Lid: invalid state", error); }
            }
        }
        onExited: {
            root.ready = false;
            if (root.enabled) retry.restart();
        }
    }
    Timer { id: retry; interval: 5000; onTriggered: bridge.running = true }
    Timer { id: settle; interval: 500; onTriggered: Compositor.requestConnectedOutputs() }

    Timer { id: readRetry; interval: 5000; onTriggered: root.refresh() }

    function refresh(): void {
        if (ready && present) settle.restart();
    }
    function evaluate(): void {
        if (!ready || !present) return;
        const rows = Compositor.connectedOutputs;
        if (!closed) {
            root.suspendRequested = false;
            for (const name of Object.keys(persist.disabled)) {
                if (rows.some(o => o.name === name))
                    Compositor.setOutputEnabled(name, true, persist.disabled[name]);
            }
            const orphaned = rows.filter(o => o.internal && !o.enabled && !(o.name in persist.disabled));
            if (orphaned.length) Compositor.restoreInternalOutputs(orphaned.map(o => o.name));
            persist.disabled = ({});
            return;
        }
        if (rows.some(o => !o.internal)) {
            root.suspendRequested = false;
            const saved = Object.assign({}, persist.disabled);
            for (const o of rows.filter(o => o.internal && o.enabled)) {
                saved[o.name] = saved[o.name] ?? Compositor.lidRestoreRule(o.name);
                Compositor.setOutputEnabled(o.name, false, saved[o.name]);
            }
            persist.disabled = saved;
        } else if (!root.suspendRequested) {
            root.suspendRequested = true;
            Session.suspend(); // Idle's existing delay inhibitor locks before actual sleep.
        }
    }
    Connections {
        target: Compositor
        function onConnectedOutputsReady(success: bool) {
            if (success && !settle.running) root.evaluate();
            else if (!success && root.ready && root.present) readRetry.restart();
        }
        function onOutputsChanged() { root.refresh(); }
        function onOutputsChanging() { root.refresh(); }
        function onConfigurationReloaded() { root.refresh(); }
    }
    Connections {
        target: Idle
        function onPreparingSleepChanged() {
            if (!Idle.preparingSleep) { root.suspendRequested = false; root.refresh(); }
        }
    }
    IpcHandler {
        target: "lid"
        function state(): string {
            return JSON.stringify({ready: root.ready, present: root.present, closed: root.closed,
                suspended: root.suspendRequested, disabled: Object.keys(persist.disabled), outputs: Compositor.connectedOutputs});
        }
    }
}
