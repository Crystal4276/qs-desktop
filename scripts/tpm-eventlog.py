#!/usr/bin/env python3
"""Summarize a TCG2 event log without exposing measured payloads or credentials."""
import argparse, collections, json, pathlib, struct, sys

def parse(data):
    offset = 0
    def take(n):
        nonlocal offset
        if n < 0 or n > len(data)-offset:
            raise ValueError('truncated TPM event log')
        result=data[offset:offset+n]; offset+=n; return result
    def u32(): return struct.unpack('<I', take(4))[0]
    pcr, kind = u32(), u32(); take(20)
    spec = take(u32())
    if pcr != 0 or kind != 3 or len(spec)<29 or spec[:16]!=b'Spec ID Event03\0':
        raise ValueError('expected TCG2 Spec ID event')
    count=struct.unpack_from('<I', spec, 24)[0]
    if count<1 or count>16 or 29+4*count>len(spec):
        raise ValueError('invalid digest algorithm table')
    sizes={}
    for i in range(count):
        algorithm, size=struct.unpack_from('<HH',spec,28+4*i)
        if algorithm in sizes or size<1 or size>128: raise ValueError('invalid digest size')
        sizes[algorithm]=size
    if 29+4*count+spec[28+4*count]!=len(spec): raise ValueError('invalid vendor data')
    events=[]
    while offset<len(data):
        start=offset; pcr,kind,n=u32(),u32(),u32()
        if pcr>23 or n<1 or n>len(sizes): raise ValueError('invalid event header')
        seen=set()
        for _ in range(n):
            algorithm=struct.unpack('<H',take(2))[0]
            if algorithm not in sizes or algorithm in seen: raise ValueError('unknown or duplicate digest algorithm')
            seen.add(algorithm);take(sizes[algorithm])
        payload=take(u32())
        events.append((pcr,kind,payload,offset-start))
    return events

def summarize(data):
    events=parse(data); counts=collections.Counter(); fonts=collections.Counter(); markers=[]
    for pcr,kind,payload,size in events:
        counts[str(pcr)]+=1
        if pcr==9 and kind==13 and b'qs-horizon/' in payload and payload.rstrip(b'\0').endswith(b'.pf2'):
            # Restrict to a basename, never emit arbitrary measured command lines.
            fonts[payload.rstrip(b'\0').rsplit(b'/',1)[-1].decode('ascii','replace')]+=1
        # SMBIOS uses PCR1 EV_EVENT_TAG, with event ID, size and UTF-16 description.
        if pcr==1 and kind==6 and len(payload)>=8:
            tag,n=struct.unpack_from('<II',payload)
            expected={0xd5cb7cbc:'smbios:type1',0xe0d47bc8:'smbios:type2',0xc0b3bd23:'smbios:type11'}.get(tag)
            if expected and n==len(payload)-8 and payload[8:]==(expected+'\0').encode('utf-16-le'):
                markers.append(expected)
        if pcr==11 and kind==13:
            for section in ('.linux','.initrd'):
                if payload==(section+'\0').encode('utf-16-le'):
                    markers.append(section)
    return dict(bytes=len(data),events=len(events),pcr_counts=dict(counts),fonts=dict(fonts),markers=sorted(set(markers)))

if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('log',type=pathlib.Path,nargs='?',default=pathlib.Path('/sys/kernel/security/tpm0/binary_bios_measurements'))
    args=ap.parse_args()
    try: print(json.dumps(summarize(args.log.read_bytes()),indent=2))
    except (OSError,ValueError) as e: sys.exit(str(e))
