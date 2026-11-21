#!/usr/bin/env python3
"""Charging policy and real card on an isolated Wayland bench. Never writes real hardware."""
import argparse
import importlib.util
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
ShellRoot {
 PanelWindow {
  id: bar
  anchors { top: true; left: true; right: true }
  implicitHeight: Theme.bar.exclusiveZone
  exclusiveZone: height
  Item { id: button; property bool hovered: false; x: 100; width: 32; height: 32 }
 }
 BatteryPanel { id: panel; holdOpen: true }
 TestCase { id: events; parent: panel.frameItem; when: false }
 function find(item, name) {
  if (item.objectName === name) return item;
  for (let c of item.children ?? []) { const found = find(c, name); if (found) return found; }
  return null;
 }
 IpcHandler {
  target: "charging-test"
  function open(): void { panel.toggle(button, Qt.LeftButton); }
  function close(): void { panel.close(); }
  function preview(): void { panel.preview(button, Qt.LeftButton); }
  function refresh(): void { Charging.refresh(); }
  function choose(full: bool): void { Charging.select(full); }
  function absent(value: bool): void { Battery.available = !value; }
  function press(full: bool): void {
   const tile = find(panel.frameItem, full ? "battery-full" : "battery-preserve");
   tile.forceActiveFocus(); events.keyClick(Qt.Key_Space);
  }
  function pressEscape(): void { events.keyClick(Qt.Key_Escape); }
  function shot(path: string): void { panel.frameItem.grabToImage(r => r.saveToFile(path)); }
  function state(): string {
   const f=panel.frameItem;
   return JSON.stringify({ready:Charging.ready,configured:Charging.configured,busy:Charging.busy,mode:Charging.mode,
    phase:Charging.departure,wanted:Charging.wanted,applied:Charging.applied,onBattery:Charging.onBattery,error:Charging.error,
    visible:panel.visible,preview:panel.previewing,height:f.height,max:f.maxHeight,width:f.width,
    preserve:find(f,"battery-preserve").checked,full:find(f,"battery-full").checked});
  }
 }
}
'''

FAKE = '''#!/usr/bin/python3
import json, os, sys, time
from pathlib import Path
w=Path(os.environ["CHARGING_BENCH"])
time.sleep(float((w/"delay").read_text()))
s=json.loads((w/"controller.json").read_text())
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
print(json.dumps(s))
'''


def card_test(work, shots, scale):
    root = work / "shell"
    shutil.copytree(REPO, root, ignore=shutil.ignore_patterns(".git", ".shots", ".agents", ".codex", ".aws", "__pycache__"))
    (root / "services/Battery.qml").write_text(FIXTURE)
    (root / "services/Session.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject { property bool lockActive: false }")
    (root / "shell.qml").write_text(SHELL)
    runtime = work / "runtime"
    runtime.mkdir(mode=0o700)
    bindir = work / "bin"
    bindir.mkdir()
    (bindir / "python3").write_text(FAKE)
    (bindir / "python3").chmod(0o755)
    for key in ("fail", "ignored", "delay"):
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
    compositor = subprocess.Popen(["sway", "-c", str(config)], env=env, stdout=(work / "sway.log").open("w"), stderr=subprocess.STDOUT)
    shell = None
    try:
        sock = runtime / f"sway-ipc.{os.getuid()}.{compositor.pid}.sock"
        until(sock.exists)
        env.update(SWAYSOCK=str(sock), I3SOCK=str(sock))
        run("swaymsg", "exec", f'echo $WAYLAND_DISPLAY > {work}/wayland', env=env)
        until(lambda: (work / "wayland").exists())
        env.update(WAYLAND_DISPLAY=(work / "wayland").read_text().strip(), QT_QPA_PLATFORM="wayland")

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
            ipc("refresh")
            return settled()

        until(lambda: state()["applied"])
        ipc("open")
        s = settled()
        assert s["preserve"] and s["mode"] == "preserve" and s["height"] < s["max"], s
        if shots:
            shots.mkdir(parents=True, exist_ok=True)
            ipc("shot", str(shots / f"battery-preserve-{scale}.png"))
            time.sleep(.3)
        # Native Space-key action on the actual tile, then ordinary refresh must not cancel it.
        ipc("press", "true")
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
        (work / "fail").write_text("0")
        ipc("choose", "false")
        until(lambda: state()["applied"])
        # Unsupported and unconfigured batteries remain readable, with no setter invocation.
        before = (work / "writes").read_text()
        update(configured=False)
        ipc("choose", "true")
        assert (work / "writes").read_text() == before
        update(configured=True)
        ipc("open")
        ipc("pressEscape")
        until(lambda: not state()["visible"])
        ipc("preview")
        assert state()["preview"]
        ipc("open")
        assert not state()["preview"]
        ipc("close")
        log = (work / "qs.log").read_text()
        warnings = [line for line in log.splitlines() if re.search(r"WARN|ERROR|TypeError|ReferenceError", line)
                    and "UPower" not in line and not any(term in line for term in
                        ("xdg-desktop-portal", "qt.qpa.services:", "atk-bridge:", "AT-SPI:"))]
        assert not warnings, "\n".join(warnings)
        print(f"PASS real card {scale}×: keyboard/preview/Escape, preservation/full/AC-return, off-AC arming, restart persistence, authorization failure/no retry loop, unavailable configuration")
    finally:
        if shell and shell.poll() is None:
            os.killpg(shell.pid, signal.SIGTERM)
            shell.wait(timeout=5)
        compositor.terminate()
        compositor.wait(timeout=5)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--shots", type=Path)
    parser.add_argument("--scale", type=float, default=1)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="qs-charging-test-") as tmp:
        work = Path(tmp)
        try:
            setup_test(work)
            card_test(work, args.shots.resolve() if args.shots else None, args.scale)
        except Exception:
            for name in ("qs.log", "sway.log"):
                if (work / name).exists():
                    print((work / name).read_text())
            raise
