#!/usr/bin/env python3
"""Exercise real Bluez profile logic with fake devices and recording commands on a private bus."""
import argparse,json,os,shutil,signal,subprocess,tempfile,time
from pathlib import Path
REPO=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--expect-bugs',action='store_true');parser.add_argument('--expect-stale',action='store_true');args=parser.parse_args()
with tempfile.TemporaryDirectory(prefix='qs-bt-profiles-') as tmp:
 w=Path(tmp)
 for d in ('shell/services','bin','runtime'): (w/d).mkdir(parents=True)
 (w/'runtime').chmod(0o700)
 s=(REPO/'services/Bluez.qml').read_text().replace(': BluetoothDevice', ': var').replace('property BluetoothDevice ', 'property var ')
 s=s.replace('readonly property var devices: Bluetooth.devices.values', 'property var devices: []')
 (w/'shell/services/Bluez.qml').write_text(s)
 (w/'shell/services/Battery.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property int warningLevel: 30; property int rearmMargin: 10; function levelOf(p) { return 101; } }')
 (w/'shell/services/Notifs.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var defaultTimeouts: [1000,1000,1000] }')
 (w/'state').write_text('1');(w/'mode').write_text('ok')
 (w/'bin/pw-dump').write_text('''#!/usr/bin/python3
import json,os,time
from pathlib import Path
w=Path(os.environ['BT_TEST_WORK'])
active=int((w/'state').read_text())
if (w/'mode').read_text()=='slow-read':
 (w/'reading').touch();time.sleep(.4)
if (w/'mode').read_text()=='bad-json': print('{');raise SystemExit()
print(json.dumps([{'id':50,'type':'PipeWire:Interface:Device','info':{'params':{'EnumProfile':[{'index':i,'name':n,'description':d,'available':a} for i,n,d,a in [(0,'off','Off','yes'),(1,'a2dp-sink','High Fidelity Playback (A2DP Sink, codec AAC)','yes'),(2,'headset-head-unit','Headset Head Unit (HSP/HFP, codec MSBC)','yes'),(3,'absent','Unavailable','no')]],'Profile':[{'index':active}]}}}]))
''')
 (w/'bin/wpctl').write_text('''#!/usr/bin/python3
import json,os,sys,time
from pathlib import Path
w=Path(os.environ['BT_TEST_WORK']);index=int(sys.argv[-1])
with (w/'calls').open('a') as f:f.write(str(index)+'\\n')
if (w/'mode').read_text()=='fail':print('Refused by device',file=sys.stderr);raise SystemExit(1)
time.sleep(.4 if index==1 else .03)
(w/'state').write_text(str(index))
''')
 for name in ('pw-dump','wpctl'): (w/'bin'/name).chmod(0o755)
 (w/'shell/shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.services
ShellRoot {
 QtObject { id: device
  property string address: "00:11:22:33:44:55"
  property string name: "Test headset"
  property bool connected: true
  property bool paired: true
  property bool batteryAvailable: false
  property real battery: 0
  property int state: BluetoothDeviceState.Connected
  property string icon: "audio-headphones"
 }
 Component.onCompleted: Bluez.devices = [device]
 IpcHandler { target: "test"
  function read(): void { Bluez.readAudioCard(device); }
  function select(n: int): void { Bluez.setAudioProfile(device,n); }
  function burst(): void { Bluez.setAudioProfile(device,1); Bluez.setAudioProfile(device,2); }
  function disconnect(): void { device.connected=false; }
  function reconnect(): void { device.connected=true; }
  function state(): string { return JSON.stringify({card:Bluez.audioCards[device.address] ?? null,busy:Bluez.profileChanges?.[device.address] ?? false,error:Bluez.profileErrors?.[device.address] ?? ""}); }
 }
}''')
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QS_TEST='1',XDG_RUNTIME_DIR=str(w/'runtime'),XDG_STATE_HOME=str(w/'local'),XDG_CACHE_HOME=str(w/'cache'),BT_TEST_WORK=str(w),PATH=str(w/'bin')+':'+os.environ['PATH'],GIO_USE_VFS='local',GVFS_DISABLE_FUSE='1')
 env.pop('WAYLAND_DISPLAY',None)
 # Caller supplies a private bus, used for both native Bluetooth and notifications.
 env['DBUS_SYSTEM_BUS_ADDRESS']=env['DBUS_SESSION_BUS_ADDRESS']
 log=(w/'log').open('w');p=subprocess.Popen(['qs','-p',str(w/'shell')],env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
 def ipc(f,*a):return subprocess.check_output(['qs','ipc','--pid',str(p.pid),'call','test',f,*map(str,a)],env=env,text=True,stderr=subprocess.PIPE).strip()
 def state():return json.loads(ipc('state'))
 def wait(fn):
  for _ in range(100):
   try:
    v=fn()
    if v:return v
   except (subprocess.SubprocessError,ValueError):pass
   time.sleep(.03)
  raise AssertionError((w/'log').read_text())
 try:
  wait(lambda: ipc('read') or True);s=wait(lambda: state()['card']);assert len(s['profiles'])==2,s
  ipc('burst');time.sleep(.15);running=state();time.sleep(.5);s=state();calls=(w/'calls').read_text().splitlines()
  if args.expect_bugs:
   assert calls==['1','2'] and s['card']['active']==1 and not running['busy'],(calls,s,running)
   print('REPRO concurrent profile commands: both run, slow first request overwrites second; no busy state')
  else:
   assert calls==['1'] and running['busy'] and s['card']['active']==1 and not s['busy'],(calls,s,running)
   ipc('select',2);wait(lambda: state()['card']['active']==2 and not state()['busy'])
  (w/'mode').write_text('fail');ipc('select',1);time.sleep(.2);s=state()
  if args.expect_bugs:
   assert not s['error'],s;print('REPRO failed profile change: no error exposed to UI')
  else:
   assert s['error'] and not s['busy'],s
   (w/'mode').write_text('ok');ipc('select',1);wait(lambda: not state()['busy'] and not state()['error'])
   ipc('disconnect');time.sleep(.1);assert state()['card'] is None,state()
   ipc('select',2);time.sleep(.1);assert not state()['busy'],state()
   ipc('reconnect');ipc('read');wait(lambda: state()['card'])
   # An invalid interpreter forces FailedToStart without falling back to the session wpctl.
   (w/'bin/wpctl').write_text('#!/nonexistent-test-interpreter\n')
   ipc('select',2);wait(lambda: state()['error'] and not state()['busy'])
   (w/'mode').write_text('bad-json');ipc('read');wait(lambda: state()['card'] is None)
   (w/'mode').write_text('slow-read');ipc('read');wait(lambda: (w/'reading').exists())
   ipc('disconnect');ipc('reconnect');time.sleep(.6)
   if args.expect_stale:
    assert state()['card'] is not None,state();print('REPRO stale profile read repopulates card after disconnect/reconnect')
   else:
    assert state()['card'] is None,state()
   print('PASS profiles: filtering, serialized selection, confirmed active state, failure/retry, disconnected guard, malformed response')
 finally:
  os.killpg(p.pid,signal.SIGTERM);p.wait(timeout=5);log.close()
  content=(w/'log').read_text()
  if 'TypeError' in content or 'ReferenceError' in content or 'Unable to assign' in content:raise AssertionError(content)
