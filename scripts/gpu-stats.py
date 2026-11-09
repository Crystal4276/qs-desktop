#!/usr/bin/env python3
"""Read available DRM/sysfs metrics. No perf counters or inferred utilization."""
import json
import os
from pathlib import Path
import re
import sys


def number(path):
    try:
        value = float(path.read_text().strip())
        return value if value >= 0 and value < float('inf') else -1
    except (OSError, ValueError):
        return -1


def first(paths, divisor=1):
    for path in paths:
        value = number(path)
        if value >= 0:
            return value / divisor
    return -1


def memory(value):
    match = re.fullmatch(r'(\d+)\s*(B|KiB|MiB|GiB)?', value.strip())
    if not match:
        return None
    return int(match[1]) * {'B': 1, 'KiB': 1024, 'MiB': 1048576, 'GiB': 1073741824}[match[2] or 'B'] / 1048576


def process_memory(card, processes, proc=Path('/proc')):
    device = (card / 'device').resolve().name
    result = {}
    for process in processes:
        path = proc / str(process['pid'])
        try:
            def identity():
                stat = (path / 'stat').read_text()
                return f"{process['pid']}:{stat[stat.rindex(')') + 2:].split()[19]}"
            if identity() != process['key']:
                continue
            clients = {}
            for fd in os.scandir(path / 'fd'):
                try:
                    # Most descriptors are sockets/files. Only DRM nodes carry GPU metrics.
                    if not os.readlink(fd.path).startswith('/dev/dri/'):
                        continue
                    info = path / 'fdinfo' / fd.name
                    fields = dict(line.split(':', 1) for line in info.read_text().splitlines() if ':' in line)
                    fields = {k: v.strip() for k, v in fields.items()}
                    if fields.get('drm-pdev') != device or 'drm-client-id' not in fields:
                        continue
                    values = [memory(v) for k, v in fields.items() if k.startswith('drm-resident-')]
                    if not values or any(v is None for v in values):
                        continue
                    clients[device + ':' + fields['drm-client-id']] = sum(values)
                except (OSError, ValueError):
                    continue
            if identity() == process['key'] and clients:
                result[process['key']] = clients
        except (OSError, ValueError, IndexError):
            continue
    return result


def sample(card, vendor, processes, proc=Path('/proc')):
    device = card / 'device'
    hwmon = list((device / 'hwmon').glob('hwmon*'))
    sensors = [p for h in hwmon for p in sorted(h.glob('temp*_input'))]
    def edge_first(path):
        try:
            return path.with_name(path.name.replace('_input', '_label')).read_text().strip() != 'edge'
        except OSError:
            return True
    sensors.sort(key=edge_first)
    gpu = dict(name={'intel': 'Intel GPU', 'amd': 'AMD GPU', 'nvidia': 'NVIDIA GPU'}.get(vendor, 'GPU'),
               load=first([device / 'gpu_busy_percent']),
               memUsed=first([device / 'mem_info_vram_used'], 1048576),
               memTotal=first([device / 'mem_info_vram_total'], 1048576),
               temperature=first(sensors, 1000),
               power=first([h / 'power1_average' for h in hwmon], 1000000), fan=-1,
               clock=number(card / 'gt_act_freq_mhz'),
               shared=vendor == 'intel')
    # hwmon frequencies are Hz, the i915 attribute is already MHz.
    if gpu['clock'] < 0:
        gpu['clock'] = first([h / 'freq1_input' for h in hwmon], 1000000)
    clients = process_memory(card, processes, proc) if vendor in ('intel', 'amd') else {}
    available = any(gpu[k] >= 0 for k in ('load', 'temperature', 'power', 'clock')) or (gpu['memTotal'] > 0 and gpu['memUsed'] >= 0)
    return dict(gpu=gpu if available else None, clients=clients)


if __name__ == '__main__':
    request = json.load(sys.stdin)
    print(json.dumps(sample(Path(sys.argv[1]), sys.argv[2], request.get('processes', []))))
