#!/usr/bin/env python3
"""Legacy rescue naming migration: payloads, BLS names, rollback and saved selections."""
import importlib.util, pathlib, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
s=importlib.util.spec_from_file_location('setup',ROOT/'scripts/grub-horizon-setup.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
def snapshot(r):return {str(p.relative_to(r)):p.read_bytes() for p in r.rglob('*') if p.is_file()}
def fixture(r,marked=True):
    (r/'.horizon-test-root').touch()
    for d in ['etc/default','etc/grub.d','etc/mkinitcpio.d','boot/grub','boot/EFI/Linux']:(r/d).mkdir(parents=True,exist_ok=True)
    (r/'etc/default/grub').write_text('GRUB_DEFAULT=saved\nGRUB_TIMEOUT=5\n')
    (r/'boot/grub/grub.cfg').write_text('old config')
    for kernel in ['linux','linux-lts']:
        (r/f'boot/EFI/Linux/arch-{kernel}.efi').write_bytes(b'normal-'+kernel.encode())
        (r/f'boot/EFI/Linux/arch-{kernel}~rescue.efi').write_bytes(b'rescue-'+kernel.encode())
        (r/f'etc/mkinitcpio.d/{kernel}.preset').write_text(
            "PRESETS=('default' 'rescue')\n"+f'default_uki="/boot/EFI/Linux/arch-{kernel}.efi"\nrescue_uki="/boot/EFI/Linux/arch-{kernel}~rescue.efi"\n'+
            'rescue_options=(-S plymouth)\n'+(m.RESCUE_MARK+'\n' if marked else ''))
def run(r,*args,ok=True):
    p=subprocess.run(['python3',str(ROOT/'scripts/grub-horizon-setup.py'),*args,'--root',str(r)],text=True,capture_output=True)
    assert (p.returncode==0)==ok,(p.stdout,p.stderr)
    return p
with tempfile.TemporaryDirectory(prefix='qs-rescue-names-') as td:
    base=pathlib.Path(td)
    r=base/'migration';r.mkdir();fixture(r,marked=False)
    run(r,'install')  # Existing Horizon state before the legacy marker is adopted.
    for p in (r/'etc/mkinitcpio.d').glob('*.preset'):p.write_text(p.read_text()+m.RESCUE_MARK+'\n')
    before=snapshot(r);run(r,'install','--dry-run');assert snapshot(r)==before
    normal={p.name:p.read_bytes() for p in (r/'boot/EFI/Linux').glob('*.efi') if '~' not in p.name}
    run(r,'install')
    for kernel in ['linux','linux-lts']:
        target=r/f'boot/EFI/Linux/arch-{kernel}.bak.efi'
        assert target.read_bytes()==b'rescue-'+kernel.encode()
        assert not (r/f'boot/EFI/Linux/arch-{kernel}~rescue.efi').exists()
        assert f'rescue_uki="/boot/EFI/Linux/arch-{kernel}.bak.efi"' in (r/f'etc/mkinitcpio.d/{kernel}.preset').read_text()
    assert all((r/'boot/EFI/Linux'/n).read_bytes()==v for n,v in normal.items())
    text=(r/'etc/grub.d/99_qs_horizon').read_text()
    assert 'set default="advanced-options>arch-linux-lts.bak.efi"' in text
    assert 'qs_horizon_group "arch-linux.bak.efi" "arch-linux-lts.bak.efi"' in text
    assert subprocess.check_output(['sort','-Vr'],input=b'arch-linux.efi\narch-linux.bak.efi\n').splitlines()[0]==b'arch-linux.efi'
    before=snapshot(r);assert 'déjà à jour' in run(r,'install').stdout;assert snapshot(r)==before
    # Interrupted post-commit cleanup: matching old/new files are safe to finish.
    (r/'boot/EFI/Linux/arch-linux~rescue.efi').write_bytes(b'rescue-linux')
    run(r,'install');assert not (r/'boot/EFI/Linux/arch-linux~rescue.efi').exists()
    run(r,'uninstall');assert (r/'boot/EFI/Linux/arch-linux.bak.efi').read_bytes()==b'rescue-linux'
    assert 'arch-linux.bak.efi' in (r/'etc/mkinitcpio.d/linux.preset').read_text()
    # A resumed update may already name the new target before its copy exists.
    r=base/'resume';r.mkdir();fixture(r)
    for p in (r/'etc/mkinitcpio.d').glob('*.preset'):p.write_text(p.read_text().replace('~rescue.efi','.bak.efi'))
    run(r,'install')
    assert 'qs_horizon_group "arch-linux.bak.efi" "arch-linux-lts.bak.efi"' in (r/'etc/grub.d/99_qs_horizon').read_text()
    assert 'déjà à jour' in run(r,'install').stdout
    for case in ['collision','missing','unmanaged','failure']:
        r=base/case;r.mkdir();fixture(r,marked=case!='unmanaged')
        if case=='collision':(r/'boot/EFI/Linux/arch-linux.bak.efi').write_bytes(b'foreign')
        if case=='missing':(r/'boot/EFI/Linux/arch-linux~rescue.efi').unlink()
        if case=='failure':(r/'etc/pacman.d').write_text('force failure after copy and preset update')
        before=snapshot(r)
        run(r,'install',ok=case=='unmanaged')
        if case!='unmanaged':
            after=snapshot(r)
            assert all(after.get(k)==v for k,v in before.items()),case
            assert not any('.bak.efi' in k for k in after if k not in before),case
        else:assert (r/'boot/EFI/Linux/arch-linux~rescue.efi').exists()
print('PASS: migration, payload identity, BLS sorting, aliases, dry-run, repeat, interrupted cleanup, conflicts and rollback')
