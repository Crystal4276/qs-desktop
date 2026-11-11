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
            gap = value['rightStart'] - value['leftEnd']
            assert gap >= 9.99, value
            # Media pill snaps to the usual pill spacing when it would leave less than mediaSnapGap (50 px).
            if any(s['name'] == 'mpris' and s['wanted'] for s in value['slots']):
                assert abs(gap - 10) < 1 or gap >= 50, value
            for name in ('volume', 'slider'):
                assert any(s['name'] == name and s['wanted'] and s['width'] > 0 for s in value['slots']), value
            # Rendered media label inside its module (padding 10 px on each side): never over its neighbours.
            for s in value['slots']:
                if s['name'] == 'mpris' and s['wanted']: assert s['label'] + 20 <= s['width'] + 0.5, value
            return value
        def check_text(value, artist, title):
            media = next(s for s in value['slots'] if s['name'] == 'mpris')
            # Whole text; else the whole artist and the title elided; else the artist alone (the title when there is no
            # artist), elided if needed: never an elided artist next to the title. Elided alone, at least
            # Theme.bar.mediaMinLetters (3) letters, else icons only (no bare « D… »).
            full, main, text = ' - '.join(s for s in (artist, title) if s), artist or title, media['text']
            rest = text[len(artist) + 3:] if artist and title and text.startswith(artist + ' - ') else None
            assert (text in ('', full, main) or (rest and rest.endswith('…') and title.startswith(rest[:-1]))
                    or (text.endswith('…') and main.startswith(text[:-1]) and len(text[:-1].strip()) >= 3)), value
            return media, full, rest
        # Player already present when the bar is built, room changed without a track change (widths measured before the bar
        # font was applied stayed ~60 % too small: full text over the speaker, 2026-11-11).
        for updates in (999, 0, 999):
            ipc('updates', updates)
            state()
        for width in (1280, 1480, 1600, 1920, 3440, 1280, 1920):
            run('swaymsg', 'output', 'HEADLESS-1', 'mode', f'{width}x1200', env=env)
            time.sleep(.2)
            for artist, title in [('Run The Jewels', 'ooh la la (feat. long title)'), ('W'*100, 'long title '*20),
                                  ('', 'Title only'), ('Artist only', ''), ('日本語 🎵 café'*10, 'Été 👩🏽‍💻'*30),
                                  ('Ren', 'Hi Ren'), ('Deftones', 'Around the Fur')]:
                for paused, updates in [('true', 999), ('false', 0)]:
                    ipc('configure', artist, title, paused, updates)
                    value = state()
                    media, full, rest = check_text(value, artist, title)
                    # Text (artist - title) capped at Theme.bar.mediaTextMaxWidth (600 px).
                    assert media['textWidth'] <= 600.5, value
                    # The title fills the room left by the artist (Deftones at 1920 px: whole artist, part of the title).
                    if width == 1920 and artist == 'Deftones' and media['text'] != full: assert rest, value
                    # No room for text: player icon only, plus the pause icon when paused.
                    if not media['text']: assert media['segments'] == (2 if paused == 'true' else 1), value
                    # A short artist and title that fit are never elided.
                    if width >= 1920 and artist == 'Ren': assert media['text'] == 'Ren - Hi Ren', value
                    # Near the cap: the elided artist may lose up to one glyph ('W' ≈ 26 px).
                    if width == 3440 and artist.startswith('W'): assert media['text'] and media['textWidth'] > 550, value
                    if width == 1280: assert value['level'] == 2, value
                    if width == 1480 and updates: assert value['level'] == 1, value
                    if width >= 1920: assert value['level'] == 0, value
            run('grim', '-g', f'0,0 {width}x65', str(work / f'bar-{width}.png'), env=env)
        # Tight room, 5 px steps: the artist alone shrinks letter by letter down to icons only (never « D… » / « De… »).
        ipc('configure', 'Deftones', 'Around the Fur', 'false', 999)
        for width in range(1250, 1351, 5):
            run('swaymsg', 'output', 'HEADLESS-1', 'mode', f'{width}x1200', env=env)
            time.sleep(.2)
            check_text(state(), 'Deftones', 'Around the Fur')
        for extra in (1, 3, 0):
            ipc('extras', extra)
            state()
        ipc('absent')
        value = state()
        assert all(not s['wanted'] for s in value['slots'] if s['name'] in ('mpris', 'battery', 'backlight')), value
        log = (work / 'qs.log').read_text()
        assert 'WARN scene:' not in log and not re.search(r'^\s*ERROR\b', log, re.MULTILINE), log
        print('PASS bar: player present at startup, 98 metadata/update/pause/resize cases, tight-room sweep, tray growth, hardware/media absence; '
              'media label always inside its module; no QML warnings')
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
