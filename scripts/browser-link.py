#!/usr/bin/env python3
"""HTTP(S) links use a browser window on the primary output; no args launch normally."""
import fcntl
import json
import os
from pathlib import Path
import shlex
import socket
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parent.parent


def query(command):
    return json.loads(subprocess.check_output(command, text=True, timeout=3))


def default_profile(pid):
    try:
        raw = [v.decode(errors='replace') for v in Path(f'/proc/{int(pid)}/cmdline').read_bytes().split(b'\0') if v]
        args = shlex.split(raw[0]) if len(raw) == 1 else raw
        return bool(args) and Path(args[0]).name == 'chromium' and not any(a.startswith('--user-data-dir') for a in args)
    except (OSError, ValueError):
        return False


class Hyprland:
    def windows(self):
        monitors = {m['id']: m['name'] for m in query(['hyprctl', '-j', 'monitors'])}
        return [dict(id=c['address'], output=monitors.get(c['monitor']), pid=c['pid'],
                     rank=c['focusHistoryID'] if c.get('focusHistoryID', -1) >= 0 else 1_000_000)
                for c in query(['hyprctl', '-j', 'clients']) if c.get('class', '').lower() == 'chromium' and c.get('mapped', True)]

    def focus(self, output, window):
        arg = 'window="address:' + window['id'] + '"' if window else 'monitor=' + lua_string(output)
        result = subprocess.check_output(['hyprctl', 'dispatch', 'hl.dsp.focus({' + arg + '})'], text=True, timeout=3)
        if result.strip() != 'ok':
            raise RuntimeError('Browser destination could not be focused')
        # Wait for native focus to be observable before Chromium chooses its last active window.
        deadline = time.monotonic() + 1
        while time.monotonic() < deadline:
            if window:
                if query(['hyprctl', '-j', 'activewindow']).get('address') == window['id']:
                    return
            elif any(m['name'] == output and m.get('focused') for m in query(['hyprctl', '-j', 'monitors'])):
                return
            time.sleep(.02)
        raise RuntimeError('Browser focus was not confirmed')


def lua_string(value):
    # JSON string escaping agrees with Lua for connector names; reject control characters.
    if any(ord(c) < 32 for c in value):
        raise ValueError('Invalid output name')
    return json.dumps(value, ensure_ascii=False)


class Sway:
    def windows(self):
        result = []
        def walk(node, output=''):
            if node.get('type') == 'output':
                output = node['name']
            if node.get('app_id') == 'chromium' or node.get('window_properties', {}).get('class', '').lower() == 'chromium':
                result.append(dict(id=node['id'], output=output, pid=node.get('pid', 0), rank=len(result)))
            children = node.get('nodes', []) + node.get('floating_nodes', [])
            order = node.get('focus', [])
            children.sort(key=lambda n: order.index(n['id']) if n['id'] in order else len(order))
            for child in children:
                walk(child, output)
        walk(query(['swaymsg', '-t', 'get_tree']))
        return result

    def focus(self, output, window):
        target = f'[con_id={int(window["id"])}] focus' if window else 'focus output ' + json.dumps(output)
        # Same cursor policy as Compositor.focusWindow: avoid moving the user's pointer.
        result = query(['swaymsg', 'mouse_warping none; ' + target + '; mouse_warping output'])
        if not result or not all(r.get('success') for r in result):
            raise RuntimeError('Browser destination could not be focused')


def open_links(urls, backend, primary, launch=None):
    windows = backend.windows()
    candidates = [w for w in windows if w['output'] == primary and default_profile(w['pid'])]
    target = min(candidates, key=lambda w: w['rank']) if candidates else None
    backend.focus(primary, target)
    command = ['chromium', *([] if target else ['--new-window']), '--', *urls]
    if launch is not None:
        process = launch(command)
        if process is None:
            return
    else:
        process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL, start_new_session=True)
    # Keep concurrent external links from creating duplicate initial windows.
    deadline = time.monotonic() + 3
    known = {w['id'] for w in windows}
    while time.monotonic() < deadline:
        if target and process.poll() is not None:
            return
        if not target:
            try:
                if any(w['id'] not in known and w['output'] == primary and default_profile(w['pid']) for w in backend.windows()):
                    return
            except (OSError, ValueError, subprocess.SubprocessError):
                return  # Command was already delivered; never send the same URL a second time.
        time.sleep(.05)


def selected_origin(urls):
    try:
        path=Path(os.environ['XDG_RUNTIME_DIR'])/'qs-open-origin.sock'
        with socket.socket(socket.AF_UNIX) as client:
            client.settimeout(.3);client.connect(str(path))
            client.sendall(json.dumps({'pid':os.getpid(),'uris':urls}).encode())
            return json.loads(client.recv(64)) is True
    except (OSError,ValueError,KeyError):
        return False


def main(args):
    if not args or not all(u.lower().startswith(('http://', 'https://')) for u in args):
        os.execvp('chromium', ['chromium', *(['--', *args] if args else [])])
    if not selected_origin(args):
        os.execvp('chromium', ['chromium', '--', *args])
    delivered = []
    def launch(command):
        env = {k: v for k, v in os.environ.items() if k not in ('XDG_ACTIVATION_TOKEN', 'DESKTOP_STARTUP_ID', 'HL_INITIAL_WORKSPACE_TOKEN')}
        process = subprocess.Popen(command, env=env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        delivered.append(process)
        return process
    try:
        primary = subprocess.check_output([str(REPO/'scripts/ipc.sh'), 'outputs', 'primaryName'], text=True, timeout=3).strip()
        if not primary:
            raise RuntimeError('No primary output')
        backend = Sway() if os.environ.get('SWAYSOCK') else Hyprland() if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE') else None
        if backend is None:
            raise RuntimeError('No supported compositor')
        runtime = Path(os.environ.get('XDG_RUNTIME_DIR', ''))
        if not runtime.is_absolute():
            raise RuntimeError('No session runtime')
        fd = os.open(runtime/'qs-browser-link.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            open_links(args, backend, primary, launch)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
        if delivered:
            return 1
        os.execvp('chromium', ['chromium', '--', *args])


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
