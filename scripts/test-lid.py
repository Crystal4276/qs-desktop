#!/usr/bin/env python3
"""Exercise real Lid.qml on a private bus with simulated lid, resumes, outputs and suspend."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

repo = Path(__file__).resolve().parents[1]
HOLDOFF = 4  # seconds; 30 in Lid.qml (logind's HoldoffTimeoutSec)
STEP = 1.3   # settle (500 ms) + IPC margin
failures = []


def check(name, ok, detail=''):
    print(('ok    ' if ok else 'FAIL  ') + name + ('' if ok else f'  {detail}'))
    if not ok:
        failures.append(name)


with tempfile.TemporaryDirectory(prefix='qs-test-lid-') as temp:
    r = Path(temp)
    for d in ('services', 'scripts', 'runtime'):
        (r/d).mkdir()
    lid_qml = (repo/'services/Lid.qml').read_text()
    (r/'services/Lid.qml').write_text(lid_qml.replace('interval: 30000', f'interval: {HOLDOFF * 1000}'))
    # The bridge has the real wire protocol but reads only a private FIFO.
    (r/'scripts/lid-state.py').write_text('import os\nwith os.fdopen(os.open(' + repr(str(r/'events'))
                                          + ', os.O_RDWR)) as f:\n for line in f: print(line, end="", flush=True)\n')
    os.mkfifo(r/'events')
    fifo = os.open(r/'events', os.O_RDWR | os.O_NONBLOCK)
    (r/'services/Compositor.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property bool isSway: true
 property bool isHyprland: false
 property var outputs: []
 property var connectedOutputs: []
 property bool fail: false
 property int queries: 0
 property var actions: []
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
    (r/'shell.qml').write_text('''import Quickshell
import Quickshell.Io
import qs.services
ShellRoot {
 property var service: Lid
 IpcHandler {
  target: "test"
  function state(): string { return JSON.stringify({requests: Session.requests, actions: Compositor.actions, queries: Compositor.queries}); }
  // Active displays (Compositor.outputs) follow the connected ones, as the compositor reports them.
  function outputs(rows: string): void { const all = JSON.parse(rows).rows; Compositor.connectedOutputs = all;
   Compositor.outputs = all.filter(o => o.enabled).map(o => ({name: o.name})); }
  function changing(): void { Compositor.outputsChanging(); }
  function fail(value: bool): void { Compositor.fail = value; }
 }
}
''')
    # No reload popup: offscreen has no window backend, and its failure leaves IPC refusing queries after a reload.
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QS_NO_RELOAD_POPUP='1', XDG_RUNTIME_DIR=str(r/'runtime'),
               XDG_CACHE_HOME=str(r/'cache'), XDG_STATE_HOME=str(r/'state'))
    env.pop('QS_TEST', None)
    env.pop('WAYLAND_DISPLAY', None)
    with (r/'log').open('w+') as log:
        proc = subprocess.Popen(['dbus-run-session', '--', 'qs', '-p', str(r)], env=env,
                                stdout=log, stderr=log, start_new_session=True)
        try:
            pid = ''
            for _ in range(100):
                pid = subprocess.run(['pgrep', '-P', str(proc.pid), '-x', 'qs'], capture_output=True, text=True).stdout.strip()
                if pid and subprocess.run(['qs', 'ipc', '--pid', pid, 'call', 'test', 'state'], env=env,
                                          capture_output=True).returncode == 0:
                    break
                time.sleep(.1)
            else:
                raise SystemExit('qs did not start')

            def ipc(method, *args):
                return subprocess.check_output(['qs', 'ipc', '--pid', pid, 'call', 'test', method, *args], env=env,
                                               text=True, stderr=subprocess.DEVNULL).strip()

            def state(): return json.loads(ipc('state'))

            def lid(closed, present=True, ready=True, **extra):
                os.write(fifo, (json.dumps(dict(ready=ready, present=present, closed=closed, **extra)) + '\n').encode())
                time.sleep(STEP)

            def reload():
                # Real hot reload: Quickshell watches the copy; singletons (fakes included) start afresh.
                text = (r/'services/Lid.qml').read_text()
                before = (r/'log').read_text().count('Configuration Loaded')
                (r/'services/Lid.qml').write_text(text + '\n// reload\n')
                for _ in range(100):
                    if (r/'log').read_text().count('Configuration Loaded') > before:
                        break
                    time.sleep(.1)
                time.sleep(STEP)
                return (r/'log').read_text().count('Configuration Loaded') > before

            def outputs(*rows):
                ipc('outputs', json.dumps(dict(rows=list(rows))))
                time.sleep(STEP)

            panel = dict(name='eDP-1', internal=True, enabled=True)
            panel_off = dict(panel, enabled=False)
            ext = dict(name='HDMI-A-1', internal=False, enabled=True)

            outputs(panel); lid(False)
            check('lid open: no display query', state()['queries'] == 0, state())
            lid(True)
            check('closed without external: suspend', state()['requests'] == 1, state())
            lid(True)
            check('repeated state: one request', state()['requests'] == 1, state())
            time.sleep(HOLDOFF)
            check('no sleep after the request: retried after the holdoff', state()['requests'] == 2, state())
            lid(False)

            outputs(panel, ext); lid(True)
            check('closed with external: panel disabled', state()['actions'][-1:] == [dict(name='eDP-1', enabled=False, rule='saved:eDP-1')], state())
            outputs(panel_off, ext)
            lid(False)
            check('reopened: panel restored', state()['actions'][-1:] == [dict(name='eDP-1', enabled=True, rule='saved:eDP-1')], state())
            outputs(panel, ext)
            s = state(); outputs(panel_off, ext); lid(False)
            check('lid open: panel disabled by the user left alone',
                  len(state()['actions']) == len(s['actions']) and state()['queries'] == s['queries'], state())

            outputs(panel, dict(ext, enabled=False)); lid(True)
            check('disabled external does not count: suspend', state()['requests'] == 3, state())
            check('disabled external: panel kept', not any(a.get('enabled') is False for a in state()['actions'][len(s['actions']):]), state())
            lid(False)

            # Resume reported by the bridge, no request pending: the dock's displays are not there yet.
            outputs(panel); lid(True)
            check('closed again: suspend', state()['requests'] == 4, state())
            lid(False)
            lid(True, resumed=True)
            check('resume lid closed: holdoff, no immediate suspend', state()['requests'] == 4, state())
            outputs(panel, ext)
            check('dock found during the holdoff: panel disabled', state()['actions'][-1].get('enabled') is False, state())
            time.sleep(HOLDOFF)
            check('docked after the holdoff: no suspend', state()['requests'] == 4, state())

            ipc('fail', 'true'); outputs(panel_off)
            check('failed read: no suspend', state()['requests'] == 4, state())
            ipc('fail', 'false'); ipc('changing'); time.sleep(STEP)
            check('read again (outputsChanging): last external unplugged, suspend', state()['requests'] == 5, state())

            lid(False); lid(True, present=False); lid(True, ready=False)
            check('no lid or bridge not ready: nothing', state()['requests'] == 5, state())

            # Panel off before closing (yours, or left by a shell that lost its state): opening the lid turns it on.
            outputs(panel_off, ext); lid(True)
            n = len(state()['actions'])
            lid(False)
            check('panel off before closing: restored on opening', 'restore' in (state()['actions'][n:] or [{}])[-1], state())

            # QML reload while docked, panel disabled by Lid: its rule survives the new engine.
            outputs(panel, ext); lid(True)
            check('reload test: panel disabled', state()['actions'][-1:] == [dict(name='eDP-1', enabled=False, rule='saved:eDP-1')], state())
            check('reload test: hot reload done', reload())
            outputs(panel_off, ext); lid(False)
            check('after a QML reload: panel restored with its saved rule',
                  state()['actions'] == [dict(name='eDP-1', enabled=True, rule='saved:eDP-1')], state())
        finally:
            os.killpg(proc.pid, signal.SIGTERM); proc.wait(timeout=5); os.close(fifo)
            log.seek(0); text = log.read()
            if 'ERROR' in text or 'WARN' in text:
                print(text)
                failures.append('QML warnings')
print('PASS lid' if not failures else f'{len(failures)} failure(s)')
sys.exit(1 if failures else 0)
