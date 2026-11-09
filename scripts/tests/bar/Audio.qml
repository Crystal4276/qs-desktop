pragma Singleton
import QtQuick
QtObject {
 property bool ready: true; property real volume: .5; property bool muted: false; property int percent: 50
 property var sink: null; property var source: null; property var sinks: []; property var sources: []; property var streams: []
 property string description: "Test"; property bool micMuted: false
 signal changedByKey(string kind)
 function toggleMute() {} function cycleSink() {} function step(v) {} function setVolume(v) {}
}