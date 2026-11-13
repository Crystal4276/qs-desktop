#!/usr/bin/env python3
"""CPU counters through the real services and rendered gauges, on isolated Sway."""
import json
import os
from pathlib import Path
import shutil
import sys
import subprocess
import tempfile
import time

repo = Path(__file__).resolve().parents[1]
HARNESS = '''import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.monitor
import "services/CpuUsage.js" as CpuUsage
ShellRoot {
    property var samples: []
    MonitorPanel { id: panel }
    Connections {
        target: Monitor
        function onCoresChanged() {
            samples = samples.slice(-1).concat([{raw:Monitor.previousCores,total:Monitor.cpuTotal,cores:Monitor.cores}]);
        }
    }
    Timer { interval: 400; running: true; onTriggered: panel.toggle(null) }
    function gauges(item, result) {
        if (item.label !== undefined && /^\\d+$/.test(item.label) && item.value !== undefined) {
            const track = item.children[1];
            result.push({label:item.label,value:item.value,width:track.width,fill:track.children[0].width});
        }
        for (const child of item.children ?? []) gauges(child, result);
    }
    IpcHandler {
        target: "cpuprobe"
        function state(): string {
            const rendered = []; gauges(panel.contentItem, rendered);
            return JSON.stringify({active:Monitor.active, total:Monitor.cpuTotal, cores:Monitor.cores, processes:Monitor.processes.map(p => ({pid:p.pid,cpu:p.cpu})),
                raw:Monitor.previousCores, samples:samples, bar:SystemStats.cpuUsage, gauges:rendered});
        }
        function close(): void { panel.close(); }
        function open(): void { panel.toggle(null); }
        function bar(text: string): void { SystemStats.parseCpu(text); }
        function check(): string {
            const r = text => CpuUsage.parse(text)[0];
            const zero = r("cpu 0 0 0 0 0 0 0 0 0 0");
            const full = r("cpu 100 0 0 0 0 0 0 0 100 0");
            const half = r("cpu 100 0 0 100 0 0 0 0 100 0");
            const nice = r("cpu 0 100 0 100 0 0 0 0 0 100");
            if (CpuUsage.usage(full,zero)!==100 || CpuUsage.usage(half,zero)!==50
                || CpuUsage.usage(nice,zero)!==50 || CpuUsage.usage(zero,full)!==0
                || CpuUsage.usage(full,full)!==0 || CpuUsage.usage(full,null)!==0
                || CpuUsage.parse("cpu invalid").length!==0
                || CpuUsage.usage(r("cpu0 100 0 0 0 0 0 0 0"),full)!==0)
                throw new Error("CPU counter fixtures");
            return "PASS";
        }
    }
}'''


def until(test, timeout=6):
    end = time.monotonic()+timeout
    while time.monotonic() < end:
        result = test()
        if result: return result
        time.sleep(.1)
    raise AssertionError('Timed out')


def rendered(s):
    assert len(s['gauges']) == len(s['cores']), s
    for g, expected in zip(s['gauges'], s['cores']):
        assert g['width'] > 0 and abs(g['value']*100-expected) < .01, g
        assert abs(g['fill']-g['width']*expected/100) < .1, g


with tempfile.TemporaryDirectory(prefix='qs-cpu-') as tmp:
    work = Path(tmp)
    root = work/'repo'
    shutil.copytree(repo, root, ignore=shutil.ignore_patterns('.git','.shots','.agents','.codex','__pycache__','*.zip'))
    (root/'shell.qml').write_text(HARNESS)
    runtime = work/'run'; runtime.mkdir(mode=0o700)
    env = dict(os.environ, QS_TEST='1', QT_QPA_PLATFORM='wayland', QT_QUICK_BACKEND='software',
               XDG_RUNTIME_DIR=str(runtime), XDG_STATE_HOME=str(work/'state'), XDG_CACHE_HOME=str(work/'cache'),
               WLR_BACKENDS='headless', WLR_RENDERER='pixman', WLR_LIBINPUT_NO_DEVICES='1')
    for k in ('SWAYSOCK','I3SOCK','HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_DISPLAY'): env.pop(k,None)
    conf = work/'sway.conf'; conf.write_text('xwayland disable\nswaybg_command -\noutput HEADLESS-1 mode 1920x1200\n')
    with (work/'sway.log').open('w') as log:
        sway = subprocess.Popen(['sway','-c',str(conf)],env=env,stdout=log,stderr=subprocess.STDOUT)
    shell = None
    try:
        until(lambda: list(runtime.glob('sway-ipc.*.sock')))
        env.update(SWAYSOCK=str(next(runtime.glob('sway-ipc.*.sock'))),I3SOCK=str(next(runtime.glob('sway-ipc.*.sock'))),
                   WAYLAND_DISPLAY=next(p for p in runtime.glob('wayland-*') if not p.name.endswith('.lock')).name)
        live = '--live' in sys.argv
        stat = work/'stat'
        baseline = 'cpu 0 0 0 0 0 0 0 0 0 0\ncpu0 0 0 0 0 0 0 0 0 0 0\ncpu1 0 0 0 0 0 0 0 0 0 0\n'
        stat.write_text(baseline)
        if not live:
            for name in ('Monitor','SystemStats'):
                p=root/f'services/{name}.qml'; p.write_text(p.read_text().replace('path: "/proc/stat"',f'path: "{stat}"'))
        with (work/'qs.log').open('w') as log:
            shell = subprocess.Popen(['qs','--no-color','-p',str(root)],env=env,stdout=log,stderr=subprocess.STDOUT)
        def ipc(method,*args):
            return subprocess.check_output(['qs','ipc','--pid',str(shell.pid),'call','cpuprobe',method,*args],env=env,text=True,timeout=3).strip()
        def state(): return json.loads(ipc('state'))
        until(lambda: shell.poll() is None and (runtime/'quickshell/by-pid'/str(shell.pid)).exists())
        assert ipc('check')=='PASS'
        try:
            until(lambda: state()['active'] and len(state()['cores'])>0)
        except Exception:
            print('state:', state()); print((work/'qs.log').read_text()); raise
        if not live:
            fixture = 'cpu 100 0 0 100 0 0 0 0 100 0\ncpu0 50 0 0 50 0 0 0 0 50 0\ncpu1 50 0 0 50 0 0 0 0 50 0\n'
            ipc('bar',baseline);ipc('bar',fixture);stat.write_text(fixture)
            try:
                s=until(lambda: (s if s['total']==50 else None) if (s:=state()) else None)
            except AssertionError:
                print('VM fixture final state:',state()); raise
            assert s['cores']==[50,50] and s['bar']==50, s
            rendered(s)
            ipc('close');assert not state()['active'] and state()['raw']==[]
            # New baseline after a closed interval, not an average over it.
            stat.write_text(fixture.replace('50','500').replace('100','1000'))
            ipc('open');until(lambda: state()['raw'] and state()['raw'][0]['total']==2000)
            assert state()['total']==0
            print('PASS: VM total, per-CPU and bar 50%; rendered widths; close/reopen; counter fixtures')
        else:
            import math
            cpus = sorted(os.sched_getaffinity(0))
            # Exercise SMT separately; multi mode uses distinct physical cores.
            solo=[c for c in cpus if (Path(f'/sys/devices/system/cpu/cpu{c}/topology/thread_siblings_list').read_text().strip()==str(c))]
            target=cpus[0] if '--smt' in sys.argv else (solo[0] if solo else cpus[0])
            physical={}
            for c in solo+cpus:
                topology=Path(f'/sys/devices/system/cpu/cpu{c}/topology')
                key=tuple((topology/k).read_text().strip() for k in ('physical_package_id','core_id'))
                physical.setdefault(key,c)
            targets=list(physical.values())[:3] if '--multi' in sys.argv else [target]
            sensors=[h/'temp1_input' for h in Path('/sys/class/hwmon').glob('hwmon*') if (h/'name').read_text().strip() in ('coretemp','k10temp','zenpower')]
            assert sensors, '--live requires a readable CPU temperature sensor'
            assert max(int(p.read_text())/1000 for p in sensors)<80, 'CPU already at thermal stop threshold'
            dest=repo/'.shots/cpu-validation'/('multi' if len(targets)>1 else str(target))
            dest.mkdir(parents=True,exist_ok=True)
            workers=[]; peak=0; readings=[]; saturated=set()
            try:
                for cpu in targets:
                    workers.append(subprocess.Popen(['python3','-c',f'import os,time; os.sched_setaffinity(0,{{{cpu}}}); end=time.monotonic()+30\nwhile time.monotonic()<end: pass']))
                for sample_index in range(30):
                    for _ in range(10):
                        time.sleep(.1)
                        temp=max([int(p.read_text())/1000 for p in sensors] or [0]); peak=max(peak,temp)
                        if temp>=80: raise AssertionError('Thermal stop at 80 C')
                    s=state();rendered(s)
                    if len(s['samples'])==2:
                        before_sample, current_sample=s['samples']
                        for i,(now,before) in enumerate(zip(current_sample['raw'],before_sample['raw'])):
                            elapsed=now['total']-before['total']; idle=now['idle']-before['idle']
                            expected=math.floor(100*(1-idle/elapsed)) if elapsed>0 and 0<=idle<=elapsed else 0
                            assert expected==(s['total'] if i==0 else s['cores'][i-1]), s
                    saturated.update(c for c in targets if s['cores'][c]>=95)
                    if sample_index==10:
                        subprocess.run(['grim',str(dest/'monitor.png')],env=env,check=True,timeout=5)
                    readings.append({'total':s['total'],'targets':[s['cores'][c] for c in targets],'temperature':temp,'processes':[p for p in s['processes'] if p['pid'] in [w.pid for w in workers]]})
                for worker in workers: worker.wait(timeout=3)
                assert saturated==set(targets), readings
                steady=[r for r in readings if all(v>=95 for v in r['targets'])]
                assert steady and all(r['total']>=100*len(targets)/len(cpus)-3 for r in steady), readings
                print('PASS: 30 s live counters and rendered widths; CPUs',targets,'total range',min(r['total'] for r in steady),max(r['total'] for r in steady),'peak C',peak)
            finally:
                (dest/'readings.json').write_text(json.dumps({'targets':targets,'peakTemperature':peak,'readings':readings},indent=2))
                for worker in workers:
                    if worker.poll() is None: worker.terminate();worker.wait()
        ipc('close')
        shell.terminate();shell.wait(timeout=5)
        output=(work/'qs.log').read_text().replace('  WARN quickshell.I3.ipc: I3 event socket disconnected.','')
        assert 'WARN' not in output and 'ERROR' not in output, output
    finally:
        if shell and shell.poll() is None: shell.terminate();shell.wait(timeout=5)
        sway.terminate();sway.wait(timeout=5)
