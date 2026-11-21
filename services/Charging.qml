pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// UPower owns charging; this service only selects its native preset and remembers one departure.
Singleton {
    id: root

    property var status: ({})
    property bool ready: false
    property bool panelOpen: false
    property string error: ""
    property bool again: false
    property string attempted: ""   // a failed automatic request is retried only by a click or a power-source change
    readonly property bool busy: reader.busy || setter.busy
    readonly property var details: status.battery ?? ({})
    readonly property bool supported: details.ChargeThresholdSupported === true
    readonly property bool configured: status.configured === true && details.ChargeStartThreshold === 50 && details.ChargeEndThreshold === 80
    readonly property bool onBattery: status.onBattery === true
    readonly property string mode: status.mode ?? ""   // confirmed by both UPower and the kernel
    readonly property bool departure: state.phase !== "preserve"
    readonly property string wanted: departure ? "full" : "preserve"
    readonly property bool applied: configured && mode === wanted
    readonly property int limit: mode === "preserve" ? 80 : mode === "full" ? 100 : 0
    readonly property string program: Quickshell.shellPath("scripts/batteryctl.py")

    // Public actions are shared by every screen. Never start a second hardware action concurrently.
    function select(departure: bool): void {
        if (!configured || busy)
            return;
        state.phase = departure ? (onBattery ? "armed" : "connected") : "preserve";
        state.lastOnline = !onBattery;
        stateFile.writeAdapter();
        error = "";
        attempted = "";
        apply();
    }

    function powerChanged(online: bool): void {
        if (state.lastOnline !== online) {
            attempted = "";
            if (state.phase === "armed" && online)
                state.phase = "connected";
            else if (state.phase === "connected" && !online)
                state.phase = "away";
            else if (state.phase === "away" && online)
                state.phase = "preserve";
            state.lastOnline = online;
            stateFile.writeAdapter();
        }
    }

    function apply(): void {
        if (!ready || !configured || busy || applied || attempted === wanted)
            return;
        attempted = wanted;
        setter.runCommand(["python3", "-I", program, wanted]);
    }

    function refresh(): void {
        if (!ready || !Battery.available)
            return;
        if (busy)
            again = true;
        else
            reader.runCommand(["python3", "-I", program, "status"]);
    }

    function accept(output: string): bool {
        try {
            const value = JSON.parse(output);
            if (value.error || !value.battery || !value.hardware)
                throw new Error(value.error || "Invalid battery status");
            status = value;
            powerChanged(!onBattery);
            return true;
        } catch (e) {
            error = String(e.message ?? e);
            return false;
        }
    }

    CliRunner {
        id: reader
        program: "python3"
        probe: false
        onFinished: {
            if (code === 0 && root.accept(output)) {
                if (!setter.busy)
                    root.apply();
            } else {
                root.error = root.error || error || "Battery information unavailable";
            }
            if (root.again) {
                root.again = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    CliRunner {
        id: setter
        program: "python3"
        probe: false
        onFinished: {
            if (code === 0 && root.accept(output)) {
                root.error = "";
                // The source may have changed while the native call was running.
                root.attempted = "";
                Qt.callLater(root.apply);
            } else {
                try { root.error = JSON.parse(output).error || error; }
                catch (_) { root.error = error || "Charging mode could not be changed"; }
            }
            Qt.callLater(root.refresh);
        }
    }

    FileView {
        id: stateFile
        path: Quickshell.statePath("battery-charging.json")
        printErrors: false
        onLoaded: root.begin()
        onLoadFailed: root.begin()
        JsonAdapter {
            id: state
            property string phase: "preserve"   // preserve → armed/connected → away → preserve on AC return
            property var lastOnline: null
        }
    }

    function begin(): void {
        if (ready)
            return;
        if (!["preserve", "armed", "connected", "away"].includes(state.phase))
            state.phase = "preserve";
        ready = true;
        refresh();
    }

    Connections {
        target: UPower
        function onOnBatteryChanged(): void { root.refresh(); }
    }
    Connections {
        target: Battery
        function onAvailableChanged(): void { root.refresh(); }
    }
    onPanelOpenChanged: if (panelOpen) refresh()

    // No custom daemon: details are queried only on source changes and slowly in the background.
    Timer {
        running: root.ready && Battery.available
        interval: root.panelOpen ? 5000 : 60000
        repeat: true
        onTriggered: root.refresh()
    }

    function duration(seconds: real): string {
        if (!(seconds > 0) || seconds > 72 * 3600)
            return "";
        const minutes = Math.max(1, Math.round(seconds / 60));
        return minutes < 60 ? `${minutes} min` : `${Math.floor(minutes / 60)} h${minutes % 60 ? ` ${minutes % 60} min` : ""}`;
    }

    IpcHandler {
        target: "charging"
        function preserve(): void { root.select(false); }
        function prepareDeparture(): void { root.select(true); }
        function refresh(): void { root.refresh(); }
        function state(): string {
            return JSON.stringify({configured: root.configured, mode: root.mode, wanted: root.wanted,
                applied: root.applied, onBattery: root.onBattery, busy: root.busy, error: root.error});
        }
    }
}
