#!/usr/bin/env python3
"""Thème Catppuccin de Thunderbird (system-setup.sh thunderbird-theme) : installation, mise à jour, politique existante et
retrait, isolés (faux sudo, chemins système remplacés par un dossier jetable)."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parent.parent
ID = "{3782e2b5-f78b-54d6-9475-20d4fab2c92c}"


def scenario(root, thunderbird=True):
    (root / "bin").mkdir(parents=True)
    fakes = {"sudo": 'exec "$@"'}
    if thunderbird:
        fakes["thunderbird"] = "exit 0"
    for name, body in fakes.items():
        (root / "bin" / name).write_text("#!/bin/sh\n" + body + "\n")
        (root / "bin" / name).chmod(0o755)
    repo = root / "repo"
    (repo / "scripts").mkdir(parents=True)
    source = (REPO / "scripts/system-setup.sh").read_text()
    source = source.replace("state=/var/lib/qs-desktop/system-setup", f"state={root}/state")
    source = source.replace("/etc/thunderbird", f"{root}/etc/thunderbird")
    source = source.replace("/usr/local/share/catppuccin-thunderbird", f"{root}/share/catppuccin-thunderbird")
    source = source.replace(" -o root -g root", "")
    if not thunderbird:   # le vrai Thunderbird de la machine ne compte pas
        source = source.replace("command -v thunderbird >/dev/null", '[[ -x "$TEST_ROOT/bin/thunderbird" ]]')
    helper = repo / "scripts/system-setup.sh"
    helper.write_text(source)
    env = dict(os.environ, TEST_ROOT=str(root), PATH=f"{root}/bin:" + os.environ["PATH"])

    def run(*args):
        r = subprocess.run(["bash", str(helper), *args], env=env, text=True, capture_output=True)
        assert r.returncode == 0, r.stdout + r.stderr
        return r.stdout

    return run


def policy_url(root):
    p = json.loads((root / "etc/thunderbird/policies/policies.json").read_text())
    entry = p["policies"]["ExtensionSettings"][ID]
    assert entry["installation_mode"] == "normal_installed", entry
    assert entry["install_url"].startswith("file://"), entry
    return Path(entry["install_url"][len("file://"):])


with tempfile.TemporaryDirectory(prefix="qs-thunderbird-test-") as tmp:
    base = Path(tmp)
    xpi1, xpi2 = base / "v1.xpi", base / "v2.xpi"
    xpi1.write_bytes(b"PK theme v1")
    xpi2.write_bytes(b"PK theme v2")

    # Installation, second passage sans changement, nouvelle version, retrait.
    root = base / "fresh"
    run = scenario(root)
    out = run("--dry-run", "thunderbird-theme", str(xpi1))
    assert "install -D" in out and not (root / "etc").exists() and not (root / "share").exists(), out
    run("thunderbird-theme", str(xpi1))
    first = policy_url(root)
    assert first.read_bytes() == xpi1.read_bytes() and str(first).startswith(str(root / "share/catppuccin-thunderbird/"))
    registry = (root / "state/registry").read_text()
    out = run("thunderbird-theme", str(xpi1))
    assert "à jour" in out and "+ " not in out and (root / "state/registry").read_text() == registry, out
    run("thunderbird-theme", str(xpi2))
    second = policy_url(root)
    assert second != first and not first.exists() and second.read_bytes() == xpi2.read_bytes()
    run("uninstall")
    assert not (root / "etc/thunderbird").exists() and not (root / "share/catppuccin-thunderbird").exists()
    run("uninstall")

    # Politique déjà là (pas d'install.sh) : jamais écrasée, ni retirée.
    root = base / "foreign"
    run = scenario(root)
    mine = root / "etc/thunderbird/policies/policies.json"
    mine.parent.mkdir(parents=True)
    mine.write_text('{"policies": {"DisableTelemetry": true}}\n')
    out = run("thunderbird-theme", str(xpi1))
    assert "gardé" in out and mine.read_text() == '{"policies": {"DisableTelemetry": true}}\n', out
    assert not (root / "share/catppuccin-thunderbird").exists()
    run("uninstall")
    assert mine.read_text() == '{"policies": {"DisableTelemetry": true}}\n'

    # /etc/thunderbird déjà là (autre réglage) : gardé au retrait, seule notre politique retirée.
    root = base / "etc-present"
    run = scenario(root)
    other = root / "etc/thunderbird/autre.cfg"
    other.parent.mkdir(parents=True)
    other.write_text("x\n")
    run("thunderbird-theme", str(xpi1))
    policy_url(root)
    run("uninstall")
    assert other.read_text() == "x\n" and not (root / "etc/thunderbird/policies/policies.json").exists()

    # Thunderbird absent : rien.
    root = base / "absent"
    run = scenario(root, thunderbird=False)
    out = run("thunderbird-theme", str(xpi1))
    assert "absent" in out and not (root / "etc").exists(), out

print("test-thunderbird-theme : OK")
