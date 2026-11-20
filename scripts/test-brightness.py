#!/usr/bin/env python3
"""Exercise real brightness control with quantized fake sysfs; never change real hardware."""
import json
import math
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]


def check(maximum):
    with tempfile.TemporaryDirectory(prefix='qs-brightness-test-') as tmp:
        work = Path(tmp)
        for name in ('services', 'config', 'modules/bar', 'bin', 'runtime', 'sys/class/backlight/test'):
            (work / name).mkdir(parents=True, exist_ok=True)
        (work / 'runtime').chmod(0o700)
        for name in ('services/Brightness.qml', 'config/Theme.qml', 'modules/bar/VolumeSlider.qml',
                     'modules/bar/WheelSteps.qml', 'modules/bar/GradientFill.qml'):
            shutil.copy2(REPO / name, work / name)
        (work / 'assets').symlink_to(REPO / 'assets')
        device = work / 'sys/class/backlight/test'
        (device / 'max_brightness').write_text(str(maximum))
        (device / 'brightness').write_text(str(maximum))
        if maximum == 0:
            shutil.rmtree(device)
        (work / 'delay').write_text('0')
        (work / 'fail').write_text('0')
        (work / 'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.bar
ShellRoot {
    Timer {
        id: sequence
        property int remaining: 0
        property int points: 0
        repeat: true
        onTriggered: {
            slider.step(points);
            if (--remaining === 0) stop();
        }
    }
    VolumeSlider { id: slider; value: Brightness.percent / 100; stepHandler: points => Brightness.step(points); onMoved: v => Brightness.setPercent(Math.round(v * 100)) }
    VolumeSlider { id: volume; value: .07; onMoved: v => value = v }
    IpcHandler {
        target: "test"
        function state(): string { return JSON.stringify({available: Brightness.available, current: Brightness.current, percent: Brightness.percent, target: Brightness.target, applied: Brightness.applied, volume: volume.value, remaining: sequence.remaining}); }
        function set(p: int): void { Brightness.setPercent(p); }
        function steps(points: int, count: int, viaSlider: bool): void { for (let i=0;i<count;i++) { if (viaSlider) slider.step(points); else Brightness.step(points); } }
        function timed(points: int, count: int): void { sequence.points = points; sequence.remaining = count; sequence.interval = 90; sequence.start(); }
        function mixed(): void { Brightness.setPercent(80); slider.step(-5); Brightness.setPercent(7); slider.step(5); }
        function drag(v: real): void { slider.emit(v); }
        function volumeStep(points: int): void { volume.step(points); }
    }
}''')
        fake = work / 'bin/brightnessctl'
        fake.write_text('''#!/usr/bin/env python3
import json, math, os, sys, time
from pathlib import Path
w = Path(os.environ['BRIGHTNESS_TEST_ROOT'])
time.sleep(float((w/'delay').read_text()))
if (w/'fail').read_text() == '1': sys.exit(1)
d = w/'sys/class/backlight/test'
maximum = int((d/'max_brightness').read_text())
value = sys.argv[-1]
raw = math.floor(float(value[:-1])*maximum/100+.5) if value.endswith('%') else int(value)
if '--min-value=1' in sys.argv: raw = max(1,raw)
raw = max(0,min(maximum,raw))
(d/'brightness').write_text(str(raw))
with (w/'writes').open('a') as f: f.write(json.dumps({'value': raw, 'args': sys.argv[1:]})+'\\n')
''')
        fake.chmod(0o755)
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QS_TEST='1', QS_SYSFS_ROOT=str(work / 'sys'),
                   BRIGHTNESS_TEST_ROOT=tmp, PATH=str(work / 'bin') + ':/usr/bin:/bin',
                   XDG_RUNTIME_DIR=str(work / 'runtime'), XDG_STATE_HOME=str(work / 'state'),
                   XDG_CACHE_HOME=str(work / 'cache'))
        for key in ('SWAYSOCK', 'I3SOCK', 'HYPRLAND_INSTANCE_SIGNATURE', 'WAYLAND_DISPLAY', 'DISPLAY'):
            env.pop(key, None)
        with (work / 'qs.log').open('w') as log:
            proc = subprocess.Popen(['dbus-run-session', '--', 'qs', '-p', str(work)], env=env,
                                    stdout=log, stderr=log, start_new_session=True)
            try:
                def until(predicate):
                    deadline = time.monotonic() + 8
                    while time.monotonic() < deadline:
                        try:
                            value = predicate()
                            if value:
                                return value
                        except (subprocess.SubprocessError, ValueError):
                            pass
                        time.sleep(.025)
                    raise AssertionError((work / 'qs.log').read_text())
                pid = until(lambda: subprocess.check_output(['pgrep', '-P', str(proc.pid), 'qs'], text=True).strip())
                def ipc(method, *args, target='test'):
                    return subprocess.check_output(['qs', 'ipc', '--pid', pid, 'call', target, method, *map(str, args)],
                                                   env=env, text=True, stderr=subprocess.DEVNULL, timeout=3).strip()
                def state():
                    return json.loads(ipc('state'))
                until(state)
                if maximum == 0:
                    assert not state()['available']
                    ipc('set', 50)
                    ipc('steps', 5, 3, 'true')
                    ipc('up', target='brightness')
                    time.sleep(.1)
                    assert not (work / 'writes').exists()
                    print('PASS absent backlight: unavailable, no command')
                    return
                until(lambda: state()['available'])
                def raw(percent):
                    return max(1, math.floor(maximum * percent / 100 + .5))
                def settled():
                    until(lambda: state()['target'] == -1 and state()['remaining'] == 0)
                    return state()['current']
                def setp(value):
                    ipc('set', value)
                    return settled()
                def step(points, count=1, via_slider=False):
                    ipc('steps', points, count, str(via_slider).lower())
                    return settled()
                assert setp(1) == raw(1), f'1% becomes black: {state()}'
                for via_slider in (False, True):
                    setp(1)
                    for expected in range(5, 101, 5):
                        actual = step(5, via_slider=via_slider)
                        assert actual == raw(expected), f'up stuck/skipped at requested {expected}%: {state()}'
                    for expected in list(range(95, 0, -5)) + [1]:
                        actual = step(-5, via_slider=via_slider)
                        assert actual == raw(expected), f'down stuck/skipped at requested {expected}%: {state()}'
                    assert step(-5) == raw(1)
                    setp(100)
                    assert step(5) == maximum
                    setp(7)
                    assert step(5, via_slider=via_slider) == raw(10)
                    setp(7)
                    assert step(-5, via_slider=via_slider) == raw(5)
                    (work / 'delay').write_text('.1')
                    setp(1)
                    assert step(5, 20, via_slider) == maximum
                    assert step(-5, 20, via_slider) == raw(1)
                    (work / 'delay').write_text('0')
                # Separate input events cross command exits and the one-second sysfs poll.
                (work / 'delay').write_text('.13')
                setp(1)
                ipc('timed', 5, 20)
                assert settled() == maximum
                ipc('timed', -5, 20)
                assert settled() == raw(1)
                ipc('mixed')
                assert settled() == raw(10)
                (work / 'delay').write_text('0')
                assert setp(-50) == raw(1)
                assert setp(150) == maximum
                before = (work / 'writes').read_text()
                assert step(0) == maximum
                assert (work / 'writes').read_text() == before
                setp(1)
                ipc('up', target='brightness')
                assert settled() == raw(5)
                ipc('down', target='brightness')
                assert settled() == raw(1)
                ipc('drag', '.07')
                assert settled() == raw(7)
                ipc('volumeStep', 5)
                assert state()['volume'] == .12
                # A different program changes the hardware; the next step must use the observed level.
                setp(25)
                external = max(1, maximum // 2)
                (device / 'brightness').write_text(str(external))
                until(lambda: state()['current'] == external)
                observed = state()['percent']
                assert step(5) == raw((observed // 5 + 1) * 5)
                # A failed write must not poison the base used after recovery.
                setp(25)
                (work / 'fail').write_text('1')
                setp(80)
                (work / 'fail').write_text('0')
                observed = state()['percent']
                assert step(5) == raw((observed // 5 + 1) * 5)
                assert not any('ERROR' in line or 'WARN' in line for line in (work/'qs.log').read_text().splitlines()), (work/'qs.log').read_text()
                print(f'PASS max={maximum}: full up/down, boundaries, off-grid, rapid steps, IPC, slider, external change, failed write')
            finally:
                os.killpg(proc.pid, signal.SIGTERM)
                proc.wait(timeout=5)


if __name__ == '__main__':
    import sys
    for maximum in map(int, sys.argv[1:] or ('10000', '64', '16', '0')):
        check(maximum)
