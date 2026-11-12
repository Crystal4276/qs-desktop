#!/usr/bin/env python3
"""Offline deployment tests: real files in a synthetic root, no privilege or host boot access."""
import importlib.util,json,os,pathlib,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('setup',ROOT/'scripts/grub-horizon-setup.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
with tempfile.TemporaryDirectory(prefix='qs-horizon-test-') as td:
    r=pathlib.Path(td);(r/'.horizon-test-root').touch()
    for d in ['etc/mkinitcpio.d','etc/grub.d','boot/grub','boot/EFI/Linux']:(r/d).mkdir(parents=True,exist_ok=True)
    original='GRUB_TIMEOUT=5\nGRUB_DEFAULT=saved\nGRUB_CMDLINE_LINUX="preserve-me"\nGRUB_THEME="previous-theme"\n'
    (r/'etc/default').mkdir();(r/'etc/default/grub').write_text(original);(r/'boot/grub/grub.cfg').write_text('original generated config')
    for kernel in ['linux','linux-lts']:
        lines=[]
        for variant,suffix in [('default',''),('fallback','-fallback'),('rescue','~rescue')]:
            name=f'arch-{kernel}{suffix}.efi';(r/'boot/EFI/Linux'/name).write_bytes(b'fixture')
            lines.append(f'{variant}_uki="/boot/EFI/Linux/{name}"')
        (r/f'etc/mkinitcpio.d/{kernel}.preset').write_text('\n'.join(lines))
    entries=m.labels(r);assert len(entries)==6
    titles=[t for _,t,_ in entries]
    assert len(set(titles))==6 and 'Arch Linux (standard, fallback)' in titles and 'Arch Linux LTS (fallback)' in titles
    (r/'boot/EFI/Linux/arch-linux-lts-fallback.efi').unlink();assert len(m.labels(r))==5
    def run(action,*args,ok=True):
        p=subprocess.run(['python3',str(ROOT/'scripts/grub-horizon-setup.py'),action,'--root',td,*args],text=True,capture_output=True)
        assert (p.returncode==0)==ok,(p.stdout,p.stderr);return p
    run('install','--dry-run');assert (r/'etc/default/grub').read_text()==original
    run('install');before={str(p.relative_to(r)):p.read_bytes() for p in r.rglob('*') if p.is_file()}
    assert 'déjà à jour' in run('install').stdout
    assert before=={str(p.relative_to(r)):p.read_bytes() for p in r.rglob('*') if p.is_file()}
    snippet=(r/'etc/grub.d/99_qs_horizon').read_text()
    for entry_id,title,cls in m.ACTION_ENTRIES:
        assert f'qs_horizon_entry "{entry_id}" "{title}" "{cls}"' in snippet
    assert 'qs_horizon_group "arch-linux-fallback.efi" "arch-linux~rescue.efi" "arch-linux-lts~rescue.efi"\n' in snippet
    assert '"arch-linux-lts-fallback.efi"' not in snippet
    assert 'menuentry ' not in snippet and 'submenu ' not in snippet
    defaults=r/'etc/default/grub';assert 'preserve-me' in defaults.read_text() and 'GRUB_TIMEOUT=2' in defaults.read_text()
    defaults.write_text(defaults.read_text()+'# user edit\n');run('uninstall',ok=False)
    defaults.write_bytes(before['etc/default/grub']);run('uninstall');assert defaults.read_text()==original
    assert not (r/'etc/grub.d/99_qs_horizon').exists() and not (r/'boot/grub/themes/qs-horizon').exists()
    run('uninstall');assert (r/'boot/grub/grub.cfg').read_text()=='original generated config'
    run('install');run('uninstall');assert defaults.read_text()==original
    (r/'etc/pacman.d/hooks').rmdir();(r/'etc/pacman.d').rmdir();(r/'etc/pacman.d').write_text('force transaction failure')
    run('install',ok=False);assert defaults.read_text()==original and not (r/'boot/grub/themes/qs-horizon').exists()
    assert not (r/'etc/grub.d/99_qs_horizon').exists()
    (r/'etc/pacman.d').unlink()
    (r/'boot/EFI/Linux/arch-linux-fallback.efi').unlink()
    # The laptop has rescue images without conventional fallback images: both still belong under Advanced options.
    run('install');snippet=(r/'etc/grub.d/99_qs_horizon').read_text()
    assert 'qs_horizon_group "arch-linux~rescue.efi" "arch-linux-lts~rescue.efi"\n' in snippet
    assert 'advanced-options>arch-linux~rescue.efi' in snippet
    assert 'advanced-options>arch-linux-lts~rescue.efi' in snippet
    for image in ('arch-linux.efi','arch-linux-lts.efi','arch-linux~rescue.efi','arch-linux-lts~rescue.efi'):
        assert (r/'boot/EFI/Linux'/image).read_bytes()==b'fixture'
    run('uninstall')
    (r/'boot/EFI/Linux/arch-linux-lts~rescue.efi').unlink()
    run('install');snippet=(r/'etc/grub.d/99_qs_horizon').read_text()
    assert 'qs_horizon_group "arch-linux~rescue.efi"\n' in snippet
    assert '"arch-linux-lts~rescue.efi"' not in snippet
    run('uninstall')
    (r/'boot/EFI/Linux/arch-linux~rescue.efi').unlink()
    run('install');assert 'qs_horizon_group' not in (r/'etc/grub.d/99_qs_horizon').read_text()
    run('uninstall')

    # Exercise all installer entry points with fake privilege tools; no actual sudo/polkit or host paths.
    installer=r/'installer';(installer/'scripts').mkdir(parents=True)
    binaries=installer/'bin';binaries.mkdir()
    calls=installer/'calls'
    tools={
        'sudo':'echo sudo >> "$HORIZON_CALLS"\n[ "${HORIZON_DENY:-}" != 1 ] || exit 1\nexport HORIZON_ELEVATED=1\nexec "$@"',
        'pkexec':'echo pkexec >> "$HORIZON_CALLS"\nexit 99',
    }
    for name,body in tools.items():
        p=binaries/name;p.write_text('#!/bin/sh\n'+body+'\n');p.chmod(0o755)
    setup=installer/'scripts/grub-horizon-setup.py'
    setup.write_text('''#!/bin/sh
if [ "$1" != --dry-run ] && [ "${HORIZON_ELEVATED:-}" != 1 ]; then exec pkexec "$0" "$@"; fi
echo "setup $*" >> "$HORIZON_CALLS"
''');setup.chmod(0o755)
    for name in ('system-setup.sh','network-setup.sh','greeter-setup.sh','plymouth-setup.sh'):
        p=installer/'scripts'/name;p.write_text('#!/bin/sh\nexit 0\n');p.chmod(0o755)
    (installer/'scripts/browser-links-setup.py').write_text('')
    source=(ROOT/'install.sh').read_text().split('\nif [[ -n "$uninstall" ]]; then\n')[0]
    for host_path in ('/etc/grub.d/15_uki','/etc/default/grub','/var/lib/qs-desktop'):
        local_path=installer/host_path.lstrip('/')
        source=source.replace(host_path,str(local_path))
    for name in ('etc/grub.d/15_uki','etc/default/grub','var/lib/qs-desktop/grub-horizon/state.json'):
        p=installer/name;p.parent.mkdir(parents=True,exist_ok=True);p.touch()
    script=installer/'install.sh'
    script.write_text(source+'\nif [[ -n "$uninstall" ]]; then do_uninstall; else step_grub_horizon; fi\n')
    env=dict(os.environ,HOME=str(installer/'home'),XDG_CONFIG_HOME=str(installer/'home/config'),
             XDG_STATE_HOME=str(installer/'home/state'),XDG_DATA_HOME=str(installer/'home/data'),
             PATH=str(binaries)+':'+os.environ['PATH'],HORIZON_CALLS=str(calls))
    for args,action in [(('--profil','travail'),'install'),(('--profil','jeux'),'uninstall'),(('--uninstall',),'uninstall')]:
        for dry in (False,True):
            calls.unlink(missing_ok=True)
            result=subprocess.run(['bash',str(script),'--yes','--no-packages',*args,*(['--dry-run'] if dry else [])],
                                  env=env,text=True,capture_output=True)
            assert result.returncode==0,result.stdout+result.stderr
            expected=f'setup --dry-run {action}\n' if dry else f'sudo\nsetup {action}\n'
            assert calls.read_text()==expected,(args,dry,calls.read_text())
    calls.unlink()
    result=subprocess.run(['bash',str(script),'--profil','travail'],env={**env,'HORIZON_DENY':'1'},text=True,capture_output=True)
    assert result.returncode==0 and 'Horizon non installé' in result.stdout
    assert calls.read_text()=='sudo\n','Denied sudo must never fall back to polkit'
print('PASS: names, recovery grouping, absent images, boot parameters, idempotence, rollback and installer sudo/dry-run/denial')
