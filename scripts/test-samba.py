#!/usr/bin/env python3
"""Samba : provisioning isolé, aucun service ni pare-feu réel modifié."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-samba-test-') as tmp:
    root = Path(tmp)
    (root / 'scripts').mkdir()
    (root / 'bin').mkdir()
    shutil.copytree(REPO / 'dotfiles/samba', root / 'dotfiles/samba')
    shutil.copy(REPO / 'scripts/samba-wait-zerotier.sh', root / 'scripts/samba-wait-zerotier.sh')
    source = (REPO / 'scripts/system-setup.sh').read_text()
    for old, new in [('/var/lib/qs-desktop/system-setup', str(root / 'state')),
                     ('/etc/samba/smb.conf', str(root / 'smb.conf')),
                     ('/etc/samba/smb.host.conf', str(root / 'smb.host.conf')),
                     ('/proc/sys/kernel/hostname', str(root / 'hostname')),
                     ('/var/lib/samba/usershares', str(root / 'usershares')),
                     ('/etc/ufw/ufw.conf', str(root / 'ufw.conf')),
                     ('/etc/systemd/system/smb.service.d/50-qs-zerotier.conf', str(root / 'unit.conf')),
                     ('/usr/local/libexec/qs-samba-wait-zerotier', str(root / 'wait.sh'))]:
        source = source.replace(old, new)
    helper = root / 'scripts/system-setup.sh'
    helper.write_text(source)
    (root / 'smb.conf').write_text('[global]\nserver string = original\n')
    original = (root / 'smb.conf').read_bytes()
    (root / 'hostname').write_text('sans-fichier\n')
    (root / 'ufw.conf').write_text('ENABLED=yes\n')
    (root / 'rules').write_text('ufw allow 22/tcp\n')
    (root / 'active').touch()
    (root / 'enabled').touch()
    for name, body in {
        'sudo': 'echo "sudo $*" >> "$TEST_ROOT/calls"\nexec env "$@"',
        'smbd': 'exit 0',
        'ip': 'exit 0',
        'ss': 'exit 0',
        'pdbedit': 'echo "$USER:1000:User"',
        'id': 'if [ "$1" = -nG ]; then echo sambashare; else /usr/bin/id "$@"; fi',
        'stat': 'echo "1770 sambashare"',
        'install': """args=()
while (( $# )); do
 case "$1" in -o|-g) shift 2;; *) args+=("$1"); shift;; esac
done
exec /usr/bin/install "${args[@]}"
""",
        'systemctl': """echo "systemctl $*" >> "$TEST_ROOT/calls"
case "$1" in
is-enabled) test -f "$TEST_ROOT/enabled";;
is-active) test -f "$TEST_ROOT/active";;
enable) touch "$TEST_ROOT/enabled";;
start) touch "$TEST_ROOT/active";;
disable) rm -f "$TEST_ROOT/enabled";;
stop) rm -f "$TEST_ROOT/active";;
esac""",
        'ufw': """echo "ufw $*" >> "$TEST_ROOT/calls"
if [ "$1 $2" = 'show added' ]; then cat "$TEST_ROOT/rules"
elif [ "$1" = allow ]; then
 echo 'ufw allow in on zt+ to any port 445 proto tcp comment qs-desktop-samba-zerotier' >> "$TEST_ROOT/rules"
elif [ "$1" = --force ]; then sed -i '/zt+/d' "$TEST_ROOT/rules"
fi""",
    }.items():
        file = root / 'bin' / name
        file.write_text('#!/bin/bash\n' + body + '\n')
        file.chmod(0o755)
    env = dict(os.environ, TEST_ROOT=tmp, PATH=str(root / 'bin') + ':' + os.environ['PATH'])
    def run(*args, success=True):
        result = subprocess.run(['bash', str(helper), *args], env=env, capture_output=True, text=True)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return result
    run('--dry-run', 'samba')
    assert 'sudo ' not in (root / 'calls').read_text()
    assert not (root / 'state').exists()
    assert (root / 'smb.conf').read_bytes() == original
    run('samba')
    target = root / 'smb.conf'
    assert 'valid users = %S' in target.read_text()
    assert 'bind interfaces only = yes' in target.read_text()
    assert 'options=dynamic' in target.read_text()
    assert 'hosts allow =' not in target.read_text()
    before = target.stat().st_mtime_ns
    registry = (root / 'state/registry').read_bytes()
    (root / 'calls').unlink()
    run('samba')
    assert target.stat().st_mtime_ns == before
    assert (root / 'state/registry').read_bytes() == registry
    calls = (root / 'calls').read_text()
    assert 'systemctl restart' not in calls and 'ufw allow' not in calls
    run('uninstall')
    assert target.read_bytes() == original
    assert (root / 'rules').read_text() == 'ufw allow 22/tcp\n'
    assert (root / 'active').exists() and (root / 'enabled').exists()
    # Une règle et un service préexistants ne nous appartiennent pas.
    (root / 'rules').write_text('ufw allow in on zt+ to any port 445 proto tcp\n')
    run('samba')
    run('uninstall')
    assert 'zt+' in (root / 'rules').read_text()
    # Service initialement arrêté : activation nécessaire même s'il est déjà enabled.
    (root / 'active').unlink()
    (root / 'ufw.conf').write_text('ENABLED=no\n')
    (root / 'calls').unlink()
    run('samba')
    assert (root / 'active').exists()
    assert 'ufw ' not in (root / 'calls').read_text()
    run('uninstall')
    assert not (root / 'active').exists() and (root / 'enabled').exists()
    # Service non activé : l'installation et le retrait restaurent les deux états.
    (root / 'enabled').unlink()
    run('samba')
    assert (root / 'active').exists() and (root / 'enabled').exists()
    run('uninstall')
    assert not (root / 'active').exists() and not (root / 'enabled').exists()
    # Attente bornée, aucune attente si le service ZeroTier est inactif.
    waiter = root / 'scripts/samba-wait-zerotier.sh'
    result = subprocess.run(['bash', str(waiter)], env=env, capture_output=True, text=True)
    assert result.returncode == 0
    (root / 'active').touch()
    (root / 'bin/sleep').write_text('#!/bin/sh\n echo tick >> "$TEST_ROOT/ticks"\n')
    (root / 'bin/sleep').chmod(0o755)
    result = subprocess.run(['bash', str(waiter)], env=env, capture_output=True, text=True)
    assert result.returncode == 0 and '30 s' in result.stderr
    assert len((root / 'ticks').read_text().splitlines()) == 30
    # Fichier machine (terrier : réseau local) installé, validé avec smb.conf, retiré au retrait.
    (root / 'hostname').write_text('terrier\n')
    run('samba')
    host = root / 'smb.host.conf'
    assert 'bridge0' in host.read_text()
    assert 'include = /etc/samba/smb.host.conf' in target.read_text()
    (root / 'calls').unlink()
    run('samba')
    assert 'systemctl restart' not in (root / 'calls').read_text()
    host.write_text('# ancien\n')
    run('samba')
    assert 'bridge0' in host.read_text() and 'systemctl restart' in (root / 'calls').read_text()
    run('uninstall')
    assert not host.exists() and target.read_bytes() == original
    (root / 'dotfiles/samba/hosts/terrier.conf').write_text('interfaces = lo\nserver role = invalid-role\n')
    run('samba', success=False)
    assert not host.exists() and target.read_bytes() == original
    (root / 'hostname').write_text('sans-fichier\n')
    # Une configuration invalide ne remplace jamais l'original.
    (root / 'dotfiles/samba/smb.conf').write_text('[global]\nserver role = invalid-role\n')
    run('samba', success=False)
    assert target.read_bytes() == original
print('PASS Samba : validation, fichier machine, simulation, idempotence, service arrêté, UFW actif/inactif et retrait isolés')
