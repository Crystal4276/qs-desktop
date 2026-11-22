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
    property string readError: ""
    property string actionError: ""
    readonly property string error: actionError || readError
    property bool again: false
    property string attempted: ""   // a failed automatic request is retried only by a click or a power-source change
    readonly property bool busy: reader.busy || setter.busy
    readonly property bool loading: reader.busy && !status.battery
    readonly property bool changing: setter.busy
    readonly property var details: status.battery ?? ({})
    readonly property bool supported: details.ChargeThresholdSupported === true
    readonly property bool configured: status.configured === true && details.ChargeStartThreshold === 50 && details.ChargeEndThreshold === 80
    readonly property bool onBattery: UPower.onBattery
    readonly property string mode: status.mode ?? ""   // confirmed by both UPower and the kernel
    readonly property bool departure: state.phase !== "preserve"
    readonly property string wanted: departure ? "full" : "preserve"
    readonly property bool applied: configured && mode === wanted
    readonly property int limit: mode === "preserve" ? 80 : mode === "full" ? 100 : 0
    readonly property string program: Quickshell.shellPath("scripts/batteryctl.py")

    // A selection during a read is applied by reader.onFinished; the latest choice wins.
    // Public actions are shared by every screen. Never start a second hardware action concurrently.
    function select(departure: bool): void {
        if (!configured || changing)
            return;
        state.phase = departure ? (onBattery ? "armed" : "connected") : "preserve";
        state.lastOnline = !onBattery;
        Qt.callLater(root.saveState);
        readError = "";
        actionError = "";
        attempted = "";
        apply();
    }

    function saveState(): void { stateFile.writeAdapter(); }

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
            Qt.callLater(root.saveState);
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

    function accept(output: string): void {
        const value = JSON.parse(output);
        if (value.error || !value.battery || !value.hardware)
            throw new Error(value.error || "Invalid battery status");
        // Power transitions come from the native signal, never from an older command reply.
        status = value;
    }

    function failure(output: string, fallback: string): string {
        try { return JSON.parse(output).error || fallback; }
        catch (_) { return fallback; }
    }

    function retry(): void {
        readError = "";
        actionError = "";
        attempted = "";
        refresh();
    }

    CliRunner {
        id: reader
        program: "python3"
        probe: false
        onFinished: {
            try {
                if (code !== 0)
                    throw new Error(root.failure(output, error || "Battery information unavailable"));
                root.accept(output);
                root.readError = "";
                root.apply();
            } catch (e) {
                root.readError = String(e.message ?? e);
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
            try {
                if (code !== 0)
                    throw new Error(root.failure(output, error || "Charging mode could not be changed"));
                root.accept(output);
                root.actionError = "";
                // The source may have changed while the native call was running.
                root.attempted = "";
                Qt.callLater(root.apply);
            } catch (e) {
                root.actionError = String(e.message ?? e);
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
        if (Battery.available)
            powerChanged(!onBattery);
        refresh();
    }

    Connections {
        target: UPower
        function onOnBatteryChanged(): void {
            if (root.ready && Battery.available)
                root.powerChanged(!root.onBattery);
            root.refresh();
        }
    }
    Connections {
        target: Battery
        function onAvailableChanged(): void {
            if (root.ready && Battery.available)
                root.powerChanged(!root.onBattery);
            root.refresh();
        }
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
