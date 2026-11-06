#!/usr/bin/env python3
"""Portails captifs : installation réversible et service QML avec backend factice.
Le test QML exige Quickshell et un compositeur Wayland de banc (voir DEVELOPMENT.md).
Aucune connexion réelle ni action VPN ; les lancements et nmcli sont factices.
"""
import configparser
import json
import os
from pathlib import Path
import re
import shutil
import shlex
import signal
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]
SETUP = REPO / 'scripts/network-setup.sh'
CONF = Path('etc/NetworkManager/conf.d/90-qs-desktop-connectivity.conf')


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, capture_output=True, timeout=10, **kwargs).stdout.strip()


def stop_group(proc):
    try: os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError: pass
    try: proc.communicate(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        proc.communicate()


def installation_test(work):
    root = work / 'system'
    def setup(*args):
        return run(str(SETUP), '--root', str(root), *args)
    setup('--dry-run', 'install')
    assert not root.exists(), 'dry-run wrote files'
    target = root / CONF
    target.parent.mkdir(parents=True)
    original = b'[connectivity]\nuri=http://original.example/check\n'
    target.write_bytes(original)
    target.chmod(0o640)
    setup('install')
    expected = (REPO / 'dotfiles/NetworkManager/conf.d' / CONF.name).read_bytes()
    assert target.read_bytes() == expected
    setup('install')
    assert (root / 'var/lib/qs-desktop/network-setup/original').read_bytes() == original
    setup('--dry-run', 'uninstall')
    assert target.read_bytes() == expected
    target.write_text('# local edit\n')
    setup('uninstall')
    assert target.read_bytes() == original and target.stat().st_mode & 0o777 == 0o640
    assert next(target.parent.glob('*.before-restore-*')).read_text() == '# local edit\n'
    target.unlink()
    setup('install')
    setup('uninstall')
    assert not target.exists()
    setup('install')
    assert target.read_bytes() == expected
    setup('uninstall')
    state = root / 'var/lib/qs-desktop/network-setup'
    state.mkdir(parents=True)
    result = subprocess.run([str(SETUP), '--root', str(root), 'install'], capture_output=True)
    assert result.returncode != 0 and not target.exists(), 'partial backup must refuse installation'
    parser = configparser.ConfigParser()
    parser.read_string(expected.decode())
    url = re.search(r'captivePortalUrl: "([^"]+)"', (REPO / 'services/Network.qml').read_text())[1]
    assert url == parser['connectivity']['uri'] and url.startswith('http://')
    assert parser['connectivity']['response'] == ''
    print('PASS installation: dry-run, idempotence, backup, restore, local edits, partial state, shared URL')


def concurrent_installation_test(work):
    # Hold the first install just before it creates its backup, then start a second invocation.
    # The old script lets both enter this section and the second overwrites the original backup.
    for existing in (True, False):
        sync = work / ('race-existing' if existing else 'race-new')
        system = sync / 'system'
        bindir = sync / 'bin'
        bindir.mkdir(parents=True)
        target = system / CONF
        target.parent.mkdir(parents=True)
        original = b'original-settings\n'
        if existing: target.write_bytes(original)
        real_install = shlex.quote(shutil.which('install'))
        real_flock = shlex.quote(shutil.which('flock'))
        (bindir / 'install').write_text('''#!/bin/bash
if [[ $1 == -d && ${@: -1} == */network-setup ]]; then
    touch "$SYNC/$SIDE.wait"
    while [[ ! -f $SYNC/$SIDE.go ]]; do sleep 0.01; done
fi
exec ''' + real_install + ' "$@"\n')
        (bindir / 'flock').write_text('#!/bin/bash\ntouch "$SYNC/$SIDE.lockwait"\nexec ' + real_flock + ' "$@"\n')
        for stub in bindir.iterdir(): stub.chmod(0o755)
        processes = []
        def start(side):
            proc = subprocess.Popen([str(SETUP), '--root', str(system), 'install'], stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE, text=True, start_new_session=True,
                                    env=dict(os.environ, SYNC=str(sync), SIDE=side,
                                             PATH=str(bindir) + ':' + os.environ['PATH']))
            processes.append(proc)
            return proc
        def await_marker(*names):
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                if any((sync / name).exists() for name in names): return
                time.sleep(0.01)
            raise AssertionError('No synchronization marker: ' + str(names))
        try:
            first = start('a'); await_marker('a.wait')
            second = start('b'); await_marker('b.wait', 'b.lockwait')
            (sync / 'a.go').touch()
            output = first.communicate(timeout=5)
            assert first.returncode == 0, output
            (sync / 'b.go').touch()
            output = second.communicate(timeout=5)
            assert second.returncode == 0, output
            run(str(SETUP), '--root', str(system), 'uninstall')
            if existing: assert target.read_bytes() == original, 'concurrent installs overwrote the original backup'
            else: assert not target.exists(), 'concurrent installs saved the managed file as the original'
        finally:
            for proc in processes:
                stop_group(proc)
    print('PASS concurrent installs: original restored / new file removed')


def qml_test(work):
    stage = work / 'shell'
    # Actual code, with only the native backend and external effects substituted.
    for name in ('services', 'config', 'modules'):
        shutil.copytree(REPO / name, stage / name)
    (stage / 'assets').symlink_to(REPO / 'assets', target_is_directory=True)
    network = (stage / 'services/Network.qml').read_text().replace('Networking.', 'Backend.')
    # Accelerate the ten-second timer; disable /proc sampling so route changes are deterministic.
    network = network.replace('interval: 10000', 'interval: 100')
    network = network.replace('running: true\n        repeat: true\n        triggeredOnStart: true',
                              'running: false\n        repeat: true\n        triggeredOnStart: false', 1)
    (stage / 'services/Network.qml').write_text(network)
    shutil.copy2(REPO / 'scripts/tests/network/Backend.qml', stage / 'services/Backend.qml')
    shutil.copy2(REPO / 'scripts/tests/network/shell.qml', stage / 'shell.qml')
    (stage / 'services/Launch.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var commands: []; function exec(args) { commands = commands.concat([args]); } }\n')
    bindir = work / 'bin'
    bindir.mkdir()
    (bindir / 'nmcli').write_text('#!/bin/sh\nexit 0\n')
    (bindir / 'nmcli').chmod(0o755)
    env = dict(os.environ, QS_TEST='1', XDG_STATE_HOME=str(work / 'state'), XDG_CACHE_HOME=str(work / 'cache'),
               GIO_USE_VFS='local', GVFS_DISABLE_FUSE='1', PATH=str(bindir) + ':' + os.environ['PATH'])
    log = work / 'qml.log'
    with log.open('w') as output:
        proc = subprocess.Popen(['qs', '-p', str(stage)], env=env, stdout=output, stderr=subprocess.STDOUT,
                                start_new_session=True)
        try:
            def ipc(method, *args):
                return run('qs', 'ipc', '--pid', str(proc.pid), 'call', 'test', method, *args)
            def snap(): return json.loads(ipc('snapshot'))
            def config(**values):
                ipc('configure', json.dumps(values))
                time.sleep(0.04)
            for _ in range(100):
                if proc.poll() is not None: raise AssertionError(log.read_text())
                try:
                    snap()
                    break
                except subprocess.CalledProcessError:
                    time.sleep(0.05)
            else: raise AssertionError(log.read_text())
            config(interfaceName='test-wifi', connectivity=4)
            assert not snap()['portal'] and not snap()['buttonVisible']
            before = snap()['checks']; time.sleep(0.25)
            assert snap()['checks'] == before, 'normal connectivity must not poll'
            config(connectivity=2)
            assert snap()['portal'] and snap()['buttonVisible'] and not snap()['commands']
            ipc('stale'); assert not snap()['commands']
            before = snap()['checks']; time.sleep(0.25)
            assert snap()['checks'] > before, 'portal must poll with all panels closed'
            ipc('capture', str(work / 'portal.png')); time.sleep(0.15)
            # Exercise the actual WifiPanel handler, including exclusive keyboard release.
            ipc('openPanel'); time.sleep(0.1)
            ipc('activate'); result = snap()
            assert result['commands'] == [['xdg-open', 'http://ping.omacom.io/nm-check.txt']]
            assert result['closedBeforeLaunch']
            config(connectivity=4)
            before = snap()['checks']; time.sleep(0.25)
            assert not snap()['portal'] and snap()['checks'] == before
            config(connectivity=3)
            assert not snap()['portal']
            before = snap()['checks']; time.sleep(0.25)
            assert snap()['checks'] > before
            config(connectivity=2, connectivityCheckEnabled=False)
            assert not snap()['portal'] and not snap()['limited'] and snap()['connectivity'] == 0
            before = snap()['checks']; time.sleep(0.25)
            assert snap()['checks'] == before
            config(connectivityCheckEnabled=True)
            assert snap()['portal'] and snap()['checks'] > before
            config(canCheckConnectivity=False)
            assert not snap()['portal']
            config(canCheckConnectivity=True, wired=True, interfaceName='test-ethernet')
            assert not snap()['portal'] and not snap()['limited']
            config(wired=False, joined=False)
            assert not snap()['portal']
            before = snap()['checks']; config(joined=True)
            assert snap()['portal'] and snap()['checks'] > before
            config(connectivity=4)
            before = snap()['checks']
            ipc('panels', 'false', '1'); time.sleep(0.04)
            assert snap()['checks'] == before, 'hover preview must not request a check'
            ipc('panels', 'true', '1'); time.sleep(0.04)
            assert snap()['checks'] > before
            ipc('panels', 'true', '2')
            config(connectivity=2)
            before = snap()['checks']; time.sleep(0.32)
            assert 2 <= snap()['checks'] - before <= 4, 'one timer across multiple panels'
            config(wifiEnabled=False)
            assert not snap()['portal']
            before = snap()['checks']; time.sleep(0.25)
            assert snap()['checks'] == before
            errors = [line for line in log.read_text().splitlines() if ('WARN' in line or 'ERROR' in line)
                      and 'qt.qpa.services:' not in line and 'qt.qpa.wayland.textinput:' not in line]
            assert not errors, '\n'.join(errors)
            print('PASS QML: portal/full/limited, guarded click, browser argv, polling, disabled checks/radio, route attribution, reconnect, preview/pinned, multiple panels')
            if (work / 'portal.png').exists():
                print('Capture:', work / 'portal.png')
            else:
                print('Capture indisponible : banc sans rendu ou fenêtre masquée.')
        finally:
            stop_group(proc)


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--setup-only', action='store_true')
    parser.add_argument('--keep', type=Path, help='Keep logs and capture in this new directory')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='qs-network-test-') as tmp:
        work = Path(tmp)
        installation_test(work)
        concurrent_installation_test(work)
        try:
            if not args.setup_only: qml_test(work)
        finally:
            if args.keep: shutil.copytree(work, args.keep, symlinks=True)
