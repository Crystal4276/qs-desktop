#!/usr/bin/env python3
"""Boot real GRUB in disposable QEMU/OVMF. No host disks or network attached."""
import argparse,contextlib,importlib.util,json,pathlib,re,shutil,socket,subprocess,sys,time
from PIL import Image, ImageChops
ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('horizon_setup',ROOT/'scripts/grub-horizon-setup.py')
setup=importlib.util.module_from_spec(spec);spec.loader.exec_module(setup)
LABELS=['Arch Linux (standard)','Arch Linux LTS','Arch Linux (standard, fallback)','Arch Linux LTS (fallback)']
def qmp(path,command,arguments=None):
    with socket.socket(socket.AF_UNIX) as s:
        s.settimeout(5);s.connect(str(path));f=s.makefile('rwb');f.readline()
        def call(cmd,args):
            f.write((json.dumps({'execute':cmd,'arguments':args or {}})+'\n').encode());f.flush()
            while True:
                r=json.loads(f.readline())
                if 'error' in r: raise RuntimeError(r)
                if 'return' in r:return r['return']
        call('qmp_capabilities',{});return call(command,arguments)
def is_theme(im):
    colors=dict((c,n) for n,c in im.getcolors(im.width*im.height))
    return (colors.get((17,17,27),0)>im.width*im.height*.25
            and colors.get((24,24,37),0)>1000 and colors.get((166,227,161),0)>20)
def stop_process(process):
    if process.poll() is None:
        process.terminate()
    try: process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill();process.wait(timeout=5)

def run(mode,count,timeout,broken,auto=False,missing_module=False,corrupt=False,default_entry="0",shuffled=False,without_restart=False,resource_fault=None,tpm=False,missing_child=False,corrupt_child=False):
    missing_background = broken and not missing_module and not corrupt and not resource_fault
    broken = broken or missing_module or corrupt or bool(resource_fault)
    out=ROOT/'.shots/grub-horizon'/f'{mode}-{count}{"-corrupt" if corrupt else "-missing-module" if missing_module else "-broken" if broken else ""}{"-auto" if auto else ""}';out.mkdir(parents=True,exist_ok=True)
    if corrupt_child: out=out.with_name(out.name+'-corrupt-child');out.mkdir(parents=True,exist_ok=True)
    if missing_child: out=out.with_name(out.name+'-missing-child');out.mkdir(parents=True,exist_ok=True)
    if tpm: out=out.with_name(out.name+'-tpm');out.mkdir(parents=True,exist_ok=True)
    if resource_fault: out=out.with_name(out.name+'-'+resource_fault);out.mkdir(parents=True,exist_ok=True)
    if default_entry!='0':out=out.with_name(out.name+('-saved' if '>' in default_entry else '-default-'+default_entry));out.mkdir(parents=True,exist_ok=True)
    if shuffled or without_restart:
        out=out.with_name(out.name+('-shuffled' if shuffled else '')+('-without-restart' if without_restart else ''));out.mkdir(parents=True,exist_ok=True)
    fat=out/'fat';(fat/'EFI/BOOT').mkdir(parents=True,exist_ok=True)
    theme=ROOT/'dotfiles/grub/horizon'
    cfg='insmod all_video\ninsmod gfxterm\nloadfont $prefix/fonts/unicode.pf2\nset gfxmode='+('auto' if auto else mode+',auto')+'\nterminal_output gfxterm\nset timeout_style=menu\nset timeout='+str(timeout)+'\nset default="'+default_entry+'"\n'
    for i in (reversed(range(count)) if shuffled else range(count)):
        label=(LABELS+['Advanced options','UEFI Firmware Settings','Restart'])[i%7]
        if count==12 and i==11: label='Arch Linux LTS (fallback) - exemple de titre tres long pour verifier la selection visible'
        if i==4 or (i==6 and without_restart):
            continue  # Created by grouping the two real fixture fallback entries.
        else:
            entry_id={2:'fallback-standard',3:'fallback-lts',5:'uefi-firmware',6:'restart'}.get(i,f'entry-{i}')
            cfg+=f'menuentry "{label}" --class {"arch" if i%7<4 else "other"} --id {entry_id} {{ halt; }}\n'
    cfg+='serial\nterminal_output --append serial\nsource $prefix/themes/qs-horizon/select.cfg\nterminal_output --append serial\n'
    for entry_id,title,cls in setup.ACTION_ENTRIES:
        cfg+=f'if [ -n "$theme" ]; then qs_horizon_entry "{entry_id}" "{title}" "{cls}"; fi\n'
    cfg+=setup.group_config(['fallback-standard','fallback-lts'])
    cfg+=setup.order_config(['entry-0','entry-1'])
    cfg+='source $prefix/themes/qs-horizon/select.cfg\nterminal_output --append serial\n'
    cfg+='echo THEME=$theme\n'
    cfg+='echo MODE=$qs_horizon_mode ROWS=$qs_horizon_rows\necho DEFAULT=$default\nvideoinfo\n'
    (out/'grub.cfg').write_text(cfg)
    files=[f'boot/grub/grub.cfg={out}/grub.cfg']
    files += [f'boot/grub/themes/qs-horizon/{p.relative_to(theme)}={p}' for p in sorted(theme.rglob('*')) if p.is_file() and not ((missing_module and p.name=='horizon.mod') or (missing_background and p.name=='background.png'))]
    if missing_child:
        files=[x for x in files if f'/{mode}/theme-2.txt=' not in x]
    if corrupt_child:
        invalid_child=out/'invalid-child-theme.txt';invalid_child.write_text('+ boot_menu { left = ???')
        files=[x.split('=')[0]+'='+str(invalid_child) if f'/{mode}/theme-2.txt=' in x else x for x in files]
    if resource_fault:
        # Inject malformed lists into the standalone image, never the source theme.
        original=(theme/mode/'resources.lst').read_bytes()
        content={'empty':b'', 'unterminated':b'background.png',
                 'nul':b'background.png\n\0missing.pf2\n',
                 'missing-font':b'background.png\nmissing.pf2\n',
                 'missing-last':original+b'missing.png\n'}[resource_fault]
        bad=out/'resources-fault.lst';bad.write_bytes(content)
        files=[x.split('=')[0]+'='+str(bad) if f'/{mode}/resources.lst=' in x else x for x in files]
    if corrupt:
        invalid=out/'invalid.png';invalid.write_bytes(b'invalid PNG for fault injection')
        files=[x.split('=')[0]+'='+str(invalid) if '/background.png=' in x else x for x in files]
    subprocess.run(['grub-mkstandalone','-O','x86_64-efi','-o',str(fat/'EFI/BOOT/BOOTX64.EFI'),*files],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    vars=out/'vars.fd';shutil.copy('/usr/share/edk2/x64/OVMF_VARS.4m.fd',vars)
    sock=out/'qmp.sock';sock.unlink(missing_ok=True)
    w,h=mode.split('x')
    cmd=['qemu-system-x86_64','-machine','q35,accel=tcg','-m','512','-smp','2','-drive','if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd','-drive',f'if=pflash,format=raw,file={vars}','-drive',f'format=raw,file=fat:rw:{fat}','-vga','none','-device',f'{"virtio-vga" if mode=="1366x768" else "VGA,vgamem_mb=64"},xres={w},yres={h}','-display','none','-net','none','-serial',f'file:{out}/serial.log','-parallel','none','-qmp',f'unix:{sock},server=on,wait=off']
    cleanup=contextlib.ExitStack()
    emulator=None
    if tpm:
        state=out/'tpm-state'
        if state.exists(): shutil.rmtree(state)
        state.mkdir()
        control=out/'swtpm.sock';control.unlink(missing_ok=True)
        emulator=subprocess.Popen(['swtpm','socket','--tpm2','--tpmstate',f'dir={state}',
                                   '--ctrl',f'type=unixio,path={control}'])
        cleanup.callback(stop_process,emulator)
        try:
            deadline=time.monotonic()+10
            while not control.exists():
                if emulator.poll() is not None or time.monotonic()>deadline:
                    raise RuntimeError('swtpm did not start')
                time.sleep(.05)
        except BaseException:
            cleanup.close();raise
        cmd += ['-chardev',f'socket,id=chrtpm,path={control}',
                '-tpmdev','emulator,id=tpm0,chardev=chrtpm','-device','tpm-tis,tpmdev=tpm0']
    with cleanup, (out/'qemu.log').open('w') as log:
        cleanup.callback(sock.unlink,missing_ok=True)
        p=subprocess.Popen(cmd,stdout=log,stderr=log)
        cleanup.callback(stop_process,p)
        try:
            deadline=time.monotonic()+65; found=False
            while time.monotonic()<deadline and p.poll() is None:
                time.sleep(.15)
                if not sock.exists():continue
                ppm=out/'frame.ppm'
                try:qmp(sock,'screendump',{'filename':str(ppm)})
                except (OSError,RuntimeError):continue
                im=Image.open(ppm).convert('RGB')
                if is_theme(im) or (broken and im.width>=640 and im.height>=480 and 'Use the ^ and v keys' in (out/'serial.log').read_text(errors='replace')):
                    im.save(out/'menu.png');found=True;break
            if not found: raise RuntimeError('No Horizon menu captured: '+str(out))
            time.sleep(1.05)
            qmp(sock,'screendump',{'filename':str(ppm)});Image.open(ppm).save(out/'countdown.png')
            qmp(sock,'send-key',{'keys':[{'type':'qcode','data':'down'}]});time.sleep(2.5)
            assert p.poll() is None, 'Keyboard failed to interrupt timeout'
            qmp(sock,'screendump',{'filename':str(ppm)});Image.open(ppm).save(out/'navigation.png')
            if count>=7 and not broken:
                for k in ['home','down','down','ret']:
                    qmp(sock,'send-key',{'keys':[{'type':'qcode','data':k}]});time.sleep(.15)
                for _ in range(70):
                    qmp(sock,'screendump',{'filename':str(ppm)});child=Image.open(ppm).convert('RGB')
                    text_child=missing_child or corrupt_child
                    child_serial=(out/'serial.log').read_text(errors='replace')
                    if (is_theme(child) and not text_child) or (text_child and not is_theme(child) and all(label in child_serial for label in LABELS[2:4])):
                        # Serial output can precede the framebuffer redraw. Require a
                        # stable frame and visible text rows before claiming fallback.
                        time.sleep(.3)
                        qmp(sock,'screendump',{'filename':str(ppm)})
                        stable=Image.open(ppm).convert('RGB')
                        if ImageChops.difference(child,stable).getbbox() is not None:
                            continue
                        if text_child:
                            x,y=stable.size
                            entries=stable.crop((int(.04*x),int(.13*y),int(.96*x),int(.23*y)))
                            if entries.convert('L').point(lambda v:255 if v>100 else 0).histogram()[255]<1000:
                                continue
                        stable.save(out/'submenu.png');break
                    time.sleep(.1)
                else:raise RuntimeError('Fallback submenu did not render')
                qmp(sock,'send-key',{'keys':[{'type':'qcode','data':'esc'}]})
                for _ in range(70):
                    time.sleep(.1);qmp(sock,'screendump',{'filename':str(ppm)})
                    parent=Image.open(ppm).convert('RGB')
                    if is_theme(parent):
                        parent.save(out/'parent-restored.png');break
                else:raise RuntimeError('Parent theme was not restored after submenu')
            if count>7:
                for _ in range(count-1):qmp(sock,'send-key',{'keys':[{'type':'qcode','data':'down'}]});time.sleep(.12)
                qmp(sock,'screendump',{'filename':str(ppm)});Image.open(ppm).save(out/'scroll.png')
            serial=(out/'serial.log').read_text(errors='replace')
            if not broken and count>=7:
                expected=LABELS[:2]+['Advanced options','UEFI Firmware Settings','Restart']
                positions=[serial.index(title) for title in expected]
                assert positions==sorted(positions),'Wrong native menu order'
                if not corrupt_child: assert 'error:' not in serial.lower(),'GRUB reported an error'
                if count==7:assert 'ROWS=5' in serial,'Missing entry or duplicate Restart'
            if resource_fault:
                assert 'THEME=\r' in serial or 'THEME=\n' in serial, 'Invalid resources enabled theme'
            active=re.search(r'MODE=(\d+x\d+)',serial)
            active=active[1] if active else None
            result={'requested':mode,'grub_mode':active,'actual':f'{im.width}x{im.height}','entries':count,'tpm':tpm,'resource_fault':resource_fault,'missing_child_theme':missing_child,'corrupt_child_theme':corrupt_child,'captured':True,'framebuffer_matches':active==f'{im.width}x{im.height}' if active else None}
            (out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(result,flush=True)
        finally:
            if p.poll() is None:
                try:qmp(sock,'quit')
                except (OSError,RuntimeError):pass
            try: p.wait(timeout=10)
            except subprocess.TimeoutExpired: stop_process(p)
    return out
if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--modes',nargs='+',default=['1920x1200','2560x1440','3440x1440','3840x2160']);ap.add_argument('--entries',type=int,choices=[4,7,12],default=7);ap.add_argument('--corrupt-child-theme',action='store_true');ap.add_argument('--missing-child-theme',action='store_true');ap.add_argument('--tpm',action='store_true');ap.add_argument('--resource-fault',choices=['empty','unterminated','nul','missing-font','missing-last']);ap.add_argument('--timeout',type=int,default=2);ap.add_argument('--broken',action='store_true');ap.add_argument('--auto',action='store_true');ap.add_argument('--missing-module',action='store_true');ap.add_argument('--corrupt-background',action='store_true');ap.add_argument('--shuffled',action='store_true');ap.add_argument('--without-restart',action='store_true');ap.add_argument('--default-entry',choices=['0','1','2','entry-0','entry-1','fallback-standard','fallback-lts','advanced-options>fallback-standard'],default='0');a=ap.parse_args()
    failed=False
    for m in a.modes:
        out=run(m,a.entries,a.timeout,a.broken,a.auto,a.missing_module,a.corrupt_background,a.default_entry,a.shuffled,a.without_restart,a.resource_fault,a.tpm,a.missing_child_theme,a.corrupt_child_theme)
        failed |= json.loads((out/'result.json').read_text())['framebuffer_matches'] is False
    sys.exit(1 if failed else 0)
