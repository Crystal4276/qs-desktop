#!/usr/bin/env python3
"""Vrai Samba dans un espace réseau isolé : pkexec unshare --net python3 scripts/test-samba-network.py."""
import pathlib, tempfile, subprocess, time, socket, os, signal, threading
if os.readlink('/proc/self/ns/net') == os.readlink('/proc/1/ns/net'):
    raise SystemExit('Espace réseau isolé obligatoire')
REPO = pathlib.Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-samba-native-') as d:
    p = pathlib.Path(d)
    for n in ['state', 'lock', 'cache', 'private', 'pid', 'rpc']:
        (p / n).mkdir()
    conf = p / 'smb.conf'
    base = (REPO / 'dotfiles/samba/smb.conf').read_text()
    extra = '\n[global]\nsmb ports = 1445\n'
    for k, v in [('state directory', 'state'), ('lock directory', 'lock'), ('cache directory', 'cache'), ('private dir', 'private'), ('pid directory', 'pid'), ('ncalrpc dir', 'rpc')]:
        extra += f'{k} = {p / v}\n'
    extra += f'log file = {p}/log.%m\n'
    conf.write_text(base + extra)

    def ip(*args):
        subprocess.run(['ip', *args], check=True, capture_output=True)
    ip('link', 'set', 'lo', 'up')
    ip('link', 'add', 'virbrqscheck', 'type', 'dummy')
    ip('addr', 'add', '203.0.113.1/24', 'dev', 'virbrqscheck')
    ip('link', 'set', 'virbrqscheck', 'up')

    def add_zerotier():
        time.sleep(1)
        ip('link', 'add', 'ztqscheck', 'type', 'dummy')
        ip('addr', 'add', '192.0.2.1/24', 'dev', 'ztqscheck')
        ip('link', 'set', 'ztqscheck', 'up')
    thread = threading.Thread(target=add_zerotier)
    thread.start()
    (p / 'bin').mkdir()
    (p / 'bin/systemctl').write_text('#!/bin/sh\nexit 0\n')
    (p / 'bin/systemctl').chmod(493)
    env = dict(os.environ, PATH=str(p / 'bin') + ':' + os.environ['PATH'])
    subprocess.run(['bash', str(REPO / 'scripts/samba-wait-zerotier.sh')], check=True, env=env)
    assert b'192.0.2.1/24' in subprocess.check_output(['ip', '-o', '-4', 'addr', 'show', 'dev', 'ztqscheck']), 'Le serveur doit attendre une adresse'
    thread.join()
    proc = subprocess.Popen(['smbd', '-F', '--no-process-group', '-l', str(p), '-s', str(conf)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, start_new_session=True)
    try:

        def listens(addr, expected):
            for _ in range(50):
                try:
                    with socket.create_connection((addr, 1445), timeout=0.1):
                        ok = True
                except OSError:
                    ok = False
                if ok == expected:
                    return
                time.sleep(0.1)
            raise AssertionError(f'{addr}: expected listening={expected}; smbd exit={proc.poll()}')
        listens('127.0.0.1', True)
        listens('203.0.113.1', True)
        listens('192.0.2.1', True)
        ip('addr', 'del', '192.0.2.1/24', 'dev', 'ztqscheck')
        listens('192.0.2.1', False)
        ip('addr', 'add', '192.0.2.1/24', 'dev', 'ztqscheck')
        listens('192.0.2.1', True)
        ip('link', 'add', 'wifiqscheck', 'type', 'dummy')
        ip('addr', 'add', '198.51.100.1/24', 'dev', 'wifiqscheck')
        ip('link', 'set', 'wifiqscheck', 'up')
        listens('198.51.100.1', False)
        print('PASS natif Samba : attente ZeroTier au démarrage, accès libvirt, retrait et retour IP ZeroTier, interface physique refusée')
    finally:
        os.killpg(proc.pid, signal.SIGTERM) if proc.poll() is None else None
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        if proc.returncode not in (0, -15):
            print(proc.stderr.read().decode())
            for f in p.glob('log*'):
                if f.is_file():
                    print(f.read_text())
