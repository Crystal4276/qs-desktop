#!/usr/bin/env python3
"""Real UPower proxy and logind FD exchange on a private system bus; no hardware access."""
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import threading
import time
from gi.repository import Gio, GLib

if '--private' not in sys.argv:
    raise SystemExit(subprocess.call(['dbus-run-session', '--', sys.executable, __file__, '--private']))
os.environ['DBUS_SYSTEM_BUS_ADDRESS'] = os.environ['DBUS_SESSION_BUS_ADDRESS']
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
state = dict(LidIsPresent=True, LidIsClosed=False)
readers = []
calls = []          # time of each Inhibit call
refuse = [False]    # logind refuses Inhibit (polkit, error)
failures = []
xml = '''<node>
<interface name="org.freedesktop.UPower"><property name="LidIsPresent" type="b" access="read"/><property name="LidIsClosed" type="b" access="read"/></interface>
<interface name="org.freedesktop.login1.Manager"><method name="Inhibit"><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="h" direction="out"/></method></interface>
</node>'''
interfaces = Gio.DBusNodeInfo.new_for_xml(xml).interfaces


def check(name, ok, detail=''):
    print(('ok    ' if ok else 'FAIL  ') + name + ('' if ok else f'  {detail}'))
    if not ok:
        failures.append(name)


def method(connection, sender, path, interface, method, params, invocation):
    assert params.unpack()[0] == 'handle-lid-switch' and params.unpack()[-1] == 'block'
    calls.append(time.monotonic())
    if refuse[0]:
        invocation.return_dbus_error('org.freedesktop.DBus.Error.AccessDenied', 'refused by the test')
        return
    read, write = os.pipe()
    readers.append(read)
    fds = Gio.UnixFDList.new()
    index = fds.append(write)
    os.close(write)
    invocation.return_value_with_unix_fd_list(GLib.Variant('(h)', (index,)), fds)


def own(name):
    bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'RequestName',
                  GLib.Variant('(su)', (name, 0)), None, Gio.DBusCallFlags.NONE, -1, None)


bus.register_object('/org/freedesktop/UPower', interfaces[0], None,
                    lambda c, s, p, i, key: GLib.Variant('b', state[key]), None)
bus.register_object('/org/freedesktop/login1', interfaces[1], method, None, None)
own('org.freedesktop.login1')
loop = GLib.MainLoop()
thread = threading.Thread(target=loop.run, daemon=True)
thread.start()
script = str(Path(__file__).with_name('lid-state.py'))
bridges = []


def start():
    bridges.append(subprocess.Popen([sys.executable, script], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True))
    return bridges[-1]


def read(bridge):
    assert select.select([bridge.stdout], [], [], 6)[0], 'bridge timed out'
    line = bridge.stdout.readline()
    assert line, bridge.stderr.read()
    return json.loads(line)


def changed(**values):
    state.update(values)
    bus.emit_signal(None, '/org/freedesktop/UPower', 'org.freedesktop.DBus.Properties', 'PropertiesChanged',
                    GLib.Variant('(sa{sv}as)', ('org.freedesktop.UPower', {k: GLib.Variant('b', v) for k, v in values.items()}, [])))


def released(fd):
    return bool(select.select([fd], [], [], 2)[0]) and os.read(fd, 1) == b''


try:
    # UPower appears after the bridge, while logind refuses: failures in a burst leave a single pending retry.
    refuse[0] = True
    bridge = start()
    check('UPower absent: not ready', read(bridge) == dict(ready=False, present=False, closed=False))
    own('org.freedesktop.UPower')
    burst = time.monotonic()
    for closed in (True, False, True, False):
        changed(LidIsClosed=closed)
        time.sleep(.1)
    time.sleep(5.6)
    retries = [t for t in calls if t > burst + 4.5]
    check('refused inhibitor: one retry for a burst of failures', len(retries) == 1, f'{len(retries)} retries')
    refuse[0] = False
    time.sleep(5)
    check('refused inhibitor: acquired at the next retry', len(readers) == 1, f'{len(readers)} inhibitors')
    bridge.terminate(); bridge.wait(timeout=3)
    check('bridge stopped: inhibitor released', released(readers[0]))

    state.update(LidIsPresent=True, LidIsClosed=False)
    n = len(readers)
    bridge = start()
    while (s := read(bridge)) != dict(ready=True, present=True, closed=False):
        pass
    check('initial state: one inhibitor', len(readers) == n + 1)
    changed(LidIsClosed=True)
    check('PropertiesChanged followed', read(bridge)['closed'])
    check('no duplicate inhibitor', len(readers) == n + 1)
    bridge.terminate(); bridge.wait(timeout=3)
    check('process exit: inhibitor released', released(readers[-1]))

    state.update(LidIsPresent=False, LidIsClosed=False)
    n = len(calls)
    bridge = start()
    check('no lid: reported', read(bridge) == dict(ready=True, present=False, closed=False))
    try:
        code = bridge.wait(timeout=3)
    except subprocess.TimeoutExpired:
        code = None
    check('no lid: bridge exits with code 0 (not restarted)', code == 0, f'code {code}')
    check('no lid: no inhibitor', len(calls) == n)
finally:
    for b in bridges:
        if b.poll() is None:
            b.kill(); b.wait()
    loop.quit(); thread.join(timeout=2)
    for fd in readers:
        os.close(fd)
print('PASS lid bridge' if not failures else f'{len(failures)} failure(s)')
sys.exit(1 if failures else 0)
