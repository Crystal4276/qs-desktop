#!/usr/bin/env python3
"""Exercise Core Lab selection with the real service and picker on isolated Sway.
No real session or VPN actions.
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
    wallpapers = work / 'wallpapers'
    import struct, zlib
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', 1, 1, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(b'\0\x94\xe2\xd5')) + chunk(b'IEND', b'')
    for design in range(9):
        for size in ('1280x800', '1920x1200', '2560x1440', '3840x2160', '3440x1440'):
            p = wallpapers / f'corelab/design{design}/design{design}_{size}.png'
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(png)
    p = wallpapers / 'simple/old.png'
    p.parent.mkdir(); p.write_bytes(png)
    host = root / 'hosts' / f'{Path("/proc/sys/kernel/hostname").read_text().strip()}.json'
    def profile(value):
        host.write_text(json.dumps(dict(profile=value, wallpapersDir=str(wallpapers),
                                       wallpaper=dict(kind='simple', path='simple/old.png'), idle=dict(timeout=0))))
    profile('travail')
    probe = root / 'shell.qml'
    qml = probe.read_text().replace('import Quickshell\n', 'import Quickshell\nimport Quickshell.Io\n')
    qml = qml[:qml.rfind('}')] + '''
    PickerWindow { id: picker }
    IpcHandler {
        target: "corelab-test"
        function open(): void { picker.open(null); picker.tab = "corelab"; }
        function close(): void { picker.close(); }
        function refresh(): void { Wallpapers.refresh(); }
        function choose(index: int): void { picker.apply(index); }
        function own(): void { Wallpapers.setOutput("test", "corelab/design1"); }
        function resolve(w: int, h: int, scale: real): string {
            return JSON.stringify(Wallpapers.forOutput({name:"test", description:"test", width:w, height:h, scale:scale}, Compositor.outputs));
        }
        function state(): string {
            return JSON.stringify({ready:Wallpapers.ready, items:picker.items, tabs:picker.tabs,
                selection:Wallpapers.selection, overrides:Wallpapers.overrides, lib:Wallpapers.library,
                shown:Compositor.outputs.map(o => Wallpapers.forOutput(o, Compositor.outputs)), keep:Wallpapers.chosenPaths()});
        }
    }
}
'''
    probe.write_text(qml)
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
            return run('qs', 'ipc', '--pid', pid, 'call', 'corelab-test', method, *map(str, args), env=env)
        def state():
            return json.loads(ipc('state'))
        def wait_for(predicate):
            for _ in range(60):
                v = state()
                if predicate(v): return v
                time.sleep(.1)
            raise AssertionError(v)
        wait_for(lambda v: v['ready'] and len(v['lib']['corelab']) == 9)
        ipc('open')
        v = wait_for(lambda v: len(v['items']) == 9)
        assert all(i['images'][0].endswith('_1920x1200.png') for i in v['items']), v
        assert v['selection']['path'] == 'simple/old.png', v
        ipc('choose', 0)
        assert state()['selection'] == dict(kind='corelab', path='corelab/design0')
        def resolve(w, h, scale=1): return json.loads(ipc('resolve', w, h, scale))['path']
        assert resolve(1920,1200).endswith('_1920x1200.png')
        assert resolve(2560,1440,1.5).endswith('_3840x2160.png')
        assert resolve(1707,960,1.5).endswith('_2560x1440.png')
        assert resolve(3440,1440).endswith('_3440x1440.png')
        assert resolve(1600,1000).endswith('_1920x1200.png')
        assert resolve(8000,5000).endswith('_1920x1200.png')
        ipc('own')
        assert 'design1_' in resolve(1920,1200)
        assert any('design1_' in p for p in state()['keep'])
        time.sleep(.5)
        os.killpg(shell.pid, signal.SIGTERM); shell.wait(timeout=5)
        shell = subprocess.Popen(['dbus-run-session', '--', 'qs', '-p', str(root)], env=env,
                                 stdout=(work / 'qs.log').open('a'), stderr=subprocess.STDOUT, start_new_session=True)
        time.sleep(3); pid = run('pgrep', '-P', str(shell.pid), 'qs')
        assert 'design1_' in resolve(1920,1200)
        assert state()['selection']['path'] == 'corelab/design0'
        profile('jeux')
        wait_for(lambda v: not v['lib']['corelab'] and all(t['key'] != 'corelab' for t in v['tabs']))
        assert resolve(1920,1200) == 'simple/old.png'
        assert state()['selection']['path'] == 'corelab/design0'
        profile('travail')
        wait_for(lambda v: len(v['lib']['corelab']) == 9)
        assert 'design1_' in resolve(1920,1200)
        # Missing preferred variant selects another resolution from the same design.
        ipc('close'); time.sleep(.3)
        (wallpapers/'corelab/design1/design1_1920x1200.png').unlink()
        ipc('refresh'); time.sleep(.4)
        assert resolve(1920,1200).endswith('_1280x800.png')
        run('qs', 'ipc', '--pid', pid, 'call', 'wallpaper', 'set', 'simple', 'simple/old.png', env=env)
        ipc('own'); time.sleep(.3)
        shutil.rmtree(wallpapers/'corelab')
        ipc('refresh'); wait_for(lambda v: not v['lib']['corelab'])
        assert resolve(1920,1200) == 'simple/old.png'
        log = (work/'qs.log').read_text()
        assert 'WARN scene:' not in log and not re.search(r'^\s*ERROR(?! quickshell.service.pipewire.loop:)\b', log, re.MULTILINE), log
        print('PASS Core Lab: scan, 9 items, physical resolution/scaling/fallback, per-output, caches, persistence, profiles, missing directory')
    finally:
        if shell:
            try: os.killpg(shell.pid, signal.SIGTERM)
            except ProcessLookupError: pass
            shell.wait(timeout=5)
        sway.terminate(); sway.wait(timeout=5)


if __name__ == '__main__':
    with tempfile.TemporaryDirectory(prefix='qs-corelab-') as temporary:
        try:
            test(Path(temporary))
        except Exception:
            for name in ('sway.log', 'qs.log'):
                p = Path(temporary)/name
                if p.exists(): print(p.read_text())
            raise
