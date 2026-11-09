pragma Singleton
import QtQuick
QtObject { property bool available: true; property bool charging: false; property int percent: 70; property bool warning: false; function levelOf(p) { return 101; } function notifyLow(d,p,l) {} property int warningLevel: 30; property int rearmMargin: 10 }