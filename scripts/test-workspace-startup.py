#!/usr/bin/env python3
"""Replay the QS 0.3.2 startup race on private IPC sockets; no real desktop actions."""
import json, os, pathlib, re, shutil, signal, socket, subprocess, sys, tempfile, threading, time
repo = pathlib.Path(__file__).resolve().parent.parent
if '--private-bus' not in sys.argv:
    raise SystemExit(subprocess.call(['dbus-run-session', '--', sys.executable, __file__, '--private-bus']))

def run(mode):
    with tempfile.TemporaryDirectory(prefix='qs-ws-') as tmp:
        root=pathlib.Path(tmp)
        for n in ('services','config','bin','runtime/hypr/test'): (root/n).mkdir(parents=True, exist_ok=True)
        for n in ('Compositor','Outputs'): shutil.copy2(repo/f'services/{n}.qml',root/f'services/{n}.qml')
        (root/'config/Settings.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    property var workspaceLayouts: []
    function primaryOf(outs) { return outs.find(o => o.name === "CENTER") ?? null; }
}
''')
        (root/'shell.qml').write_text('''import Quickshell
import qs.services
ShellRoot { property var service: Outputs }
''')
        rows=[dict(id=i,address=str(i),name=str(i),monitor=m,monitorID=j,windows=0) for j,(i,m) in enumerate([(1,'LEFT'),(2,'CENTER'),(3,'RIGHT')])]
        six=dict(id=6,address='6',name='6',monitor='CENTER',monitorID=1,windows=1)
        snapshot=root/'snapshot.json'; snapshot.write_text(json.dumps(rows+[six]))
        count=root/'count'; count.write_text('0')
        (root/'bin/hyprctl').write_text(f'''#!{sys.executable}
import pathlib,time
p=pathlib.Path({str(count)!r}); n=int(p.read_text()); p.write_text(str(n+1))
mode={mode!r}
if mode == 'failure' or (mode == 'retry' and n < 2): print('invalid'); raise SystemExit(1)
reply=pathlib.Path({str(snapshot)!r}).read_text()
if mode in ('delayed','destroy','concurrent'): time.sleep(.25)
print(reply)
'''); (root/'bin/hyprctl').chmod(0o755)
        stop=threading.Event(); events=[]; actions=[]; threads=[]; listeners=[]
        def emit(msg):
            for c in events:
                try: c.sendall((msg+'\n').encode())
                except OSError: pass
        def handle(c):
            with c:
                req=c.recv(65536).decode()
                if req=='j/status': answer={'configProvider':'lua'}
                elif req=='j/monitors':
                    answer=[dict(id=j,name=m,make=m,model='test',serial=str(j),width=w,height=1440,x=x,y=0,scale=1,focused=j==1,activeWorkspace={'id':i,'name':str(i)},disabled=False,mirrorOf='none') for j,(i,m,w,x) in enumerate([(1,'LEFT',2560,0),(2,'CENTER',3440,2560),(3,'RIGHT',2560,6000)])]
                elif req=='j/workspaces':
                    # Snapshot captured before creation, delivered afterwards. QS drops 6.
                    if not getattr(handle,'queried',False):
                        handle.queried=True
                        deadline=time.monotonic()+2
                        while not events and time.monotonic()<deadline: time.sleep(.01)
                        emit('createworkspacev2>>6,6'); time.sleep(.15)
                        answer=rows
                    else: answer=rows+[six]
                elif req=='j/clients': answer=[]
                elif req.startswith('dispatch '):
                    actions.append(req)
                    if 'workspace = 6, monitor = "LEFT"' in req:
                        six['monitor']='LEFT'; six['monitorID']=0
                        emit('moveworkspacev2>>6,6,LEFT')
                    c.sendall(b'ok'); return
                else: c.sendall(b'ok'); return
                c.sendall(json.dumps(answer).encode())
        def serve(listener,event=False):
            while not stop.is_set():
                try: c,_=listener.accept()
                except (OSError,TimeoutError): continue
                if event: events.append(c)
                else:
                    t=threading.Thread(target=handle,args=(c,),daemon=True); t.start(); threads.append(t)
        for name,event in [('.socket.sock',False),('.socket2.sock',True)]:
            sock=socket.socket(socket.AF_UNIX);sock.bind(str(root/'runtime/hypr/test'/name));sock.listen();sock.settimeout(.1);listeners.append(sock)
            t=threading.Thread(target=serve,args=(sock,event),daemon=True);t.start();threads.append(t)
        def during_query():
            deadline=time.monotonic()+4
            while int(count.read_text())==0 and time.monotonic()<deadline: time.sleep(.01)
            if mode=='destroy':
                snapshot.write_text(json.dumps(rows)); emit('destroyworkspacev2>>6,6')
            elif mode=='concurrent':
                eight=dict(id=8,address='8',name='8',monitor='CENTER',monitorID=1,windows=1)
                snapshot.write_text(json.dumps(rows+[six,eight])); emit('createworkspacev2>>8,8')
        if mode in ('destroy','concurrent'):
            t=threading.Thread(target=during_query,daemon=True);t.start();threads.append(t)
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_NO_XDG_DESKTOP_PORTAL='1',GIO_USE_VFS='local',GVFS_DISABLE_FUSE='1',NO_AT_BRIDGE='1',QS_TEST='1',HYPRLAND_INSTANCE_SIGNATURE='test',XDG_RUNTIME_DIR=str(root/'runtime'),XDG_STATE_HOME=str(root/'state'),XDG_CACHE_HOME=str(root/'cache'),PATH=str(root/'bin')+':'+os.environ['PATH'])
        for k in ('SWAYSOCK','I3SOCK','QS_DESKTOP_HOME','WAYLAND_DISPLAY','DISPLAY'): env.pop(k,None)
        with (root/'qs.log').open('w+') as log:
            p=subprocess.Popen(['qs','-p',str(root)],env=env,stdout=log,stderr=log,start_new_session=True)
            try:
                deadline=time.monotonic()+5
                while time.monotonic()<deadline:
                    if p.poll() is not None: break
                    if any('workspace = 6, monitor = "LEFT"' in a for a in actions): break
                    time.sleep(.05)
                time.sleep(.4)
                log.seek(0); text=log.read()
                assert 'Failed to load configuration' not in text, text
                moves=sum('workspace = 6, monitor = "LEFT"' in a for a in actions)
                if mode=='destroy':
                    assert moves==0 and int(count.read_text())>=2, (actions,text)
                elif mode=='failure':
                    assert moves==0 and int(count.read_text())==3, (actions,text)
                else: assert moves==1, (actions,text)
                if mode=='concurrent': assert any('workspace = 8, monitor = \"RIGHT\"' in a for a in actions), (actions,text)
                assert len(actions)<8, actions
                if mode=='normal':
                    before=len(actions)
                    six['monitor']='CENTER'
                    emit('moveworkspacev2>>6,6,CENTER')
                    time.sleep(.4)
                    assert len(actions)==before, 'manual move was overridden'
                print('PASS',mode,'queries',count.read_text(),'moves',moves,flush=True)
            finally:
                os.killpg(p.pid,signal.SIGTERM);p.wait(timeout=5)
                stop.set()
                for c in events: c.close()
                for sock in listeners: sock.close()
                for t in threads: t.join(timeout=.3)
for mode in ('normal','delayed','retry','failure','destroy','concurrent'): run(mode)
