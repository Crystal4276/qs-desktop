import QtQuick
// Profil NetworkManager factice (NMSettings) : écriture fusionnée groupe par groupe, secrets jamais relus, `settingsChanged`
// après coup comme la relecture D-Bus ; suppression enregistrée.
QtObject {
    property QtObject network
    property string uuid
    property var map: ({})
    signal settingsChanged(var settings)
    function read() { return map; }
    function write(values) {
        Backend.calls = Backend.calls.concat([["write", values]]);
        const next = JSON.parse(JSON.stringify(map));
        for (const group of Object.keys(values))
            next[group] = Object.assign(next[group] ?? {}, values[group]);
        if (next["802-1x"])
            delete next["802-1x"].password;
        map = next;
        if (!Backend.silentWrites)   // écriture sans réponse (garde-fou)
            Qt.callLater(() => settingsChanged(next));
    }
    function forget() {
        Backend.calls = Backend.calls.concat([["forget", uuid]]);
        network.nmSettings = network.nmSettings.filter(s => s !== this);
    }
}
