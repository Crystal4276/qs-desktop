#!/usr/bin/env python3
"""Real IdleMonitor and session lock on isolated Sway; no real suspension or PAM."""
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]


def run(*args, env):
    return subprocess.check_output(args, env=env, text=True, timeout=5).strip()


def test(work):
    root = work / 'shell'
    for name in ('services', 'config'):
        (root / name).mkdir(parents=True)
    shutil.copy2(REPO / 'services/Idle.qml', root / 'services/Idle.qml')
    (root / 'config/Settings.qml').write_text('''pragma Singleton
import QtQuick
QtObject { property var idle: ({timeout: 0, lockBeforeSleep: false, lockOnIdle: null}) }
''')
    (root / 'services/Battery.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool available: true }\n')
    (root / 'services/Session.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    property bool locked: false
    property bool lockActive: false
    property bool confirm: false
    property int requests: 0
    function lock() { requests++; lockActive = true; }
}
''')
    (root / 'services/Compositor.qml').write_text('''pragma Singleton
import Quickshell
Singleton {
    property bool isHyprland: false
    property var outputs: []
    property int offRequests: 0
    function setPower(names, on) {
        if (!on) offRequests++;
        Quickshell.execDetached(["swaymsg", "output", "*", "power", on ? "on" : "off"]);
    }
}
''')
    (root / 'shell.qml').write_text('''import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
ShellRoot {
    readonly property var service: Idle
    PanelWindow { id: panel; implicitWidth: 10; implicitHeight: 10; exclusiveZone: 0 }
    IdleInhibitor { id: inhibit; window: panel; enabled: false }
    WlSessionLock {
        locked: Session.lockActive && Session.confirm
        onSecureChanged: Session.locked = secure
        WlSessionLockSurface {}
    }
    IpcHandler {
        target: "test"
        function state(): string { return JSON.stringify({lockOnIdle: Idle.lockOnIdle,
            waiting: Idle.waitingIdleLock, locked: Session.locked, requests: Session.requests, off: Compositor.offRequests}); }
        function configure(battery: bool, policy: string, seconds: int): void {
            Battery.available = battery;
            Settings.idle = {timeout: seconds, lockBeforeSleep: false, lockOnIdle: JSON.parse(policy)};
        }
        function confirm(): void { Session.confirm = true; }
        function reset(): void {
            Settings.idle = {timeout: 0, lockBeforeSleep: false, lockOnIdle: null};
            Session.lockActive = false; Session.confirm = false;
        }
        function retry(): void { Idle.screensOff(); }
        function fail(): void { Session.lockActive = false; }
        function waylandInhibit(value: bool): void { inhibit.enabled = value; }
        function dbusInhibit(count: int): void { Idle.dbusInhibitors = count; }
    }
}
''')
    runtime = work / 'runtime'
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), WLR_BACKENDS='headless', WLR_RENDERER='pixman',
        WLR_LIBINPUT_NO_DEVICES='1', QS_TEST='1', GIO_USE_VFS='local', GVFS_DISABLE_FUSE='1',
        XDG_STATE_HOME=str(work / 'state'), XDG_CACHE_HOME=str(work / 'cache'))
    for key in ('SWAYSOCK', 'I3SOCK', 'HYPRLAND_INSTANCE_SIGNATURE', 'WAYLAND_DISPLAY', 'DISPLAY', 'QS_IDLE_SOCKET', 'QS_LOCK_STATE'):
        env.pop(key, None)
    config = work / 'sway.conf'
    config.write_text('xwayland disable\nswaybg_command -\noutput HEADLESS-1 mode 800x600\n')
    sway = subprocess.Popen(['sway', '-c', str(config)], env=env, stdout=(work / 'sway.log').open('w'), stderr=subprocess.STDOUT)
    shell = None
    try:
        sock = runtime / f'sway-ipc.{os.getuid()}.{sway.pid}.sock'
        deadline = time.monotonic() + 8
        while not sock.exists() and time.monotonic() < deadline:
            if sway.poll() is not None: raise AssertionError('Sway did not start')
            time.sleep(.05)
        env.update(SWAYSOCK=str(sock), I3SOCK=str(sock))
        run('swaymsg', 'exec', f'echo $WAYLAND_DISPLAY > {work}/wayland', env=env)
        while not (work / 'wayland').exists() and time.monotonic() < deadline: time.sleep(.05)
        env.update(WAYLAND_DISPLAY=(work / 'wayland').read_text().strip(), QT_QPA_PLATFORM='wayland')
        shell = subprocess.Popen(['dbus-run-session', '--', 'qs', '-p', str(root)], env=env,
            stdout=(work / 'qs.log').open('w'), stderr=subprocess.STDOUT, start_new_session=True)
        pid = None
        def ipc(method, *args, target='test'):
            return run('qs', 'ipc', '--pid', pid, 'call', target, method, *map(str, args), env=env)
        def until(predicate):
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                try:
                    if predicate(): return
                except (subprocess.SubprocessError, ValueError): pass
                if shell.poll() is not None: raise AssertionError('Quickshell exited')
                time.sleep(.05)
            raise AssertionError('condition timed out')
        until(lambda: bool(run('pgrep', '-P', str(shell.pid), 'qs', env=env)))
        pid = run('pgrep', '-P', str(shell.pid), 'qs', env=env)
        def state(): return json.loads(ipc('state'))
        def powered(): return json.loads(run('swaymsg', '-t', 'get_outputs', '-r', env=env))[0]['power']
        def reset():
            ipc('reset'); until(lambda: not state()['locked'] and not state()['waiting'] and powered())
        def configure(battery=True, policy='null', seconds=1):
            ipc('configure', str(battery).lower(), policy, seconds)
        until(state)
        configure()
        until(lambda: state()['waiting'])
        assert state()['requests'] == 1 and state()['off'] == 0 and powered(), state()
        ipc('retry')
        assert state()['requests'] == 1, 'duplicate lock request'
        time.sleep(2.2)
        assert powered() and state()['off'] == 0, 'powered off before confirmation'
        ipc('confirm'); until(lambda: state()['locked'] and not powered())
        reset()
        # Input while waiting must cancel deferred DPMS, while preserving the requested lock.
        configure(); until(lambda: state()['waiting'])
        off = state()['off']
        run('swaymsg', 'seat', 'seat0', 'cursor', 'move', '1', '0', env=env)
        until(lambda: not state()['waiting'])
        ipc('confirm'); until(lambda: state()['locked'])
        assert state()['off'] == off and powered(), state()
        reset()
        # Disabling monitoring while waiting also cancels deferred DPMS.
        configure(); until(lambda: state()['waiting'])
        off = state()['off']
        configure(seconds=0); until(lambda: not state()['waiting'])
        ipc('confirm'); until(lambda: state()['locked'])
        assert state()['off'] == off and powered(), state()
        reset()
        configure(); until(lambda: state()['waiting'])
        ipc('fail'); time.sleep(1.2)
        assert powered() and state()['off'] == off, 'failed lock powered off'
        reset()
        # Desktop default and explicit opt-out: DPMS without a lock request.
        for battery, policy in ((False, 'null'), (True, 'false')):
            before = state()['requests']; configure(battery, policy)
            until(lambda: not powered())
            assert state()['requests'] == before and not state()['locked'], state()
            reset()
        configure(False, 'true'); until(lambda: state()['waiting'])
        assert json.loads(ipc('state', target='idle'))['lockOnIdle'] is True
        ipc('confirm'); until(lambda: state()['locked'] and not powered())
        # Already locked: no additional lock request on next inactivity cycle.
        before = state()['requests']; configure(False, 'true', 0); until(powered)
        configure(False, 'true'); until(lambda: not powered())
        assert state()['requests'] == before, state()
        reset()
        # Both existing inhibition mechanisms prevent idle lock and DPMS.
        for method, value, clear in (('waylandInhibit', 'true', 'false'), ('dbusInhibit', '1', '0')):
            ipc(method, value); configure(); before = state()['requests']; time.sleep(2.2)
            assert state()['requests'] == before and powered(), state()
            ipc(method, clear); until(lambda: state()['waiting'])
            reset()
        before = state()['requests']; time.sleep(1.2)
        assert state()['requests'] == before and powered(), 'zero timeout locked'
        log = (work / 'qs.log').read_text()
        unexpected = [line for line in log.splitlines() if re.search(r'\b(?:WARN|ERROR)\b', line)
            and 'qt.qpa.services: Failed to register with host portal' not in line]
        assert not unexpected, '\n'.join(unexpected)
        print('PASS idle lock: native inactivity/secure lock/DPMS, policies, cancellation, failure, inhibitors, zero timeout')
    finally:
        if shell:
            try: os.killpg(shell.pid, signal.SIGTERM)
            except ProcessLookupError: pass
            shell.wait(timeout=5)
        sway.terminate(); sway.wait(timeout=5)


if __name__ == '__main__':
    with tempfile.TemporaryDirectory(prefix='qs-idle-lock-') as tmp:
        try: test(Path(tmp))
        except Exception:
            for name in ('qs.log', 'sway.log'):
                p = Path(tmp) / name
                if p.exists(): print(p.read_text())
            raise
