#!/usr/bin/env python3
"""Run the real GPU/monitor QML against fake hardware, in an isolated compositor."""
import os
from pathlib import Path
import shutil
import time
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='qs-gpu-qml-') as tmp:
    work = Path(tmp)
    root = work / 'shell'
    shutil.copytree(repo, root, ignore=shutil.ignore_patterns('.git', '.shots', '.agents', '.codex', '__pycache__'))
    device = work / 'sys/devices/0000:00:02.0'
    device.mkdir(parents=True)
    card = work / 'sys/class/drm/card1'
    card.mkdir(parents=True)
    (card/'device').symlink_to(device)
    (device/'vendor').write_text('0x8086')
    (device/'boot_vga').write_text('1')
    (card/'gt_act_freq_mhz').write_text('0')
    (root/'shell.qml').write_text('''import QtQuick
import Quickshell
import qs.services
import qs.modules.bar
import qs.modules.monitor
ShellRoot {
    property string vendor: Quickshell.env("GPU_VENDOR")
    GpuModule { id: bar }
    MonitorPanel { id: panel }
    Timer {
        interval: 500; running: true
        onTriggered: {
            if (Gpu.vendor !== vendor || Gpu.cardPath === "" || Gpu.available !== (vendor !== "intel") || bar.shown !== (vendor !== "intel"))
                throw new Error("Intel detection / bar visibility");
            panel.toggle(null);
        }
    }
    Timer {
        interval: 2800; running: true
        onTriggered: {
            if (Monitor.gpu?.clock !== Number(Quickshell.env("GPU_CLOCK")) || Monitor.gpu?.load !== Number(Quickshell.env("GPU_LOAD")) || Monitor.gpu?.temperature !== Number(Quickshell.env("GPU_TEMP")))
                throw new Error("Intel GPU without temperature: " + JSON.stringify(Monitor.gpu));
            Monitor.processes = [
                {key: "1:10", gpu: 2, gpuClients: {shared: 2}},
                {key: "2:10", gpu: 2, gpuClients: {shared: 2}}
            ];
            if (Monitor.gpuMemory(Monitor.processes) !== 2) throw new Error("Duplicate client in application");
            panel.close();
            if (Monitor.gpu !== null || Monitor.processes.some(p => p.gpu > 0)) throw new Error("Stale readings");
            console.log("GPU_QML_PASS");
            Qt.quit();
        }
    }
    Timer { interval: 5000; running: true; onTriggered: Qt.quit() }
}''')
    runtime = work / 'runtime'
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, QT_QPA_PLATFORM='wayland', QT_QUICK_BACKEND='software', QS_TEST='1', QS_SYSFS_ROOT=str(work/'sys'),
               XDG_STATE_HOME=str(work/'state'), XDG_CACHE_HOME=str(work/'cache'), XDG_RUNTIME_DIR=str(runtime),
               WLR_BACKENDS='headless', WLR_RENDERER='pixman', WLR_LIBINPUT_NO_DEVICES='1')
    for key in ('SWAYSOCK','I3SOCK','HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_DISPLAY'):
        env.pop(key,None)
    config = work/'sway.conf'
    config.write_text('xwayland disable\nswaybg_command -\noutput HEADLESS-1 mode 1920x1200\n')
    with (work/'sway.log').open('w') as log:
        sway = subprocess.Popen(['sway','-c',str(config)],env=env,stdout=log,stderr=subprocess.STDOUT)
        try:
            for _ in range(50):
                sockets = list(runtime.glob('wayland-*'))
                sockets = [p for p in sockets if not p.name.endswith('.lock')]
                ipc = list(runtime.glob('sway-ipc.*.sock'))
                if sockets and ipc: break
                time.sleep(.1)
            assert sockets and ipc, (work/'sway.log').read_text()
            env.update(WAYLAND_DISPLAY=sockets[0].name,SWAYSOCK=str(ipc[0]),I3SOCK=str(ipc[0]))
            bindir = work/'bin'
            bindir.mkdir()
            smi = bindir/'nvidia-smi'
            smi.write_text('#!/bin/sh\ncase "$1" in\n--query-gpu=temperature.gpu,utilization.gpu) echo "45, 35";;\n--query-gpu=name,*) echo "Test NVIDIA, 35, 10, 100, 45, 20, 30, 800";;\npmon) echo "# no clients";;\nesac\n')
            smi.chmod(0o755)
            env['PATH'] = str(bindir) + ':' + env['PATH']
            for vendor, ident, clock, load, temperature in [('intel','0x8086',0,-1,-1), ('amd','0x1002',600,32,-1), ('nvidia','0x10de',800,35,45)]:
                (device/'vendor').write_text(ident)
                if vendor == 'amd':
                    (device/'gpu_busy_percent').write_text('32')
                    hwmon = device/'hwmon/hwmon0'
                    hwmon.mkdir(parents=True)
                    (hwmon/'freq1_input').write_text('600000000')
                    (card/'gt_act_freq_mhz').unlink()
                if vendor == 'nvidia':
                    (device/'gpu_busy_percent').unlink()
                env.update(GPU_VENDOR=vendor,GPU_CLOCK=str(clock),GPU_LOAD=str(load),GPU_TEMP=str(temperature))
                logpath = work/(vendor+'.log')
                with logpath.open('w') as output:
                    shell = subprocess.Popen(['qs','-p',str(root)],env=env,stdout=output,stderr=subprocess.STDOUT)
                    try:
                        time.sleep(2)
                        subprocess.run(['grim',str(work/(vendor+'.png'))],env=env,check=True,timeout=5)
                        shell.wait(timeout=10)
                    finally:
                        if shell.poll() is None:
                            shell.terminate()
                            shell.wait(timeout=5)
                output = logpath.read_text()
                print(vendor, output)
                assert 'GPU_QML_PASS' in output
                # Quickshell may log its IPC disconnection during normal shutdown.
                startup = output.replace('  WARN quickshell.I3.ipc: I3 event socket disconnected.', '')
                assert 'WARN' not in startup and 'ERROR' not in startup
        finally:
            sway.terminate()
            sway.wait(timeout=5)
