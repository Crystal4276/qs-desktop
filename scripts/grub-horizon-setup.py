#!/usr/bin/env python3
"""Reversible Horizon deployment. Never runs grub-install or rebuilds initramfs."""
import argparse,hashlib,json,os,pathlib,re,shutil,subprocess,sys,tempfile
REPO=pathlib.Path(__file__).resolve().parents[1]
THEME=REPO/'dotfiles/grub/horizon'
MARK='# Managed by QS Desktop Horizon'
# Existing entries only: IDs used by GRUB and the approved preview. No new boot actions.
ACTION_ENTRIES=[('advanced-options','Advanced options','advanced'),
                ('uefi-firmware','UEFI Firmware Settings','uefi-firmware'),
                ('restart','Restart','restart')]
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def labels(root):
    result=[]
    for p in sorted((root/'etc/mkinitcpio.d').glob('*.preset')):
        kernel=p.stem
        if kernel not in ('linux','linux-lts'):continue
        kind='standard' if kernel=='linux' else 'LTS'
        for variant,path in re.findall(r'^([a-z]+)_uki=[\'\"]([^\'\"]+)[\'\"]\s*$',p.read_text(),re.M):
            image=root/path.lstrip('/')
            if not image.is_file():continue
            if variant=='default':title='Arch Linux (standard)' if kind=='standard' else 'Arch Linux LTS'
            elif variant=='fallback':title='Arch Linux (standard, fallback)' if kind=='standard' else 'Arch Linux LTS (fallback)'
            elif variant=='rescue':title=f'Arch {kind} (secours sans Plymouth)'
            else:continue
            result.append((image.name,title,'arch'))
    return result
def group_config(ids):
    if not ids:return ''
    # A pre-existing automatic boot-failure fallback strategy keeps its top-level indexes.
    restore=''.join(f'if [ "$default" = "advanced-options>{i}" ]; then set default="{i}"; fi\n' for i in ids)
    return restore+('if [ -n "$theme" -a -z "$fallback" ]; then\n'
            '  qs_horizon_group '+ ' '.join('"'+i+'"' for i in ids)+'\n'
            '  source $prefix/themes/qs-horizon/select.cfg\nfi\n')
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('action',choices=['audit','status','install','uninstall']);ap.add_argument('--dry-run',action='store_true');ap.add_argument('--root',type=pathlib.Path,default=pathlib.Path('/'));a=ap.parse_args();root=a.root.resolve()
    def path(s):return root/s.lstrip('/')
    state=path('/var/lib/qs-desktop/grub-horizon'); dest=path('/boot/grub/themes/qs-horizon'); cfg=path('/boot/grub/grub.cfg');defaults=path('/etc/default/grub');snippet=path('/etc/grub.d/99_qs_horizon');hook=path('/etc/pacman.d/hooks/91-qs-horizon-module.hook')
    if a.action in ('audit','status'):
        print(json.dumps({'installed':(state/'state.json').exists(),'grub_config_readable':os.access(cfg,os.R_OK),'images':[{'id':i,'title':t,'class':c} for i,t,c in labels(root)],'module_present':(dest/'horizon.mod').exists()},indent=2));return
    if a.dry_run:
        print(f'{a.action}: {dest}, {defaults}, {snippet}, {hook}; validation grub-script-check, génération grub-mkconfig, sauvegarde/restauration dans {state}');return
    if root==pathlib.Path('/') and os.geteuid()!=0:
        os.execvp('pkexec',['pkexec',sys.executable,str(pathlib.Path(__file__).resolve()),a.action]);return
    # A synthetic root may only be used for offline tests. No probing the host in that case.
    real=root==pathlib.Path('/')
    if not real and not (root/'.horizon-test-root').exists():raise RuntimeError('Synthetic root requires .horizon-test-root')
    old=json.loads((state/'state.json').read_text()) if (state/'state.json').exists() else None
    if a.action=='uninstall' and not old:print('Horizon absent');return
    if a.action=='install':
        if not cfg.is_file() or not defaults.is_file():raise RuntimeError('GRUB existant attendu ; aucun chargeur installé par cet outil')
        manifest=json.loads((THEME/'module.json').read_text())
        if digest(THEME/'horizon.mod')!=manifest['sha256']:raise RuntimeError('Empreinte du module invalide')
        if real:
            if not path('/etc/grub.d/15_uki').is_file():raise RuntimeError('Intégration UKI attendue (15_uki) ; aucun générateur remplacé')
            version=subprocess.check_output(['grub-mkstandalone','--version'],text=True).strip()
            if version!=manifest['grub_version']:raise RuntimeError('Version GRUB différente : reconstruire le module avant installation')
            if 'x86_64-efi' not in manifest['platform']:raise RuntimeError('Module non UEFI x86_64')
            if not pathlib.Path('/sys/firmware/efi').exists():raise RuntimeError('Thème graphique réservé à UEFI ; chargeur existant conservé')
        original=defaults.read_text()
        changed=original
        for key,value in [('GRUB_TIMEOUT_STYLE','menu'),('GRUB_TIMEOUT','2'),('GRUB_GFXMODE','auto'),('GRUB_TERMINAL_OUTPUT','gfxterm')]:
            changed=re.sub(r'^'+key+r'=.*\n?','',changed,flags=re.M)
            changed+=f'\n{key}={value}\n'
        # Avoid loading any previous theme from 00_header; restore it on uninstall.
        changed=re.sub(r'^GRUB_THEME=.*$', '# Previous theme suspended by QS Desktop Horizon',changed,flags=re.M)
        text='#!/bin/sh\n'+MARK+'\ncat <<\'QS_HORIZON\'\nsource $prefix/themes/qs-horizon/select.cfg\n'
        for image,title,cls in labels(root)+ACTION_ENTRIES:
            if not re.fullmatch(r'[A-Za-z0-9_.~+-]+',image):raise RuntimeError('Unsupported UKI filename')
            text+=f'if [ -n "$theme" ]; then qs_horizon_entry "{image}" "{title}" "{cls}"; fi\n'
        recovery_ids=[image for image,title,cls in sorted(labels(root),key=lambda e:'LTS' in e[1]) if '(fallback)' in title or ', fallback)' in title or '(secours sans Plymouth)' in title]
        text+=group_config(recovery_ids)
        text+='QS_HORIZON\n'
        hooktext='''# Managed by QS Desktop Horizon
[Trigger]
Operation = Upgrade
Operation = Install
Type = Package
Target = grub
[Action]
Description = Disabling Horizon module until rebuilt for updated GRUB
When = PostTransaction
Exec = /usr/bin/rm -f /boot/grub/themes/qs-horizon/horizon.mod
'''
        if old and all(p.is_file() and digest(p)==old['installed'].get(str(p.relative_to(root))) for p in [defaults,snippet,hook]) and dest.exists() and all((dest/p.relative_to(THEME)).is_file() and digest(dest/p.relative_to(THEME))==digest(p) for p in THEME.rglob('*') if p.is_file()):
            # Recheck image inventory: updates may add a fallback after the initial install.
            if snippet.read_text()==text:print('Horizon déjà à jour');return
        if old:
            for p in (defaults,snippet,hook):
                if not p.is_file() or digest(p)!=old['installed'].get(str(p.relative_to(root))):raise RuntimeError(f'Réglage modifié depuis installation : {p} ; examiner avant mise à jour')
        if not old and (dest.exists() or snippet.exists() or hook.exists()):raise RuntimeError('Destination existante non gérée ; rien remplacé')
        writes={defaults:changed,snippet:text,hook:hooktext}
    else:
        for name,expected in old['installed'].items():
            p=path(name)
            if p.exists() and digest(p)!=expected:raise RuntimeError(f'Réglage modifié : {p} ; restauration automatique refusée')
        writes={}
    # Keep first originals for removal, plus a separate rollback snapshot of every transaction.
    state.mkdir(parents=True,exist_ok=True)
    targets=[defaults,snippet,hook,cfg]
    with tempfile.TemporaryDirectory(prefix='transaction-',dir=state) as td:
        rollback=pathlib.Path(td)
        for i,p in enumerate(targets):
            if p.exists():shutil.copy2(p,rollback/str(i))
        if dest.exists():shutil.copytree(dest,rollback/'theme')
        if not old and a.action=='install':
            (state/'original').mkdir(exist_ok=True)
            for i,p in enumerate(targets):
                if p.exists():shutil.copy2(p,state/'original'/str(i))
        try:
            if a.action=='install':
                if dest.exists():shutil.rmtree(dest)
                shutil.copytree(THEME,dest)
                for p,text in writes.items():p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
                snippet.chmod(0o755)
            else:
                for i,p in enumerate(targets[:3]):
                    saved=state/'original'/str(i)
                    if saved.exists():shutil.copy2(saved,p)
                    else:p.unlink(missing_ok=True)
                if dest.exists():shutil.rmtree(dest)
            if real:
                candidate=cfg.with_name('grub.cfg.horizon-new')
                try:
                    subprocess.run(['grub-mkconfig','-o',str(candidate)],check=True)
                    subprocess.run(['grub-script-check',str(candidate)],check=True)
                    candidate.replace(cfg)
                finally:candidate.unlink(missing_ok=True)
            if a.action=='install':
                data={'installed':{str(p.relative_to(root)):digest(p) for p in (defaults,snippet,hook)}}
                pending=state/'state.json.new'
                pending.write_text(json.dumps(data,indent=2)+'\n');pending.replace(state/'state.json')
            else:(state/'state.json').unlink()
        except BaseException:
            for i,p in enumerate(targets):
                saved=rollback/str(i)
                if saved.exists():shutil.copy2(saved,p)
                elif p.is_file() or p.is_symlink():p.unlink()
            if dest.exists():shutil.rmtree(dest)
            if (rollback/'theme').exists():shutil.copytree(rollback/'theme',dest)
            raise
    print('Horizon '+('installé' if a.action=='install' else 'retiré'))
if __name__=='__main__':
    try:main()
    except (RuntimeError,subprocess.CalledProcessError,OSError) as e:sys.exit(str(e))
