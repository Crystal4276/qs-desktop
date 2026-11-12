#!/usr/bin/env python3
"""Export the canonical geometric design reference; not a working GRUB theme."""
from pathlib import Path
import xml.etree.ElementTree as ET
import subprocess
from html import escape

ROOT=Path(__file__).resolve().parents[1]
def inner(path):
    root=ET.parse(path).getroot()
    return ''.join(ET.tostring(c,encoding='unicode') for c in root)

def build():
    bg=ET.parse(ROOT/'assets/backgrounds/horizon-1920x1080.svg').getroot()
    parts=[''.join(ET.tostring(c,encoding='unicode') for c in bg)]
    arch=inner(ROOT/'assets/source/arch_linux_icon_green.svg')
    labels=['Arch Linux','Arch Linux LTS','Arch Linux (fallback)','Arch Linux LTS (fallback)','Advanced options','UEFI Firmware Settings','Restart']
    for i,label in enumerate(labels):
        x,y,w,h=1066,145+i*90,724,76
        border='#6c7086' if i==0 else '#45475a'
        parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="27.636" fill="#181825" stroke="{border}" stroke-width="1"/>')
        ix,iy=x+30,y+14
        if i<4:
            parts.append(f'<svg x="{ix}" y="{iy}" width="48" height="48" viewBox="0 0 512 512">{arch}</svg>')
        else:
            icon=['<path d="M3 10 24 1 45 10 24 19Z M3 22 24 31 45 22 M3 34 24 43 45 34"/>','<rect x="9" y="9" width="30" height="30"/><rect x="16" y="16" width="16" height="16"/><path d="M16 2V9M24 2V9M32 2V9M16 39V46M24 39V46M32 39V46M2 16H9M2 24H9M2 32H9M39 16H46M39 24H46M39 32H46"/>','<path d="M40 16A18 18 0 1 0 41 31 M40 4V17H27"/>'][i-4]
            parts.append(f'<svg x="{ix}" y="{iy}" width="48" height="48" viewBox="0 0 48 48"><g fill="none" stroke="#cdd6f4" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">{icon}</g></svg>')
        parts.append(f'<text x="{x+128}" y="{y+49}" fill="#cdd6f4" font-family="Inter" font-size="32" font-weight="400">{escape(label)}</text>')
    parts.append('<text x="1066" y="824" fill="#a6e3a1" font-family="Inter" font-size="28">Booting in 2 s</text>')
    parts.append('<rect x="1292" y="803" width="498" height="20" rx="10" fill="#181825" stroke="#6c7086" stroke-width="1"/><clipPath id="bar"><rect x="1292" y="803" width="498" height="20" rx="10"/></clipPath><rect x="1292" y="803" width="300" height="20" fill="#a6e3a1" clip-path="url(#bar)"/>')
    parts.append('<text x="54" y="1030" fill="#cdd6f4" font-family="Inter" font-size="24" xml:space="preserve">↑ ↓ Select     Enter Boot     E Edit     C Console</text>')
    # Identity placement is illustrative until the original DM Sans lockup is built.
    kaust=ET.parse(ROOT/'assets/source/kaust-mark.svg').getroot()
    viewbox=kaust.get('viewBox') or f'0 0 {kaust.get("width","100").removesuffix("px")} {kaust.get("height","100").removesuffix("px")}'
    content=''.join(ET.tostring(c,encoding='unicode') for c in kaust)
    parts.append(f'<svg x="1260" y="998" width="38" height="38" viewBox="{viewbox}">{content}</svg>')
    parts.append('<text x="1312" y="1026" fill="#cdd6f4" font-family="Inter" font-size="20">Imaging and Characterization Core Lab</text>')
    svg='<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">'+''.join(parts)+'</svg>'
    target=ROOT/'reference'
    target.mkdir(exist_ok=True)
    (target/'horizon-approved-2s.svg').write_text(svg)
    subprocess.run(['rsvg-convert','-o',str(target/'horizon-approved-2s.png')],input=svg.encode(),check=True)
    print('Canonical reference exported with true circular geometry.')

if __name__=='__main__': build()
