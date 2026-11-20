#!/usr/bin/env python3
"""Real Audio service + private PipeWire/WirePlumber; never use session audio."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]

def test():
    with tempfile.TemporaryDirectory(prefix='qs-audio-test-') as tmp:
        w = Path(tmp)
        for d in ('r', 'config/wireplumber/wireplumber.conf.d', 'shell/services', 'shell/config', 'bin'):
            (w/d).mkdir(parents=True, exist_ok=True)
        (w/'r').chmod(0o700)
        (w/'config/wireplumber/wireplumber.conf.d/90-test.conf').write_text('''wireplumber.profiles = { main = {
          monitor.alsa = disabled
          monitor.bluez = disabled
          monitor.bluez-midi = disabled
          monitor.v4l2 = disabled
          monitor.libcamera = disabled
        } }\n''')
        shutil.copy2(REPO/'services/Audio.qml', w/'shell/services/Audio.qml')
        (w/'shell/services/Notifs.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool doNotDisturb: false; property bool loaded: true }')
        (w/'shell/services/Launch.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { function exec(args) {} }')
        (w/'shell/config/Settings.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var doNotDisturb: ({muteApps: []}) }')
        (w/'bin/notify-send').write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$AUDIO_TEST_NOTIFICATIONS"\n')
        (w/'bin/notify-send').chmod(0o755)
        (w/'shell/shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
ShellRoot {
 IpcHandler { target: "test"
  function state(): string { return JSON.stringify({sink: Audio.sink?.name, pending: Audio.requestedSink?.name, sinks: Audio.sinks.map(n=>({name:n.name,id:n.id,volume:n.audio.volume})), streams: Audio.streams.map(n=>({id:n.id,name:n.name})), source: Audio.source?.id}); }
  function select(name: string): void { Audio.setDefaultSink(Audio.sinks.find(n=>n.name===name)); }
  function burst(): void { Audio.cycleSink(); Audio.cycleSink(); Audio.cycleSink(); }
 }
}''')
        env = dict(os.environ, XDG_RUNTIME_DIR=str(w/'r'), PIPEWIRE_RUNTIME_DIR=str(w/'r'),
                   XDG_CONFIG_HOME=str(w/'config'), XDG_STATE_HOME=str(w/'state'), XDG_CACHE_HOME=str(w/'cache'),
                   QT_QPA_PLATFORM='offscreen', QS_TEST='1', GIO_USE_VFS='local', GVFS_DISABLE_FUSE='1',
                   PATH=str(w/'bin')+':'+os.environ['PATH'], AUDIO_TEST_NOTIFICATIONS=str(w/'notifications'))
        for k in ('PIPEWIRE_REMOTE', 'SWAYSOCK', 'I3SOCK', 'HYPRLAND_INSTANCE_SIGNATURE', 'WAYLAND_DISPLAY', 'DISPLAY'):
            env.pop(k, None)
        procs=[]
        def start(args, name):
            with (w/(name+'.log')).open('w') as log:
                p=subprocess.Popen(args, env=env, stdout=log, stderr=log, start_new_session=True)
            procs.append(p)
            return p
        def run(*args):
            return subprocess.check_output(args, env=env, text=True, stderr=subprocess.PIPE, timeout=5).strip()
        def until(fn):
            deadline=time.monotonic()+10
            while time.monotonic()<deadline:
                try:
                    v=fn()
                    if v: return v
                except (subprocess.SubprocessError, ValueError, KeyError): pass
                time.sleep(.05)
            raise AssertionError('Timeout; '+str([(p.name,p.read_text()[-3500:]) for p in w.glob('*.log')]))
        def nodes(): return json.loads(run('pw-dump'))
        def node(name): return next((n for n in nodes() if n.get('info',{}).get('props',{}).get('node.name')==name),None)
        def linked(stream, sink):
            a,b=node(stream),node(sink)
            return a and b and any(n.get('info',{}).get('props',{}).get('link.output.node')==a['id'] and n['info']['props'].get('link.input.node')==b['id'] for n in nodes())
        try:
            start(['pipewire'], 'pipewire')
            until(lambda:(w/'r/pipewire-0').exists())
            start(['wireplumber'], 'wireplumber')
            until(lambda:run('pw-metadata','-l'))
            for name,cls in [('dac','Audio/Sink'),('headphones','Audio/Sink'),('mic','Audio/Source/Virtual')]:
                run('pw-cli','create-node','adapter',f'{{ factory.name=support.null-audio-sink node.name={name} media.class={cls} object.linger=true audio.position=[ FL FR ] }}')
            until(lambda:node('headphones'))
            run('wpctl','set-default',str(node('dac')['id']))
            for name,vol in [('dac','23%'),('headphones','35%')]: run('wpctl','set-volume',str(node(name)['id']),vol)
            start(['qs','-p',str(w/'shell')], 'qs')
            qs=procs[-1]
            def ipc(method,*args): return run('qs','ipc','--pid',str(qs.pid),'call','test',method,*args)
            def cycle(): return run('qs','ipc','--pid',str(qs.pid),'call','audio','cycleSink')
            def state(): return json.loads(ipc('state'))
            until(lambda:state().get('sink')=='dac')
            players=[]
            for name in ('music','browser'):
                players.append(start(['pw-cat','--playback','--raw','--rate','48000','--channels','2','--format','s16','--properties',f'node.name={name}', '/dev/zero'],name))
            until(lambda:linked('music','dac') and linked('browser','dac'))
            for name in ('music','browser'):
                run('pw-metadata','-n','default','--',str(node(name)['id']),'target.object',str(node('dac')['info']['props']['object.serial']),'Spa:Id')
            # Counterexample: changing only the default leaves explicitly pinned apps on DAC.
            run('wpctl','set-default',str(node('headphones')['id']))
            until(lambda:state()['sink']=='headphones')
            assert linked('music','dac'), 'baseline no longer reproduces'
            print('PASS: baseline pinned stream stays on DAC',flush=True)
            ipc('select','headphones')
            until(lambda:linked('music','headphones') and linked('browser','headphones'))
            until(lambda:not state().get('pending'))
            before=state()
            assert before.get('source') is not None, before
            run('wpctl','set-volume',str(node('music')['id']),'41%')
            run('wpctl','set-mute',str(node('browser')['id']),'1')
            assert all(abs(n['volume']-({'dac':.23,'headphones':.35}[n['name']]))<.001 for n in before['sinks']),before
            for name in ('dac','headphones','dac'):
                ipc('select',name)
                until(lambda:linked('music',name) and linked('browser',name))
                until(lambda:not state().get('pending'))
            ipc('burst')
            until(lambda:state()['sink']=='headphones' and not state().get('pending'))
            until(lambda:linked('music','headphones') and linked('browser','headphones'))
            assert state()['source']==before['source']
            for n in state()['sinks']:
                assert abs(n['volume']-({'dac':.23,'headphones':.35}[n['name']]))<.001,state()
            assert abs(float(run('wpctl','get-volume',str(node('music')['id'])).split()[1])-.41)<.005
            assert 'MUTED' in run('wpctl','get-volume',str(node('browser')['id']))
            cycle()
            until(lambda:state()['sink']=='dac' and not state().get('pending'))
            cycle()
            until(lambda:state()['sink']=='headphones' and not state().get('pending'))
            # A suspended application still has to move before it resumes.
            os.kill(players[0].pid,signal.SIGSTOP)
            ipc('select','dac')
            until(lambda:linked('music','dac') and linked('browser','dac'))
            os.kill(players[0].pid,signal.SIGCONT)
            players[1].terminate(); players[1].wait(timeout=3)
            ipc('select','headphones')
            until(lambda:linked('music','headphones') and not state().get('pending'))
            run('pw-cli','destroy',str(node('headphones')['id']))
            until(lambda:state()['sink']=='dac')
            ipc('select','dac')
            until(lambda:linked('music','dac') and not state().get('pending'))
            for p in players:
                if p.poll() is None: p.terminate(); p.wait(timeout=3)
            until(lambda:not state()['streams'])
            ipc('select','dac'); until(lambda:not state().get('pending'))
            assert not (w/'notifications').exists() or 'Error' not in (w/'notifications').read_text(),(w/'notifications').read_text()
            late=start(['pw-cat','--playback','--raw','--rate','48000','--channels','2','--format','s16','--properties','node.name=late','/dev/zero'],'late')
            until(lambda:linked('late','dac'))
            # A failed helper reports failure without a hung switch or a success notification.
            (w/'bin/pw-metadata').write_text('#!/bin/sh\nexit 1\n')
            (w/'bin/pw-metadata').chmod(0o755)
            ipc('select','dac')
            until(lambda:not state().get('pending') and (w/'notifications').exists() and 'Audio Switch Error' in (w/'notifications').read_text())
            (w/'bin/pw-metadata').unlink()
            late.terminate(); late.wait(timeout=3)
            run('pw-cli','destroy',str(node('dac')['id']))
            until(lambda:not state()['sinks'])
            cycle()
            until(lambda:'No sinks found!' in (w/'notifications').read_text())
            log=(w/'qs.log').read_text()
            assert not any(t in log for t in ('ReferenceError','TypeError','Error:','Unable to assign')),log
            print('PASS: two apps, both directions, retained volumes, rapid keys, paused/closed apps, removed sink, no streams, microphone unchanged, per-app volume/mute preserved, real shortcut IPC, command failure, no sinks',flush=True)
        finally:
            for p in reversed(procs):
                if p.poll() is None:
                    os.killpg(p.pid,signal.SIGCONT)
                    os.killpg(p.pid,signal.SIGTERM)
                    try:p.wait(timeout=3)
                    except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()

if __name__=='__main__': test()
