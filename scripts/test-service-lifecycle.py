#!/usr/bin/env python3
"""Exercise Bluez/FileOps through native signals and reloads on private benches.
All system/session D-Bus traffic goes to a fake bus; commands and notifications
are stubbed. No real Bluetooth, power, VPN or file-operation actions.
"""
import argparse
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
FIXTURES = REPO / 'scripts/tests/service-lifecycle'


def run(*args, env):
    return subprocess.check_output(args, env=env, text=True, stderr=subprocess.PIPE, timeout=10).strip()


def wait_for(predicate, description):
    for _ in range(120):
        value = predicate()
        if value:
            return value
        time.sleep(.05)
    raise AssertionError('Timed out: ' + description)


def test(work, source, compositor, expect_warnings):
    root = work / 'shell'
    shutil.copytree(source, root, ignore=shutil.ignore_patterns('.git', '.shots', '.agents', '.codex', '.aws', '__pycache__'))
    shutil.copy2(FIXTURES / 'probe.qml', root / 'probe.qml')
    # Keep runtime paths short enough for Hyprland's Unix sockets.
    runtime = work / 'r'
    runtime.mkdir(mode=0o700)
    bindir = work / 'bin'
    bindir.mkdir()
    for name in ('nordvpn', 'tailscale', 'zerotier-cli', 'systemctl', 'brightnessctl'):
        p = bindir / name
        p.write_text('#!/bin/sh\nexit 1\n')
        p.chmod(0o755)
    notifications = work / 'notifications.jsonl'
    stub = bindir / 'notify-send'
    stub.write_text('''#!/usr/bin/python3
import sys,json,os,signal,time
path=os.environ['QS_TEST_NOTIFICATIONS']
def record(event):
    with open(path,'a') as f:
        f.write(json.dumps({'event':event,'argv':sys.argv[1:],'pid':os.getpid()})+'\\n')
def done(signum,frame):
    record('closed');sys.exit(0)
signal.signal(signal.SIGINT,done);signal.signal(signal.SIGTERM,done);record('sent')
if '--print-id' in sys.argv:print('123',flush=True)
if '--wait' in sys.argv:
    time.sleep(15)
''')
    stub.chmod(0o755)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), XDG_STATE_HOME=str(work / 'state'),
               XDG_CACHE_HOME=str(work / 'cache'), QS_TEST='1', GIO_USE_VFS='local', GVFS_DISABLE_FUSE='1',
               PATH=str(bindir) + ':' + os.environ['PATH'], QS_TEST_NOTIFICATIONS=str(notifications), NO_COLOR='1',
               NO_AT_BRIDGE='1')
    for key in ('SWAYSOCK', 'I3SOCK', 'HYPRLAND_INSTANCE_SIGNATURE', 'WAYLAND_DISPLAY', 'DISPLAY', 'QS_IDLE_SOCKET', 'QS_LOCK_STATE'):
        env.pop(key, None)
    processes = []

    def start(args, name, process_env=None, pipe=False):
        with (work / (name + '.log')).open('w') as log:
            p = subprocess.Popen(args, env=process_env or env, text=True, stdout=subprocess.PIPE if pipe else log,
                                 stderr=log, start_new_session=True)
        processes.append(p)
        return p

    def stop(p):
        if p.poll() is None:
            os.killpg(p.pid, signal.SIGTERM)
            try:
                p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(p.pid, signal.SIGKILL)
                p.wait(timeout=5)

    def events():
        return [json.loads(line) for line in notifications.read_text().splitlines()] if notifications.exists() else []

    def notices(summary, event='sent'):
        return [n for n in events() if n['event'] == event and summary in n['argv']]

    try:
        bus = start(['dbus-daemon', '--session', '--nofork', '--print-address=1'], 'bus', pipe=True)
        address = bus.stdout.readline().strip()
        assert address, 'private bus did not start'
        env.update(DBUS_SESSION_BUS_ADDRESS=address, DBUS_SYSTEM_BUS_ADDRESS=address)
        bluez = start(['python3', str(FIXTURES / 'bluez.py'), address], 'bluez', pipe=True)
        assert bluez.stdout.readline().strip() == 'READY', 'fake BlueZ did not start'

        def control(action):
            run('gdbus', 'call', '--address', address, '--dest', 'org.bluez', '--object-path', '/',
                '--method', 'org.test.Control.Run', action, env=env)

        if compositor == 'sway':
            config = work / 'sway.conf'
            config.write_text('xwayland disable\nswaybg_command -\noutput HEADLESS-1 mode 1280x800\n')
            env.update(WLR_BACKENDS='headless', WLR_RENDERER='pixman', WLR_LIBINPUT_NO_DEVICES='1')
            comp = start(['sway', '-c', str(config)], 'compositor')
            sock = runtime / f'sway-ipc.{os.getuid()}.{comp.pid}.sock'
            wait_for(sock.exists, 'isolated Sway')
            env.update(SWAYSOCK=str(sock), I3SOCK=str(sock))
        else:
            config = work / 'hyprland.lua'
            config.write_text('hl.config({misc={disable_hyprland_logo=true,disable_splash_rendering=true,disable_autoreload=true},'
                              'ecosystem={no_update_news=true,no_donation_nag=true},animations={enabled=false},cursor={no_warps=true}})\n')
            nested = dict(env, AQ_BACKEND='wayland', WAYLAND_DISPLAY=str(Path(os.environ['XDG_RUNTIME_DIR']) / os.environ['WAYLAND_DISPLAY']))
            comp = start(['Hyprland', '-c', str(config)], 'compositor', nested)
            sock = wait_for(lambda: next((runtime / 'hypr').glob('*/.socket.sock'), None), 'nested Hyprland')
            env['HYPRLAND_INSTANCE_SIGNATURE'] = sock.parent.name
        display = wait_for(lambda: next((p for p in runtime.glob('wayland-*') if p.is_socket()), None), 'test Wayland socket')
        env.update(WAYLAND_DISPLAY=display.name, QT_QPA_PLATFORM='wayland', GDK_BACKEND='wayland')
        if compositor == 'hyprland':
            run('hyprctl', 'output', 'create', 'headless', env=env)
            time.sleep(.2)
            run('hyprctl', 'eval', 'hl.monitor({output="HEADLESS-1",mode="1280x800@60",position="0x0",scale=1}); '
                'hl.monitor({output="WAYLAND-1",disabled=true})', env=env)
        shell = start(['qs', '-p', str(root / 'probe.qml')], 'probe')
        wait_for(lambda: 'Configuration Loaded' in (work / 'probe.log').read_text(), 'probe startup')

        def ipc(method):
            return run('qs', 'ipc', '--pid', str(shell.pid), 'call', 'probe', method, env=env)

        def state():
            return json.loads(ipc('state'))

        def check(predicate):
            def ready():
                value = state()
                assert type(value['busy']) is bool, value
                return value if predicate(value) else None
            return wait_for(ready, 'service state')

        check(lambda s: not s['available'] and not s['busy'])
        control('add')
        check(lambda s: s['available'] and s['enabled'] and len(s['devices']) == 1 and not s['busy'])
        for action, busy in [('enabling', True), ('enabled', False), ('disabling', True), ('disabled', False), ('enabled', False)]:
            control(action)
            check(lambda s: s['busy'] == busy)
        ipc('connect')
        check(lambda s: s['busy'])
        control('connected')
        check(lambda s: not s['busy'] and s['devices'][0]['connected'])
        ipc('disconnect')
        check(lambda s: s['busy'])
        control('disconnected')
        check(lambda s: not s['busy'] and not s['devices'][0]['connected'])
        ipc('automatic')
        check(lambda s: not s['busy'] and s['devices'][0]['state'] == 3)
        ipc('requested')  # The user-request flag makes the automatic attempt visible.
        check(lambda s: s['busy'])
        control('connected')
        check(lambda s: not s['busy'])
        ipc('disconnect')
        control('disconnected')
        check(lambda s: not s['busy'])
        control('unpaired')
        time.sleep(.1)
        ipc('pair')
        check(lambda s: s['busy'])
        control('paired')
        check(lambda s: not s['busy'])
        control('remove')
        check(lambda s: not s['available'] and not s['busy'] and not s['devices'])

        def window(name, title, app='nemo', chatter=False):
            command = work / (name + '.title')
            args = ['python3', str(FIXTURES / 'window.py'), str(command), title, app]
            p = start(args + (['chatter'] if chatter else []), name)
            return p, command

        client, title = window('progress', '10% Copying "A" to "B"')
        check(lambda s: any(w['title'] == '10% Copying "A" to "B"' for w in s['windows']))
        title.write_text('90% Copying "C" to "D"')
        check(lambda s: any(w['title'] == '90% Copying "C" to "D"' for w in s['windows']))
        title.write_text('CLOSE')
        client.wait(timeout=5)
        wait_for(lambda: notices('File Operations'), 'progress completion notification')
        assert 'C → D' in notices('File Operations')[-1]['argv'][-1], events()
        question, question_title = window('question', '')
        check(lambda s: any(w['app'] == 'nemo' and w['title'] == '' for w in s['windows']))
        front, front_title = window('front', 'Other application', 'other')
        check(lambda s: any(w['app'] == 'other' and w['active'] for w in s['windows']))
        wait_for(lambda: notices('Waiting for your answer'), 'question notification')
        assert '--urgency=critical' in notices('Waiting for your answer')[-1]['argv'], events()
        question_title.write_text('CLOSE')
        question.wait(timeout=5)
        wait_for(lambda: notices('Waiting for your answer', 'closed'), 'question notification withdrawn')
        front_title.write_text('CLOSE')
        front.wait(timeout=5)
        probe_log = (work / 'probe.log').read_text()
        assert not re.search(r'WARN scene:|ERROR:|TypeError|ReferenceError', probe_log), probe_log
        stop(shell)
        print('PASS native Bluetooth states, silent reconnection/user request, pairing; latest progress title and question withdrawal', flush=True)

        # No probe in the complete desktop: native changes must continue throughout
        # old-engine interruption. Static properties do not reproduce this race.
        control('add')
        control('chatter')
        for i in range(2):
            window('chatter' + str(i), '50% Copying "A" to "B"', 'nemo' if i == 0 else 'other', True)
        time.sleep(.3)
        full = start(['qs', '-p', str(root)], 'full')
        log_path = work / 'full.log'
        wait_for(lambda: 'Configuration Loaded' in log_path.read_text(), 'full desktop startup')
        blocks = run('qs', 'ipc', '--pid', str(full.pid), 'call', 'outputs', 'blocks', env=env)
        assert 'HEADLESS-' in blocks, blocks
        for i in range(6):
            qml = root / 'shell.qml'
            qml.write_text(qml.read_text() + f'\n// lifecycle reload {i}\n')
            wait_for(lambda: log_path.read_text().count('Configuration Loaded') >= i + 2, 'complete reload')
            time.sleep(.25)
        time.sleep(.3)
        log = log_path.read_text()
        assert full.poll() is None and 'Failed to load configuration' not in log, log
        counts = {name: len(re.findall(r'WARN scene:.*' + name + r'.*Unable to assign', log)) for name in ('Bluez.qml', 'FileOps.qml')}
        if expect_warnings:
            assert all(counts.values()), counts
        else:
            assert not any(counts.values()), log
            # Existing Poller/Tailscale teardown race, also seen on the unchanged
            # source. Keep it visible; this change is limited to Bluez/FileOps.
            scene = [line for line in log.splitlines() if 'WARN scene:' in line]
            assert all(re.search(r'@services/Tailscale.qml\[176:9\]: Unable to assign \[undefined\] to bool$', line) for line in scene), log
            assert not re.search(r'TypeError|ReferenceError', log), log
        # These diagnostics come from the deliberately absent system services and
        # the host's pre-existing desktop entries; leave them visible in the log.
        print('PASS full desktop: six reloads with native updates; warning counts', counts, flush=True)
        print('Full-start diagnostics:', '\n'.join(sorted(set(line for line in log.splitlines()
              if ('WARN' in line or 'ERROR' in line) and not any(name in line for name in counts)))), flush=True)
    finally:
        for p in reversed(processes):
            stop(p)
        for event in events():
            pid = event['pid']
            try:
                if str(stub).encode() in Path(f'/proc/{pid}/cmdline').read_bytes():
                    os.kill(pid, signal.SIGTERM)
            except (ProcessLookupError, FileNotFoundError):
                pass


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compositor', choices=['sway', 'hyprland'], default='sway')
    parser.add_argument('--source', type=Path, default=REPO, help='source tree for a before/after counter-test')
    parser.add_argument('--expect-warnings', action='store_true', help='require both original teardown warnings in the stress test')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='qsl-', dir='/tmp') as temporary:
        try:
            test(Path(temporary), args.source, args.compositor, args.expect_warnings)
        except Exception:
            for name in ('probe.log', 'full.log', 'bluez.log', 'compositor.log'):
                path = Path(temporary) / name
                if path.exists():
                    print(name + '\n' + path.read_text())
            raise
