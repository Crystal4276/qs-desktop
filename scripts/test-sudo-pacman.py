#!/usr/bin/env python3
"""Règle pacman : tests isolés sans privilèges, paquets ni écriture système."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parent.parent
VISUDO = shutil.which('visudo')


def scenario(root, original=None):
    root.mkdir()
    repo = root / 'repo'
    (repo / 'scripts').mkdir(parents=True)
    shutil.copytree(REPO / 'dotfiles/sudoers', repo / 'dotfiles/sudoers')
    binaries = root / 'bin'
    binaries.mkdir()
    sudoers = root / 'sudoers'
    directory = root / 'sudoers.d'
    directory.mkdir()
    sudoers.write_text(f'@includedir {directory}\n')
    target = directory / '90-qs-desktop-pacman'
    if original is not None:
        target.write_text(original)
        target.chmod(0o440)
    for name, body in {
        'sudo': 'echo sudo >> "$TEST_ROOT/calls"\nexec "$@"',
        'visudo': '''echo "visudo $*" >> "$TEST_ROOT/calls"
if [ "$1" = -cf ]; then
    test ! -e "$TEST_ROOT/syntax-fail" || exit 1
    exec "$REAL_VISUDO" -cf "$2"
fi
if [ -e "$TEST_ROOT/final-fail" ] && grep -q 'NOPASSWD: /usr/bin/pacman' "$TEST_ROOT/sudoers.d/90-qs-desktop-pacman" 2>/dev/null; then exit 1; fi
exit 0''',
    }.items():
        path = binaries / name
        path.write_text('#!/bin/sh\n' + body + '\n')
        path.chmod(0o755)
    source = (REPO / 'scripts/system-setup.sh').read_text()
    source = source.replace('state=/var/lib/qs-desktop/system-setup', f'state={root}/state')
    source = source.replace('/etc/sudoers', str(sudoers))
    source = source.replace('-o root -g root', '')
    source = source.replace('440 0:0', f'440 {os.getuid()}:{os.getgid()}')
    helper = repo / 'scripts/system-setup.sh'
    helper.write_text(source)
    helper.chmod(0o755)
    source = (REPO / 'install.sh').read_text().split('\nif [[ -n "$uninstall" ]]; then\n')[0]
    source += '\n[[ -n "$system" ]] && step_pacman_sudo\nprintf "%s\\n" "${pending[@]}"\n'
    installer = repo / 'install.sh'
    installer.write_text(source)
    env = dict(os.environ, TEST_ROOT=str(root), REAL_VISUDO=VISUDO,
               PATH=str(binaries) + ':' + os.environ['PATH'])

    def run(*args, installer_only=False, success=True):
        result = subprocess.run(['bash', str(installer if installer_only else helper), *args],
                                env=env, capture_output=True, text=True, start_new_session=True)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return result.stdout

    return run, target


assert VISUDO, 'visudo requis (paquet sudo)'
with tempfile.TemporaryDirectory(prefix='qs-pacman-sudo-test-') as tmp:
    base = Path(tmp)
    for name, original in [('absent', None), ('present', '# original\n%wheel ALL=(ALL:ALL) ALL\n')]:
        root = base / name
        run, target = scenario(root, original)
        run('--dry-run', 'pacman-sudo')
        assert not (root / 'calls').exists() and not (root / 'state').exists()
        run('pacman-sudo')
        assert '%wheel ALL=(root) NOPASSWD: /usr/bin/pacman' in target.read_text()
        assert target.stat().st_mode & 0o777 == 0o440
        registry = (root / 'state/registry').read_bytes()
        stat = target.stat()
        run('pacman-sudo')
        assert target.stat().st_mtime_ns == stat.st_mtime_ns
        assert (root / 'state/registry').read_bytes() == registry
        run('uninstall')
        assert (target.read_text() if target.exists() else None) == original
        run('uninstall')

    for failure in ['syntax-fail', 'final-fail', 'no-include', 'wrong-include', 'symlink']:
        for original in [None, '# original\n']:
            root = base / f'{failure}-{original is None}'
            run, target = scenario(root, original)
            if failure == 'no-include':
                (root / 'sudoers').write_text('# no includedir\n')
            elif failure == 'wrong-include':
                (root / 'sudoers').write_text(f'@includedir {root}/sudoersXd\n')
            elif failure == 'symlink':
                target.unlink(missing_ok=True)
                target.symlink_to(root / 'untouched')
                (root / 'untouched').write_text('unchanged')
            else:
                (root / failure).touch()
            run('pacman-sudo', success=False)
            if failure == 'symlink':
                assert target.is_symlink() and (root / 'untouched').read_text() == 'unchanged'
            else:
                assert (target.read_text() if target.exists() else None) == original
            assert not list((root / 'sudoers.d').glob('.qs-*'))

    for option in ['--dry-run', '--no-system', '--no-packages', 'refusal', 'yes']:
        root = base / option
        run, target = scenario(root)
        args = [option, '--yes'] if option.startswith('--') else (['--yes'] if option == 'yes' else [])
        run(*args, installer_only=True)
        assert target.exists() == (option in ['--no-packages', 'yes'])
        if option in ['--dry-run', '--no-system', 'refusal']:
            assert not (root / 'calls').exists()
    source = (REPO / 'install.sh').read_text().split('\nif [[ -n "$uninstall" ]]; then\n')[1]
    assert source.index('&& step_pacman_sudo') < source.index('&& step_reflector') < source.index('&& step_packages')
print('PASS sudo pacman : validation, restauration, idempotence, simulation, options, refus, ordre et retrait')
