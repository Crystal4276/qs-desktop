#!/usr/bin/env python3
"""Test the real Idle service with fake logind commands; never suspend or authenticate."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

if '--private-bus' not in sys.argv:
    raise SystemExit(subprocess.call(['dbus-run-session', '--', sys.executable, __file__, '--private-bus']))
repo = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-sleep-') as tmp:
    root = Path(tmp)
    for name in ('services', 'config', 'bin', 'runtime'):
        (root / name).mkdir(mode=0o700)
    shutil.copy2(repo / 'services/Idle.qml', root / 'services/Idle.qml')
    (root / 'config/Settings.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { readonly property var idle: ({ timeout: 0, lockBeforeSleep: true }) }\n')
    (root / 'services/Battery.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool available: false }\n')
    (root / 'services/Compositor.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool isHyprland: false; property var outputs: []; function setPower(names, on) {} }\n')
    (root / 'services/Session.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool locked: false; property int requests: 0; function lock() { requests++; } }\n')
    (root / 'shell.qml').write_text('''import Quickshell
import Quickshell.Io
import qs.services
ShellRoot {
    readonly property var service: Idle
    IpcHandler {
        target: "test"
        function state(): string { return JSON.stringify({holding: Idle.holding, locked: Session.locked, requests: Session.requests}); }
        function secure(value: bool): void { Session.locked = value; }
    }
}
''')
    # gdbus reads a private FIFO. systemd-inhibit simply stays alive until released/killed.
    fake = '''#!{python}
import os, signal, time
from pathlib import Path
r=Path(os.environ['SLEEP_TEST_ROOT'])
name=Path(__file__).name
with (r/(name+'.pids')).open('a') as f: f.write(str(os.getpid())+'\\n')
if name == 'gdbus':
    with os.fdopen(os.open(r/'events', os.O_RDWR)) as f:
        for line in f: print(line, end='', flush=True)
else:
    while True: signal.pause()
'''.format(python=sys.executable)
    for name in ('gdbus', 'systemd-inhibit'):
        p = root / 'bin' / name
        p.write_text(fake)
        p.chmod(0o755)
    os.mkfifo(root / 'events')
    fifo = os.open(root / 'events', os.O_RDWR | os.O_NONBLOCK)
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QS_TEST='1', SLEEP_TEST_ROOT=tmp,
        PATH=str(root / 'bin') + ':' + os.environ['PATH'], XDG_RUNTIME_DIR=str(root / 'runtime'),
        XDG_STATE_HOME=str(root / 'state'), XDG_CACHE_HOME=str(root / 'cache'))
    for key in ('QS_IDLE_SOCKET', 'QS_LOCK_STATE', 'SWAYSOCK', 'I3SOCK', 'HYPRLAND_INSTANCE_SIGNATURE'):
        env.pop(key, None)
    with (root / 'qs.log').open('w+') as log:
        qs = subprocess.Popen(['qs', '-p', str(root)], env=env, stdout=log, stderr=log, start_new_session=True)
        def ipc(method, *args):
            r = subprocess.run(['qs', 'ipc', '--pid', str(qs.pid), 'call', 'test', method, *args], env=env,
                capture_output=True, text=True, timeout=3)
            if r.returncode: raise RuntimeError(r.stderr)
            return r.stdout.strip()
        def until(predicate, seconds=8):
            deadline=time.monotonic()+seconds
            while time.monotonic()<deadline:
                try:
                    value=predicate()
                    if value: return value
                except (OSError, RuntimeError, ValueError): pass
                if qs.poll() is not None:
                    log.seek(0); raise AssertionError(log.read())
                time.sleep(.05)
            log.seek(0); raise AssertionError('condition timed out\n'+log.read())
        def pids(name):
            p=root/(name+'.pids')
            return list(map(int, p.read_text().split())) if p.exists() else []
        def alive(pid):
            try: os.kill(pid, 0); return True
            except ProcessLookupError: return False
        def event(value):
            os.write(fifo, f'/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep ({value},)\n'.encode())
        def state(): return json.loads(ipc('state'))
        try:
            until(lambda: pids('gdbus') and pids('systemd-inhibit'))
            until(state)
            event('true')
            until(lambda: state()['requests']==1)
            time.sleep(2.5)
            assert state()['holding'] and alive(pids('systemd-inhibit')[-1]), 'inhibition released before lock confirmation'
            ipc('secure', 'true')
            until(lambda: not state()['holding'])
            until(lambda: not alive(pids('systemd-inhibit')[-1]))
            count=len(pids('systemd-inhibit'))
            time.sleep(5.3)
            assert len(pids('systemd-inhibit'))==count, 'voluntary release restarted inhibitor'
            event('false')
            until(lambda: len(pids('systemd-inhibit'))>count)
            # Already locked: release immediately, then rearm on resume.
            event('true'); until(lambda: not state()['holding'])
            event('false'); until(lambda: state()['holding'])
            count=len(pids('systemd-inhibit'))
            until(lambda: alive(pids('systemd-inhibit')[-1]))
            os.kill(pids('systemd-inhibit')[-1], signal.SIGTERM)
            until(lambda: len(pids('systemd-inhibit'))>count)
            count=len(pids('gdbus'))
            os.kill(pids('gdbus')[-1], signal.SIGTERM)
            until(lambda: len(pids('gdbus'))>count)
            ipc('secure', 'false')
            event('true'); until(lambda: state()['requests']==2)
            ipc('secure', 'true'); until(lambda: not state()['holding'])
            until(lambda: not alive(pids('systemd-inhibit')[-1]))
            count=len(pids('systemd-inhibit'))
            time.sleep(5.3)
            assert len(pids('systemd-inhibit'))==count, 'recovered inhibitor ignored voluntary release'
        finally:
            os.killpg(qs.pid, signal.SIGTERM)
            qs.wait(timeout=5)
            os.close(fifo)
print('PASS sleep: delayed confirmation, voluntary release, resume, process recovery, subsequent lock')
