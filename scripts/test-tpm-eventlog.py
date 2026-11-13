#!/usr/bin/env python3
"""Counterexamples for the boot measurement evidence parser."""
import importlib.util, pathlib, struct
p=pathlib.Path(__file__).with_name('tpm-eventlog.py')
spec=importlib.util.spec_from_file_location('eventlog',p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
u=lambda *x:struct.pack('<'+'I'*len(x),*x)
s=b'Spec ID Event03\0'+u(0)+bytes([0,2,0,2])+u(1)+struct.pack('<HH',11,32)+bytes([0])
header=u(0,3)+bytes(20)+u(len(s))+s

def event(pcr,kind,payload):return u(pcr,kind,1)+struct.pack('<H',11)+bytes(32)+u(len(payload))+payload
for payload in [b'',b'grub_cmd: echo smbios:type1 .linux .initrd']:
 assert m.summarize(header+event(8,13,payload))['markers']==[]
payload=('smbios:type1\0').encode('utf-16-le');tag=u(0xd5cb7cbc,len(payload))+payload
assert m.summarize(header+event(1,6,tag))['markers']==['smbios:type1']
assert m.summarize(header+event(8,6,tag))['markers']==[]
assert m.summarize(header+event(11,13,('.linux\0').encode('utf-16-le')))['markers']==['.linux']
font=b'(hd0,gpt1)/grub/themes/qs-horizon/1920x1200/inter-32.pf2'
assert m.summarize(header+event(8,13,b'grub_cmd: loadfont '+font))['fonts']=={}
assert m.summarize(header+event(9,13,font))['fonts']=={'inter-32.pf2':1}
valid=header+event(9,13,font)
for n in range(len(valid)):
 if n==len(header):continue  # A valid empty log after its specification record.
 try:m.parse(valid[:n])
 except ValueError:pass
 else:raise AssertionError(('accepted truncation',n))
for invalid in [header+u(24,13,1),header+u(1,13,17), header+u(1,13,1)+struct.pack('<H',0xffff)]:
 try:m.parse(invalid)
 except ValueError:pass
 else:raise AssertionError('accepted invalid header')

# Acceptance gates must reject plausible but incomplete or undersized evidence.
p=pathlib.Path(__file__).with_name('check-grub-horizon-tpm.py')
spec=importlib.util.spec_from_file_location('gate',p);gate=importlib.util.module_from_spec(spec);spec.loader.exec_module(gate)
resources=pathlib.Path(__file__).resolve().parents[1]/'dotfiles/grub/horizon/1920x1200/resources.lst'
expected_fonts=sorted(name for name in resources.read_text().splitlines() if name.endswith('.pf2'))
assert expected_fonts

def fixture(digest_size=32,fonts=None,opens=0,before=40*1024,obsolete=False,real_markers=True,extra=b''):
    spec_data=b'Spec ID Event03\0'+u(0)+bytes([0,2,0,2])+u(1)+struct.pack('<HH',11,digest_size)+bytes([0])
    first=u(0,3)+bytes(20)+u(len(spec_data))+spec_data
    def record(pcr,kind,payload):
        return u(pcr,kind,1)+struct.pack('<H',11)+bytes(digest_size)+u(len(payload))+payload
    data=first+record(0,3,bytes(before-len(first)-18-digest_size))
    root=b'(hd0,gpt1)/grub/themes/qs-horizon/'
    data+=record(9,13,root+b'select.cfg\0')
    for name in expected_fonts if fonts is None else fonts:
        data+=record(9,13,root+b'1920x1200/'+name.encode()+b'\0')
    if real_markers:
        desc=('smbios:type1\0').encode('utf-16-le')
        data+=record(1,6,u(0xd5cb7cbc,len(desc))+desc)
        for name in ('.linux','.initrd'):
            data+=record(11,13,(name+'\0').encode('utf-16-le'))
    else:
        data+=record(8,13,b'grub_cmd: echo smbios:type1 .linux .initrd')
    for _ in range(opens):data+=record(8,13,b'grub_cmd: qs_horizon_fallback_menu\0')
    if obsolete:data+=record(9,13,root+b'1920x1200/normal_nw.png\0')
    if extra:data+=record(0,3,extra)
    return data

def rejected(data,message,stress=False):
    try:gate.check(data,stress=stress)
    except ValueError as error:assert message in str(error),(message,error)
    else:raise AssertionError(('accepted invalid acceptance evidence',message))

assert gate.check(fixture())['before_horizon_bytes']==40*1024
assert gate.check(fixture(opens=3),stress=True)['submenu_opens']==3
rejected(fixture(digest_size=1),'SHA-256')
rejected(fixture(fonts=expected_fonts[:-1]),'fonts')
rejected(fixture(fonts=expected_fonts+[expected_fonts[0]]),'fonts')
rejected(fixture(obsolete=True),'obsolete pill slices')
rejected(fixture(real_markers=False),'missing real UKI')
rejected(fixture(before=37*1024),'approximately 40 KiB')
rejected(fixture(extra=bytes(20*1024)),'budget exceeded')
for opens in (2,4):rejected(fixture(opens=opens),'three measured',stress=True)
print('PASS: evidence markers/fonts, algorithm bounds, every truncation and acceptance counterexamples')
