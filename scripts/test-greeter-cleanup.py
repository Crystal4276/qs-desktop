#!/usr/bin/env python3
"""Exercise only greeter removal, with private paths and fake privilege/service commands."""
import os
from pathlib import Path
import subprocess
import tempfile

SOURCE = Path(__file__).with_name('greeter-setup.sh').read_text()
with tempfile.TemporaryDirectory(prefix='qs-greeter-cleanup-') as tmp:
    root = Path(tmp)
    binaries = root / 'bin'
    binaries.mkdir()
    for name, body in {
        'sudo': 'exec "$@"',
        'systemctl': 'case "$1" in is-active) test -f "$TEST_ROOT/active";; is-enabled) exit 1;; *) exit 0;; esac',
    }.items():
        path = binaries / name
        path.write_text('#!/bin/sh\n' + body + '\n')
        path.chmod(0o755)
    # Only these two production roots are redirected; no real privileged command is used.
    script = root / 'cleanup.sh'
    script.write_text(SOURCE.replace('dest=/usr/local/share/qs-desktop', f'dest={root}/installed')
        .replace('var=/var/lib/qs-desktop', f'var={root}/state'))
    state = root / 'state'
    state.mkdir()
    for name in ('network-setup', 'openrgb-setup', 'alice', 'greeter', 'backup'):
        (state / name).mkdir()
    protected = [state / name / 'keep' for name in ('network-setup', 'openrgb-setup', 'alice')]
    protected += [state / 'network-setup.lock', state / 'unrelated']
    for file in protected:
        file.write_bytes(b'original\x00contents')
    target = root / 'pam-target'
    target.write_text('installed')
    saved = state / 'backup' / 'pam-original'
    saved.write_text('original')
    (state / 'backups').write_text(f'{target} {saved}\n')
    (state / 'previous-dm').write_text('sddm.service')
    (state / 'greeter' / 'state.json').write_text('{}')
    (root / 'installed').mkdir()
    env = dict(os.environ, TEST_ROOT=tmp, PATH=str(binaries) + ':' + os.environ['PATH'])
    def run(*args):
        result = subprocess.run(['bash', str(script), *args, 'uninstall'], env=env, capture_output=True, text=True)
        assert result.returncode == 0, result.stdout + result.stderr
    def preserved():
        assert all(p.read_bytes() == b'original\x00contents' for p in protected)
    run('--dry-run')
    assert target.read_text() == 'installed' and saved.exists()
    (root / 'active').touch()
    run()
    assert saved.exists() and (root / 'installed').exists()
    (root / 'active').unlink()
    # Missing backup: retain the recovery record and previous display manager.
    missing = state / 'backup' / 'missing'
    with (state / 'backups').open('a') as f:
        f.write(f'{root}/missing-target {missing}\n')
    run()
    preserved()
    assert target.read_text() == 'original'
    assert (state / 'backups').read_text() == f'{root}/missing-target {missing}\n'
    assert (state / 'previous-dm').exists()
    missing.write_text('recovered')
    run()
    preserved()
    assert (root / 'missing-target').read_text() == 'recovered'
    assert not (state / 'greeter').exists()
    assert not (state / 'backups').exists() and not (state / 'previous-dm').exists()
    run()
    preserved()
print('PASS greeter: shared data, dry-run, active service, missing backup, restore, repeated uninstall')
