#!/usr/bin/env python3
"""Notification panel geometry and interaction on isolated Wayland benches."""
import argparse, json, os, re, shutil, signal, subprocess, tempfile, time
from pathlib import Path
REPO=Path(__file__).resolve().parents[1]
def run(*args, **kwargs):
    return subprocess.check_output(args,text=True,stderr=subprocess.PIPE,timeout=10,**kwargs).strip()
def test(work, compositor, scale, shots, height):
    root=work/'shell'
    shutil.copytree(REPO,root,ignore=shutil.ignore_patterns('.git','.shots','.agents','.codex','.aws','__pycache__'))
    shutil.copy2(REPO/'scripts/tests/notifications/shell.qml',root/'shell.qml')
    p=root/'modules/bar/NotificationsPanel.qml'
    p.write_text(p.read_text().replace('    id: root','    id: root\n    readonly property alias testList: historyList\n    readonly property alias testControls: controls\n    readonly property alias testScrollbar: scrollbar',1))
    (root/'services/Session.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool lockActive: false }')
    (root/'services/Media.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var player: null; property real length: 0; property real position: 0; function refreshPosition() {} }')
    runtime = work / 'r'
    runtime.mkdir(mode=0o700)
    bindir = work / 'bin'
    bindir.mkdir()
    for name in ('nordvpn', 'systemctl', 'brightnessctl', 'notify-send'):
        target = bindir / name
        target.write_text('#!/bin/sh\nexit 1\n')
        target.chmod(0o755)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), WLR_BACKENDS='headless', WLR_RENDERER='pixman',
               WLR_LIBINPUT_NO_DEVICES='1', QS_TEST='1', GIO_USE_VFS='local', GVFS_DISABLE_FUSE='1',
               XDG_STATE_HOME=str(work / 'state'), XDG_CACHE_HOME=str(work / 'cache'),
               PATH=str(bindir) + ':' + os.environ['PATH'])
    for key in ('SWAYSOCK', 'I3SOCK', 'HYPRLAND_INSTANCE_SIGNATURE', 'WAYLAND_DISPLAY', 'DISPLAY', 'QS_IDLE_SOCKET', 'QS_LOCK_STATE'):
        env.pop(key, None)
    shell = None
    sway = None
    try:
        if compositor == 'hyprland':
            config=work/'hyprland.lua'
            config.write_text('hl.config({misc={disable_hyprland_logo=true,disable_splash_rendering=true,disable_autoreload=true},ecosystem={no_update_news=true,no_donation_nag=true},animations={enabled=false},cursor={no_warps=true}})\n')
            parent=dict(os.environ)
            nested=dict(env,AQ_BACKEND='wayland',WAYLAND_DISPLAY=str(Path(parent['XDG_RUNTIME_DIR'])/parent['WAYLAND_DISPLAY']))
            sway=subprocess.Popen(['Hyprland','-c',str(config)],env=nested,stdout=(work/'sway.log').open('w'),stderr=subprocess.STDOUT)
            for _ in range(100):
                ipc_sockets=list((runtime/'hypr').glob('*/.socket.sock'))
                sockets=[p for p in runtime.glob('wayland-*') if p.is_socket()]
                if ipc_sockets and sockets: break
                if sway.poll() is not None: raise AssertionError((work/'sway.log').read_text())
                time.sleep(.1)
            assert ipc_sockets and sockets, (work/'sway.log').read_text()
            time.sleep(.4)
            for window in json.loads(run('hyprctl','clients','-j',env=parent)):
                if window['pid']==sway.pid:
                    run('hyprctl','dispatch','hl.dsp.window.move({window="address:'+window['address']+'",workspace="special:qs-notification-test",follow=false})',env=parent)
            env.update(HYPRLAND_INSTANCE_SIGNATURE=ipc_sockets[0].parent.name,WAYLAND_DISPLAY=sockets[0].name,QT_QPA_PLATFORM='wayland')
            run('hyprctl','output','create','headless',env=env); time.sleep(.25)
            run('hyprctl','eval',f'hl.monitor({{output="HEADLESS-1",mode="{round(1920*scale)}x{round(height*scale)}@60",position="0x0",scale={scale}}}); hl.monitor({{output="WAYLAND-1",disabled=true}})',env=env)
            time.sleep(.5)
        else:
            config = work / 'sway.conf'
            config.write_text(f'xwayland disable\nswaybg_command -\noutput HEADLESS-1 mode {round(1920*scale)}x{round(height*scale)} scale {scale}\n')
            sway = subprocess.Popen(['sway', '-c', str(config)], env=env, stdout=(work / 'sway.log').open('w'), stderr=subprocess.STDOUT)
            sock = runtime / f'sway-ipc.{os.getuid()}.{sway.pid}.sock'
            for _ in range(60):
                if sock.exists(): break
                if sway.poll() is not None: raise AssertionError((work / 'sway.log').read_text())
                time.sleep(.1)
            assert sock.exists(), 'Sway did not start'
            env.update(SWAYSOCK=str(sock), I3SOCK=str(sock))
            # Obtain the actual socket chosen by this compositor.
            run('swaymsg', 'exec', f'echo $WAYLAND_DISPLAY > {work}/wayland', env=env)
            for _ in range(60):
                if (work / 'wayland').exists(): break
                time.sleep(.1)
            env.update(WAYLAND_DISPLAY=(work / 'wayland').read_text().strip(), QT_QPA_PLATFORM='wayland')
        shell = subprocess.Popen(['dbus-run-session', '--', 'qs', '-p', str(root)], env=env,
                                 stdout=(work / 'qs.log').open('w'), stderr=subprocess.STDOUT, start_new_session=True)
        time.sleep(4)
        pid = run('pgrep', '-P', str(shell.pid), 'qs')
        def ipc(method,*args):
            return run('qs','ipc','--pid',pid,'call','notification-test',method,*map(str,args),env=env)
        def state():
            time.sleep(.12)
            return json.loads(ipc('state'))
        ipc('open'); ipc('fill',1); short=state()
        assert short['height'] < short['max'] and not short['scrollbar'],short
        for media in ('true','false'):
            ipc('media',media)
            for quiet in ('true','false'):
                ipc('quiet',quiet); ipc('fill',100); s=state()
                assert abs(s['height']-s['max'])<1 and s['listHeight']>100 and s['scrollbar'],s
                assert s['outerY']==0,s
                ipc('wheel'); t=state(); assert t['y']>0 and t['controlsY']==s['controlsY'],t
                ipc('end'); ipc('remove'); t=state(); assert t['y']<=t['content']-t['listHeight']+1,t
        before=state(); ipc('expand'); expanded=state(); assert expanded['content']>before['content'],expanded
        ipc('close'); ipc('open'); assert state()['y']==0
        ipc('drag'); assert state()['y']>0,state()
        ipc('fill',101); s=state(); assert s['count']==100 and s['first']=='Message 1',s
        ipc('tab'); assert state()['focus']
        if shots:
            shots.mkdir(parents=True,exist_ok=True)
            ipc('shot',str(shots/f'notifications-{compositor}-{scale}.png'));time.sleep(.4)
        # PersistentProperties retain the history through a real reload.
        qml=root/'shell.qml'
        text=qml.read_text().replace('import QtTest','').replace('TestCase { id: events; parent: panel.frameItem; when: false }','')
        # QtTest cannot instantiate its singleton across a Quickshell reload.
        text=text[:text.index('        function wheel()')] + text[text.index('        function shot('):]
        qml.write_text(text+'\n// reload\n');time.sleep(2)
        assert state()['count']==100,state()
        ipc('preview'); ipc('close'); assert not state()['seen'],state()
        ipc('open'); ipc('close'); assert state()['seen'],state()
        ipc('open'); ipc('end'); ipc('clear'); s=state()
        assert s['count']==0 and s['y']==0 and not s['scrollbar'] and s['height']<s['max'],s
        log=(work/'qs.log').read_text()
        assert not re.search(r'WARN scene:|ERROR|TypeError|ReferenceError|Failed to load',log),log
        print(f'PASS {compositor} scale {scale}: adaptive height, fixed controls, wheel/drag, deletion, 100-entry cap, reload, preview/seen, keyboard, clear')
    finally:
        if shell:
            os.killpg(shell.pid,signal.SIGTERM);shell.wait(timeout=5)
        if sway:
            sway.terminate();sway.wait(timeout=5)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--compositor',choices=['sway','hyprland'],default='sway')
    p.add_argument('--scale',type=float,default=1)
    p.add_argument('--shots',type=Path)
    p.add_argument('--height',type=int,default=1200)
    args=p.parse_args()
    with tempfile.TemporaryDirectory(prefix='qsn-',dir='/tmp') as tmp:
        try: test(Path(tmp),args.compositor,args.scale,args.shots,args.height)
        except Exception:
            for name in ('qs.log','sway.log'):
                log=Path(tmp)/name
                if log.exists(): print(log.read_text()[-15000:])
            raise
