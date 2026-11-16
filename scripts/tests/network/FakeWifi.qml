import QtQuick
import Quickshell.Networking
// Réseau Wi-Fi factice hors de la liste (Network.wifiNetworks) : connexions enregistrées dans Backend.calls, état piloté par le
// test.
QtObject {
    property string name
    property int security: WifiSecurityType.Wpa2Eap
    property int state: ConnectionState.Disconnected
    readonly property bool connected: state === ConnectionState.Connected
    property bool stateChanging: false
    property real signalStrength: 0.6
    property var nmSettings: []
    readonly property bool known: nmSettings.length > 0
    signal connectionFailed(int reason)
    function connect() { Backend.calls = Backend.calls.concat([["connect", ""]]); }
    function connectWithSettings(settings) {
        Backend.calls = Backend.calls.concat([["connect", settings.uuid]]);
        state = ConnectionState.Connecting;
    }
    function connectWithPsk(psk) { Backend.calls = Backend.calls.concat([["psk", psk]]); }
}
