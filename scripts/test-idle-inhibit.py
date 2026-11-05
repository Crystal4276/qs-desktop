#!/usr/bin/env python3
"""Exercise the inhibition API on a private bus, without a compositor or real session changes."""
import json
import os
from pathlib import Path
import socket
import shutil
import signal
import subprocess
import sys
import tempfile
import time

from gi.repository import Gio, GLib


def test_startup(helper, directory):
    # A scheduler pause before object registration must not expose a half-ready service.
    fixture = directory / 'slow-start.py'
    fixture.write_text("""import runpy, sys, time
from gi.repository import Gio
register = Gio.DBusConnection.register_object
def slow_register(self, *args):
    time.sleep(.2)
    return register(self, *args)
Gio.DBusConnection.register_object = slow_register
sys.argv = sys.argv[1:]
runpy.run_path(sys.argv[0], run_name='__main__')
""")
    process = subprocess.Popen([sys.executable, str(fixture), str(helper), str(directory / 'startup.sock')])
    client = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    try:
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            owned = client.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
                'org.freedesktop.DBus', 'NameHasOwner', GLib.Variant('(s)', ('org.freedesktop.ScreenSaver',)),
                None, Gio.DBusCallFlags.NONE, 1000, None).unpack()[0]
            if owned:
                break
            time.sleep(.005)
        assert owned, 'startup did not publish the service'
        cookie = client.call_sync('org.freedesktop.ScreenSaver', '/org/freedesktop/ScreenSaver',
            'org.freedesktop.ScreenSaver', 'Inhibit', GLib.Variant('(ss)', ('test', 'startup')),
            None, Gio.DBusCallFlags.NONE, 2000, None).unpack()[0]
        assert cookie != 0
    finally:
        process.terminate()
        process.wait(timeout=5)
    print('PASS: service callable immediately when its name becomes available')


def test_supervisor(directory):
    runtime = directory / 'runtime'
    runtime.mkdir(mode=0o700)
    binaries = directory / 'bin'
    binaries.mkdir()
    # The PID guard checks the executable name: use a private Bash copy called qs.
    shutil.copy2(shutil.which('bash'), binaries / 'qs')
    startup = directory / 'bash-startup'
    startup.write_text("desktop() { while :; do sleep .2; done; }\n")
    compositor = binaries / 'hyprctl'
    compositor.write_text('#!/bin/sh\nexit 0\n')
    compositor.chmod(0o755)
    env = dict(os.environ, PATH=str(binaries) + ':' + os.environ['PATH'],
        BASH_ENV=str(startup), XDG_RUNTIME_DIR=str(runtime),
        HYPRLAND_INSTANCE_SIGNATURE='test-idle', PERF_NO_ENV='1')
    env.pop('SWAYSOCK', None)
    script = str(Path(__file__).with_name('desktop.sh'))
    pidfile = runtime / 'qs-desktop.test-idle.pid'
    socket_path = runtime / 'qs-idle.test-idle.sock'

    def until(predicate):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            try:
                value = predicate()
                if value:
                    return value
            except (OSError, ValueError, GLib.Error):
                pass
            time.sleep(.02)
        raise AssertionError('supervisor condition timed out')

    client = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    with (directory / 'supervisor.log').open('w') as log:
        supervisor = subprocess.Popen([script, 'watch'], env=env, stdout=log, stderr=log,
            start_new_session=True)
        try:
            until(socket_path.exists)
            helper_pid = until(lambda: client.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
                'org.freedesktop.DBus', 'GetConnectionUnixProcessID',
                GLib.Variant('(s)', ('org.freedesktop.ScreenSaver',)), None,
                Gio.DBusCallFlags.NONE, 1000, None).unpack()[0])
            first_pid = until(lambda: int(pidfile.read_text()))
            cookie = client.call_sync('org.freedesktop.ScreenSaver', '/org/freedesktop/ScreenSaver',
                'org.freedesktop.ScreenSaver', 'Inhibit', GLib.Variant('(ss)', ('test', 'restart')),
                None, Gio.DBusCallFlags.NONE, 1000, None).unpack()[0]
            os.kill(first_pid, signal.SIGTERM)
            until(lambda: int(pidfile.read_text()) != first_pid)
            with socket.socket(socket.AF_UNIX) as replay:
                replay.settimeout(2)
                replay.connect(str(socket_path))
                assert json.loads(replay.makefile('r').readline())['count'] == 1
            client.call_sync('org.freedesktop.ScreenSaver', '/org/freedesktop/ScreenSaver',
                'org.freedesktop.ScreenSaver', 'UnInhibit', GLib.Variant('(u)', (cookie,)),
                None, Gio.DBusCallFlags.NONE, 1000, None)
            previous_helper = helper_pid
            os.kill(helper_pid, signal.SIGKILL)
            def replacement():
                pid = client.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
                    'org.freedesktop.DBus', 'GetConnectionUnixProcessID',
                    GLib.Variant('(s)', ('org.freedesktop.ScreenSaver',)), None,
                    Gio.DBusCallFlags.NONE, 1000, None).unpack()[0]
                return pid if pid != previous_helper else None
            helper_pid = until(replacement)
            os.kill(helper_pid, signal.SIGSTOP)
            stopped = subprocess.run([script, 'stop'], env=env, stdout=log, stderr=log, timeout=5)
            assert stopped.returncode == 0
            supervisor.wait(timeout=2)
            assert not socket_path.exists() and not pidfile.exists()
            assert not Path(f'/proc/{helper_pid}').exists()
            # A stopped service must not retain the supervisor lock.
            restarted = subprocess.Popen([script, 'watch'], env=env, stdout=log, stderr=log,
                start_new_session=True)
            try:
                until(socket_path.exists)
                until(pidfile.exists)
                assert restarted.poll() is None
            finally:
                subprocess.run([script, 'stop'], env=env, stdout=log, stderr=log, timeout=5)
                restarted.wait(timeout=2)
                # Include the fake shell's short-lived sleep children in cleanup.
                try:
                    os.killpg(restarted.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
        finally:
            subprocess.run([script, 'stop'], env=env, stdout=log, stderr=log, timeout=5)
            try:
                os.killpg(supervisor.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            supervisor.wait(timeout=2)
    print('PASS: automatic shell restart preserves cookies; crashed helper restarts; frozen helper cannot block stop or relaunch')


def test_old_cookie(helper, directory):
    path = str(directory / 'generation.sock')
    client = Gio.bus_get_sync(Gio.BusType.SESSION, None)

    def call(method, variant):
        return client.call_sync('org.freedesktop.ScreenSaver', '/org/freedesktop/ScreenSaver',
            'org.freedesktop.ScreenSaver', method, variant, None, Gio.DBusCallFlags.NONE, 2000, None).unpack()

    def snapshot():
        with socket.socket(socket.AF_UNIX) as stream:
            stream.settimeout(1)
            stream.connect(path)
            with stream.makefile('r') as reader:
                return json.loads(reader.readline())['count']

    def launch():
        process = subprocess.Popen([sys.executable, str(helper), path])
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                try:
                    assert snapshot() == 0
                    return process
                except OSError:
                    time.sleep(.01)
            raise AssertionError('bridge restart timed out')
        except BaseException:
            process.terminate()
            process.wait(timeout=5)
            raise

    process = launch()
    try:
        old = call('Inhibit', GLib.Variant('(ss)', ('test', 'old tab')))[0]
        process.kill()
        process.wait(timeout=5)
        process = launch()
        new = call('Inhibit', GLib.Variant('(ss)', ('test', 'new tab')))[0]
        assert old != new, 'a retained cookie was reused after restart'
        call('UnInhibit', GLib.Variant('(u)', (old,)))
        assert snapshot() == 1, 'old tab released the new tab inhibitor'
        call('UnInhibit', GLib.Variant('(u)', (new,)))
        assert snapshot() == 0
    finally:
        process.terminate()
        process.wait(timeout=5)
    print('PASS: releasing a retained cookie after daemon restart does not release the new video')


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
        test_startup(helper, Path(directory))
        test_supervisor(Path(directory))
        test_old_cookie(helper, Path(directory))
    print('PASS: cookies, caller ownership, replay, name collision, disconnect, legacy path, cleanup')


if __name__ == '__main__':
    if sys.argv[1:] == ['--private']:
        test()
    else:
        sys.exit(subprocess.call(['dbus-run-session', '--', sys.executable, __file__, '--private']))
