#!/usr/bin/env python3
"""Install UPower's 50–80% preset, with reversible hardware/configuration changes.

Run as the desktop user in a terminal (one sudo invocation). --root stages/tests an
isolated filesystem: no sudo, daemon reload, or access to the real battery.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parents[1]
FILES = ("charge_control_start_threshold", "charge_control_end_threshold", "charge_types")


def devices(root):
    return [p for p in sorted((root / "sys/class/power_supply").glob("*"))
            if (p / "type").is_file() and (p / "type").read_text().strip() == "Battery"
            and all((p / name).exists() for name in FILES[:2])
            and (not (p / FILES[2]).exists()
                 or all(mode in (p / FILES[2]).read_text().replace("[", "").replace("]", "").split() for mode in ("Custom", "Standard")))]


def refresh(staging):
    if not staging:
        for command in (["systemd-hwdb", "update"], ["udevadm", "control", "--reload"],
                        ["udevadm", "trigger", "--subsystem-match=power_supply", "--action=change"],
                        ["udevadm", "settle"], ["systemctl", "restart", "upower.service"]):
            subprocess.run(command, check=True)


def restore(root, state, staging):
    saved = json.loads((state / "original.json").read_text())
    for name in ("etc/udev/hwdb.d/61-qs-desktop-battery.hwdb", "var/lib/upower/charging-threshold-status"):
        target = root / name
        backup = state / name.replace("/", "_")
        if backup.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(backup, target)
        else:
            target.unlink(missing_ok=True)
    for battery in saved:
        device = root / battery["path"]
        if not device.exists():
            continue  # A removable battery may be absent during uninstall.
        # Broaden the interval first so a stricter current interval cannot clamp the original values.
        (device / FILES[1]).write_text("100")
        for name in FILES[:2]:
            (device / name).write_text(battery[name])
        if battery.get("charge_types"):
            (device / FILES[2]).write_text(battery["charge_types"])
    refresh(staging)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("action", choices=("install", "uninstall"))
    args = parser.parse_args()
    staging = args.root is not None
    root = args.root.resolve() if staging else Path("/")
    if staging and root == Path("/"):
        parser.error("--root must be an isolated directory")
    state = root / "var/lib/qs-desktop/battery-setup"
    target = root / "etc/udev/hwdb.d/61-qs-desktop-battery.hwdb"
    source = REPO / "dotfiles/udev/61-qs-desktop-battery.hwdb"
    if state.is_symlink() or target.is_symlink():
        raise RuntimeError("Refusing a symbolic link on the installation state or configuration")
    batteries = devices(root)
    if args.action == "install" and not batteries:
        print("= recharge : aucun contrôleur compatible, aucun changement")
        return
    if args.action == "install" and (state / "ready").exists() and target.is_file() and target.read_bytes() == source.read_bytes():
        print("= préservation 50–80 % déjà configurée ; mode courant conservé")
        return
    if args.action == "uninstall" and not (state / "original.json").exists():
        print("= recharge : aucune installation à retirer")
        return
    print(f"+ recharge : {'configurer le préréglage UPower 50–80 %' if args.action == 'install' else 'restaurer les réglages initiaux'}")
    if args.dry_run:
        return
    if not staging and os.geteuid() != 0:
        # No password handling or cached credentials in the script.
        raise SystemExit(subprocess.call(["sudo", "--", sys.executable, "-I", str(Path(__file__).resolve()), args.action]))
    if args.action == "uninstall":
        restore(root, state, staging)
        shutil.rmtree(state)
        return
    if state.exists():
        raise RuntimeError("Existing battery installation state: restore it before changing the preset")
    saved = []
    for device in batteries:
        item = {"path": str(device.relative_to(root))}
        for name in FILES[:2]:
            item[name] = (device / name).read_text().strip()
        if (device / FILES[2]).exists():
            match = re.search(r"\[([^]]+)\]", (device / FILES[2]).read_text())
            if not match:
                raise RuntimeError("Cannot identify the original charging mode")
            item[FILES[2]] = match[1]
        saved.append(item)
    originals = ("etc/udev/hwdb.d/61-qs-desktop-battery.hwdb", "var/lib/upower/charging-threshold-status")
    if any((root / name).is_symlink() for name in originals):
        raise RuntimeError("Refusing a symbolic link on the original configuration")
    state.mkdir(parents=True, mode=0o755)
    (state / "original.json").write_text(json.dumps(saved))
    for name in originals:
        original = root / name
        if original.is_symlink():
            raise RuntimeError("Refusing a symbolic link on the original configuration")
        if original.exists():
            shutil.copy2(original, state / name.replace("/", "_"))
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        target.chmod(0o644)
        for device in batteries:
            for name, value in zip(FILES[:2], ("50", "80")):
                (device / name).write_text(value)
                if (device / name).read_text().strip() != value:
                    raise RuntimeError("The battery controller rejected the preservation preset")
        refresh(staging)
        (state / "ready").touch(mode=0o644)
    except Exception:
        restore(root, state, staging)
        shutil.rmtree(state)
        raise


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Battery setup: {error}", file=sys.stderr)
        sys.exit(1)
