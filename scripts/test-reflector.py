#!/usr/bin/env python3
"""Reflector: installation et retrait isolés, sans sudo réel, réseau ni service réel."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parent.parent


def scenario(root, enabled=False, active=False, present=True, mode='ok'):
    root.mkdir()
    binaries = root / 'bin'
    binaries.mkdir()
    repo = root / 'repo'
    (repo / 'scripts').mkdir(parents=True)
    shutil.copytree(REPO / 'dotfiles/reflector', repo / 'dotfiles/reflector')
    mirrors = root / 'mirrorlist'
    mirrors.write_text('Server = https://original/$repo/os/$arch\n')
    conf = root / 'reflector.conf'
    conf.write_text('# personal configuration\n')
    (root / 'os-release').write_text('ID=arch\n')
    (root / 'mode').write_text(mode)
    for name, value in [('enabled', enabled), ('active', active)]:
        if value:
            (root / name).touch()
    fake = {
        'sudo': 'exec "$@"',
        'pacman': '''echo "pacman $*" >> "$TEST_ROOT/calls"
[ "$(cat "$TEST_ROOT/mode")" != bootstrap-fail ] || exit 1
printf '#!/bin/sh\nexit 0\n' > "$TEST_ROOT/bin/reflector"
chmod +x "$TEST_ROOT/bin/reflector"''',
        'systemctl': '''echo "systemctl $*" >> "$TEST_ROOT/calls"
case "$1" in
is-enabled) test -f "$TEST_ROOT/enabled";;
is-active) test -f "$TEST_ROOT/active";;
enable) touch "$TEST_ROOT/enabled";;
disable) rm -f "$TEST_ROOT/enabled";;
stop) rm -f "$TEST_ROOT/active";;
start)
 if [ "$2" = reflector.timer ]; then touch "$TEST_ROOT/active"; exit; fi
 case "$(cat "$TEST_ROOT/mode")" in
 fail) echo damaged > "$TEST_ROOT/mirrorlist"; exit 1;;
 empty) echo '# no mirrors' > "$TEST_ROOT/mirrorlist";;
 *) echo 'Server = https://fast/$repo/os/$arch' > "$TEST_ROOT/mirrorlist";;
 esac;;
esac''',
    }
    if present:
        fake['reflector'] = 'exit 0'
    for name, body in fake.items():
        path = binaries / name
        path.write_text('#!/bin/sh\n' + body + '\n')
        path.chmod(0o755)
    source = (REPO / 'scripts/system-setup.sh').read_text()
    source = source.replace('state=/var/lib/qs-desktop/system-setup', f'state={root}/state')
    source = source.replace('/etc/xdg/reflector/reflector.conf', str(conf))
    source = source.replace('/etc/pacman.d/mirrorlist', str(mirrors))
    source = source.replace('/etc/os-release', str(root / 'os-release'))
    source = source.replace(' -o root -g root', '')  # faux sudo : aucune attribution root dans le banc
    helper = repo / 'scripts/system-setup.sh'
    helper.write_text(source)
    helper.chmod(0o755)
    source = (REPO / 'install.sh').read_text().split('\nif [[ -n "$uninstall" ]]; then\n')[0]
    source = source.replace('/etc/os-release', str(root / 'os-release'))
    # Le vrai branchement de l'étape préliminaire ; le reste du bureau n'est pas installé dans ce test.
    source += '\n[[ -n "$system" ]] && step_reflector\necho PACKAGES\nprintf "%s\\n" "${pending[@]}"\n'
    installer = repo / 'install.sh'
    installer.write_text(source)
    env = dict(os.environ, TEST_ROOT=str(root), HOME=str(root / 'home'), PATH=str(binaries) + ':' + os.environ['PATH'])

    def run(*args, helper_only=False, success=True):
        result = subprocess.run(['bash', str(helper if helper_only else installer), *args], env=env, text=True, capture_output=True, start_new_session=True)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return result.stdout

    def calls():
        return (root / 'calls').read_text() if (root / 'calls').exists() else ''

    return run, calls, mirrors, conf


with tempfile.TemporaryDirectory(prefix='qs-reflector-test-') as tmp:
    base = Path(tmp)
    for enabled, active in [(False, False), (True, True), (True, False), (False, True)]:
        root = base / f'normal-{enabled}-{active}'
        run, calls, mirrors, conf = scenario(root, enabled, active)
        originals = mirrors.read_bytes(), conf.read_bytes()
        run('--dry-run', '--yes')
        assert all(line.startswith(('systemctl is-enabled', 'systemctl is-active')) for line in calls().splitlines())
        assert (mirrors.read_bytes(), conf.read_bytes()) == originals
        (root / 'calls').unlink(missing_ok=True)
        assert not (root / 'state').exists()
        out = run('--yes')
        assert 'start reflector.service' in out, out
        assert out.index('start reflector.service') < out.index('PACKAGES')
        assert 'https://fast/' in mirrors.read_text()
        assert (root / 'enabled').exists() and (root / 'active').exists()
        before = calls()
        run('--yes')
        assert calls().count('start reflector.service') == 1
        assert calls()[len(before):].count('start reflector.timer') == 0
        # Disparition de la liste : réinitialisation même si le marqueur existe.
        mirrors.unlink()
        run('--yes')
        assert 'https://fast/' in mirrors.read_text()
        # Changement de configuration : nouvelle initialisation, sauvegarde initiale intacte.
        conf.write_text('# changed\n')
        run('--yes')
        assert calls().count('start reflector.service') == 3
        # Échec après une ancienne réussite : garder la dernière liste, puis retenter.
        latest = mirrors.read_bytes()
        conf.write_text('# another change\n')
        (root / 'mode').write_text('fail')
        run('--yes')
        assert mirrors.read_bytes() == latest
        assert not (root / 'state/reflector-ready').exists()
        (root / 'mode').write_text('ok')
        run('--yes')
        assert calls().count('start reflector.service') == 5
        run('uninstall', helper_only=True)
        assert (mirrors.read_bytes(), conf.read_bytes()) == originals
        assert (root / 'enabled').exists() == enabled
        assert (root / 'active').exists() == active
        run('uninstall', helper_only=True)

    for mode in ['fail', 'empty', 'bootstrap-fail']:
        root = base / mode
        run, calls, mirrors, conf = scenario(root, present=mode != 'bootstrap-fail', mode=mode)
        original = mirrors.read_bytes()
        out = run('--yes')
        assert mirrors.read_bytes() == original and 'PACKAGES' in out
        assert 'relancer install.sh' in out
        assert not (root / 'state/reflector-ready').exists()
        assert not (root / 'active').exists()
        (root / 'mode').write_text('ok')
        run('--yes')
        assert 'https://fast/' in mirrors.read_text()

    root = base / 'bootstrap'
    run, calls, mirrors, conf = scenario(root, present=False)
    out = run('--yes')
    assert calls().index('pacman -S --needed --noconfirm reflector') < calls().index('start reflector.service')
    assert '-Sy' not in calls()

    for option in ['--no-system', '--no-packages', 'refusal', 'derivative']:
        root = base / option
        run, calls, mirrors, conf = scenario(root, present=False)
        if option == 'derivative':
            (root / 'os-release').write_text('ID=manjaro\nID_LIKE=arch\n')
        run(*([] if option in ['refusal', 'derivative'] else [option, '--yes']))
        assert not calls()
        assert not (root / 'state').exists()
    root = base / 'no-packages-present'
    run, calls, mirrors, conf = scenario(root)
    run('--no-packages', '--yes')
    assert 'pacman ' not in calls() and 'start reflector.service' in calls()

    root = base / 'absent-files'
    run, calls, mirrors, conf = scenario(root)
    mirrors.unlink()
    conf.unlink()
    run('--yes')
    assert mirrors.exists() and conf.exists()
    run('uninstall', helper_only=True)
    assert not mirrors.exists() and not conf.exists()

print('PASS Reflector: ordre, amorçage, options, simulation, échecs, reprise, idempotence, retrait et états antérieurs du timer')
