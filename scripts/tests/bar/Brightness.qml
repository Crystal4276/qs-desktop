pragma Singleton
import QtQuick
QtObject { property bool available: true; property int percent: 50; signal changedByKey()
 function step(v) {} }