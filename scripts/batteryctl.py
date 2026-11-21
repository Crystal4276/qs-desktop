#!/usr/bin/env python3
"""One-shot UPower client: read battery details or select its native charging policy."""
import json
import os
from pathlib import Path
import sys

from gi.repository import Gio, GLib

NAME = "org.freedesktop.UPower"
DEVICE = NAME + ".Device"
ROOT = "/org/freedesktop/UPower"
READY = Path("/var/lib/qs-desktop/battery-setup/ready")


def call(bus, path, interface, method, parameters=None):
    result = bus.call_sync(NAME, path, interface, method, parameters, None,
                          Gio.DBusCallFlags.NONE, 8000, None).unpack()
    return result[0] if result else None  # EnableChargeThreshold has no return arguments.


def properties(bus, path, interface):
    return call(bus, path, "org.freedesktop.DBus.Properties", "GetAll",
                GLib.Variant("(s)", (interface,)))


def snapshot(bus):
    for path in call(bus, ROOT, NAME, "EnumerateDevices"):
        data = properties(bus, path, DEVICE)
        if data.get("Type") != 2 or not data.get("PowerSupply") or not data.get("IsPresent"):
            continue
        native = Path(data.get("NativePath", ""))
        native = native if native.is_absolute() else Path("/sys/class/power_supply") / native
        # Only actual kernel devices: never follow a path supplied by an unrelated D-Bus device.
        native = native.resolve()
        if not native.is_relative_to("/sys/devices"):
            raise RuntimeError("Invalid battery device path")
        hardware = {}
        for key in ("charge_types", "charge_control_start_threshold", "charge_control_end_threshold"):
            try:
                hardware[key] = (native / key).read_text().strip()
            except FileNotFoundError:
                hardware[key] = ""
        return {"path": path, "battery": data, "hardware": hardware,
                "onBattery": properties(bus, ROOT, NAME).get("OnBattery", False),
                "configured": READY.is_file()}
    return {"path": "", "battery": {}, "hardware": {}, "configured": False, "onBattery": False}


def mode(state):
    battery, hardware = state["battery"], state["hardware"]
    types = hardware.get("charge_types", "")
    if (battery.get("ChargeThresholdEnabled") is True
            and hardware.get("charge_control_start_threshold") == "50"
            and hardware.get("charge_control_end_threshold") == "80"
            and (not types or "[Custom]" in types)):
        return "preserve"
    if (battery.get("ChargeThresholdEnabled") is False
            and hardware.get("charge_control_end_threshold") == "100"
            and (not types or "[Standard]" in types)):
        return "full"
    return ""


def select(bus, selected):
    state = snapshot(bus)
    if not state["configured"] or not state["battery"].get("ChargeThresholdSupported"):
        raise RuntimeError("Battery charging modes are not configured")
    # These are UPower's cached preservation settings, even while the full-charge mode is active.
    if (state["battery"].get("ChargeStartThreshold"), state["battery"].get("ChargeEndThreshold")) != (50, 80):
        raise RuntimeError("Charging thresholds differ from the configured 50–80% policy")
    call(bus, state["path"], DEVICE, "EnableChargeThreshold", GLib.Variant("(b)", (selected == "preserve",)))
    state = snapshot(bus)
    if mode(state) != selected:
        raise RuntimeError("The battery controller did not confirm the requested charging mode")
    return state


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("status", "preserve", "full"):
        raise SystemExit("Usage: batteryctl.py status|preserve|full")
    # A bench must supply a private system bus; QS_TEST alone never authorizes hardware changes.
    if os.environ.get("QS_TEST") and not os.environ.get("DBUS_SYSTEM_BUS_ADDRESS", "").startswith("unix:path=/tmp/"):
        raise RuntimeError("A battery test requires a private system bus")
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    state = snapshot(bus) if sys.argv[1] == "status" else select(bus, sys.argv[1])
    state["mode"] = mode(state)
    print(json.dumps(state))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
