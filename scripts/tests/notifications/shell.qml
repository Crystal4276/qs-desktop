import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.bar
ShellRoot {
    PanelWindow {
        id: bar
        anchors { top: true; left: true; right: true }
        implicitHeight: Theme.bar.exclusiveZone
        exclusiveZone: height
        Item { id: button; property bool hovered: false; x: 600; width: 32; height: 32 }
    }
    NotificationsPanel { id: panel; holdOpen: true }
    TestCase { id: events; parent: panel.frameItem; when: false }
    IpcHandler {
        target: "notification-test"
        function open(): void { panel.toggle(button, Qt.LeftButton); }
        function preview(): void { panel.preview(button, Qt.LeftButton); }
        function close(): void { panel.close(); }
        function fill(n: int): void {
            Notifs.clearHistory();
            for (let i=0;i<n;i++) Notifs.archive({summary:`Message ${i}`,appName:"Test",body:"A notification with some text to read. ".repeat(5),icon:"dialog-information",timestamp:Date.now()},false);
        }
        function quiet(on: bool): void { Notifs.setDoNotDisturb(on); }
        function media(on: bool): void { Media.player = on ? {trackTitle:"Example track",trackArtist:"Artist",trackAlbum:"Album"} : null; }
        function end(): void { panel.testList.contentY=panel.testList.contentHeight-panel.testList.height; }
        function expand(): void { panel.testList.contentItem.children[0].children.find(c=>c.entry!==undefined).expanded=true; }
        function remove(): void { Notifs.removeHistory(Notifs.history[0].key); }
        function clear(): void { Notifs.clearHistory(); }
        function wheel(): void { const l=panel.testList; events.mouseWheel(l,l.width/2,l.height/2,0,-120); }
        function drag(): void {
            const b=panel.testScrollbar, t=b.contentItem;
            events.mousePress(t,t.width/2,t.height/2);
            events.mouseMove(t,t.width/2,t.height/2+100,50);
            events.mouseRelease(t,t.width/2,t.height/2+100);
        }
        function tab(): void { events.keyClick(Qt.Key_Tab); }
        function keyboardEnd(): bool {
            panel.frameItem.forceActiveFocus();
            for (let i=0;i<250;i++) {
                events.keyClick(Qt.Key_Tab);
                for (let a=panel.frameItem.focusedItem;a;a=a.parent)
                    if (a.entry?.key===Notifs.history[0]?.key) return true;
            }
            return false;
        }
        function pressEscape(): void { events.keyClick(Qt.Key_Escape); }
        function shot(path: string): void { panel.frameItem.grabToImage(r=>r.saveToFile(path)); }
        function state(): string {
            const l=panel.testList,f=panel.frameItem;
            return JSON.stringify({count:Notifs.history.length,first:Notifs.history[0]?.summary,seen:!Notifs.unseen,
                quiet:Notifs.quiet.length,popups:Notifs.popups.length,visible:panel.visible,width:f.width,height:f.height,max:f.maxHeight,outerY:f.children[0].contentY,
                controlsY:panel.testControls.mapToItem(f,0,0).y,listHeight:l.height,content:l.contentHeight,y:l.contentY,
                scrollbar:panel.testScrollbar.visible,focus:!!f.focusedItem});
        }
    }
}
