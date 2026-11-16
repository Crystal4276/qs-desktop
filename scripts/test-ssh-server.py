#!/usr/bin/env python3
"""sshd des machines clientes, filtré par UFW, et rétention de leur journal : provisioning isolé, aucun service,
pare-feu ni journal réel modifié."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parent.parent
UFW_FILES = {'/etc/default/ufw': 'default', '/etc/ufw/ufw.conf': 'ufw.conf',
             '/etc/ufw/user.rules': 'user.rules', '/etc/ufw/user6.rules': 'user6.rules'}
with tempfile.TemporaryDirectory(prefix='qs-sshd-test-') as tmp:
    root = Path(tmp)
    (root / 'scripts').mkdir()
    (root / 'bin').mkdir()
    shutil.copytree(REPO / 'dotfiles/journald', root / 'dotfiles/journald')
    source = (REPO / 'scripts/system-setup.sh').read_text().replace('/var/lib/qs-desktop/system-setup', str(root / 'state'))
    for old, new in UFW_FILES.items():
        source = source.replace(old, str(root / new))
    journal = root / 'journald.conf.d/60-qs-desktop-client.conf'
    source = source.replace('/etc/systemd/journald.conf.d/60-qs-desktop-client.conf', str(journal))
    helper = root / 'scripts/system-setup.sh'
    helper.write_text(source)
    # Fichiers UFW simulés : ufw.conf porte l'état, user.rules les règles ajoutées.
    originals = {'default': 'DEFAULT_INPUT_POLICY="ACCEPT"\n', 'ufw.conf': 'ENABLED=no\n',
                 'user.rules': 'ufw allow 8080/tcp\n', 'user6.rules': '# v6\n'}
    for name, text in originals.items():
        (root / name).write_text(text)
    for name, body in {
        'sudo': 'echo "sudo $*" >> "$TEST_ROOT/calls"\nexec env "$@"',
        'systemctl': """echo "systemctl $*" >> "$TEST_ROOT/calls"
unit="${@: -1}"
case "$1" in
cat) true;;
is-enabled) test -f "$TEST_ROOT/enabled-$unit";;
is-active) test -f "$TEST_ROOT/active-$unit";;
enable) touch "$TEST_ROOT/enabled-$unit"; [ "$2" != --now ] || touch "$TEST_ROOT/active-$unit";;
start) touch "$TEST_ROOT/active-$unit";;
disable) rm -f "$TEST_ROOT/enabled-$unit";;
stop) rm -f "$TEST_ROOT/active-$unit";;
esac""",
        # Propriétaire root ignoré : le test tourne sans privilège.
        'install': 'args=()\nwhile (( $# )); do case "$1" in -o|-g) shift 2;; *) args+=("$1"); shift;; esac; done\n'
                   'exec /usr/bin/install "${args[@]}"',
        'ufw': """echo "ufw $*" >> "$TEST_ROOT/calls"
case "$1" in
show) cat "$TEST_ROOT/user.rules";;
allow) echo "ufw $*" >> "$TEST_ROOT/user.rules";;
default) echo "DEFAULT_INPUT_POLICY=\\"DROP\\"" > "$TEST_ROOT/default";;
--force) case "$2" in
  enable) echo ENABLED=yes > "$TEST_ROOT/ufw.conf";;
  disable) echo ENABLED=no > "$TEST_ROOT/ufw.conf";;
  delete) sed -i '/port 22 /d' "$TEST_ROOT/user.rules";;
  esac;;
esac""",
    }.items():
        file = root / 'bin' / name
        file.write_text('#!/bin/bash\n' + body + '\n')
        file.chmod(0o755)
    env = dict(os.environ, TEST_ROOT=tmp, PATH=str(root / 'bin') + ':' + os.environ['PATH'])

    def run(*args, success=True):
        result = subprocess.run(['bash', str(helper), *args], env=env, capture_output=True, text=True)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return result.stdout

    def calls():
        text = (root / 'calls').read_text() if (root / 'calls').exists() else ''
        (root / 'calls').unlink(missing_ok=True)
        return text

    def state():
        return {name: (root / name).read_text() for name in originals}

    run('--dry-run', 'ssh-server')
    assert 'sudo ' not in calls() and not (root / 'state').exists() and state() == originals
    # UFW inactif : activé avant sshd, entrant refusé, ZeroTier (22, 445) et VM ouverts.
    run('ssh-server')
    log = calls()
    assert log.index('ufw --force enable') < log.index('systemctl start sshd.service'), log
    rules = (root / 'user.rules').read_text()
    for rule in ('allow in on zt+ to any port 22 proto tcp', 'allow in on zt+ to any port 445 proto tcp', 'allow in on virbr+'):
        assert rule in rules, rules
    assert 'DROP' in (root / 'default').read_text() and (root / 'ufw.conf').read_text() == 'ENABLED=yes\n'
    for unit in ('ufw.service', 'sshd.service'):
        assert (root / f'enabled-{unit}').exists() and (root / f'active-{unit}').exists()
    registry = (root / 'state/registry').read_bytes()
    # Relance : rien ne change.
    run('ssh-server')
    log = calls()
    assert 'ufw allow' not in log and 'enable' not in log.replace('is-enabled', '') and 'start' not in log, log
    assert (root / 'state/registry').read_bytes() == registry
    # Retrait : UFW désactivé, règles et politique d'origine, services comme avant.
    run('uninstall')
    assert state() == originals, state()
    # ufw.service désactivé (comme les autres services du registre) ; ses règles sont déjà retirées par « ufw disable ».
    assert not list(root.glob('enabled-*')) and not (root / 'active-sshd.service').exists()
    (root / 'active-ufw.service').unlink()
    assert 'ufw --force disable' in calls()
    # UFW déjà actif (réglé à la main) : seule la règle SSH s'ajoute et repart au retrait ; pare-feu laissé actif.
    (root / 'ufw.conf').write_text('ENABLED=yes\n')
    run('ssh-server')
    log = calls()
    assert 'ufw --force enable' not in log and 'ufw default' not in log and 'virbr+' not in log
    assert 'port 22' in (root / 'user.rules').read_text()
    run('uninstall')
    assert (root / 'user.rules').read_text() == originals['user.rules']
    assert (root / 'ufw.conf').read_text() == 'ENABLED=yes\n'
    # sshd déjà actif à la main : laissé tel quel au retrait.
    (root / 'enabled-sshd.service').touch()
    (root / 'active-sshd.service').touch()
    run('ssh-server')
    run('uninstall')
    assert (root / 'enabled-sshd.service').exists() and (root / 'active-sshd.service').exists()
    # UFW absent : sshd jamais activé sans pare-feu.
    (root / 'enabled-sshd.service').unlink()
    (root / 'active-sshd.service').unlink()
    (root / 'bin/ufw').unlink()
    env['PATH'] = ':'.join([str(root / 'bin')] + [d for d in os.environ['PATH'].split(':') if not Path(d, 'ufw').exists()])
    run('ssh-server', success=False)
    assert not list(root.glob('enabled-*')) and not list(root.glob('active-*'))
    # Journal : la veille gardée, pas plus ; journald relu seulement si le fichier change, retrait complet.
    calls()
    run('--dry-run', 'client-journal')
    assert 'sudo ' not in calls() and not journal.exists()
    run('client-journal')
    conf = journal.read_text()
    assert 'MaxRetentionSec=2day' in conf and 'MaxFileSec=1h' in conf and 'Storage=persistent' in conf
    assert 'systemctl reload systemd-journald.service' in calls()
    run('client-journal')
    assert 'reload' not in calls()
    run('uninstall')
    assert not journal.exists() and 'systemctl reload systemd-journald.service' in calls()
print('PASS sshd : simulation, UFW activé avant sshd (ZeroTier, VM), idempotence, retrait, UFW déjà actif, sshd préexistant, ufw absent ;'
      ' journal : simulation, la veille gardée, idempotence, retrait')
