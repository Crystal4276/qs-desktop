import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import qs.services
ShellRoot {
    property bool busy: Bluez.busy
    property string fileops: FileOps.summary
    IpcHandler {
        target: "probe"
        function state(): string {
            return JSON.stringify({available: Bluez.available, busy: Bluez.busy, enabled: Bluez.enabled,
                devices: Bluez.devices.map(d=>({name:d.name,state:d.state,connected:d.connected,busy:Bluez.isBusy(d)})),
                windows: ToplevelManager.toplevels.values.map(w=>({app:w.appId,title:w.title,active:w.activated}))});
        }
        function connect(): void { Bluez.connectDevice(Bluez.devices[0]); }
        function requested(): void { Bluez.requested = Bluez.withFlag(Bluez.requested, Bluez.devices[0].address, true); }
        function pair(): void { Bluez.devices[0].pair(); }
        function disconnect(): void { Bluez.disconnectDevice(Bluez.devices[0]); }
        function automatic(): void { Bluez.autoAttempts = Bluez.withFlag(Bluez.autoAttempts, Bluez.devices[0].address, true); Bluez.devices[0].connect(); }
    }
}
