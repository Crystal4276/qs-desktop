import QtQuick
import Quickshell.Networking
// Réseau Wi-Fi factice hors de la liste (Network.wifiNetworks) : connexions enregistrées dans Backend.calls.
QtObject {
    property string name
    property int security: WifiSecurityType.Wpa2Eap
    property bool connected: false
    property bool stateChanging: false
    property int state: ConnectionState.Disconnected
    property real signalStrength: 0.6
    property var nmSettings: []
    readonly property bool known: nmSettings.length > 0
    signal connectionFailed(int reason)
    function connect() { Backend.calls = Backend.calls.concat([["connect", ""]]); }
    function connectWithSettings(settings) { Backend.calls = Backend.calls.concat([["connect", settings.uuid]]); }
    function connectWithPsk(psk) { Backend.calls = Backend.calls.concat([["psk", psk]]); }
}
