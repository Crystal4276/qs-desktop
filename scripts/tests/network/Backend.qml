pragma Singleton
import QtQuick
import Quickshell.Networking
QtObject {
    property int backend: NetworkBackendType.NetworkManager
    property bool wifiEnabled: true
    property bool wifiHardwareEnabled: true
    property bool canCheckConnectivity: true
    property bool connectivityCheckEnabled: true
    property int connectivity: NetworkConnectivity.Full
    property int checks: 0
    property bool joined: true
    property bool wired: false
    property QtObject network: QtObject {
        property string name: "Guest Wi-Fi"
        property bool connected: Backend.joined
        property bool known: true
        property real signalStrength: 0.8
        property int security: WifiSecurityType.Open
        property int state: connected ? ConnectionState.Connected : ConnectionState.Disconnected
        function disconnect() { Backend.joined = false; }
    }
    property QtObject wifi: QtObject {
        property int type: DeviceType.Wifi
        property string name: "test-wifi"
        property bool scannerEnabled: false
        property var networks: ({values: Backend.joined ? [Backend.network] : []})
    }
    property QtObject ethernet: QtObject {
        property int type: DeviceType.Wired
        property bool connected: Backend.wired
        property bool hasLink: Backend.wired
        property string name: "test-ethernet"
    }
    property var devices: ({values: [wifi, ethernet]})
    function checkConnectivity() { checks++; }
}
