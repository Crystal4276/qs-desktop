#!/usr/bin/env python3
"""UPower lid events, logind ownership and resumes; JSON stream consumed by Lid.qml.
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
        self.state = dict(ready=False, present=False, closed=False)
        self.last = None
        self.loop = GLib.MainLoop()
        self.bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.power = Gio.DBusProxy.new_sync(self.bus, Gio.DBusProxyFlags.NONE, None,
            'org.freedesktop.UPower', '/org/freedesktop/UPower', 'org.freedesktop.UPower', None)
        self.login = Gio.DBusProxy.new_sync(self.bus, Gio.DBusProxyFlags.NONE, None,
            'org.freedesktop.login1', '/org/freedesktop/login1', 'org.freedesktop.login1.Manager', None)
        self.power.connect('g-properties-changed', self.changed)
        self.power.connect('notify::g-name-owner', self.changed)
        self.login.connect('notify::g-name-owner', self.login_changed)
        self.login.connect('g-signal', self.login_signal)
        self.bus.connect('closed', lambda *_: self.loop.quit())
        self.changed()

    def release(self):
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None

    def login_changed(self, *_):
        self.release()
        self.changed()

    def login_signal(self, proxy, sender, name, params):
        # Resume: Lid.qml holds off its suspend decision, like logind's HoldoffTimeoutSec.
        if name == 'PrepareForSleep' and not params.unpack()[0]:
            self.report(resumed=True)

    def retry(self):
        self.retry_source = 0
        self.changed()
        return GLib.SOURCE_REMOVE

    def changed(self, *_):
        present = self.power.get_cached_property('LidIsPresent')
        closed = self.power.get_cached_property('LidIsClosed')
        known = bool(self.power.get_name_owner() and present is not None and closed is not None)
        lid = known and present.unpack()
        self.absent = known and not lid
        if not lid or not self.login.get_name_owner():
            self.release()
        elif self.fd is None:
            try:
                # Holding the returned FD inhibits only automatic lid handling, never sleep itself.
                reply, fds = self.bus.call_with_unix_fd_list_sync('org.freedesktop.login1',
                    '/org/freedesktop/login1', 'org.freedesktop.login1.Manager', 'Inhibit',
                    GLib.Variant('(ssss)', ('handle-lid-switch', 'Quickshell',
                        'Suspend unless an external display is connected', 'block')),
                    GLib.VariantType.new('(h)'), Gio.DBusCallFlags.NONE, 3000, None, None)
                self.fd = fds.get(reply.unpack()[0])
            except GLib.Error as error:
                # Meanwhile logind also handles the lid (same default policy); the lid state is still reported.
                print(f"Lid bridge: {error}", file=sys.stderr)
                if not self.retry_source:  # one pending retry, however many events failed
                    self.retry_source = GLib.timeout_add_seconds(5, self.retry)
        self.state = dict(ready=known, present=bool(lid), closed=bool(lid and closed.unpack()))
        self.report()
        # No lid (desktop): logind keeps its own handling, nothing to follow.
        if self.absent:
            self.loop.quit()

    def report(self, resumed=False):
        line = json.dumps(dict(self.state, resumed=True) if resumed else self.state)
        if resumed or line != self.last:  # other UPower properties (OnBattery…) change nothing here
            print(line, flush=True)
        if not resumed:
            self.last = line

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
