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
    readonly property bool enabled: Quickshell.env("QS_TEST") !== "1" && (Compositor.isSway || Compositor.isHyprland)

    PersistentProperties {
        id: persist
        reloadableId: "lid"
        property var disabled: ({}) // output -> restore rule; retained across QML reloads
        property bool closedSeen: false // lid handled while closed: its opening restores the internal panels
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
        // Exit code 0: no lid (desktop), nothing to follow.
        onExited: code => {
            root.ready = false;
            if (root.enabled && code !== 0) retry.restart();
        }
    }
    Timer { id: retry; interval: 5000; onTriggered: bridge.running = true }
    Timer { id: settle; interval: 500; onTriggered: Compositor.requestConnectedOutputs() }
    Timer { id: readRetry; interval: 5000; onTriggered: root.refresh() }
    // Like logind's HoldoffTimeoutSec: after a resume, a dock's displays take seconds to appear; after a request, the suspend
    // is retried if the system did not sleep (refused, or woken with the lid still closed).
    Timer { id: holdoff; interval: 30000; onTriggered: root.refresh() }

    // Active displays only: DPMS and other monitor refreshes do not change docking.
    readonly property string outputsKey: Compositor.outputs.map(o => o.name).sort().join(" ")
    onOutputsKeyChanged: refresh()

    // Displays matter while the lid is closed, and once when it opens.
    function refresh(): void {
        if (ready && present && (closed || persist.closedSeen)) settle.restart();
    }
    function evaluate(): void {
        if (!ready || !present) return;
        const rows = Compositor.connectedOutputs;
        if (!closed) {
            holdoff.stop();
            if (!persist.closedSeen) return; // a panel disabled with the lid open is the user's choice
            for (const name of Object.keys(persist.disabled)) {
                if (rows.some(o => o.name === name))
                    Compositor.setOutputEnabled(name, true, persist.disabled[name]);
            }
            const orphaned = rows.filter(o => o.internal && !o.enabled && !(o.name in persist.disabled));
            if (orphaned.length) Compositor.restoreInternalOutputs(orphaned.map(o => o.name));
            persist.disabled = ({});
            persist.closedSeen = false;
            return;
        }
        persist.closedSeen = true;
        // A connected but disabled external display cannot hold the session.
        if (rows.some(o => !o.internal && o.enabled)) {
            const saved = Object.assign({}, persist.disabled);
            for (const o of rows.filter(o => o.internal && o.enabled)) {
                saved[o.name] = saved[o.name] ?? Compositor.lidRestoreRule(o.name);
                Compositor.setOutputEnabled(o.name, false, saved[o.name]);
            }
            persist.disabled = saved;
        } else if (!holdoff.running) {
            holdoff.restart();
            Session.suspend(); // Idle's existing delay inhibitor locks before actual sleep.
        }
    }
    Connections {
        target: Compositor
        function onConnectedOutputsReady(success: bool) {
            if (success && !settle.running) root.evaluate();
            else if (!success && root.ready && root.present) readRetry.restart();
        }
        function onOutputsChanging() { root.refresh(); }
        function onConfigurationReloaded() { root.refresh(); }
    }
    Connections {
        target: Idle
        function onPreparingSleepChanged() {
            if (!Idle.preparingSleep) { holdoff.restart(); root.refresh(); }
        }
    }
    IpcHandler {
        target: "lid"
        function state(): string {
            return JSON.stringify({ready: root.ready, present: root.present, closed: root.closed, holdoff: holdoff.running,
                disabled: Object.keys(persist.disabled), outputs: Compositor.connectedOutputs});
        }
    }
}
