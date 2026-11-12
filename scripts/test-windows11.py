#!/usr/bin/env python3
"""Launcher state transitions and native desktop installation, without a real VM."""
import json, os, pathlib, subprocess, tempfile, time
R = pathlib.Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-win11-test-') as d:
    p = pathlib.Path(d); (p/'bin').mkdir(); (p/'run').mkdir()
    env = dict(os.environ, PATH=str(p/'bin')+':'+os.environ['PATH'], XDG_RUNTIME_DIR=str(p/'run'), TEST_DIR=d)
    for name, body in {
        'virsh': '''import os, pathlib, sys, time
p=pathlib.Path(os.environ['TEST_DIR']); a=sys.argv[1:]
with (p/'calls').open('a') as f: f.write(' '.join(a)+'\\n')
if 'domstate' in a:
 s=(p/'state').read_text(); print(s); sys.exit(1 if s=='error' else 0)
if (p/'hold-start').exists(): time.sleep(1)
if (p/'fail-start').exists(): sys.exit(1)
''',
        'virt-manager': '''import fcntl, os, pathlib, sys, time
p=pathlib.Path(os.environ['TEST_DIR'])
assert 'XDG_ACTIVATION_TOKEN' not in os.environ
assert sys.argv[1:]==['--connect','qemu:///system','--show-domain-console','win11'], sys.argv
# Verrou rendu avant la console : virt-manager peut rester ouvert, un nouveau clic doit passer.
fcntl.flock(open(pathlib.Path(os.environ['XDG_RUNTIME_DIR'])/'qs-windows11.lock','w'), fcntl.LOCK_EX|fcntl.LOCK_NB)
with (p/'calls').open('a') as f: f.write('console\\n')
if (p/'hold').exists(): time.sleep(1)
''',
        'notify-send': 'import sys\n',
    }.items():
        f=p/'bin'/name; f.write_text('#!/usr/bin/python3\n'+body); f.chmod(0o755)
    cmd=[str(R/'scripts/windows11-launch.sh'), 'qemu:///system', 'win11']
    def launch(state, good=True):
        (p/'state').write_text(state); (p/'calls').write_text('')
        a=subprocess.run(cmd,env=dict(env,XDG_ACTIVATION_TOKEN='test'),capture_output=True)
        assert (a.returncode==0)==good, a.stderr
        return (p/'calls').read_text()
    assert ' start ' in launch('shut off') and 'console' in launch('shut off')
    assert ' start ' not in launch('running')
    assert 'console' not in launch('error',False)
    (p/'fail-start').touch(); assert 'console' not in launch('shut off',False); (p/'fail-start').unlink()
    def concurrent(flag, state, ready):
        (p/flag).touch(); (p/'state').write_text(state); (p/'calls').write_text('')
        a=subprocess.Popen(cmd,env=env)
        for _ in range(100):
            if ready in (p/'calls').read_text(): break
            time.sleep(.01)
        subprocess.run(cmd,env=env,check=True); a.wait(timeout=3); (p/flag).unlink()
        return (p/'calls').read_text()
    # Double clic pendant le démarrage : une seule mise en route, le second clic ne fait rien.
    calls=concurrent('hold-start','shut off',' start ')
    assert calls.count(' start ')==1 and calls.count('console')==1, calls
    # Clic pendant que la console est ouverte : virt-manager rappelé (il réaffiche sa fenêtre).
    assert concurrent('hold','running','console').count('console')==2
    print('PASS states, errors, activation token, double click during start, click with console open')
    # Exercise the real installer functions with isolated state, including desktop escaping.
    t=(R/'install.sh').read_text(); funcs=t[t.index('recorded()'):t.index('# --- 2. Configs')]
    funcs+=t[t.index('host_setting()'):t.index('dnd_mutes()')]
    home=p/'home'; home.mkdir(); repo=p/'repo with spaces'; repo.mkdir(); (repo/'hosts').mkdir()
    (repo/'hosts/default.json').write_text('{}')
    host=repo/'hosts/test.json'; host.write_text('{}')
    env.update(REPO=str(repo),DATA=str(home),STATE=str(p/'registry'),FUNCTIONS=funcs)
    shell='''set -euo pipefail
repo="$REPO"; data="$DATA"; state="$STATE"; registry="$state/registry"; host=test; dry="${TEST_DRY:-}"; stamp=test
run() { [[ -n "$dry" ]] || "$@"; }
eval "$FUNCTIONS"
step_windows11
'''
    def install(dry=''):
        return subprocess.run(['bash','-c',shell],env=dict(env,TEST_DRY=dry),capture_output=True,check=True)
    out=home/'applications/qs-windows11.desktop'
    install(); assert not out.exists()
    host.write_text(json.dumps({'windows11':{'uri':'qemu:///system','domain':'win11'}}))
    install('yes'); assert not out.exists()
    out.parent.mkdir(); out.write_text('original')
    install(); subprocess.run(['desktop-file-validate',str(out)],check=True)
    assert 'repo with spaces/scripts/windows11-launch.sh"' in out.read_text()
    assert out.with_name(out.name+'.bak-test').read_text()=='original'
    before=out.stat().st_mtime_ns; install(); assert out.stat().st_mtime_ns==before
    print('PASS unconfigured host, dry run, backup, spaces, desktop validation, idempotence')
