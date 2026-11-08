#!/usr/bin/env python3
"""Place content opened by Deluge, Thunderbird and Steam on the primary output.

Observe native launches/activation, not file extensions or source workspaces.
No URI, filename or document content is logged or persisted.
"""
import hashlib
import fcntl
import signal
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import threading
import time

import gi
from gi.repository import Gio, GLib

REPO = Path(__file__).resolve().parent.parent
SOURCES = {'deluge', 'deluge-gtk', 'thunderbird', 'steam', 'steamwebhelper'}
SOURCE_CLASSES = {'deluge', 'org.mozilla.thunderbird', 'thunderbird', 'steam'}


def identity(pid):
    try:
        p = Path('/proc')/str(int(pid))
        if p.stat().st_uid != os.getuid():
            return None
        stat = (p/'stat').read_text(); end = stat.rindex(')'); fields = stat[end+2:].split()
        return dict(pid=int(pid), ppid=int(fields[1]), start=fields[19], name=stat[stat.index('(')+1:end].lower())
    except (OSError, ValueError, IndexError):
        return None


def source_of(pid):
    seen = set()
    for _ in range(40):
        if pid in seen:
            break
        seen.add(pid); row = identity(pid)
        if not row:
            break
        if row['name'] in SOURCES:
            return row['name']
        pid = row['ppid']
    return ''


def startup_source(pid):
    try:
        env = (Path('/proc')/str(pid)/'environ').read_bytes().split(b'\0')
        value = next((s.split(b'=',1)[1].decode(errors='replace') for s in env if s.startswith(b'DESKTOP_STARTUP_ID=')), '')
        # Deluge's native open_file/show_file embeds its live source PID in this ID.
        match = re.match(r'^(?:deluge(?:-gtk)?)[-_](\d+)[-_]', value)
        return source_of(int(match[1])) if match else ''
    except (OSError, ValueError):
        return ''


def query(args):
    return json.loads(subprocess.check_output(args, text=True, timeout=2))


class Desktop:
    def __init__(self):
        self.sway = bool(os.environ.get('SWAYSOCK'))

    def windows(self):
        if not self.sway:
            return [dict(id=c['address'], pid=c['pid'], app=c.get('class','').lower(),
                         output=c['monitor'], title=c.get('title',''), rank=c.get('focusHistoryID',-1))
                    for c in query(['hyprctl','-j','clients']) if c.get('mapped', True)]
        result = []
        def walk(n, output=''):
            if n.get('type') == 'output': output=n['name']
            if n.get('pid') and (n.get('app_id') or n.get('window')):
                result.append(dict(id=n['id'],pid=n['pid'],app=(n.get('app_id') or n.get('window_properties',{}).get('class','')).lower(),
                                   output=output,title=n.get('name',''),rank=0 if n.get('focused') else len(result)+1))
            for child in n.get('nodes',[])+n.get('floating_nodes',[]): walk(child,output)
        walk(query(['swaymsg','-t','get_tree']))
        return result

    def place(self, window, primary):
        if self.sway:
            command=f'mouse_warping none; [con_id={int(window["id"])}] move container to output {json.dumps(primary)}; [con_id={int(window["id"])}] focus; mouse_warping output'
            if not all(x.get('success') for x in query(['swaymsg',command])):
                raise RuntimeError('Could not place opened content')
        else:
            target='window="address:'+window['id']+'"'
            command='function() qsPlaceExternal("address:'+window['id']+'",'+json.dumps(primary)+') end'
            result=subprocess.check_output(['hyprctl','dispatch',command],text=True,timeout=2)
            if result.strip()!='ok': raise RuntimeError('Could not place opened content')


class Policy:
    def __init__(self, desktop, primary):
        self.desktop=desktop;self.primary=primary;self.pending=[];self.requests={};self.routed={}
        self.publish=lambda:None

    def remember(self, uris, source):
        if source:
            for uri in uris:
                self.requests[hashlib.sha256(uri.encode()).hexdigest()]=(time.monotonic()+5,source)

    def request_source(self, uris):
        now=time.monotonic()
        self.requests={k:v for k,v in self.requests.items() if v[0]>now}
        return next((self.requests[hashlib.sha256(u.encode()).hexdigest()][1] for u in uris
                     if hashlib.sha256(u.encode()).hexdigest() in self.requests),'')

    def track(self, pid, source, desktop_file=''):
        row=identity(pid)
        if not row or not source:return
        self.routed[pid]=(row['start'],time.monotonic()+5,source)
        self.publish()
        if not self.desktop.sway:
            own = {'deluge'} if source.startswith('deluge') else {'steam'} if source.startswith('steam') else {'thunderbird','org.mozilla.thunderbird'}
            matches=[w for w in self.desktop.windows() if w['pid']==pid and w['app'] not in own]
            if matches:
                self.desktop.place(min(matches,key=lambda w:w['rank'] if w['rank']>=0 else 1_000_000),self.primary())
            return
        self.pending.append(dict(pid=pid,start=row['start'],source=source,until=time.monotonic()+4,
                                 known={w['id']:w['title'] for w in self.desktop.windows()},desktop=desktop_file,begin=time.monotonic()))

    def forwarded_source(self, pid):
        value=self.routed.get(pid);row=identity(pid)
        return value[2] if value and row and row['start']==value[0] and value[1]>time.monotonic() else ''

    def poll(self):
        now=time.monotonic()
        self.routed={p:v for p,v in self.routed.items() if v[1]>now}
        if not self.pending:return True
        windows=self.desktop.windows();remaining=[]
        for request in self.pending:
            if now>request['until']:continue
            row=identity(request['pid'])
            if not row or row['start']!=request['start']:continue
            own = {'deluge'} if request['source'].startswith('deluge') else {'steam'} if request['source'].startswith('steam') else {'thunderbird','org.mozilla.thunderbird'}
            matches=[w for w in windows if w['pid']==request['pid'] and w['app'] not in own]
            fresh=[w for w in matches if w['id'] not in request['known'] or request['known'][w['id']]!=w['title']]
            if not fresh and now-request['begin']<.25:
                remaining.append(request);continue
            if fresh or matches:
                target=min(fresh or matches,key=lambda w:w['rank'] if w['rank']>=0 else 1_000_000)
                self.desktop.place(target,self.primary())
            else:remaining.append(request)
        self.pending=remaining
        return True

    def opened(self, window):
        if window['app'] in SOURCE_CLASSES:return
        # Later windows of an existing viewer need their own open request, not its old ancestry.
        if any(w['pid']==window['pid'] and w['id']!=window['id'] for w in self.desktop.windows()):return
        source=source_of(window['pid']) or startup_source(window['pid'])
        if source:self.desktop.place(window,self.primary())


class Observer:
    def __init__(self):
        self.desktop=Desktop();self.cached_primary='';self.policy=Policy(self.desktop,self.primary)
        self.control=Gio.bus_get_sync(Gio.BusType.SESSION,None)
        self.name_pending=[];self.origins={};self.child=None
        self.control.signal_subscribe('org.freedesktop.DBus','org.freedesktop.DBus','NameOwnerChanged','/org/freedesktop/DBus',None,Gio.DBusSignalFlags.NONE,self.owner_changed)
        names=self.control.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','ListNames',None,None,Gio.DBusCallFlags.NONE,1000,None).unpack()[0]
        for name in names:
            if name.startswith(':'):self.cache_origin(name)
        address=Gio.dbus_address_get_for_bus_sync(Gio.BusType.SESSION,None)
        self.monitor=Gio.DBusConnection.new_for_address_sync(address,Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT|Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,None,None)
        rules=["type='method_call',interface='org.freedesktop.portal.OpenURI'",
               "type='method_call',interface='org.freedesktop.Application',member='Open'",
               "type='method_call',interface='org.gtk.Application',member='Open'",
               "type='method_call',interface='org.gtk.Application',member='CommandLine'",
               "type='method_call',interface='org.freedesktop.FileManager1'",
               "type='method_call',interface='org.mpris.MediaPlayer2.Player',member='OpenUri'",
               "type='signal',interface='org.gtk.gio.DesktopAppInfo',member='Launched'"]
        self.monitor.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus.Monitoring','BecomeMonitor',GLib.Variant('(asu)',(rules,0)),None,Gio.DBusCallFlags.NONE,2000,None)
        self.monitor.add_filter(self.message,None)
        self.polling=False
        self.primary()
        self.socket=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
        self.path=Path(os.environ['XDG_RUNTIME_DIR'])/'qs-open-origin.sock'
        self.lock=os.open(self.path.with_suffix('.lock'),os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
        fcntl.flock(self.lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        self.path.unlink(missing_ok=True);self.socket.bind(str(self.path));self.path.chmod(0o600);self.socket.listen(5)
        GLib.io_add_watch(self.socket.fileno(),GLib.IO_IN,self.origin_query)
        self.state_path=self.path.with_suffix('.state')
        self.policy.publish=self.publish
        self.publish()
        self.watch_windows()

    def publish(self):
        if self.desktop.sway:return
        primary=self.cached_primary
        value=primary+'\n'+''.join(f"{pid} {row[0]} {row[1]:.3f}\n" for pid,row in self.policy.routed.items() if row[1]>time.monotonic())
        temp=self.state_path.with_suffix('.tmp')
        fd=os.open(temp,os.O_WRONLY|os.O_CREAT|os.O_TRUNC|os.O_NOFOLLOW,0o600)
        with os.fdopen(fd,'w') as stream:stream.write(value)
        temp.replace(self.state_path)

    def primary(self):
        name=subprocess.check_output([str(REPO/'scripts/ipc.sh'),'outputs','primaryName'],text=True,timeout=3).strip()
        outputs=query(['swaymsg','-t','get_outputs']) if self.desktop.sway else query(['hyprctl','-j','monitors'])
        if name not in {row['name'] for row in outputs if row.get('active',True)}:
            raise RuntimeError('Primary output is not ready')
        self.cached_primary=name
        return name

    def pid(self, name):
        try:
            value=self.control.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','GetConnectionUnixProcessID',GLib.Variant('(s)',(name,)),None,Gio.DBusCallFlags.NONE,500,None)
            return value.unpack()[0]
        except GLib.Error:return 0

    def cache_origin(self,name):
        pid=self.pid(name)
        source=source_of(pid) or self.policy.forwarded_source(pid)
        if source:self.origins[name]=(time.monotonic()+3600,source)

    def owner_changed(self,connection,sender,path,interface,member,parameters):
        name,old,new=parameters.unpack()
        if name.startswith(':') and new:self.cache_origin(name)
        elif name in self.origins:self.origins[name]=(time.monotonic()+5,self.origins[name][1])
        self.origins={n:v for n,v in self.origins.items() if v[0]>time.monotonic()}

    def sender_source(self,name):
        value=self.origins.get(name)
        return value[1] if value and value[0]>time.monotonic() else ''

    def is_portal(self,pid):
        try:return (Path('/proc')/str(pid)/'exe').resolve().name.startswith('xdg-desktop-portal')
        except OSError:return False

    def message(self, connection, message, incoming, data):
        if incoming:
            GLib.idle_add(self.process,message)
        return None  # A monitor must never dispatch or reply to observed calls.

    def process(self, message):
        try:
            interface=message.get_interface();member=message.get_member();body=message.get_body()
            if body is None:return False
            body=body.unpack()
            if interface=='org.gtk.gio.DesktopAppInfo' and member=='Launched':
                desktop,display,pid,uris,extras=body
                origin=int(extras.get('origin-pid',0));source=self.sender_source(message.get_sender()) or source_of(origin) or self.policy.forwarded_source(origin)
                if not source and self.is_portal(origin):source=self.policy.request_source(uris)
                self.policy.remember(uris,source);self.track(pid,source)
                return False
            sender=self.pid(message.get_sender());source=self.sender_source(message.get_sender()) or source_of(sender) or self.policy.forwarded_source(sender)
            uris=[]
            if interface=='org.freedesktop.portal.OpenURI':
                if member=='OpenURI':uris=[body[1]]
                elif member in ('OpenFile','OpenDirectory'):
                    fds=message.get_unix_fd_list()
                    if fds:
                        fd=fds.get(body[1])
                        try:
                            file=Path(os.readlink('/proc/self/fd/'+str(fd)))
                            uris=[file.as_uri()]
                            if member=='OpenDirectory':uris.append(file.parent.as_uri())
                        finally:os.close(fd)
                if source:self.policy.remember(uris,source)
                else:
                    for uri in uris:self.policy.requests.pop(hashlib.sha256(uri.encode()).hexdigest(),None)
                return False
            if member in ('Open','ShowItems','ShowFolders'):uris=body[0] if body and isinstance(body[0],list) else []
            elif member=='OpenUri':uris=[body[0]]
            if not source and self.is_portal(sender):source=self.policy.request_source(uris)
            if source:
                self.policy.remember(uris,source)
                target=self.pid(message.get_destination())
                if target:self.track(target,source)
                else:
                    self.name_pending.append((time.monotonic()+4,message.get_destination(),source));self.schedule()
        except (OSError,ValueError,TypeError,IndexError,RuntimeError,subprocess.SubprocessError,GLib.Error):
            pass  # Native application launch continues independently.
        return False

    def schedule(self):
        if not self.polling:
            self.polling=True;GLib.timeout_add(50,self.poll)

    def track(self,pid,source):
        self.policy.track(pid,source);self.schedule()

    def poll(self):
        try:
            remaining=[]
            for until,name,source in self.name_pending:
                pid=self.pid(name)
                if pid:self.track(pid,source)
                elif until>time.monotonic():remaining.append((until,name,source))
            self.name_pending=remaining;self.policy.poll()
            self.origins={n:v for n,v in self.origins.items() if v[0]>time.monotonic()}
        except (OSError,ValueError,RuntimeError,subprocess.SubprocessError):pass
        self.polling=bool(self.name_pending or self.policy.pending)
        return self.polling

    def origin_query(self,*unused):
        client,_=self.socket.accept();client.settimeout(.1)
        try:
            data=json.loads(client.recv(65536))
            source=source_of(int(data.get('pid',0))) or self.policy.forwarded_source(int(data.get('pid',0)))
            client.sendall(json.dumps(bool(source)).encode())
        except (OSError,ValueError):pass
        finally:client.close()
        return True

    def watch_windows(self):
        def observe():
            if self.desktop.sway:
                process=subprocess.Popen(['swaymsg','-r','-m','-t','subscribe','["window"]'],stdout=subprocess.PIPE,text=True)
                self.child=process
                for line in process.stdout:
                    try:
                        event=json.loads(line)
                        if isinstance(event,dict) and event.get('change')=='new':GLib.idle_add(self.new_window,event['container'].get('id'))
                    except (ValueError,KeyError):pass
            else:
                path=Path(os.environ['XDG_RUNTIME_DIR'])/'hypr'/os.environ['HYPRLAND_INSTANCE_SIGNATURE']/'.socket2.sock'
                sock=socket.socket(socket.AF_UNIX);sock.connect(str(path));stream=sock.makefile()
                for line in stream:
                    if line.startswith(('monitoradded>>','monitorremoved>>','configreloaded>>')):
                        GLib.timeout_add(1000,self.refresh_primary)
                    if line.startswith('openwindow>>'):GLib.idle_add(self.new_window,'0x'+line.split('>>',1)[1].split(',')[0].removeprefix('0x'))
        threading.Thread(target=observe,daemon=True).start()

    def refresh_primary(self):
        try:
            self.primary();self.publish()
        except (OSError,ValueError,subprocess.SubprocessError):pass
        return False

    def new_window(self,identifier):
        try:
            window=next((w for w in self.desktop.windows() if w['id']==identifier),None)
            if window and self.desktop.sway:self.policy.opened(window)
        except (OSError,ValueError,RuntimeError,subprocess.SubprocessError):pass
        return False


if __name__=='__main__':
    observer=Observer()
    loop=GLib.MainLoop()
    signal.signal(signal.SIGTERM,lambda *_:loop.quit())
    signal.signal(signal.SIGINT,lambda *_:loop.quit())
    try:loop.run()
    finally:
        if observer.child:
            observer.child.terminate()
            try:observer.child.wait(timeout=2)
            except subprocess.TimeoutExpired:observer.child.kill();observer.child.wait()
        observer.monitor.close_sync(None);observer.socket.close();observer.path.unlink(missing_ok=True)
        observer.state_path.unlink(missing_ok=True)
        os.close(observer.lock)
