#!/usr/bin/env python3
"""Exercise the inhibition API on a private bus, without a compositor or real session changes."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

from gi.repository import Gio, GLib


def test():
    def connect():
        return Gio.DBusConnection.new_for_address_sync(os.environ['DBUS_SESSION_BUS_ADDRESS'],
            Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION, None, None)

    def call(client, method, signature, args):
        return client.call_sync('org.freedesktop.ScreenSaver', '/org/freedesktop/ScreenSaver',
            'org.freedesktop.ScreenSaver', method, GLib.Variant(signature, args), None,
            Gio.DBusCallFlags.NONE, 3000, None).unpack()

    helper = Path(__file__).with_name('idle-inhibit.py')
    with tempfile.TemporaryDirectory(prefix='qs-idle-test-') as directory:
        path = str(Path(directory) / 'idle.sock')
        process = subprocess.Popen([sys.executable, str(helper), path])
        try:
            for _ in range(100):
                if Path(path).exists():
                    break
                time.sleep(.05)
            with socket.socket(socket.AF_UNIX) as stream:
                stream.settimeout(3)
                stream.connect(path)
                reader = stream.makefile('r')
                def count(expected):
                    assert json.loads(reader.readline()) == {'ready': True, 'count': expected}
                count(0)
                a, b = connect(), connect()
                first = call(a, 'Inhibit', '(ss)', ('test', 'video'))[0]
                second = call(b, 'Inhibit', '(ss)', ('test', 'video'))[0]
                assert first != second
                count(1); count(2)
                call(b, 'UnInhibit', '(u)', (first,))  # Cannot remove another caller's cookie.
                with socket.socket(socket.AF_UNIX) as replay:
                    replay.settimeout(3); replay.connect(path)
                    assert json.loads(replay.recv(1024))['count'] == 2
                duplicate = subprocess.run([sys.executable, str(helper), path], capture_output=True, timeout=5)
                assert duplicate.returncode != 0 and Path(path).exists()
                call(a, 'UnInhibit', '(u)', (first,)); count(1)
                b.close_sync(None); count(0)
                # Legacy object path is also exported.
                result = a.call_sync('org.freedesktop.ScreenSaver', '/ScreenSaver',
                    'org.freedesktop.ScreenSaver', 'Inhibit', GLib.Variant('(ss)', ('test', 'legacy')),
                    None, Gio.DBusCallFlags.NONE, 3000, None)
                assert result.unpack()[0] != 0
                count(1); a.close_sync(None); count(0)
                reader.close()
        finally:
            process.terminate()
            process.wait(timeout=5)
        assert not Path(path).exists()
    print('PASS: cookies, caller ownership, replay, name collision, disconnect, legacy path, cleanup')


if __name__ == '__main__':
    if sys.argv[1:] == ['--private']:
        test()
    else:
        sys.exit(subprocess.call(['dbus-run-session', '--', sys.executable, __file__, '--private']))
