#!/usr/bin/env python3
"""UPower lid events and logind ownership; JSON stream consumed by Lid.qml.
Exit code 0: no lid (desktop), Lid.qml does not restart the bridge."""
import json
import os
import signal
import sys
from gi.repository import Gio, GLib


class LidState:
    def __init__(self):
        self.fd = None
        self.absent = False
        self.retry_source = 0
        self.loop = GLib.MainLoop()
        self.bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.power = Gio.DBusProxy.new_sync(self.bus, Gio.DBusProxyFlags.NONE, None,
            'org.freedesktop.UPower', '/org/freedesktop/UPower', 'org.freedesktop.UPower', None)
        self.login = Gio.DBusProxy.new_sync(self.bus, Gio.DBusProxyFlags.NONE, None,
            'org.freedesktop.login1', '/org/freedesktop/login1', 'org.freedesktop.login1.Manager', None)
        self.power.connect('g-properties-changed', self.event_changed)
        self.power.connect('notify::g-name-owner', self.event_changed)
        self.login.connect('notify::g-name-owner', self.login_changed)
        self.bus.connect('closed', lambda *_: self.loop.quit())
        self.changed()

    def release(self):
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None

    def login_changed(self, *_):
        self.release()
        self.event_changed()

    def event_changed(self, *_):
        try:
            self.changed()
        except (GLib.Error, OSError) as error:
            self.release()
            print(json.dumps(dict(ready=False, present=False, closed=False)), flush=True)
            print(f"Lid bridge: {error}", file=sys.stderr)
            if not self.retry_source:  # one pending retry, however many events failed
                self.retry_source = GLib.timeout_add_seconds(5, self.retry)

    def retry(self):
        self.retry_source = 0
        self.event_changed()
        return GLib.SOURCE_REMOVE

    def changed(self, *_):
        present = self.power.get_cached_property('LidIsPresent')
        closed = self.power.get_cached_property('LidIsClosed')
        known = bool(self.power.get_name_owner() and self.login.get_name_owner()
                     and present is not None and closed is not None)
        if not known or not present.unpack():
            self.release()
        elif self.fd is None:
            # Holding the returned FD inhibits only automatic lid handling, never sleep itself.
            reply, fds = self.bus.call_with_unix_fd_list_sync('org.freedesktop.login1',
                '/org/freedesktop/login1', 'org.freedesktop.login1.Manager', 'Inhibit',
                GLib.Variant('(ssss)', ('handle-lid-switch', 'Quickshell',
                    'Suspend unless an external display is connected', 'block')),
                GLib.VariantType.new('(h)'), Gio.DBusCallFlags.NONE, 3000, None, None)
            self.fd = fds.get(reply.unpack()[0])
        print(json.dumps(dict(ready=known, present=bool(present and present.unpack()),
                              closed=bool(closed and closed.unpack()))), flush=True)
        # No lid (desktop): logind keeps its own handling, nothing to follow.
        self.absent = known and not present.unpack()
        if self.absent:
            self.loop.quit()

    def run(self):
        try:
            if not self.absent:
                self.loop.run()
        finally:
            self.release()


if __name__ == '__main__':
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    try:
        state = LidState()
        state.run()
    except (GLib.Error, OSError) as error:
        print(f'Lid bridge: {error}', file=sys.stderr)
        sys.exit(1)
    sys.exit(0 if state.absent else 1)
