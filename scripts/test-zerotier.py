#!/usr/bin/env python3
"""Provisioning ZeroTier isolé : aucun service ni réseau réel modifié."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

REPO = Path(__file__).resolve().parent.parent
NETWORK = '0123456789abcdef'
with tempfile.TemporaryDirectory(prefix='qs-zerotier-test-') as tmp:
    root = Path(tmp)
    (root / 'scripts').mkdir()
    binaries = root / 'bin'
    binaries.mkdir()
    source = (REPO / 'scripts/system-setup.sh').read_text().replace(
        'dir=/var/lib/zerotier-one/networks.d', f'dir={root}/networks.d')
    helper = root / 'scripts/system-setup.sh'
    helper.write_text(source)
    for name, body in {
        'sudo': 'echo sudo >> "$TEST_ROOT/calls"\nexec "$@"',
        'systemctl': '''echo "systemctl $*" >> "$TEST_ROOT/calls"
case "$1" in
is-enabled) test -f "$TEST_ROOT/enabled";;
is-active) test -f "$TEST_ROOT/active";;
enable) touch "$TEST_ROOT/enabled";;
start) touch "$TEST_ROOT/active";;
esac''',
        'zerotier-cli': '''echo "cli $*" >> "$TEST_ROOT/calls"
if [ "$1 $2" = '-j info' ]; then if [ -e "$TEST_ROOT/offline" ]; then echo '{"online":false}'; else echo '{"online":true}'; fi; exit; fi
if [ "$1" = status ]; then echo '200 info 1234567890 ONLINE'; exit; fi
cat "$TEST_ROOT/response"''',
    }.items():
        file = binaries / name
        file.write_text('#!/bin/sh\n' + body + '\n')
        file.chmod(0o755)
    env = dict(os.environ, TEST_ROOT=tmp, PATH=str(binaries) + ':' + os.environ['PATH'])

    def run(*args):
        return subprocess.run(['bash', str(helper), *args], env=env,
                              capture_output=True, text=True, timeout=10)

    assert run('--dry-run', 'zerotier', NETWORK).returncode == 0
    assert not (root / 'calls').exists()
    assert run('zerotier', 'bad').returncode == 2
    for status, addresses, expected in [
        ('OK', ['10.0.0.1/24'], 0),
        ('ACCESS_DENIED', [], 3),
        ('AUTHENTICATION_REQUIRED', [], 3),
        ('NOT_FOUND', [], 1),
        ('PORT_ERROR', [], 1),
        ('CLIENT_TOO_OLD', [], 1),
    ]:
        (root / 'response').write_text(json.dumps([{'nwid': NETWORK, 'status': status,
                                                   'assignedAddresses': addresses}]))
        result = run('zerotier', NETWORK)
        assert result.returncode == expected, result.stdout + result.stderr
        if expected == 3:
            assert 'Central' in result.stdout
    membership = root / 'networks.d' / (NETWORK + '.conf')
    membership.write_bytes(b'existing binary configuration')
    before = membership.stat().st_mtime_ns
    (root / 'response').write_text(json.dumps([{'nwid': NETWORK, 'status': 'OK',
                                               'assignedAddresses': ['10.0.0.1/24']}]))
    (root / 'calls').unlink()
    assert run('zerotier', NETWORK).returncode == 0
    assert membership.read_bytes() == b'existing binary configuration'
    assert membership.stat().st_mtime_ns == before
    calls = (root / 'calls').read_text()
    assert 'cli join' not in calls and 'systemctl start' not in calls and 'systemctl enable' not in calls
    # État OK mis en cache : ne pas annoncer prêt quand le nœud est hors ligne.
    helper.write_text(source.replace('SECONDS + 60', 'SECONDS + 1'))
    (root / 'offline').touch()
    assert run('zerotier', NETWORK).returncode == 3
    assert membership.read_bytes() == b'existing binary configuration'
    settings = (root / 'networks.d' / (NETWORK + '.local.conf')).read_text()
    assert all(setting in settings for setting in ['allowDefault=0', 'allowDNS=0', 'allowGlobal=0'])
print('PASS ZeroTier : simulation, validation, états réseau, autorisation, persistance et idempotence isolées')

# Le même chemin de provisioning qu'install.sh doit fonctionner après un clone sans fichier local.
with tempfile.TemporaryDirectory(prefix='qs-zerotier-provisioning-') as tmp:
    root = Path(tmp)
    (root / 'hosts').mkdir()
    (root / 'scripts').mkdir()
    default = (REPO / 'hosts/zerotier-network').read_text().strip()
    (root / 'hosts/zerotier-network').write_text(default + '\n')
    helper = root / 'scripts/system-setup.sh'
    helper.write_text('#!/bin/sh\nprintf "%s\\n" "$*"\n')
    helper.chmod(0o755)
    source = (REPO / 'install.sh').read_text().split('\nif [[ -n "$uninstall" ]]; then\n')[0]
    installer = root / 'install.sh'
    installer.write_text(source + '\nstep_zerotier\n')

    def provision():
        return subprocess.run(['bash', str(installer), '--dry-run'], capture_output=True, text=True)

    result = provision()
    assert result.returncode == 0 and f'--dry-run zerotier {default}' in result.stdout, result.stdout + result.stderr
    local = root / 'hosts/zerotier-network.local'
    local.write_text(NETWORK + '\n')
    result = provision()
    assert result.returncode == 0 and f'--dry-run zerotier {NETWORK}' in result.stdout
    local.write_text('invalid\n')
    assert provision().returncode != 0
print('PASS provisioning : réseau fourni après clone, surcharge locale prioritaire, ID invalide refusé')
