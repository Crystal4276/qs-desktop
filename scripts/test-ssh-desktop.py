#!/usr/bin/env python3
"""SSH de l'installateur : vraies clés jetables, connexions distantes simulées."""
import os
from pathlib import Path
import pty
import select
import shutil
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-ssh-test-') as tmp:
    root = Path(tmp)
    binaries = root / 'bin'
    binaries.mkdir()
    real_ssh = shutil.which('ssh')
    fake_ssh = binaries / 'ssh'
    fake_ssh.write_text('#!/bin/bash\nif [[ "$1" == -G ]]; then exec ' + real_ssh + ''' "$@"; fi
printf 'connect\\n' >> "$TEST_ROOT/calls"
test -f "$TEST_ROOT/authorized" && test ! -f "$TEST_ROOT/offline"
''')
    copy = binaries / 'ssh-copy-id'
    copy.write_text('''#!/bin/bash
echo copy-id >> "$TEST_ROOT/calls"
test ! -f "$TEST_ROOT/offline" || exit 1
touch "$TEST_ROOT/authorized"
''')
    for file in (copy, fake_ssh):
        file.chmod(0o755)
    installer = root / 'install.sh'
    source = (REPO / 'install.sh').read_text().split('\nif [[ -n "$uninstall" ]]; then\n')[0]
    installer.write_text(source + '\nif [[ -n \"$uninstall\" ]]; then do_uninstall; else step_ssh_desktop; fi\n')
    home = root / 'home'
    home.mkdir()
    env = dict(os.environ, HOME=str(home), TEST_ROOT=tmp,
               PATH=str(binaries) + ':' + os.environ['PATH'])

    def run(*args):
        result = subprocess.run(['bash', str(installer), '--no-system', '--no-packages', *args],
                                env=env, capture_output=True, text=True, start_new_session=True, timeout=15)
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout

    def interactive(answer):
        pid, fd = pty.fork()
        if pid == 0:
            os.execvpe('bash', ['bash', str(installer), '--no-system', '--no-packages'], env)
        output = b''
        sent = False
        try:
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                if select.select([fd], [], [], .2)[0]:
                    try:
                        chunk = os.read(fd, 65536)
                    except OSError:
                        break
                    if not chunk:
                        break
                    output += chunk
                    if b'? Destination SSH' in output and not sent:
                        os.write(fd, answer.encode() + b'\n')
                        sent = True
            else:
                os.kill(pid, 9)
                raise AssertionError(output.decode())
        finally:
            os.close(fd)
            _, status = os.waitpid(pid, 0)
        assert status == 0, output.decode()
        return output.decode()

    assert 'simulation' in run('--dry-run').lower()
    assert not (home / '.ssh').exists() and not (root / 'calls').exists()
    assert 'destination absente' in run('--yes')
    assert 'destination absente' in run()
    interactive('')
    assert not (home / '.ssh').exists()
    interactive('bad target with spaces')
    assert not (home / '.ssh').exists()
    sshdir = home / '.ssh'
    sshdir.mkdir()
    config = sshdir / 'config'
    original = 'ServerAliveInterval 37\nHost unrelated\n    HostName example.invalid\n'
    config.write_text(original)
    interactive('tester@192.0.2.8')
    key = sshdir / 'id_ed25519_terrier'
    public = sshdir / 'id_ed25519_terrier.pub'
    assert public.read_text().startswith('ssh-ed25519 ')
    assert (key.stat().st_mode & 0o777) == 0o600
    assert (public.stat().st_mode & 0o777) == 0o644
    assert (sshdir.stat().st_mode & 0o777) == 0o700
    assert (config.stat().st_mode & 0o777) == 0o600
    assert config.read_text().endswith(original)
    effective = subprocess.check_output([real_ssh, '-G', '-F', str(config), 'unrelated'], text=True)
    assert 'hostname example.invalid\n' in effective and 'serveraliveinterval 37\n' in effective
    assert (root / 'calls').read_text().count('copy-id') == 1
    before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in (key, public, config)}
    run('--yes')
    assert before == {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in before}
    assert (root / 'calls').read_text().count('copy-id') == 1
    calls = (root / 'calls').read_bytes()
    run('--dry-run')
    assert (root / 'calls').read_bytes() == calls
    (root / 'authorized').unlink()
    assert 'ssh-copy-id' in run('--yes')
    assert (root / 'calls').read_text().count('copy-id') == 1
    (root / 'offline').touch()
    assert 'autorisation inachevée' in interactive('')
    # Un retrait du bureau ne doit pas référencer les fichiers SSH dans son registre.
    assert not (home / '.local/state/qs-desktop/install/registry').exists()
    run('--uninstall')
    assert before == {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in before}
    public.unlink()
    assert 'incomplète' in run('--yes')
    assert key.read_bytes() == before[key][0]
print('PASS SSH : question initiale, vraie clé, autorisation, relances, permissions, config existante, simulation, modes sans terminal et panne réseau')
