#!/usr/bin/env python3
"""Règle udev du cache d'écriture des disques amovibles : provisioning isolé, aucune règle ni udev réels modifiés."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parent.parent
RULE = 'dotfiles/udev/60-qs-desktop-removable-writeback.rules'
subprocess.run(['udevadm', 'verify', str(REPO / RULE)], check=True, capture_output=True)
with tempfile.TemporaryDirectory(prefix='qs-writeback-test-') as tmp:
    root = Path(tmp)
    (root / 'scripts').mkdir()
    (root / 'bin').mkdir()
    shutil.copytree(REPO / 'dotfiles/udev', root / 'dotfiles/udev')
    target = root / 'rules.d/60-qs-desktop-removable-writeback.rules'
    source = (REPO / 'scripts/system-setup.sh').read_text().replace('/var/lib/qs-desktop/system-setup', str(root / 'state'))
    source = source.replace('/etc/udev/rules.d/60-qs-desktop-removable-writeback.rules', str(target))
    helper = root / 'scripts/system-setup.sh'
    helper.write_text(source)
    for name, body in {
        'sudo': 'echo "sudo $*" >> "$TEST_ROOT/calls"\nexec env "$@"',
        'udevadm': 'echo "udevadm $*" >> "$TEST_ROOT/calls"',
        # Propriétaire root ignoré : le test tourne sans privilège.
        'install': 'args=()\nwhile (( $# )); do case "$1" in -o|-g) shift 2;; *) args+=("$1"); shift;; esac; done\n'
                   'exec /usr/bin/install "${args[@]}"',
    }.items():
        file = root / 'bin' / name
        file.write_text('#!/bin/bash\n' + body + '\n')
        file.chmod(0o755)
    env = dict(os.environ, TEST_ROOT=tmp, PATH=str(root / 'bin') + ':' + os.environ['PATH'])

    def run(*args):
        result = subprocess.run(['bash', str(helper), *args], env=env, capture_output=True, text=True)
        assert result.returncode == 0, result.stdout + result.stderr

    def calls():
        text = (root / 'calls').read_text() if (root / 'calls').exists() else ''
        (root / 'calls').unlink(missing_ok=True)
        return text

    run('--dry-run', 'removable-writeback')
    assert 'sudo ' not in calls() and not target.exists() and not (root / 'state').exists()
    run('removable-writeback')
    assert target.read_text() == (REPO / RULE).read_text()
    assert 'udevadm control --reload' in calls()
    # Relance : rien ne change, udev pas relu.
    run('removable-writeback')
    assert 'udevadm' not in calls()
    # Règle modifiée dans le dépôt : réinstallée et relue.
    (root / RULE).write_text((REPO / RULE).read_text() + '# changed\n')
    run('removable-writeback')
    assert target.read_text().endswith('# changed\n') and 'udevadm control --reload' in calls()
    run('uninstall')
    assert not target.exists() and 'udevadm control --reload' in calls()
print('PASS règle udev des disques amovibles : syntaxe, simulation, installation, idempotence, mise à jour, retrait')
