#!/usr/bin/env python3
"""Exercise real bar geometry in an isolated Sway with fake media/audio/battery.
No real session changes, battery discharge, notifications, or VPN actions.
Requires the existing Sway/Quickshell bench dependencies (DEVELOPMENT.md).
"""
import json
import os
import re
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.check_output(args, text=True, timeout=10, **kwargs).strip()


def test(work):
    root = work / 'shell'
    shutil.copytree(REPO, root, ignore=shutil.ignore_patterns('.git', '.shots', '.agents', '.codex', '__pycache__'))
    fixtures = REPO / 'scripts/tests/bar'
    for source in fixtures.glob('*.qml'):
        shutil.copy2(source, root / 'services' / source.name)
    # Always exercise the portable default, regardless of the test machine's overrides.
    (root / 'hosts' / f'{Path("/proc/sys/kernel/hostname").read_text().strip()}.json').write_text('{}')
    bar = root / 'modules/bar/Bar.qml'
    bar.write_text(bar.read_text().replace('import Quickshell.Wayland', 'import Quickshell.Wayland\nimport Quickshell.Io')
                   .replace('        // « Garder', (fixtures / 'probe.qml.inc').read_text() + '        // « Garder'))
    tray = root / 'modules/bar/Tray.qml'
    tray.write_text(tray.read_text().replace('        // Modules natifs,', '''        Repeater {
            model: Media.extraIcons
            Item { width: Theme.bar.trayIconSize; height: width }
        }
        // Modules natifs,'''))
    runtime = work / 'runtime'
    runtime.mkdir(mode=0o700)
    bindir = work / 'bin'
    bindir.mkdir()
    for name in ('nordvpn', 'systemctl', 'brightnessctl', 'notify-send'):
        target = bindir / name
        target.write_text('#!/bin/sh\nexit 1\n')
        target.chmod(0o755)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), WLR_BACKENDS='headless', WLR_RENDERER='pixman',
               WLR_LIBINPUT_NO_DEVICES='1', QS_TEST='1', GIO_USE_VFS='local', GVFS_DISABLE_FUSE='1',
               XDG_STATE_HOME=str(work / 'state'), XDG_CACHE_HOME=str(work / 'cache'),
               PATH=str(bindir) + ':' + os.environ['PATH'])
    for key in ('SWAYSOCK', 'I3SOCK', 'HYPRLAND_INSTANCE_SIGNATURE', 'WAYLAND_DISPLAY', 'DISPLAY', 'QS_IDLE_SOCKET', 'QS_LOCK_STATE'):
        env.pop(key, None)
    config = work / 'sway.conf'
    config.write_text('xwayland disable\nswaybg_command -\noutput HEADLESS-1 mode 1920x1200\n')
    sway = subprocess.Popen(['sway', '-c', str(config)], env=env, stdout=(work / 'sway.log').open('w'), stderr=subprocess.STDOUT)
    shell = None
    try:
        sock = runtime / f'sway-ipc.{os.getuid()}.{sway.pid}.sock'
        for _ in range(60):
            if sock.exists(): break
            if sway.poll() is not None: raise AssertionError((work / 'sway.log').read_text())
            time.sleep(.1)
        assert sock.exists(), 'Sway did not start'
        env.update(SWAYSOCK=str(sock), I3SOCK=str(sock))
        # Obtain the actual socket chosen by this compositor.
        run('swaymsg', 'exec', f'echo $WAYLAND_DISPLAY > {work}/wayland', env=env)
        for _ in range(60):
            if (work / 'wayland').exists(): break
            time.sleep(.1)
        env.update(WAYLAND_DISPLAY=(work / 'wayland').read_text().strip(), QT_QPA_PLATFORM='wayland')
        shell = subprocess.Popen(['dbus-run-session', '--', 'qs', '-p', str(root)], env=env,
                                 stdout=(work / 'qs.log').open('w'), stderr=subprocess.STDOUT, start_new_session=True)
        time.sleep(4)
        pid = run('pgrep', '-P', str(shell.pid), 'qs')
        def ipc(method, *args):
            return run('qs', 'ipc', '--pid', pid, 'call', 'geometry', method, *map(str, args), env=env)
        def state():
            time.sleep(.1)
            value = json.loads(ipc('state'))
            assert value['rightStart'] - value['leftEnd'] >= 9.99, value
            for name in ('volume', 'slider'):
                assert any(s['name'] == name and s['wanted'] and s['width'] > 0 for s in value['slots']), value
            return value
        for width in (1280, 1480, 1600, 1920, 3440, 1280, 1920):
            run('swaymsg', 'output', 'HEADLESS-1', 'mode', f'{width}x1200', env=env)
            time.sleep(.2)
            for artist, title in [('Run The Jewels', 'ooh la la (feat. long title)'), ('W'*100, 'long title '*20),
                                  ('', 'Title only'), ('Artist only', ''), ('日本語 🎵 café'*10, 'Été 👩🏽‍💻'*30)]:
                for paused, updates in [('true', 999), ('false', 0)]:
                    ipc('configure', artist, title, paused, updates)
                    value = state()
                    if width == 1280: assert value['level'] == 2, value
                    if width == 1480 and updates: assert value['level'] == 1, value
                    if width >= 1920: assert value['level'] == 0, value
            run('grim', '-g', f'0,0 {width}x65', str(work / f'bar-{width}.png'), env=env)
        for extra in (1, 3, 0):
            ipc('extras', extra)
            state()
        ipc('absent')
        value = state()
        assert all(not s['wanted'] for s in value['slots'] if s['name'] in ('mpris', 'battery', 'backlight')), value
        log = (work / 'qs.log').read_text()
        assert 'WARN scene:' not in log and not re.search(r'^\s*ERROR\b', log, re.MULTILINE), log
        print('PASS bar: 70 metadata/update/pause/resize cases, tray growth, hardware/media absence; no QML warnings')
    finally:
        if shell:
            try: os.killpg(shell.pid, signal.SIGTERM)
            except ProcessLookupError: pass
            shell.wait(timeout=5)
        sway.terminate()
        sway.wait(timeout=5)


if __name__ == '__main__':
    with tempfile.TemporaryDirectory(prefix='qs-bar-') as temporary:
        try:
            test(Path(temporary))
        except Exception:
            for name in ('sway.log', 'qs.log'):
                path = Path(temporary) / name
                if path.exists(): print(path.read_text())
            raise
