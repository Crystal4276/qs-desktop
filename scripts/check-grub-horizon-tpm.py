#!/usr/bin/env python3
"""Enforce the Horizon VM's SHA-256 measurement and navigation acceptance gates."""
import argparse, importlib.util, json, pathlib, struct, sys
spec=importlib.util.spec_from_file_location('eventlog',pathlib.Path(__file__).with_name('tpm-eventlog.py'))
eventlog=importlib.util.module_from_spec(spec);spec.loader.exec_module(eventlog)

def check(data,stress=False,mode="1920x1200"):
    events=eventlog.parse(data);summary=eventlog.summarize(data)
    if struct.unpack_from('<I',data,56)[0]!=1 or struct.unpack_from('<HH',data,60)!=(11,32):
        raise ValueError('fixture must activate SHA-256 only')
    offset=len(data)-sum(e[3] for e in events);prefix=None;opens=0
    for pcr,kind,payload,size in events:
        if pcr==9 and b'qs-horizon/select.cfg' in payload and prefix is None:prefix=offset
        if pcr==8 and kind==13 and payload.rstrip(b'\0')==b'grub_cmd: qs_horizon_fallback_menu':opens+=1
        if pcr==9 and b'qs-horizon/' in payload and payload.rstrip(b'\0').endswith(
                (b'_nw.png',b'_n.png',b'_ne.png',b'_sw.png',b'_s.png',b'_se.png')):
            raise ValueError('obsolete pill slices: source/deployment inventory differs from corrected assets')
        offset+=size
    if prefix is None or not 38*1024<=prefix<=44*1024:
        raise ValueError('fixture must consume approximately 40 KiB before Horizon')
    required={'.linux','.initrd','smbios:type1'}
    if not required<=set(summary['markers']):raise ValueError('missing real UKI or SMBIOS measurements')
    resources=pathlib.Path(__file__).resolve().parents[1]/'dotfiles/grub/horizon'/mode/'resources.lst'
    expected_fonts={name for name in resources.read_text().splitlines() if name.endswith('.pf2')}
    if set(summary['fonts'])!=expected_fonts or any(n!=1 for n in summary['fonts'].values()):
        raise ValueError('fonts must each be measured exactly once')
    limit=64*1024 if stress else 56*1024
    if len(data)>=limit:raise ValueError('event log budget exceeded')
    if stress and opens!=3:raise ValueError('expected three measured fallback submenu openings')
    summary.update(before_horizon_bytes=prefix,submenu_opens=opens,budget=limit)
    return summary

if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('log',type=pathlib.Path);ap.add_argument('--stress',action='store_true');ap.add_argument('--mode',default='1920x1200')
    args=ap.parse_args()
    try: print(json.dumps(check(args.log.read_bytes(),args.stress,args.mode),indent=2))
    except (OSError,ValueError) as e:sys.exit(str(e))
