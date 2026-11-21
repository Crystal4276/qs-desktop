#!/usr/bin/env python3
"""Charging policy and real card on an isolated Wayland bench. Never writes real hardware."""
import argparse
import importlib
import importlib.util
import sys
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tempfile
import time
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, timeout=15, **kwargs).strip()


def until(check, timeout=12):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            value = check()
            if value:
                return value
        except (subprocess.SubprocessError, ValueError):
            pass
        time.sleep(.05)
    raise AssertionError("Charging bench did not settle")


def setup_test(work):
    root = work / "staging"
    device = root / "sys/class/power_supply/BAT0"
    device.mkdir(parents=True)
    (device / "type").write_text("Battery")
    (device / "charge_control_start_threshold").write_text("50")
    (device / "charge_control_end_threshold").write_text("90")
    (device / "charge_types").write_text("Trickle Fast Standard [Adaptive] Custom")
    command = ["python3", str(REPO / "scripts/battery-setup.py"), "--root", str(root)]
    before = sorted(str(p.relative_to(root)) for p in root.rglob("*"))
    run(*command, "--dry-run", "install")
    assert sorted(str(p.relative_to(root)) for p in root.rglob("*")) == before
    run(*command, "install")
    assert (device / "charge_control_end_threshold").read_text() == "80"
    assert "[Adaptive]" in (device / "charge_types").read_text()  # setup does not silently select a mode
    (device / "charge_control_end_threshold").write_text("100")
    (device / "charge_types").write_text("Trickle Fast [Standard] Adaptive Custom")
    run(*command, "install")
    assert (device / "charge_control_end_threshold").read_text() == "100", "reinstall cancelled a departure"
    run(*command, "uninstall")
    assert (device / "charge_control_end_threshold").read_text() == "90"
    assert (device / "charge_types").read_text() == "Adaptive"
    assert not (root / "etc/udev/hwdb.d/61-qs-desktop-battery.hwdb").exists()
    run(*command, "uninstall")
    empty = work / "empty"
    run("python3", str(REPO / "scripts/battery-setup.py"), "--root", str(empty), "install")
    assert not empty.exists()
    setup_spec = importlib.util.spec_from_file_location("battery_setup", REPO / "scripts/battery-setup.py")
    setup = importlib.util.module_from_spec(setup_spec)
    setup_spec.loader.exec_module(setup)
    import sys
    for failure_index in (1, 2):
        trial = work / f"backup-failure-{failure_index}"
        shutil.copytree(root, trial)
        (trial / "sys/class/power_supply/BAT0/charge_types").write_text("Standard [Adaptive] Custom")
        originals = setup.ORIGINALS
        for name in originals:
            target = trial / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("original content")
        copy = shutil.copy2
        calls = []
        def fail_copy(src, dst):
            calls.append(src)
            if len(calls) == failure_index:
                raise OSError("Injected backup failure")
            return copy(src, dst)
        with patch.object(sys, "argv", ["battery-setup.py", "--root", str(trial), "install"]), patch.object(setup.shutil, "copy2", side_effect=fail_copy):
            try:
                setup.main()
                raise AssertionError("backup failure ignored")
            except OSError:
                pass
        assert not (trial / "var/lib/qs-desktop/battery-setup").exists()
        run("python3", str(REPO / "scripts/battery-setup.py"), "--root", str(trial), "uninstall")
        assert all((trial / name).read_text() == "original content" for name in originals)
    # Missing backups in a new manifest must fail before any file or hardware change.
    trial = work / "missing-backup"
    shutil.copytree(root, trial)
    (trial / "sys/class/power_supply/BAT0/charge_types").write_text("Standard [Adaptive] Custom")
    original = trial / setup.ORIGINALS[0]
    original.parent.mkdir(parents=True, exist_ok=True)
    original.write_text("keep this preset")
    command = ["python3", str(REPO / "scripts/battery-setup.py"), "--root", str(trial)]
    run(*command, "install")
    installed = original.read_text()
    state_dir = trial / "var/lib/qs-desktop/battery-setup"
    (state_dir / setup.ORIGINALS[0].replace("/", "_")).unlink()
    with patch.object(sys, "argv", ["battery-setup.py", "--root", str(trial), "uninstall"]):
        try:
            setup.main()
            raise AssertionError("missing backup accepted")
        except RuntimeError as error:
            assert "Incomplete battery backup" in str(error)
    assert original.read_text() == installed
    assert (trial / "sys/class/power_supply/BAT0/charge_control_end_threshold").read_text() == "80"
    # A partial old backup is refused before touching originals; completed legacy state remains supported.
    trial = work / "legacy"
    shutil.copytree(root, trial)
    state_dir = trial / "var/lib/qs-desktop/battery-setup"
    state_dir.mkdir(parents=True)
    (state_dir / "original.json").write_text("[]")
    original = trial / setup.ORIGINALS[0]
    original.parent.mkdir(parents=True, exist_ok=True)
    original.write_text("keep me")
    with patch.object(sys, "argv", ["battery-setup.py", "--root", str(trial), "uninstall"]):
        try:
            setup.main()
            raise AssertionError("incomplete legacy state accepted")
        except RuntimeError as error:
            assert "Incomplete legacy" in str(error)
    assert original.read_text() == "keep me"
    (state_dir / "ready").touch()
    copy(original, state_dir / setup.ORIGINALS[0].replace("/", "_"))
    run("python3", str(REPO / "scripts/battery-setup.py"), "--root", str(trial), "uninstall")
    assert original.read_text() == "keep me"
    # Real installer selection, fake battery detection and a recording system-step runner.
    prefix = (REPO / "install.sh").read_text().split('\nif [[ -n "$uninstall" ]]; then\n', 1)[0]
    for battery in ("0", "1"):
        command = prefix + '\ncompgen() { [[ "$BATTERY_TEST_PRESENT" == 1 ]]; }\nsub() { printf "%s\\n" "$@"; }\nstep_battery\n'
        result = run("bash", "-c", command, str(REPO / "install.sh"), "--dry-run", "--profil", "travail",
                     env=dict(os.environ, BATTERY_TEST_PRESENT=battery))
        assert ("battery-setup.py" in result) == (battery == "1"), result
        if battery == "1":
            assert "--dry-run" in result and result.endswith("install"), result
    spec = importlib.util.spec_from_file_location("batteryctl", REPO / "scripts/batteryctl.py")
    ctl = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(ctl)
    class VoidReplyBus:
        def call_sync(self, *args):
            return ctl.GLib.Variant("()", ())
    assert ctl.call(VoidReplyBus(), ctl.ROOT, ctl.DEVICE, "EnableChargeThreshold") is None
    initial = {"path": "/org/freedesktop/UPower/devices/battery_BAT0", "configured": True,
               "battery": {"ChargeThresholdSupported": True, "ChargeStartThreshold": 50,
                           "ChargeEndThreshold": 80, "ChargeThresholdEnabled": False},
               "hardware": {"charge_types": "[Adaptive]", "charge_control_start_threshold": "50",
                            "charge_control_end_threshold": "90"}}
    confirmed = json.loads(json.dumps(initial))
    confirmed["battery"]["ChargeThresholdEnabled"] = True
    confirmed["hardware"].update(charge_types="[Custom]", charge_control_end_threshold="80")
    with patch.object(ctl, "snapshot", side_effect=[initial, confirmed]), patch.object(ctl, "call") as call:
        assert ctl.select(None, "preserve") == confirmed
        assert call.call_args.args[-1].unpack() == (True,)
    with patch.object(ctl, "snapshot", return_value=initial), patch.object(ctl, "call"):
        try:
            ctl.select(None, "preserve")
            raise AssertionError("ignored hardware write reported as success")
        except RuntimeError as e:
            assert "confirm" in str(e)
    with patch.object(ctl, "snapshot", return_value=initial), patch.object(ctl, "call", side_effect=RuntimeError("Not authorized")):
        try:
            ctl.select(None, "full")
            raise AssertionError("authorization failure swallowed")
        except RuntimeError as e:
            assert str(e) == "Not authorized"
    print("PASS native client: verified write, ignored-write detection, denied authorization; setup: dry-run, install, idempotence during departure, restore, absent hardware")


FIXTURE = '''pragma Singleton
import QtQuick
import Quickshell.Services.UPower
QtObject {
 property bool available: true
 readonly property int percent: Math.round(Charging.details.Percentage ?? 72)
 readonly property bool charging: Charging.details.State === 1
 readonly property bool warning: percent <= 30
 readonly property var device: ({state: Charging.details.State ?? UPowerDeviceState.Discharging})
}
'''

SHELL = '''import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.bar
import qs.modules.menus
ShellRoot {
 PanelWindow {
  id: bar
  anchors { top: true; left: true; right: true }
  implicitHeight: Theme.bar.exclusiveZone
  exclusiveZone: height
  BatteryModule { id: button; visible: shown; x: 100; width: implicitWidth; height: implicitHeight }
  SettingsButton { id: settingsButton; x: 200; width: implicitWidth; height: implicitHeight }
 }
 Panels {}
 readonly property var panel: BarState.loaders.battery?.item ?? null
 readonly property var settings: BarState.loaders.settings?.item ?? null
 TestCase { id: events; parent: panel?.frameItem ?? bar.contentItem; when: false }
 Item { id: focusProbe; parent: panel?.frameItem ?? null; readonly property bool windowActive: Window.active }
 function texts(item) {
  if (!item || !item.visible) return [];
  let values = typeof item.text === "string" ? [item.text] : [];
  for (let child of item.children ?? []) values = values.concat(texts(child));
  return values;
 }
 function find(item, name) {
  if (!item) return null;
  if (item.objectName === name || item.text === name) return item;
  for (let c of item.children ?? []) { const found = find(c, name); if (found) return found; }
  return null;
 }
 IpcHandler {
  target: "charging-test"
  function open(): void { events.mouseClick(button); }
  function settingsOpen(): void { events.mouseClick(settingsButton); }
  function fromSettings(): void { events.mouseClick(find(settings.frameItem, `${Battery.percent} %`)); }
  function close(): void { panel?.close(); }
  function preview(): void { events.mouseMove(button,button.width/2,button.height/2); }
  function unhover(): void { events.mouseMove(bar.contentItem,400,20); }
  function outside(): void { events.mouseClick(panel.contentItem,panel.width-20,panel.height-20); }
  function refresh(): void { Charging.refresh(); }
  function cycle(): void { TestPower.onBattery = true; TestPower.onBattery = false; }
  function source(onBattery: bool): void { TestPower.onBattery = onBattery; }
  function choose(full: bool): void { Charging.select(full); }
  function absent(value: bool): void { Battery.available = !value; }
  function click(name: string): void { events.mouseClick(find(panel.frameItem,name)); }
  function press(full: bool, enter: bool): void {
   const tile = find(panel.frameItem, full ? "battery-full" : "battery-preserve");
   for(let i=0; i<8 && !tile.activeFocus; i++) events.keyClick(Qt.Key_Tab);
   if (!tile.activeFocus) throw new Error("Tile unreachable by Tab");
   events.keyClick(enter ? Qt.Key_Return : Qt.Key_Space);
  }
  function pressEscape(): void { events.keyClick(Qt.Key_Escape); }
  function shot(path: string): void { panel.frameItem.grabToImage(r => r.saveToFile(path)); }
  function state(): string {
   const f=panel?.frameItem;
   return JSON.stringify({ready:Charging.ready,configured:Charging.configured,busy:Charging.busy,mode:Charging.mode,
    phase:Charging.departure,wanted:Charging.wanted,applied:Charging.applied,onBattery:Charging.onBattery,error:Charging.error,
    barShown:button.visible,loaded:!!panel,active:focusProbe.windowActive,settingsVisible:settings?.visible ?? false,
    visible:panel?.visible ?? false,preview:panel?.previewing ?? false,height:f?.height ?? 0,max:f?.maxHeight ?? 0,width:f?.width ?? 0,
    preserve:find(f,"battery-preserve")?.checked ?? false,full:find(f,"battery-full")?.checked ?? false,
    texts:texts(f),enabled:find(f,"battery-full")?.enabled ?? false});
  }
 }
}
'''

FAKE = '''#!/usr/bin/python3
import json, os, sys, time
from pathlib import Path
w=Path(os.environ["CHARGING_BENCH"])
s=json.loads((w/"controller.json").read_text())
time.sleep(float((w/"delay").read_text()))
command=sys.argv[-1]
if command not in ("status","preserve","full"): raise SystemExit("Unexpected command")
if command != "status":
 with (w/"writes").open("a") as f: f.write(command+"\\n")
 if (w/"fail").read_text()=="1":
  print(json.dumps({"error":"Not authorized"}));sys.exit(1)
 if (w/"ignored").read_text()=="1":
  print(json.dumps({"error":"The battery controller did not confirm the requested charging mode"}));sys.exit(1)
 s["mode"]=command
 s["battery"]["ChargeThresholdEnabled"]=command=="preserve"
 s["hardware"]["charge_control_end_threshold"]="80" if command=="preserve" else "100"
 s["hardware"]["charge_types"]="[Custom]" if command=="preserve" else "[Standard]"
 (w/"controller.json").write_text(json.dumps(s))
if command == "status" and (w/"readfail").read_text()=="1":
 print(json.dumps({"error":"Temporary UPower failure"}));sys.exit(1)
print(json.dumps(s))
'''


def card_test(work, shots, scale, compositor_kind="sway"):
    root = work / "shell"
    shutil.copytree(REPO, root, ignore=shutil.ignore_patterns(".git", ".shots", ".agents", ".codex", ".aws", "__pycache__"))
    (root / "services/Battery.qml").write_text(FIXTURE)
    (root / "services/TestPower.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject { property bool onBattery: false }")
    charging = root / "services/Charging.qml"
    charging.write_text(charging.read_text().replace("target: UPower", "target: TestPower")
                        .replace("UPower.onBattery", "TestPower.onBattery"))
    (root / "services/Session.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject { property bool lockActive: false }")
    (root / "shell.qml").write_text(SHELL)
    audio = (REPO / "scripts/tests/bar/Audio.qml").read_text()
    (root / "services/Audio.qml").write_text(audio.replace("function toggleMute()", 'function outputIcon(node) { return "audio-card"; } function toggleMute()'))
    (root / "services/Session.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject { property bool lockActive: false; property bool keepAwake: false; function screenshot() {} function lock() {} function logout() {} function reboot() {} function poweroff() {} }")
    for name in ("Gammastep", "Hyprsunset"):
        (root / f"services/{name}.qml").write_text("import QtQuick\nItem { required property bool enabled; required property int temperature }")
    for name, props in {
        "Profiles": "property bool available: false; property int profile: 0; property bool hasPerformance: false; function set(v) {}",
        "Rfkill": "property bool available: false; property bool airplane: false; function toggle() {}",
        "Displays": "property var hdrOutputs: []; property var vrrOutputs: []; property bool hdr: false; property bool vrr: false; function toggleHdr() {} function toggleVrr() {}",
        "Brightness": "property bool available: false; property int percent: 50; function step(v) {} function setPercent(v) {}",
        "Compositor": "property string focusedOutput: Quickshell.screens[0]?.name ?? ''; property bool isHyprland: false; property bool isSway: true",
        "Outputs": "property var primary: Quickshell.screens[0] ?? null"
    }.items():
        (root / f"services/{name}.qml").write_text("pragma Singleton\nimport QtQuick\nimport Quickshell\nQtObject {"+props+"}")
    runtime = work / "r"
    runtime.mkdir(mode=0o700)
    bindir = work / "bin"
    bindir.mkdir()
    (bindir / "python3").write_text(FAKE)
    (bindir / "python3").chmod(0o755)
    for key in ("fail", "ignored", "delay", "readfail"):
        (work / key).write_text("0")
    controller = {"path": "/org/freedesktop/UPower/devices/battery_BAT0", "configured": True, "onBattery": False,
                  "mode": "", "battery": {"ChargeThresholdSupported": True, "ChargeThresholdEnabled": False,
                  "ChargeStartThreshold": 50, "ChargeEndThreshold": 80, "Percentage": 100, "State": 4,
                  "Temperature": 27.1, "Capacity": 100.0, "ChargeCycles": 1, "EnergyFull": 53.5,
                  "TimeToEmpty": 16477199, "TimeToFull": 0},
                  "hardware": {"charge_control_start_threshold": "50", "charge_control_end_threshold": "90", "charge_types": "[Adaptive]"}}
    (work / "controller.json").write_text(json.dumps(controller))
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), WLR_BACKENDS="headless", WLR_RENDERER="pixman",
               WLR_LIBINPUT_NO_DEVICES="1", QS_TEST="1", GIO_USE_VFS="local", GVFS_DISABLE_FUSE="1",
               XDG_STATE_HOME=str(work / "state"), XDG_CACHE_HOME=str(work / "cache"), CHARGING_BENCH=str(work),
               PATH=str(bindir) + ":" + os.environ["PATH"])
    for key in ("SWAYSOCK", "I3SOCK", "HYPRLAND_INSTANCE_SIGNATURE", "WAYLAND_DISPLAY", "DISPLAY", "QS_IDLE_SOCKET", "QS_LOCK_STATE"):
        env.pop(key, None)
    config = work / "sway.conf"
    config.write_text(f"xwayland disable\nswaybg_command -\noutput HEADLESS-1 mode {round(1920*scale)}x{round(1200*scale)} scale {scale}\n")
    shell = None
    keyboard_display = None
    compositor = None
    try:
        if compositor_kind == "hyprland":
            config = work / "hyprland.lua"
            config.write_text('hl.config({misc={disable_hyprland_logo=true,disable_splash_rendering=true,disable_autoreload=true},ecosystem={no_update_news=true,no_donation_nag=true},animations={enabled=false},cursor={no_warps=true}})\n')
            parent = dict(os.environ)
            nested = dict(env,AQ_BACKEND="wayland",WAYLAND_DISPLAY=str(Path(parent["XDG_RUNTIME_DIR"])/parent["WAYLAND_DISPLAY"]))
            compositor = subprocess.Popen(["Hyprland","-c",str(config)],env=nested,stdout=(work/"sway.log").open("w"),stderr=subprocess.STDOUT)
            until(lambda: list((runtime/"hypr").glob("*/.socket.sock")))
            sockets = until(lambda: [p for p in runtime.glob("wayland-*") if p.is_socket()])
            env.update(HYPRLAND_INSTANCE_SIGNATURE=list((runtime/"hypr").glob("*/.socket.sock"))[0].parent.name,WAYLAND_DISPLAY=sockets[0].name,QT_QPA_PLATFORM="wayland")
            for window in json.loads(run("hyprctl","clients","-j",env=parent)):
                if window["pid"] == compositor.pid:
                    run("hyprctl","dispatch",'hl.dsp.window.move({window="address:'+window["address"]+'",workspace="special:qs-battery-test",follow=false})',env=parent)
            run("hyprctl","output","create","headless",env=env)
            run("hyprctl","eval",f'hl.monitor({{output="HEADLESS-1",mode="{round(1920*scale)}x{round(1200*scale)}@60",position="0x0",scale={scale}}}); hl.monitor({{output="WAYLAND-1",disabled=true}})',env=env)
            time.sleep(.5)
        else:
            compositor = subprocess.Popen(["sway", "-c", str(config)], env=env, stdout=(work / "sway.log").open("w"), stderr=subprocess.STDOUT)
            sock = runtime / f"sway-ipc.{os.getuid()}.{compositor.pid}.sock"
            until(sock.exists)
            env.update(SWAYSOCK=str(sock), I3SOCK=str(sock))
            run("swaymsg", "exec", f'echo $WAYLAND_DISPLAY > {work}/wayland', env=env)
            until(lambda: (work / "wayland").exists())
            env.update(WAYLAND_DISPLAY=(work / "wayland").read_text().strip(), QT_QPA_PLATFORM="wayland")

        # A real Wayland keyboard is needed for keyboard-enter and native window activation.
        from pywayland.client import Display
        protocols = work / "protocols"
        protocols.mkdir()
        run(sys.executable,"-m","pywayland.scanner","-i","/usr/share/wayland/wayland.xml",str(REPO/"scripts/tests/charging/virtual-keyboard-unstable-v1.xml"),"-o",str(protocols))
        sys.path.insert(0,str(work))
        WlSeat = importlib.import_module("protocols.wayland").WlSeat
        manager_type = importlib.import_module("protocols.virtual_keyboard_unstable_v1").ZwpVirtualKeyboardManagerV1
        keyboard_display = Display(str(runtime/env["WAYLAND_DISPLAY"]))
        keyboard_display.connect()
        registry = keyboard_display.get_registry()
        objects = {}
        def global_added(reg,name,interface,version):
            if interface == WlSeat.name: objects["seat"] = reg.bind(name,WlSeat,min(version,7))
            if interface == manager_type.name: objects["manager"] = reg.bind(name,manager_type,1)
        registry.dispatcher["global"] = global_added
        keyboard_display.roundtrip()
        keyboard = objects["manager"].create_virtual_keyboard(objects["seat"])
        keymap = run("xkbcli","compile-keymap").encode()+b"\0"
        with tempfile.TemporaryFile() as mapping:
            mapping.write(keymap);mapping.flush()
            keyboard.keymap(1,mapping.fileno(),len(keymap))
            keyboard_display.roundtrip()

        def start():
            return subprocess.Popen(["dbus-run-session", "--", "qs", "-p", str(root)], env=env,
                stdout=(work / "qs.log").open("a"), stderr=subprocess.STDOUT, start_new_session=True)

        shell = start()
        pid = until(lambda: run("pgrep", "-P", str(shell.pid), "qs"))

        def ipc(method, *args):
            return run("qs", "ipc", "--pid", pid, "call", "charging-test", method, *map(str, args), env=env)

        def state():
            return json.loads(ipc("state"))

        def settled():
            def check():
                s = state()
                return s if s["ready"] and not s["busy"] else None
            return until(check)

        def update(**changes):
            s = json.loads((work / "controller.json").read_text())
            s.update(changes)
            (work / "controller.json").write_text(json.dumps(s))
            if "onBattery" in changes:
                ipc("source", str(changes["onBattery"]).lower())
            ipc("refresh")
            return settled()

        until(lambda: state()["applied"])
        assert not state()["loaded"], state()
        ipc("open")
        until(lambda: state()["visible"] and state()["active"])
        s = settled()
        assert s["preserve"] and s["mode"] == "preserve" and s["height"] < s["max"], s
        if shots:
            shots.mkdir(parents=True, exist_ok=True)
            ipc("shot", str(shots / f"battery-preserve-{scale}.png"))
            time.sleep(.3)
        ipc("press", "false", "true")
        assert settled()["preserve"]
        # Native Space-key action on the actual tile, then ordinary refresh must not cancel it.
        ipc("press", "true", "false")
        until(lambda: state()["mode"] == "full" and not state()["busy"])
        for _ in range(3):
            ipc("refresh")
            assert settled()["wanted"] == "full"
        assert state()["full"] and not state()["preserve"]
        if shots:
            ipc("shot", str(shots / f"battery-departure-{scale}.png"))
            time.sleep(.3)
        s = update(onBattery=True)
        assert s["mode"] == "full" and s["phase"]
        s = update(onBattery=False)
        until(lambda: state()["mode"] == "preserve")
        assert not state()["phase"]
        # Arm a departure while unplugged: plugging in to prepare it must not reset the choice.
        update(onBattery=True)
        ipc("choose", "true")
        until(lambda: state()["mode"] == "full")
        assert update(onBattery=False)["wanted"] == "full"
        # Full restart, not just a hot reload: departure persists without another write.
        before = (work / "writes").read_text()
        os.killpg(shell.pid, signal.SIGTERM)
        shell.wait(timeout=5)
        shell = start()
        pid = until(lambda: run("pgrep", "-P", str(shell.pid), "qs"))
        until(lambda: state()["applied"] and not state()["busy"])
        ipc("open")
        until(lambda: state()["visible"] and state()["active"])
        assert state()["full"] and (work / "writes").read_text() == before
        update(onBattery=True)
        update(onBattery=False)
        until(lambda: state()["mode"] == "preserve")
        # Refused/ignored writes: no false selection and no background retry loop.
        (work / "fail").write_text("1")
        ipc("choose", "true")
        until(lambda: state()["error"] == "Not authorized" and not state()["busy"])
        s = state()
        assert s["mode"] == "preserve" and not s["full"] and not s["applied"], s
        before = (work / "writes").read_text()
        for _ in range(3):
            ipc("refresh")
            settled()
        assert (work / "writes").read_text() == before
        assert state()["error"] == "Not authorized", state()
        (work / "fail").write_text("0")
        ipc("click", "Retry")
        until(lambda: state()["full"] and not state()["error"] and not state()["busy"])
        ipc("choose", "false")
        until(lambda: state()["applied"])
        # Rapid native transitions must survive an old read and an in-flight setter.
        for during_write in (False, True):
            ipc("choose", "false")
            until(lambda: state()["applied"] and not state()["busy"])
            if not during_write:
                ipc("choose", "true")
                until(lambda: state()["applied"] and not state()["busy"])
            (work / "delay").write_text(".8")
            ipc("choose", "true") if during_write else ipc("refresh")
            until(lambda: state()["busy"])
            ipc("cycle")
            assert state()["wanted"] == "preserve", state()
            until(lambda: state()["mode"] == "preserve" and state()["applied"] and not state()["busy"])
            (work / "delay").write_text("0")
        # Recover a read error without hiding a failed action on an ordinary successful read.
        (work / "readfail").write_text("1")
        ipc("refresh")
        until(lambda: state()["error"] == "Temporary UPower failure" and not state()["busy"])
        (work / "readfail").write_text("0")
        ipc("refresh")
        until(lambda: not state()["error"] and not state()["busy"])
        # Mouse actions and disabled controls while an action is pending.
        ipc("close")
        ipc("open")
        until(lambda: state()["visible"] and state()["active"])
        (work / "delay").write_text(".5")
        ipc("click", "battery-full")
        until(lambda: state()["busy"])
        assert not state()["enabled"]
        until(lambda: state()["full"] and not state()["busy"])
        (work / "delay").write_text("0")
        ipc("click", "battery-preserve")
        until(lambda: state()["preserve"] and not state()["busy"])
        ipc("outside")
        until(lambda: not state()["visible"])
        ipc("settingsOpen")
        until(lambda: state()["settingsVisible"])
        ipc("fromSettings")
        until(lambda: state()["visible"] and state()["active"] and not state()["settingsVisible"])
        # Unavailable health values must be omitted, never rendered as zero/NaN.
        data = json.loads((work / "controller.json").read_text())
        data["battery"].update(Capacity=0, Temperature=0, ChargeCycles=-1, EnergyFull=0)
        update(battery=data["battery"])
        assert not any(label in state()["texts"] for label in ("Temperature", "Battery health", "Charge cycles", "Capacity"))
        ipc("close")
        # Unsupported and unconfigured batteries remain readable, with no setter invocation.
        before = (work / "writes").read_text()
        update(configured=False)
        ipc("open")
        assert not state()["enabled"]
        ipc("click", "battery-full")
        ipc("choose", "true")
        ipc("close")
        assert (work / "writes").read_text() == before
        update(configured=True)
        ipc("open")
        ipc("pressEscape")
        until(lambda: not state()["visible"])
        ipc("unhover")
        ipc("preview")
        until(lambda: state()["preview"])
        ipc("open")
        assert not state()["preview"]
        ipc("close")
        ipc("absent", "true")
        assert not state()["barShown"]
        assert (work / "writes").read_text() == before
        log = (work / "qs.log").read_text()
        warnings = [line for line in log.splitlines() if re.search(r"WARN|ERROR|TypeError|ReferenceError", line)
                    and "UPower" not in line and not any(term in line for term in
                        ("xdg-desktop-portal", "qt.qpa.services:", "atk-bridge:", "AT-SPI:")
                        ) and not ("qt.qpa.wayland.textinput:" in line and "Trying to disable" in line) # Qt diagnostic also seen on the real desktop
                    ]
        assert not warnings, "\n".join(warnings)
        print(f"PASS real card {compositor_kind} {scale}×: real bar/settings/lazy loader, mouse, native window focus, Tab/Enter/Space, outside click, keyboard/preview/Escape, preservation/full/AC-return, off-AC arming, restart persistence, authorization failure/no retry loop, rapid AC return during reads/writes, read recovery, unavailable configuration")
    finally:
        if shell and shell.poll() is None:
            os.killpg(shell.pid, signal.SIGTERM)
            shell.wait(timeout=5)
        if keyboard_display:
            keyboard_display.disconnect()
        if compositor:
            compositor.terminate()
            compositor.wait(timeout=5)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--shots", type=Path)
    parser.add_argument("--compositor", choices=["sway", "hyprland"], default="sway")
    parser.add_argument("--scale", type=float, default=1)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="qs-chg-") as tmp:
        work = Path(tmp)
        try:
            setup_test(work)
            card_test(work, args.shots.resolve() if args.shots else None, args.scale, args.compositor)
        except Exception:
            for name in ("qs.log", "sway.log"):
                if (work / name).exists():
                    print((work / name).read_text())
            raise
