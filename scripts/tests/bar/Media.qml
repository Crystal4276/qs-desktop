pragma Singleton
import QtQuick
QtObject {
 property var player: ({ trackArtist: "Run The Jewels", trackTitle: "ooh la la (feat. extremely long title for sizing)" })
 property int extraIcons: 0
 property string playerName: "spotify"
 property bool paused: true
 function togglePlaying() {} function previous() {} function next() {} function shift(up) {}
 property real length: 0
 function refreshPosition() {} function seek(v) {} function step(v) {}
}