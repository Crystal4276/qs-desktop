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
        property var networks: ({values: (Backend.joined ? [Backend.network] : []).concat(Backend.listed)})
    }
    property QtObject ethernet: QtObject {
        property int type: DeviceType.Wired
        property bool connected: Backend.wired
        property bool hasLink: Backend.wired
        property string name: "test-ethernet"
        property int state: connected ? ConnectionState.Connected : ConnectionState.Disconnected
        property int linkSpeed: 1000
        property string address: ""
        property var network: null
    }
    property var devices: ({values: [wifi, ethernet]})
    function checkConnectivity() { checks++; }
    // Formulaires du panneau : réseau entreprise (802.1X) et WPA, hors liste ; appels enregistrés.
    property var calls: []
    property bool silentWrites: false
    property FakeWifi enterprise: FakeWifi { name: "Campus" }
    property FakeWifi library: FakeWifi { name: "Library" }
    property FakeWifi personal: FakeWifi { name: "Home"; security: WifiSecurityType.Wpa2Psk }
    property var temp: null   // réseau qui disparaît (hors de portée) ; sans parent (un singleton parent fait planter Qt)
    property Component profileComponent: Component { FakeProfile {} }
    property Component wifiComponent: Component { FakeWifi {} }
    // Réseaux factices ajoutés à la liste surveillée par le service (panneau détruit : sa liste n'accepte que des WifiNetwork).
    property var listed: []
    // Profil apparu (NetworkManager après `nmcli connection add`).
    function addProfile(network, uuid, map) {
        network.nmSettings = network.nmSettings.concat([profileComponent.createObject(network, { network: network, uuid: uuid, map: map })]);
    }
}
