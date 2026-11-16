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


UUID = '0f1e2d3c-4b5a-6978-8796-a5b4c3d2e1f0'


def form_test(ipc, nmcli_log, work):
    """Formulaires du panneau Wi-Fi : réseau entreprise (création sans secret sur la ligne de commande, mot de passe écrit, refus,
    nouvelle saisie, réseau enregistré, panneau fermé, annulation, échec sans raison, échec de `nmcli`) et réseau WPA."""
    def form(): return json.loads(ipc('form'))
    def calls(): return json.loads(ipc('calls'))
    def settle(seconds=0.1): time.sleep(seconds)
    def fill(**values): ipc('fill', json.dumps({PLACEHOLDERS[k]: v for k, v in values.items()}))
    def new_calls(before): return calls()[len(before):]
    created_args = ['connection', 'add', 'type', 'wifi', 'con-name', 'Campus', 'ssid', 'Campus', 'connection.autoconnect', 'no',
                    'wifi-sec.key-mgmt', 'wpa-eap', '802-1x.eap', 'ttls', '802-1x.phase2-auth', 'pap',
                    '802-1x.identity', 'alice@campus.example', '802-1x.auth-timeout', '10', '802-1x.system-ca-certs', 'yes',
                    '802-1x.domain-suffix-match', 'radius.campus.example']
    profile = json.dumps({'802-1x': {'eap': ['ttls'], 'identity': 'alice@campus.example', 'phase2-auth': 'pap'},
                          'connection': {'autoconnect': False}})

    ipc('openForm', 'enterprise'); settle()
    f = form()
    assert f['title'] == ['Sign in to Campus'] and f['passwordFor'] == 'Campus', f
    assert all(f[k]['visible'] for k in ('username', 'password', 'domain')) and f['tabs'] == {'visible': True, 'current': 'peap'}, f
    assert f['connect'] == {'visible': True, 'enabled': False} and not f['holdOpen'], f
    # Identifiant manquant : ni Entrée ni bouton.
    fill(password='pa ss'); ipc('enter', 'Password'); ipc('click', 'Connect'); settle()
    f = form()
    assert f['passwordFor'] == 'Campus' and f['holdOpen'] and not f['connect']['enabled'] and not nmcli_log.exists(), f
    fill(username=' alice@campus.example ', domain=' radius.campus.example '); ipc('pick', 'ttls'); settle()
    assert form()['connect']['enabled']
    ipc('capturePanel', str(work / 'enterprise-form.png')); settle()
    ipc('click', 'Connect'); settle()
    f = form()
    assert f['passwordFor'] == '' and f['signingIn'] and f['holdOpen'] and f['failText'] == '', f
    assert nmcli_log.read_text().splitlines() == created_args, nmcli_log.read_text()
    assert calls() == [], 'nothing written before the profile appears'
    nmcli_log.unlink()
    ipc('profile', 'enterprise', UUID, profile); settle()
    assert calls() == [['write', {'802-1x': {'password': 'pa ss'}}], ['connect', UUID]], calls()

    # Refus : profil créé supprimé (mot de passe jamais gardé), formulaire rouge avec ce qui avait été saisi.
    before = calls()
    ipc('fail', 'enterprise', 'NoSecrets', 'false'); settle()
    assert new_calls(before) == [['forget', UUID]], calls()
    f = form()
    assert f['title'] == ['Wrong username or password for Campus'] and not f['signingIn'] and f['failText'] == '', f
    assert f['username'] == {'visible': True, 'text': 'alice@campus.example', 'error': True}, f
    assert f['password']['text'] == '' and f['password']['error'], f
    assert f['tabs'] == {'visible': True, 'current': 'ttls'} and f['domain']['text'] == 'radius.campus.example', f
    ipc('capturePanel', str(work / 'enterprise-refused.png')); settle()

    # Nouvelle saisie : profil recréé ; connecté, il reçoit la connexion automatique.
    fill(password='good'); ipc('enter', 'Password'); settle()
    assert nmcli_log.read_text().splitlines() == created_args
    before = calls()
    ipc('profile', 'enterprise', UUID, profile); settle()
    ipc('setState', 'enterprise', 'Connected'); settle()
    assert new_calls(before) == [['write', {'802-1x': {'password': 'good'}}], ['connect', UUID],
                                 ['write', {'connection': {'autoconnect': True}}]], calls()
    assert not form()['signingIn']
    ipc('setState', 'enterprise', 'Disconnected'); settle()
    nmcli_log.unlink()

    # Réseau enregistré cliqué puis refusé : son mot de passe (non saisi) est gardé ; identifiant repris du profil.
    before = calls()
    ipc('openForm', 'enterprise'); settle()
    ipc('fail', 'enterprise', 'NoSecrets', 'false'); settle()
    assert new_calls(before) == [['connect', UUID]], calls()
    f = form()
    assert f['title'] == ['Wrong username or password for Campus'] and f['username']['text'] == 'alice@campus.example', f
    assert not f['tabs']['visible'] and not f['domain']['visible'], f

    # Nouveau mot de passe, autre échec : secrets effacés, profil gardé, message.
    before = calls()
    fill(username='alice', password='new'); ipc('click', 'Connect'); settle()
    ipc('fail', 'enterprise', 'WifiClientFailed', 'false'); settle()
    assert new_calls(before) == [['write', {'802-1x': {'identity': 'alice', 'password': 'new'}}], ['connect', UUID],
                                 ['clear', UUID]], calls()
    f = form()
    assert f['title'] == ['Sign in to Campus'] and f['username']['text'] == 'alice', f
    assert f['failText'] == 'Could not connect to Campus — weak signal or wrong username or password', f

    # Panneau fermé pendant la connexion (état avant le signal) : l'échec attend la réouverture.
    fill(password='again'); ipc('enter', 'Password'); settle()
    ipc('closePanel'); settle()
    before = calls()
    ipc('fail', 'enterprise', 'NoSecrets', 'true'); settle(1.2)
    assert new_calls(before) == [['clear', UUID]], calls()
    ipc('reopenPanel'); settle()
    f = form()
    assert f['title'] == ['Wrong username or password for Campus'] and f['username']['text'] == 'alice', f

    # Annulation : secret saisi effacé, rien à montrer.
    fill(password='x'); ipc('enter', 'Password'); settle()
    before = calls()
    ipc('cancel'); ipc('setState', 'enterprise', 'Disconnected'); settle(1.2)
    assert new_calls(before) == [['clear', UUID]], calls()
    f = form()
    assert f['passwordFor'] == '' and f['failText'] == '' and not f['signingIn'], f

    # Retour à « Disconnected » sans échec traduit : message après une seconde.
    ipc('openForm', 'enterprise'); settle()
    ipc('setState', 'enterprise', 'Disconnected'); settle(0.3)
    assert form()['signingIn'] and form()['passwordFor'] == ''
    settle(1.0)
    f = form()
    assert not f['signingIn'] and f['passwordFor'] == 'Campus' and f['failText'].startswith('Could not connect to Campus —'), f

    # `nmcli` en échec (réseau de nouveau sans profil) : message, saisie reprise, rien d'écrit.
    ipc('reset', 'enterprise'); settle()
    ipc('openForm', 'enterprise'); settle()
    before = calls()
    fill(username='bogus', password='x'); ipc('enter', 'Password'); settle(0.3)
    f = form()
    assert f['failText'] == 'Could not connect to Campus' and f['username']['text'] == 'bogus' and calls() == before, f

    # WPA : mot de passe seul, bouton compris.
    ipc('openForm', 'personal'); settle()
    f = form()
    assert f['title'] == ['Password for Home'] and not f['username']['visible'] and not f['domain']['visible'], f
    assert not f['tabs']['visible'] and f['connect'] == {'visible': True, 'enabled': False}, f
    fill(password='wpa key'); ipc('click', 'Connect'); settle()
    assert calls()[-1] == ['psk', 'wpa key'] and form()['pending'] == 'Home', calls()
    print('PASS QML: enterprise form (Connect button, no secret on argv, refused password never kept, retry, saved network, '
          'closed panel, cancel, unknown failure, nmcli failure), WPA form')


PLACEHOLDERS = {'username': 'Username', 'password': 'Password', 'domain': 'Server domain (optional)'}


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
    for name in ('Backend', 'FakeWifi', 'FakeProfile'):
        shutil.copy2(REPO / f'scripts/tests/network/{name}.qml', stage / f'services/{name}.qml')
    shutil.copy2(REPO / 'scripts/tests/network/shell.qml', stage / 'shell.qml')
    (stage / 'services/Launch.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var commands: []; function exec(args) { commands = commands.concat([args]); } }\n')
    bindir = work / 'bin'
    bindir.mkdir()
    # `nmcli connection add` : arguments enregistrés, profil annoncé (échec si l'identifiant est « bogus »).
    nmcli_log = work / 'nmcli-add.log'
    (bindir / 'nmcli').write_text(f'''#!/bin/sh
[ "$1 $2" = "connection add" ] || exit 0
printf '%s\\n' "$@" >> {shlex.quote(str(nmcli_log))}
case " $* " in *" bogus "*) echo "Error: failed" >&2; exit 1 ;; esac
echo "Connection '$6' ({UUID}) successfully added."
''')
    (bindir / 'nmcli').chmod(0o755)
    # Rendu logiciel direct : sur un banc sans GPU, Mesa essaie d'abord Zink et journalise son échec.
    env = dict(os.environ, QS_TEST='1', XDG_STATE_HOME=str(work / 'state'), XDG_CACHE_HOME=str(work / 'cache'),
               GIO_USE_VFS='local', GVFS_DISABLE_FUSE='1', LIBGL_ALWAYS_SOFTWARE='1',
               PATH=str(bindir) + ':' + os.environ['PATH'])
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
            form_test(ipc, nmcli_log, work)
            config(wifiEnabled=False)
            assert not snap()['portal']
            before = snap()['checks']; time.sleep(0.25)
            assert snap()['checks'] == before
            # Journal en couleurs : codes ANSI retirés avant le filtre des catégories.
            lines = [re.sub(r'\x1b\[[0-9;]*m', '', line) for line in log.read_text().splitlines()]
            errors = [line for line in lines if ('WARN' in line or 'ERROR' in line)
                      and 'qt.qpa.services:' not in line and 'qt.qpa.wayland.textinput:' not in line]
            assert not errors, '\n'.join(errors)
            print('PASS QML: portal/full/limited, guarded click, browser argv, polling, disabled checks/radio, route attribution, reconnect, preview/pinned, multiple panels')
            for name in ('portal', 'enterprise-form', 'enterprise-refused'):
                if (work / f'{name}.png').exists():
                    print('Capture:', work / f'{name}.png')
                else:
                    print(f'Capture {name} indisponible : banc sans rendu ou fenêtre masquée.')
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
