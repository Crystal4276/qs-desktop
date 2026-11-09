#!/usr/bin/env python3
"""Real battery logic with a simulated device and a recording notify-send; no hardware changes."""
from pathlib import Path
import os,subprocess,tempfile,json,time,signal,shutil
REPO = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='qs-battery-') as temp:
 r=Path(temp)
 for d in ('services','config','modules/bar','bin','runtime'): (r/d).mkdir(parents=True,exist_ok=True)
 s=(REPO / 'services/Battery.qml').read_text().replace('readonly property UPowerDevice device:', 'readonly property var device:').replace('UPower.devices.values','root.testDevices').replace('UPower.displayDevice','root.testDevice').replace('    id: root','''    id: root
    property var testDevices: [testDevice]
    property QtObject testDevice: QtObject {
        property bool isLaptopBattery: true
        property real percentage: .8
        property int state: UPowerDeviceState.Discharging
    }''')
 (r/'services/Battery.qml').write_text(s)
 shutil.copy2(REPO / 'config/Theme.qml',r/'config/Theme.qml');shutil.copy2(REPO / 'modules/bar/BatteryModule.qml',r/'modules/bar/BatteryModule.qml');(r/'assets').symlink_to(REPO / 'assets')
 (r/'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.services
import qs.modules.bar
ShellRoot {
 BatteryModule { id: module }
 IpcHandler {
  target: "test"
  function set(percent: int, charge: bool): void { Battery.testDevice.state = charge ? UPowerDeviceState.Charging : UPowerDeviceState.Discharging; Battery.testDevice.percentage = percent / 100; }
  function state(): string { return JSON.stringify({percent: Battery.percent, warning: Battery.warning, alerted: Battery.alerted, color: module.children[0].color.toString()}); }
 }
}''')
 p=r/'bin/notify-send';p.write_text('#!/usr/bin/python3\nimport json,sys\nwith open('+repr(str(r/'notifications'))+',"a") as f: f.write(json.dumps(sys.argv[1:])+"\\n")\n');p.chmod(0o755)
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=str(r/'runtime'), XDG_STATE_HOME=str(r/'state'),XDG_CACHE_HOME=str(r/'cache'),PATH=str(r/'bin')+':'+os.environ['PATH'])
 env.pop('WAYLAND_DISPLAY', None)
 q=subprocess.Popen(['dbus-run-session','--','qs','-p',str(r)],env=env,stdout=(r/'log').open('w'),stderr=subprocess.STDOUT,start_new_session=True)
 try:
  time.sleep(1)
  pid=subprocess.check_output(['pgrep','-P',str(q.pid),'qs'],text=True).strip()
  def ipc(f,*args):return subprocess.check_output(['qs','ipc','--pid',pid,'call','test',f,*map(str,args)],env=env,text=True).strip()
  def state():return json.loads(ipc('state'))
  assert state()['color']=='#94e2d5',state()
  for n in (30,29,15,14):ipc('set',n,'false');time.sleep(.15)
  assert state()['color']=='#f38ba8',state()
  notices=[json.loads(x) for x in (r/'notifications').read_text().splitlines()]
  assert len(notices)==2 and '--urgency=normal' in notices[0] and '--urgency=critical' in notices[1],notices
  ipc('set',50,'true');time.sleep(.1);assert state()['alerted']==101,state()
  ipc('set',15,'false');time.sleep(.15)
  assert len((r/'notifications').read_text().splitlines())==3
  print('PASS real Battery logic: teal/red, 30% normal, 15% critical, no duplicates, recharge rearm')
 finally:
  os.killpg(q.pid,signal.SIGTERM);q.wait(timeout=5)
  print((r/'log').read_text())
