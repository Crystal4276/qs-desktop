import QtQuick
// Profil NetworkManager factice (NMSettings) : écriture fusionnée groupe par groupe, secrets jamais relus, `settingsChanged`
// après coup comme la relecture D-Bus.
QtObject {
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
        Qt.callLater(() => settingsChanged(next));
    }
}
