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
xml = '''<node>
<interface name="org.freedesktop.UPower"><property name="LidIsPresent" type="b" access="read"/><property name="LidIsClosed" type="b" access="read"/></interface>
<interface name="org.freedesktop.login1.Manager"><method name="Inhibit"><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="h" direction="out"/></method></interface>
</node>'''
interfaces = Gio.DBusNodeInfo.new_for_xml(xml).interfaces

def method(connection, sender, path, interface, method, params, invocation):
    assert params.unpack()[0] == 'handle-lid-switch' and params.unpack()[-1] == 'block'
    read, write = os.pipe()
    readers.append(read)
    fds = Gio.UnixFDList.new()
    index = fds.append(write)
    os.close(write)
    invocation.return_value_with_unix_fd_list(GLib.Variant('(h)', (index,)), fds)

bus.register_object('/org/freedesktop/UPower', interfaces[0], None,
                    lambda c,s,p,i,key: GLib.Variant('b',state[key]), None)
bus.register_object('/org/freedesktop/login1', interfaces[1], method, None, None)
for name in ('org.freedesktop.UPower', 'org.freedesktop.login1'):
    bus.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','RequestName',
        GLib.Variant('(su)',(name,0)), None, Gio.DBusCallFlags.NONE,-1,None)
loop = GLib.MainLoop()
thread = threading.Thread(target=loop.run, daemon=True)
thread.start()
bridge = subprocess.Popen([sys.executable, str(Path(__file__).with_name('lid-state.py'))],
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
def read():
    assert select.select([bridge.stdout],[],[],6)[0], 'bridge timed out'
    line = bridge.stdout.readline()
    assert line, bridge.stderr.read()
    return json.loads(line)
def changed(**values):
    state.update(values)
    bus.emit_signal(None,'/org/freedesktop/UPower','org.freedesktop.DBus.Properties','PropertiesChanged',
        GLib.Variant('(sa{sv}as)',('org.freedesktop.UPower', {k:GLib.Variant('b',v) for k,v in values.items()},[])))
try:
    assert read() == dict(ready=True,present=True,closed=False)
    assert len(readers) == 1
    changed(LidIsClosed=True); assert read()['closed']
    assert len(readers) == 1, 'duplicate inhibitor'
    changed(LidIsPresent=False); assert not read()['present']
    assert select.select([readers[0]],[],[],2)[0] and os.read(readers[0],1)==b'', 'FD not released'
    changed(LidIsPresent=True); assert read()['ready']
    assert len(readers) == 2
    bridge.terminate(); bridge.wait(timeout=3)
    assert select.select([readers[-1]],[],[],2)[0] and os.read(readers[-1],1)==b'', 'inhibitor survived bridge'
    print('PASS lid bridge: initial state, real PropertiesChanged, real inhibitor FD, deduplication, release and reacquisition, process exit')
finally:
    if bridge.poll() is None: bridge.kill(); bridge.wait()
    loop.quit(); thread.join(timeout=2)
    for fd in readers: os.close(fd)
