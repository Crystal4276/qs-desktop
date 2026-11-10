#!/usr/bin/env python3
"""Exercise Core Lab selection with the real service and picker on isolated Sway.
No real session or VPN actions.
Requires the existing Sway/Quickshell bench dependencies (DEVELOPMENT.md).
"""
import argparse
import json
import os
import re
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.check_output(args, text=True, timeout=40, **kwargs).strip()


def test(work, compositor="sway", scale=1):
    root = work / 'shell'
    shutil.copytree(REPO, root, ignore=shutil.ignore_patterns('.git', '.shots', '.agents', '.codex', '__pycache__'))
    wallpapers = work / 'wallpapers'
    import struct, zlib
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', 1, 1, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(b'\0\x94\xe2\xd5')) + chunk(b'IEND', b'')
    # Full-size images exercise decoding and thumbnail writes, unlike the old 1-pixel fixtures.
    large = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B',1920,1200,8,2,0,0,0))
    large += chunk(b'IDAT',zlib.compress((b'\0'+b'\x94\xe2\xd5'*1920)*1200)) + chunk(b'IEND',b'')
    for design in range(9):
        for size in ('1280x800', '1920x1200', '2560x1440', '3840x2160', '3440x1440'):
            p = wallpapers / f'corelab/design{design}/design{design}_{size}.png'
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(large if size == '1920x1200' else png)
    p = wallpapers / 'simple/old.png'
    p.parent.mkdir(); p.write_bytes(png)
    host = root / 'hosts' / f'{Path("/proc/sys/kernel/hostname").read_text().strip()}.json'
    def profile(value):
        host.write_text(json.dumps(dict(profile=value, wallpapersDir=str(wallpapers),
                                       wallpaper=dict(kind='simple', path='simple/old.png'), idle=dict(timeout=0))))
    profile('travail')
    service = root/'services/Wallpapers.qml'
    text = service.read_text().replace('Qt.md5(', 'countedHash(')
    text=text.replace('    id: root','    id: root\n    signal thumbStarted()',1).replace('        thumbJobs.set(name, job);','        thumbJobs.set(name, job); thumbStarted();')
    text = text.replace('    id: root', '''    id: root
    readonly property var perf: ({hashCalls:0,scans:0})
    function countedHash(value: string): string { perf.hashCalls++; return Qt.md5(value); }
''', 1)
    text = text.replace('            onStreamFinished: {', '            onStreamFinished: { root.perf.scans++;')
    service.write_text(text)
    picker_source=root/'modules/wallpaper/PickerWindow.qml'
    t=picker_source.read_text().replace('    id: root','    id: root\n    readonly property var lifecycle: ({created:0,destroyed:0})',1)
    t=t.replace('                id: cell','                id: cell\n                Component.onCompleted: root.lifecycle.created++\n                Component.onDestruction: root.lifecycle.destroyed++')
    picker_source.write_text(t)
    probe = root / 'shell.qml'
    qml = probe.read_text().replace('import Quickshell\n', 'import QtQuick\nimport Quickshell\nimport Quickshell.Io\n')
    qml = qml[:qml.rfind('}')] + '''
    PickerWindow { id: picker }
    property var pending: null
    property bool closeNext: false
    property int libraryChanges: 0
    property int stampChanges: 0
    Connections { target: Wallpapers
        function onThumbStarted() { if(closeNext) { closeNext=false; Qt.callLater(()=>picker.close()); } }
        function onLibraryChanged() { libraryChanges++; }
        function onStampsChanged() { stampChanges++; }
    }
    IpcHandler {
        target: "corelab-test"
        function open(): void { picker.open(null); picker.tab = "corelab"; }
        function close(): void { picker.close(); }
        function cacheStats(): string { return JSON.stringify({hashes:Wallpapers.perf.hashCalls,scans:Wallpapers.perf.scans,
            visible:picker.visible,pending:Wallpapers.thumbJobs.size,created:picker.lifecycle.created,destroyed:picker.lifecycle.destroyed,libraryChanges:libraryChanges,stampChanges:stampChanges, thumbs:Wallpapers.thumbs}); }
        function name(): string { return Wallpapers.thumbName("simple/old.png",Qt.size(240,135)); }
        function reserve(): string {
            const job=Wallpapers.beginThumb("simple/old.png",Qt.size(241,136));
            if (job) pending=job;
            return job?.file ?? "";
        }
        function closeOnSave(): void { closeNext=true; }
        function tokens(): bool {
            const a=Wallpapers.beginThumb("simple/old.png",Qt.size(242,137));
            Wallpapers.cancelThumb(a);
            const b=Wallpapers.beginThumb("simple/old.png",Qt.size(242,137));
            Wallpapers.finishThumb(a,true);
            const ok=Wallpapers.currentThumb(b);
            Wallpapers.cancelThumb(b);
            return ok;
        }
        function cancel(): void { Wallpapers.cancelThumb(pending); }
        function tab(value: string): void { picker.tab=value; }
        function gridState(): string { return JSON.stringify({index:picker.grid?.currentIndex,y:picker.grid?.contentY}); }
        function reloadGrid(): void { picker.visited={}; Qt.callLater(()=>picker.visit()); }
        function imageStates(): string {
            const images=[];
            function collect(item) {
                if(typeof item.path === "string" && item.status !== undefined) images.push({path:item.path,status:item.status});
                for(const child of item.children ?? []) collect(child);
            }
            if(picker.grid) collect(picker.grid);
            return JSON.stringify(images);
        }
        function corrupt(): string { return Wallpapers.thumbSource(picker.items[0].images[0],Qt.size(Math.ceil(240*picker.pixelRatio),Math.ceil(135*picker.pixelRatio))); }
        function finish(file: string): void { Wallpapers.refresh(); Wallpapers.finishThumb(pending,true); }
        function refresh(): void { Wallpapers.refresh(); }
        function choose(index: int): void { picker.apply(index); }
        function own(): void { Wallpapers.setOutput("test", "corelab/design1"); }
        function resolve(w: int, h: int, scale: real): string {
            return JSON.stringify(Wallpapers.forOutput({name:"test", description:"test", width:w, height:h, scale:scale}, Compositor.outputs));
        }
        function state(): string {
            return JSON.stringify({ready:Wallpapers.ready, items:picker.items, tabs:picker.tabs,
                selection:Wallpapers.selection, overrides:Wallpapers.overrides, lib:Wallpapers.library, outputs:Compositor.outputs,
                shown:Compositor.outputs.map(o => Wallpapers.forOutput(o, Compositor.outputs)), keep:Wallpapers.chosenPaths()});
        }
    }
}
'''
    probe.write_text(qml)
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
                    run('hyprctl','dispatch','hl.dsp.window.move({window="address:'+window['address']+'",workspace="special:qs-wallpaper-test",follow=false})',env=parent)
            env.update(HYPRLAND_INSTANCE_SIGNATURE=ipc_sockets[0].parent.name,WAYLAND_DISPLAY=sockets[0].name,QT_QPA_PLATFORM='wayland')
            run('hyprctl','output','create','headless',env=env); time.sleep(.25)
            run('hyprctl','eval',f'hl.monitor({{output="HEADLESS-1",mode="{round(1920*scale)}x{round(1200*scale)}@60",position="0x0",scale={scale}}}); hl.monitor({{output="WAYLAND-1",disabled=true}})',env=env)
            time.sleep(.5)
        else:
            config = work / 'sway.conf'
            config.write_text(f'xwayland disable\nswaybg_command -\noutput HEADLESS-1 mode {round(1920*scale)}x{round(1200*scale)} scale {scale}\n')
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
        def ipc(method, *args):
            return run('qs', 'ipc', '--pid', pid, 'call', 'corelab-test', method, *map(str, args), env=env)
        def state():
            return json.loads(ipc('state'))
        def wait_for(predicate):
            for _ in range(60):
                v = state()
                if predicate(v): return v
                time.sleep(.1)
            raise AssertionError(v)
        wait_for(lambda v: v['ready'] and len(v['lib']['corelab']) == 9)
        assert all(o['name']=='HEADLESS-1' and o['width']==1920 and o['height']==1200 for o in state()['outputs']), state()
        ipc('open')
        v = wait_for(lambda v: len(v['items']) == 9)
        assert all(i['images'][0].endswith('_1920x1200.png') for i in v['items']), v
        assert v['selection']['path'] == 'simple/old.png', v
        # Once disk thumbnails are known, unchanged scans must publish nothing and hash nothing.
        time.sleep(.8)
        ipc('refresh'); time.sleep(.4)
        def stats(): return json.loads(ipc('cacheStats'))
        before=stats()
        for _ in range(3):
            ipc('refresh')
            deadline=time.monotonic()+10
            while stats()['scans'] <= before['scans'] and time.monotonic()<deadline: time.sleep(.02)
            after=stats()
            assert after['hashes']==before['hashes'], (before,after)
            assert after['libraryChanges']==before['libraryChanges'], (before,after)
            assert after['stampChanges']==before['stampChanges'], (before,after)
            before=after
        # Modifying one file only computes its new digest; other keys stay cached.
        # Visited grids keep their delegates/decoded pixels. Same grid object on return.
        # The active grid index and scrolling are local to each tab.
        ipc('tab','simple'); time.sleep(.3)
        ipc('tab','corelab'); time.sleep(.3)
        before_tabs=stats()
        for _ in range(10):
            ipc('tab','simple'); ipc('tab','corelab')
        assert stats()['hashes']==before_tabs['hashes']
        assert stats()['created']==before_tabs['created'], (before_tabs,stats())
        assert stats()['destroyed']==before_tabs['destroyed'], (before_tabs,stats())
        old_name=ipc('name')
        os.utime(wallpapers/'simple/old.png',ns=(1900000000000000000,1900000000000000000))
        ipc('refresh'); time.sleep(.4)
        assert ipc('name')!=old_name
        assert stats()['hashes']-before['hashes']==1, (before,stats())
        assert ipc('tokens')=='true', 'stale callback released a newer reservation'
        pending=ipc('reserve'); assert pending
        ipc('cancel'); assert ipc('reserve') == pending, 'canceled reservation did not become writable'

        ipc('refresh'); time.sleep(.3)
        assert ipc('reserve') == "", 'scan lost a pending thumbnail write'
        Path(pending).write_bytes(png)
        ipc('finish',pending); time.sleep(.3)
        assert Path(pending).name in stats()['thumbs'], 'completed write lost during scan'
        Path(pending).unlink(); ipc('refresh'); time.sleep(.3)
        assert ipc('reserve') == pending, 'deleted thumbnail did not become writable again'
        Path(pending).write_bytes(png); ipc('finish',pending); time.sleep(.3)
        shutil.rmtree(Path(pending).parent); ipc('refresh'); time.sleep(.4)
        assert ipc('reserve') == pending, 'cleared disk cache was not rebuilt'
        Path(pending).write_bytes(png); ipc('finish',pending); time.sleep(.3)
        ipc('closeOnSave')
        shutil.rmtree(Path(pending).parent); ipc('refresh'); time.sleep(.6)
        assert not stats()['visible'] and stats()['pending']==0, stats()
        ipc('open'); time.sleep(.8)
        assert stats()['pending']==0, stats()
        # Main thumbnail PNGs use the requested physical size, including fractional scale.
        import math
        target=(math.ceil(240*scale),math.ceil(135*scale))
        generated=list(Path(pending).parent.glob(f'*-{target[0]}x{target[1]}.png'))
        assert generated, target
        for image in generated:
            size=struct.unpack('!II',image.read_bytes()[16:24])
            assert all(abs(a-b)<=1 for a,b in zip(size,target)), (image,size,target)
        from urllib.parse import urlparse,unquote
        cached=Path(unquote(urlparse(ipc('corrupt')).path))
        cached.write_bytes(b'corrupt PNG')
        ipc('reloadGrid')
        deadline=time.monotonic()+10
        while time.monotonic()<deadline:
            images=json.loads(ipc('imageStates'))
            if images and all(i['status']==1 for i in images) and cached.exists() and cached.read_bytes().startswith(b'\x89PNG'):
                break
            time.sleep(.1)
        else: raise AssertionError(('cache recovery',images))
        new=wallpapers/'simple/new.png'; new.write_bytes(png)
        ipc('refresh'); wait_for(lambda v: 'simple/new.png' in v['lib']['simple'])
        new.unlink(); ipc('refresh'); wait_for(lambda v: 'simple/new.png' not in v['lib']['simple'])
        # A different library root must be indexed, then the original must resolve again.
        other=work/'other'; shutil.copytree(wallpapers,other)
        config=json.loads(host.read_text()); config['wallpapersDir']=str(other); host.write_text(json.dumps(config))
        deadline=time.monotonic()+10
        while str(other) not in ipc('resolve',1920,1200,1) and time.monotonic()<deadline: time.sleep(.1)
        assert str(other) in ipc('resolve',1920,1200,1)
        profile('travail'); time.sleep(.5)
        ipc('choose', 0)
        assert state()['selection'] == dict(kind='corelab', path='corelab/design0')
        def resolve(w, h, scale=1): return json.loads(ipc('resolve', w, h, scale))['path']
        assert resolve(1920,1200).endswith('_1920x1200.png')
        assert resolve(2560,1440,1.5).endswith('_3840x2160.png')
        assert resolve(1707,960,1.5).endswith('_2560x1440.png')
        assert resolve(3440,1440).endswith('_3440x1440.png')
        assert resolve(1600,1000).endswith('_1920x1200.png')
        assert resolve(8000,5000).endswith('_1920x1200.png')
        ipc('own')
        assert 'design1_' in resolve(1920,1200)
        assert any('design1_' in p for p in state()['keep'])
        time.sleep(.5)
        os.killpg(shell.pid, signal.SIGTERM); shell.wait(timeout=5)
        shell = subprocess.Popen(['dbus-run-session', '--', 'qs', '-p', str(root)], env=env,
                                 stdout=(work / 'qs.log').open('a'), stderr=subprocess.STDOUT, start_new_session=True)
        time.sleep(3); pid = run('pgrep', '-P', str(shell.pid), 'qs')
        assert 'design1_' in resolve(1920,1200)
        assert state()['selection']['path'] == 'corelab/design0'
        profile('jeux')
        wait_for(lambda v: not v['lib']['corelab'] and all(t['key'] != 'corelab' for t in v['tabs']))
        assert resolve(1920,1200) == 'simple/old.png'
        assert state()['selection']['path'] == 'corelab/design0'
        profile('travail')
        wait_for(lambda v: len(v['lib']['corelab']) == 9)
        assert 'design1_' in resolve(1920,1200)
        # Missing preferred variant selects another resolution from the same design.
        ipc('close'); time.sleep(.3)
        (wallpapers/'corelab/design1/design1_1920x1200.png').unlink()
        ipc('refresh'); time.sleep(.4)
        assert resolve(1920,1200).endswith('_1280x800.png')
        run('qs', 'ipc', '--pid', pid, 'call', 'wallpaper', 'set', 'simple', 'simple/old.png', env=env)
        ipc('own'); time.sleep(.3)
        shutil.rmtree(wallpapers/'corelab')
        ipc('refresh'); wait_for(lambda v: not v['lib']['corelab'])
        assert resolve(1920,1200) == 'simple/old.png'
        log = (work/'qs.log').read_text()
        unexpected='\n'.join(line for line in log.splitlines() if 'WARN scene:' in line and not ('Cannot open:' in line or 'Error decoding:' in line))
        assert not unexpected and not re.search(r'^\s*ERROR(?! quickshell.service.pipewire.loop:)\b', log, re.MULTILINE), log
        print(f'PASS Core Lab ({compositor}): selection, resolutions, stable cache/model, invalidation, concurrent writes, directory, persistence, profiles')
    finally:
        if shell:
            try: os.killpg(shell.pid, signal.SIGTERM)
            except ProcessLookupError: pass
            shell.wait(timeout=5)
        if sway:
            sway.terminate(); sway.wait(timeout=5)


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--compositor',choices=['sway','hyprland'],default='sway')
    parser.add_argument('--scale',type=float,default=1)
    args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='qw-') as temporary:
        try:
            test(Path(temporary),args.compositor,args.scale)
        except Exception:
            for name in ('sway.log', 'qs.log'):
                p = Path(temporary)/name
                if p.exists(): print(p.read_text())
            raise
