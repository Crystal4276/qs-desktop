#!/usr/bin/env python3
"""Rebuild Horizon assets/themes offline. Optional --grub-build: configured GRUB source tree."""
import argparse, hashlib, importlib.util, json, pathlib, re, shutil, subprocess
from PIL import Image, ImageDraw, ImageFont
ROOT = pathlib.Path(__file__).resolve().parents[1]
KIT = ROOT / 'assets/grub/horizon'
OUT = ROOT / 'dotfiles/grub/horizon'
def run(*args, **kw): subprocess.run(args, check=True, **kw)
def build():
    spec = importlib.util.spec_from_file_location('horizon_assets', KIT/'tools/build_assets.py')
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); mod.build()
    run('sh', str(KIT/'tools/build_fonts.sh'))
    geometries = json.loads((KIT/'geometry.json').read_text())
    for mode, g in geometries.items():
        dest=OUT/mode; dest.mkdir(parents=True,exist_ok=True)
        s=g['scale']; font=min([14,16,18,20,22,24,26,28,32,36,40,48,56,64],key=lambda n:abs(n-g['font_target_px']))
        small=max(14,round(20*s)); small=min([14,16,18,20,22,24,26,28,32,36,40,48,56,64],key=lambda n:abs(n-small))
        timeout_font=min([14,16,18,20,22,24,26,28,32,36,40,48,56,64],key=lambda n:abs(n-max(14,round(28*s))))
        for size in {font,small,timeout_font,14}: shutil.copy(KIT/f'assets/fonts/inter-{size}.pf2',dest)
        shutil.copy(KIT/f'assets/backgrounds/horizon-{mode}.png',dest/'background.png')
        # Exact nine-slice dimensions at this scale, rather than stretching a rounded sample.
        h=g['item_height']; radius=g['corner_radius']; border=g['border']; cut=radius+border+1
        for name,color in [('normal','#45475a'),('selected','#6c7086')]:
            svg=mod.svg_root(400,h,f'<rect x="{border/2}" y="{border/2}" width="{400-border}" height="{h-border}" rx="{radius}" fill="#181825" stroke="{color}" stroke-width="{border}"/>')
            mod.raster(svg,dest/'sample.png'); im=Image.open(dest/'sample.png'); xs=[0,cut,400-cut,400];ys=[0,border,h-border,h]
            for y,row in enumerate([['nw','n','ne'],['w','c','e'],['sw','s','se']]):
                for x,n in enumerate(row): im.crop((xs[x],ys[y],xs[x+1],ys[y+1])).save(dest/f'{name}_{n}.png')
        (dest/'sample.png').unlink()
        (dest/'icons').mkdir(exist_ok=True)
        mod.raster((KIT/'assets/source/arch_linux_icon_green.svg').read_text(),dest/'icons/arch.png',g['icon_size'],g['icon_size'])
        for name in ('advanced','uefi-firmware','restart'):
            mod.raster((KIT/f'assets/source/{name}.svg').read_text(),dest/f'icons/{name}.png',g['icon_size'],g['icon_size'])
        # The lockup is separate from the background; DM Sans weight 600, optical size 22.
        f=ImageFont.truetype(str(KIT/'assets/fonts/DM-Sans.ttf'),max(10,round(20*s)))
        f.set_variation_by_axes([22,600])
        text='Imaging and Characterization Core Lab'; box=f.getbbox(text)
        im=Image.new('RGBA',(box[2]+2,box[3]-box[1]+2));ImageDraw.Draw(im).text((0,-box[1]),text,font=f,fill='#cdd6f4');im.save(dest/'identity.png')
        iw,ih=im.size; kw=max(16,round(38*s));gap=max(6,round(14*s))
        mod.raster((KIT/'assets/source/kaust-mark.svg').read_text(),dest/'kaust.png',kw)
        w,height=map(int,mode.split('x')); left=round(.555*w); width=round(.377*w)
        # Preserve meaningful suffixes by reserving the whole menu width for text on small modes.
        padding=0; icon=g['icon_size']; space=max(6,round((20 if w<=1024 else 50)*s))
        # Center the visible stack on the unchanged Core Lab center (48% height).
        full_stack=7*h+6*g['item_spacing']
        timeout_top=max(round(.742*height),round(.48*height+full_stack/2+40*s))
        for rows in range(1,8):
            stack_height=rows*h+(rows-1)*g['item_spacing']
            theme_text=f'''title-text: ""
desktop-image: "background.png"
desktop-image-scale-method: "padding"
desktop-color: "#11111b"
+ boot_menu {{
 left = "55%+{round(.005*w)}"
 top = "48%-{stack_height//2}"
 width = "{40 if w<=1024 else 37}%+{round((.005 if w<=1024 else .007)*w)}"
 height = {stack_height}
 item_font = "Inter Regular {font}"
 item_color = "#cdd6f4"
 selected_item_color = "#cdd6f4"
 icon_width = {icon}
 icon_height = {icon}
 item_height = {h-2*border}
 item_padding = {padding}
 item_icon_space = {space}
 item_spacing = {g['item_spacing']+2*border}
 item_pixmap_style = "normal_*.png"
 selected_item_pixmap_style = "selected_*.png"
 scrollbar = false
}}
+ label {{ id = "__timeout__" left = "55%+{round(.005*w)}" top = {timeout_top} width = "37%+{round(.007*w)}" height = {max(20,round(40*s))} font = "Inter Regular {timeout_font}" color = "#a6e3a1" text = "Booting in %d s" }}
+ progress_bar {{ id = "__timeout__" left = "67%+{round(.003*w)}" top = {timeout_top} width = 26% height = {max(28,round(20*s))} font = "Inter Regular 14" fg_color = "#a6e3a1" bg_color = "#181825" border_color = "#6c7086" text = "" }}
+ label {{ left = "2%+{round(.008*w)}" top = 93% width = 45% height = {max(20,round(35*s))} font = "Inter Regular {small}" color = "#cdd6f4" text = "↑ ↓ Select   Enter Boot   E Edit   C Console" }}
+ image {{ left = {round(.94*w)-iw-gap-kw} top = 93% width = {kw} height = {kw} file = "kaust.png" }}
+ image {{ left = {round(.94*w)-iw} top = {round(.93*height)+(kw-ih)//2} width = {iw} height = {ih} file = "identity.png" }}
'''
            (dest/f'theme-{rows}.txt').write_text(theme_text)
        (dest/'theme.txt').write_text(theme_text)
    # Bootstrap is sourced after normal GRUB header, without changing root or prefix.
    cfg=['insmod png','insmod gfxmenu','unset theme', 'if [ -z "$qs_horizon_loaded" ]; then', '  if insmod $prefix/themes/qs-horizon/horizon.mod; then set qs_horizon_loaded=1; export qs_horizon_loaded; fi', 'fi', 'if [ "$qs_horizon_loaded" = 1 ]; then', '  if qs_horizon_video; then', '    set qs_horizon_theme=$prefix/themes/qs-horizon/$qs_horizon_mode/theme-$qs_horizon_rows.txt', '    if [ ! -f $qs_horizon_theme ]; then', '      terminal_output console', '      set gfxmode=1024x768,800x600', '      terminal_output gfxterm', '      qs_horizon_video', '      set qs_horizon_theme=$prefix/themes/qs-horizon/$qs_horizon_mode/theme-$qs_horizon_rows.txt', '    fi', '    if [ -f $qs_horizon_theme ]; then', '      set qs_horizon_ok=1']
    for mode in geometries:
        d=OUT/mode
        cfg+= [f'      if [ "$qs_horizon_mode" = "{mode}" ]; then']
        for p in sorted(d.rglob('*')):
            if p.is_file():
                rel=p.relative_to(OUT)
                cfg += [f'        if [ ! -f $prefix/themes/qs-horizon/{rel} ]; then set qs_horizon_ok=0; fi']
                if p.suffix=='.pf2': cfg += [f'        if ! loadfont $prefix/themes/qs-horizon/{rel}; then set qs_horizon_ok=0; fi']
        cfg+=['      fi']
    cfg+=['      if [ "$qs_horizon_ok" = 1 ]; then set theme=$qs_horizon_theme; export theme; fi', '    fi', '  fi','fi','if [ -z "$theme" ]; then if ! terminal_output gfxterm; then terminal_output console; fi; fi']
    (OUT/'select.cfg').write_text('\n'.join(cfg)+'\n')
if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--grub-build',type=pathlib.Path);a=ap.parse_args();build()
    if a.grub_build:
        src=a.grub_build.resolve()
        upstream=re.search(r'define PACKAGE_VERSION "([^"]+)"',(src/'config.h').read_text())[1]
        installed=subprocess.check_output(['grub-mkstandalone','--version'],text=True).strip()
        if not re.search(r'\(GRUB\) (?:\d+:)?'+re.escape(upstream)+r'(?:-|$)',installed):
            raise SystemExit('Configured GRUB sources differ from installed GRUB version')
        shutil.copy(ROOT/'scripts/grub/horizon.c',src/'grub-core/commands/horizon.c')
        defs=src/'grub-core/Makefile.core.def'; text=defs.read_text()
        if 'name = horizon;' not in text: defs.write_text(text+'\nmodule = { name = horizon; common = commands/horizon.c; };\n')
        run('./autogen.sh',cwd=src)
        run('./config.status',cwd=src)
        run('make','-C',str(src/'grub-core'),'-j4','horizon.mod')
        shutil.copy(src/'grub-core/horizon.mod',OUT/'horizon.mod')

        manifest=json.loads((OUT/'module.json').read_text())
        manifest['sha256']=hashlib.sha256((OUT/'horizon.mod').read_bytes()).hexdigest()
        manifest['grub_version']=subprocess.check_output(['grub-mkstandalone','--version'],text=True).strip()
        manifest['module_source_sha256']=hashlib.sha256((ROOT/'scripts/grub/horizon.c').read_bytes()).hexdigest()
        (OUT/'module.json').write_text(json.dumps(manifest,indent=2)+'\n')
