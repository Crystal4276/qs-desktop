#!/usr/bin/env python3
"""Session ScreenSaver inhibition API; stream counts to Quickshell over a private socket."""
import json
import os
import signal
import socket
import sys

from gi.repository import Gio, GLib
try:
    from gi.repository import GLibUnix
    add_signal = GLibUnix.signal_add
except ImportError:  # GLib before the separate GLibUnix introspection namespace.
    add_signal = GLib.unix_signal_add

NAME = "org.freedesktop.ScreenSaver"
XML = '''<node><interface name="org.freedesktop.ScreenSaver">
<method name="Inhibit"><arg type="s" direction="in"/><arg type="s" direction="in"/>
<arg type="u" direction="out"/></method>
<method name="UnInhibit"><arg type="u" direction="in"/></method>
</interface></node>'''


class Bridge:
    def __init__(self, path):
        self.path = path
        self.cookies = {}
        self.next_cookie = 0
        self.clients = {}
        self.loop = GLib.MainLoop()
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        # DO_NOT_QUEUE: never replace another desktop's service.
        result = self.bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus",
            "org.freedesktop.DBus", "RequestName", GLib.Variant("(su)", (NAME, 4)),
            GLib.VariantType.new("(u)"), Gio.DBusCallFlags.NONE, -1, None)
        if result.unpack()[0] != 1:
            raise RuntimeError(f"{NAME} already owned; not replacing it")
        interface = Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0]
        for object_path in ("/org/freedesktop/ScreenSaver", "/ScreenSaver"):
            self.bus.register_object(object_path, interface, self.method, None, None)
        self.bus.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus",
            "NameOwnerChanged", "/org/freedesktop/DBus", None, Gio.DBusSignalFlags.NONE,
            self.owner_changed)
        self.bus.connect("closed", lambda *_: self.loop.quit())
        # Only after acquiring the bus name is a stale session socket safe to remove.
        if os.path.exists(path):
            os.unlink(path)
        self.server = socket.socket(socket.AF_UNIX)
        self.server.bind(path)
        os.chmod(path, 0o600)
        self.server.listen(8)
        self.server.setblocking(False)
        GLib.io_add_watch(self.server.fileno(), GLib.IO_IN, self.accept)
        for sig in (signal.SIGTERM, signal.SIGINT):
            add_signal(GLib.PRIORITY_DEFAULT, sig, self.stop)

    def snapshot(self, client):
        try:
            client.sendall((json.dumps({"ready": True, "count": len(self.cookies)}) + "\n").encode())
        except OSError:
            self.drop(client)

    def publish(self):
        for client in list(self.clients):
            self.snapshot(client)

    def accept(self, *_):
        client, _ = self.server.accept()
        client.setblocking(False)
        self.clients[client] = GLib.io_add_watch(client.fileno(),
            GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, self.disconnected, client)
        self.snapshot(client)
        return GLib.SOURCE_CONTINUE

    def drop(self, client):
        source = self.clients.pop(client, None)
        if source is not None:
            GLib.source_remove(source)
        client.close()

    def disconnected(self, fd, condition, client):
        # The socket is a read-only event stream; incoming data or EOF closes it.
        self.clients.pop(client, None)
        client.close()
        return GLib.SOURCE_REMOVE

    def method(self, connection, sender, path, interface, method, params, invocation):
        if method == "Inhibit":
            self.next_cookie = self.next_cookie % 0xffffffff + 1
            while self.next_cookie in self.cookies:
                self.next_cookie = self.next_cookie % 0xffffffff + 1
            self.cookies[self.next_cookie] = sender
            self.publish()
            invocation.return_value(GLib.Variant("(u)", (self.next_cookie,)))
        else:
            cookie = params.unpack()[0]
            if self.cookies.get(cookie) == sender:
                del self.cookies[cookie]
                self.publish()
            invocation.return_value(GLib.Variant("()", ()))

    def owner_changed(self, connection, sender, path, interface, signal_name, params):
        name, old, new = params.unpack()
        if name.startswith(":") and old and not new:
            remaining = {cookie: owner for cookie, owner in self.cookies.items() if owner != name}
            if len(remaining) != len(self.cookies):
                self.cookies = remaining
                self.publish()

    def stop(self):
        self.loop.quit()
        return GLib.SOURCE_REMOVE

    def run(self):
        try:
            self.loop.run()
        finally:
            for client in list(self.clients):
                self.drop(client)
            self.server.close()
            os.unlink(self.path)


if __name__ == "__main__":
    try:
        Bridge(sys.argv[1]).run()
    except (RuntimeError, OSError, GLib.Error) as error:
        print(f"idle-inhibit: {error}", file=sys.stderr)
        sys.exit(1)
