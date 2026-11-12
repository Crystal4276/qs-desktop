#!/usr/bin/env python3
"""Build code-native GRUB assets. Requires Python 3, Pillow, rsvg-convert."""
from pathlib import Path
import json, math, subprocess, xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RESOLUTIONS = [(800,600),(1024,768),(1280,720),(1280,800),(1366,768),(1600,900),(1920,1080),(1920,1200),(2560,1080),(2560,1440),(2560,1600),(3440,1440),(3840,1600),(3840,2160)]
RINGS = [(1.278,'#89dceb',.55,3,10),(1.456,'#89dceb',.32,2,14),(1.733,'#74c7ec',.45,3,12),(2.122,'#74c7ec',.28,2,16),(2.467,'#89b4fa',.30,3,18),(2.956,'#89b4fa',.20,2,20),(3.456,'#6c7086',.45,2,22),(4.022,'#585b70',.45,2,24),(4.644,'#45475a',.50,2,26),(5.350,'#45475a',.42,2,28),(6.100,'#45475a',.34,2,30),(6.900,'#313244',.70,2,32),(7.750,'#313244',.55,2,34),(8.650,'#313244',.45,2,36),(9.600,'#313244',.35,2,38)]

def raster(svg, png, width=None, height=None):
    args=['rsvg-convert','-o',str(png)]
    if width is not None: args += ['-w',str(width)]
    if height is not None: args += ['-h',str(height)]
    subprocess.run(args,input=svg.encode(),check=True)

def svg_root(w,h,body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'

def build():
    for name in ['backgrounds','icons','pills','decor']:
        (ROOT/'assets'/name).mkdir(parents=True,exist_ok=True)
    mark=ET.fromstring((ROOT/'assets/source/corelab-mark.svg').read_text())
    mark_inner=''.join(ET.tostring(x,encoding='unicode') for x in mark)
    geometry={}
    for w,h in RESOLUTIONS:
        scale=min(w/1920,h/1080)
        cx,cy=.305*w,.48*h
        diameter=500*scale
        body=[f'<rect width="{w}" height="{h}" fill="#11111b"/>']
        radius=diameter/2
        for factor,color,opacity,thickness,gap in RINGS:
            r=radius*factor
            count=max(12,round(2*math.pi*r/(gap*radius/180)))
            dot=thickness*scale/2
            # Keep the menu area quiet without a horizontal band or a visible edge.
            for k in range(count):
                a=k*2*math.pi/count
                x,y=cx+r*math.cos(a),cy+r*math.sin(a)
                if not (-dot<=x<=w+dot and -dot<=y<=h+dot): continue
                quiet=max(.12,min(1,(.58*w-x)/(.12*w)))
                body.append(f'<circle cx="{x:.3f}" cy="{y:.3f}" r="{dot:.3f}" fill="{color}" opacity="{opacity*quiet:.3f}"/>')
        body.append(f'<svg x="{cx-radius:.3f}" y="{cy-radius:.3f}" width="{diameter:.3f}" height="{diameter:.3f}" viewBox="-4.5 -4.5 9 9">{mark_inner}</svg>')
        svg=svg_root(w,h,''.join(body))
        target=ROOT/f'assets/backgrounds/horizon-{w}x{h}'
        target.with_suffix('.svg').write_text(svg)
        raster(svg,target.with_suffix('.png'))
        geometry[f'{w}x{h}']={
          'scale':round(scale,5),'menu':{'left':round(.555*w),'top':round(.134*h),'width':round(.377*w),'height':round(.57*h)},
          'item_height':round(76*scale),'item_spacing':round(76*10/55*scale),'corner_radius':round(76*20/55*scale),
          'border':max(1,round(scale)), 'icon_size':max(16,round(48*scale)), 'font_target_px':max(14,round(32*scale)),
          'timeout':{'left':round(.555*w),'top':round(.742*h),'width':round(.377*w),'height':max(18,round(28*scale))},
          'footer_top':round(.93*h),'timeout_seconds':2,
          'status':'proposed geometry; verify metrics and compatibility in target GRUB'}
    arch=(ROOT/'assets/source/arch_linux_icon_green.svg').read_text()
    for size in [16,20,24,28,32,40,48,64,80,96,128]:
        raster(arch,ROOT/f'assets/icons/arch-{size}.png',size,size)
    # Native nine-slice boxes, with a complete sample for visual inspection.
    for scale in [.5,2/3,.75,1,1.25,1.5,2]:
        tag=f's{round(scale*100):03d}'
        folder=ROOT/'assets/pills'/tag
        folder.mkdir(exist_ok=True)
        w,h=max(80,round(300*scale)),round(76*scale)
        r=max(2,round(76*20/55*scale))
        border=max(1,round(scale))
        cut=r+border+1
        for state,color in [('normal','#45475a'),('selected','#6c7086')]:
            svg=svg_root(w,h,f'<rect x="{border/2}" y="{border/2}" width="{w-border}" height="{h-border}" rx="{r}" fill="#181825" stroke="{color}" stroke-width="{border}"/>')
            (folder/f'{state}.svg').write_text(svg)
            png=folder/f'{state}-sample.png'
            raster(svg,png)
            im=Image.open(png)
            xs=[0,cut,w-cut,w]; ys=[0,cut,h-cut,h]
            for yi,row in enumerate([['nw','n','ne'],['w','c','e'],['sw','s','se']]):
                for xi,suffix in enumerate(row):
                    im.crop((xs[xi],ys[yi],xs[xi+1],ys[yi+1])).save(folder/f'{state}_{suffix}.png')
    for source in ['corelab-mark.svg','kaust-mark.svg']:
        svg=(ROOT/'assets/source'/source).read_text()
        for size in [64,128,256,512,1024]:
            # Original SVG aspect ratio is preserved when only width is specified.
            raster(svg,ROOT/f'assets/decor/{source[:-4]}-{size}.png',size)
    (ROOT/'geometry.json').write_text(json.dumps(geometry,indent=2)+'\n')
    print(f'Generated {len(RESOLUTIONS)} backgrounds, 11 Arch icons, 7 nine-slice scales and original mark rasters.')

if __name__=='__main__': build()
