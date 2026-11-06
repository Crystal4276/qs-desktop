"""Native focus/close regression. See window-shell.qml; Sway starts with one 1600x1200 headless output."""
import os, sys, json, time, subprocess
from pathlib import Path
if os.environ.get('QS_TEST') != '1':
    raise SystemExit('Run only inside an isolated QS_TEST=1 compositor')
pid = int(sys.argv[1])
if b'QS_TEST=1' not in Path(f'/proc/{pid}/environ').read_bytes().split(b'\x00'):
    raise SystemExit('Target instance must also run with QS_TEST=1')
mode = sys.argv[2]
assert mode in ('sway', 'hyprland')
title = 'System Monitor — Quickshell'

def run(*args):
    return subprocess.check_output(args, text=True)

def ipc(*args):
    return run('qs', 'ipc', '--pid', str(pid), 'call', *args)

def state():
    return json.loads(ipc('windowcheck', 'state'))

def records():
    if mode == 'sway':
        result = []

        def walk(n, floating=False):
            floating = floating or n.get('type') == 'floating_con'
            if n.get('pid'):
                result.append(dict(pid=n['pid'], title=n.get('name'), id=n['id'], focused=n['focused'], floating=floating, rect=n['rect']))
            for c in n.get('nodes', []) + n.get('floating_nodes', []):
                walk(c, floating)
        walk(json.loads(run('swaymsg', '-t', 'get_tree', '-r')))
        return result
    data = json.loads(run('hyprctl', 'clients', '-j'))
    active = json.loads(run('hyprctl', 'activewindow', '-j'))
    return [dict(pid=w['pid'], title=w['title'], id=w['address'], focused=w['address'] == active.get('address'), floating=w['floating'], rect=dict(x=w['at'][0], y=w['at'][1], width=w['size'][0], height=w['size'][1])) for w in data]

def until(test):
    end = time.monotonic() + 5
    while time.monotonic() < end:
        value = test()
        if value:
            return value
        time.sleep(0.08)
    raise AssertionError('Timed out: ' + str(records()))

def monitor():
    return next((w for w in records() if w['pid'] == pid and w['title'] == title), None)

def close_target(w):
    if mode == 'sway':
        run('swaymsg', f"[con_id={w['id']}] kill")
    else:
        run('hyprctl', 'dispatch', f"""hl.dsp.window.close({{window="address:{w['id']}"}})""")
if monitor():
    close_target(monitor())
    until(lambda: not monitor())
underlay = subprocess.Popen(['zenity', '--info', '--title=qs-monitor-underlay', '--text=Disposable test window'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    until(lambda: any((w['title'] == 'qs-monitor-underlay' for w in records())))
    for iteration in range(2):
        ipc('monitor', 'toggle')
        w = until(lambda: monitor() if monitor() and monitor()['focused'] else None)
        assert w['floating'], w
        assert state()['users'] == 1, state()
        time.sleep(0.6)
        w = monitor()
        print(mode, 'focused floating window', w['rect'])
        if mode == 'hyprland':
            print('Monitor geometry:', [{k: m.get(k) for k in ('name', 'x', 'y', 'width', 'height', 'scale', 'reserved')} for m in json.loads(run('hyprctl', 'monitors', '-j'))])
        assert monitor()['focused']
        if mode == 'sway':
            run('swaymsg', 'kill')
        else:
            run('hyprctl', 'dispatch', 'hl.dsp.window.close()')
        until(lambda: not monitor())
        until(lambda: state()['users'] == 0)
        assert any((w['title'] == 'qs-monitor-underlay' for w in records())), 'Underlying window closed!'
        os.kill(pid, 0)
    if mode == 'sway':
        run('swaymsg', 'create_output')
        run('swaymsg', 'output HEADLESS-2 mode 1600x1200 pos 1600 0')
        time.sleep(1)
        ipc('windowcheck', 'openOn', 'HEADLESS-2')
        w = until(lambda: monitor() if monitor() and monitor()['focused'] else None)
        time.sleep(0.6)
        w = monitor()
        assert 1600 <= w['rect']['x'] < 3200, w
        assert abs(w['rect']['x'] - 1850) <= 2, w
        close_target(w)
        until(lambda: not monitor())
        until(lambda: state()['users'] == 0)
        print('sway: opened from second screen while first was focused: PASS')
    print(mode, 'close focused monitor twice, reopen, underlay and desktop survive, polling stops: PASS')
finally:
    underlay.terminate()
    try:
        underlay.wait(timeout=3)
    except subprocess.TimeoutExpired:
        underlay.kill()
        underlay.wait()
