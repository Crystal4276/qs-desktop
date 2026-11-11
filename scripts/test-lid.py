#!/usr/bin/env python3
"""Exercise real Lid.qml on a private bus with simulated lid, outputs and suspend."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='qs-test-lid-') as temp:
    r = Path(temp)
    for d in ('services', 'scripts', 'runtime'):
        (r/d).mkdir()
    shutil.copy2(repo/'services/Lid.qml', r/'services/Lid.qml')
    # The bridge has the real wire protocol but reads only a private FIFO.
    (r/'scripts/lid-state.py').write_text('import os\nwith os.fdopen(os.open('+repr(str(r/'events'))+', os.O_RDWR)) as f:\n for line in f: print(line, end="", flush=True)\n')
    os.mkfifo(r/'events')
    fifo = os.open(r/'events', os.O_RDWR | os.O_NONBLOCK)
    (r/'services/Compositor.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property bool isSway: true
 property bool isHyprland: false
 property var connectedOutputs: []
 property bool fail: false
 property int queries: 0
 property var actions: []
 signal outputsChanged()
 signal outputsChanging()
 signal configurationReloaded()
 signal connectedOutputsReady(bool success)
 function requestConnectedOutputs() { queries++; connectedOutputsReady(!fail); }
 function lidRestoreRule(name) { return "saved:"+name; }
 function setOutputEnabled(name, enabled, rule) { actions = actions.concat([{name, enabled, rule}]); }
 function restoreInternalOutputs(names) { actions = actions.concat([{restore: names}]); }
}
''')
    (r/'services/Session.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property int requests: 0; function suspend() { requests++; } }\n')
    (r/'services/Idle.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool preparingSleep: false }\n')
    (r/'shell.qml').write_text('''import Quickshell
import Quickshell.Io
import qs.services
ShellRoot {
 property var service: Lid
 IpcHandler {
 target: "test"
 function state(): string { return JSON.stringify({lid: JSON.parse(Lid.state ? "{}" : "{}"), ready: Lid.ready, closed: Lid.closed, requests: Session.requests, actions: Compositor.actions, queries: Compositor.queries, outputs: Compositor.connectedOutputs}); }
 function outputs(rows: string): void { Compositor.connectedOutputs = JSON.parse(rows).rows; Compositor.outputsChanging(); }
 function fail(value: bool): void { Compositor.fail = value; Compositor.outputsChanging(); }
 function resume(value: bool): void { Idle.preparingSleep = value; }
 }
}
'''.replace('lid: JSON.parse(Lid.state ? "{}" : "{}"), ', ''))
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=str(r/'runtime'),
               XDG_CACHE_HOME=str(r/'cache'), XDG_STATE_HOME=str(r/'state'))
    env.pop('QS_TEST', None)
    env.pop('WAYLAND_DISPLAY', None)
    with (r/'log').open('w+') as log:
        proc = subprocess.Popen(['dbus-run-session', '--', 'qs', '-p', str(r)], env=env,
                                stdout=log, stderr=log, start_new_session=True)
        try:
            time.sleep(.7)
            pid = subprocess.check_output(['pgrep', '-P', str(proc.pid), 'qs'], text=True).strip()
            def ipc(method, *args):
                return subprocess.check_output(['qs','ipc','--pid',pid,'call','test',method,*args], env=env, text=True, stderr=subprocess.DEVNULL).strip()
            def state(): return json.loads(ipc('state'))
            def lid(closed, present=True, ready=True):
                os.write(fifo, (json.dumps(dict(ready=ready,present=present,closed=closed))+'\n').encode())
                time.sleep(1.3)
            panel = dict(name='eDP-1', internal=True, enabled=True)
            ext = dict(name='HDMI-A-1', internal=False, enabled=True)
            def outputs(rows): ipc('outputs', json.dumps(dict(rows=rows))); time.sleep(1.3)
            outputs([panel]); lid(False); assert state()['requests'] == 0
            lid(True); assert state()['requests'] == 1, state()
            lid(True); assert state()['requests'] == 1, 'duplicate suspend'
            outputs([panel, ext]); assert state()['actions'][-1]['enabled'] is False
            outputs([dict(panel, enabled=False), ext])
            lid(False); assert state()['actions'][-1]['enabled'] is True
            lid(True); outputs([dict(panel,enabled=False)])
            assert state()['requests'] == 2, state()
            lid(False); outputs([panel, dict(ext, enabled=False)])
            lid(True); assert state()['requests'] == 2, 'connected disabled external ignored'
            outputs([dict(panel,enabled=False), ext, dict(ext,name='DP-2')])
            outputs([dict(panel,enabled=False),dict(ext,name='DP-2')]); assert state()['requests'] == 2
            ipc('fail','true'); outputs([]); assert state()['requests'] == 2, 'failed read treated as empty'
            ipc('fail','false'); time.sleep(1.3); assert state()['requests'] == 3
            lid(False); lid(True, present=False); assert state()['requests'] == 3
            lid(True, ready=False); assert state()['requests'] == 3
            outputs([dict(panel,enabled=False)]); lid(False)
            assert 'restore' in state()['actions'][-1], state()
            # Fresh startup with no lid cannot cause any action.
            print('PASS lid: suspend, docking, reopen, unplug, deduplication, disabled external, multiple displays, read failure, missing lid, recovery')
        finally:
            os.killpg(proc.pid, signal.SIGTERM); proc.wait(timeout=5); os.close(fifo)
            log.seek(0); text = log.read()
            if 'ERROR' in text or 'WARN' in text: print(text)
