#!/usr/bin/env python3
"""Intel permissions: fake capabilities and privilege helper, disposable paths only."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='qs-intel-setup-') as tmp:
    for initial in ('', 'cap_net_raw=ep'):
        root = Path(tmp)/('empty' if not initial else 'existing')
        (root/'scripts').mkdir(parents=True)
        shutil.copytree(repo/'dotfiles/pacman',root/'dotfiles/pacman')
        binary=root/'intel_gpu_top';binary.write_text('#!/bin/sh\n');binary.chmod(0o755)
        hook=root/'hooks/test.hook';hook.parent.mkdir();hook.write_text('# original hook\n')
        caps=root/'cap';caps.write_text(initial)
        bindir=root/'bin';bindir.mkdir()
        for name,body in {
            'pkexec': 'echo pkexec >> "$TEST_ROOT/calls"\nexec "$@"',
            'getcap': 'v=$(cat "$TEST_ROOT/cap"); [ -z "$v" ] || printf "%s %s\\n" "$1" "$v"',
            'setcap': '''if [ "$1" = cap_perfmon=ep ] && [ -e "$TEST_ROOT/fail" ]; then exit 1; fi
if [ "$1" = -r ]; then : > "$TEST_ROOT/cap"; else printf '%s' "$1" > "$TEST_ROOT/cap"; fi''',
        }.items():
            p=bindir/name;p.write_text('#!/bin/sh\n'+body+'\n');p.chmod(0o755)
        s=(repo/'scripts/intel-gpu-setup.sh').read_text().replace('/var/lib/qs-desktop/intel-gpu',str(root/'state')).replace('/usr/bin/intel_gpu_top',str(binary)).replace('/etc/pacman.d/hooks/90-qs-intel-gpu.hook',str(hook)).replace('"$(stat -c %u "$binary")" == 0',f'"$(stat -c %u "$binary")" == {os.getuid()}')
        helper=root/'scripts/intel-gpu-setup.sh';helper.write_text(s)
        env=dict(os.environ,TEST_ROOT=str(root),PATH=str(bindir)+':'+os.environ['PATH'])
        def run(*args,ok=True):
            p=subprocess.run(['bash',str(helper),*args],env=env,capture_output=True,text=True)
            assert (p.returncode==0)==ok,p.stdout+p.stderr
        run('--dry-run','install')
        assert not (root/'calls').exists() and not (root/'state').exists()
        (root/'fail').touch();run('install',ok=False)
        assert caps.read_text()==initial and hook.read_text()=='# original hook\n' and not (root/'state').exists()
        (root/'fail').unlink();run('install')
        assert caps.read_text()=='cap_perfmon=ep' and (root/'state/caps').read_text().strip()==initial
        calls=(root/'calls').read_text();run('install');assert (root/'calls').read_text()==calls
        assert 'Exec = /usr/bin/setcap cap_perfmon=ep /usr/bin/intel_gpu_top' in hook.read_text()
        run('--dry-run','uninstall');assert caps.read_text()=='cap_perfmon=ep'
        run('uninstall');assert caps.read_text()==initial and hook.read_text()=='# original hook\n'
        assert not (root/'state').exists();run('uninstall')
        run('install')
        caps.write_text('cap_sys_nice=ep')  # administrator changed the permission after installation
        run('uninstall')
        assert caps.read_text()=='cap_sys_nice=ep','Uninstall overwrote an administrator change'
        assert hook.read_text()=='# original hook\n' and not (root/'state').exists()
    # Existing dependency selection must include the tool only for Intel.
    for vendor in ('intel','amd','nvidia'):
        selected=subprocess.check_output(['awk','-v',f'v={vendor}','!/^#/ && $1 == v {print $2}',str(repo/'deps/gpu.txt')],text=True).splitlines()
        assert ('intel-gpu-tools' in selected)==(vendor=='intel'),selected
    # Exercise the installer system stage with every unrelated action stubbed out.
    script=Path(tmp)/'installer'
    source=(repo/'install.sh').read_text().split('\nif [[ -n "$uninstall" ]]; then\n')[0]
    source += '\nsection() { :; }; gpu_vendors() { echo "$TEST_VENDOR"; }; ask() { [[ "$1" == "Mesures GPU Intel :"* ]]; }; sub() { echo "ACTION $*"; }; step_system\n'
    script.write_text(source)
    for vendor in ('intel','amd','nvidia'):
        result=subprocess.run(['bash',str(script)],env=dict(os.environ,HOME=str(Path(tmp)/'home'),TEST_VENDOR=vendor),capture_output=True,text=True)
        assert result.returncode==0,result.stderr
        assert ('system-setup.sh intel-gpu' in result.stdout)==(vendor=='intel'),result.stdout
print('PASS Intel dependency selection, dry run, rollback, idempotence, hook and capability restoration')
