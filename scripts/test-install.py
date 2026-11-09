#!/usr/bin/env python3
"""Test des étapes du compte d'install.sh (sans paquets ni sudo) dans un dossier personnel jetable.

Copie du dépôt, HOME et XDG_RUNTIME_DIR temporaires, bus D-Bus privé (dconf isolé). Vérifie : simulation sans écriture,
installation, second passage sans aucun changement, retrait qui remet le dossier personnel et dconf dans leur état initial.
Réseau requis au premier passage (archives du thème, gardées dans QS_TEST_CACHE ou le cache du test).
Usage : python3 scripts/test-install.py [-v]
"""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

REPO = pathlib.Path(__file__).resolve().parent.parent
VERBOSE = "-v" in sys.argv
failures = []


def check(cond, what):
    print(("ok   " if cond else "ÉCHEC ") + what)
    if not cond:
        failures.append(what)


def snapshot(home):
    """Fichiers, liens et contenus du dossier personnel, hors cache et état d'install.sh."""
    out = {}
    for root, dirs, files in os.walk(home):
        rel = os.path.relpath(root, home)
        if rel.startswith((".cache", ".local/state", ".config/dconf")):
            dirs[:] = []
            continue
        for name in dirs + files:
            p = os.path.join(root, name)
            key = os.path.relpath(p, home)
            if os.path.islink(p):
                out[key] = "-> " + os.readlink(p)
                if name in dirs:
                    dirs.remove(name)
            elif os.path.isfile(p):
                out[key] = open(p, "rb").read()
            else:
                out[key] = "<dir>"
    return out


def main():
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="qs-install-test-"))
    try:
        repo = tmp / "repo"
        shutil.copytree(REPO, repo, symlinks=True, ignore=shutil.ignore_patterns(".git", ".shots", "__pycache__"))
        (repo / "dotfiles/mpv/host.conf").unlink(missing_ok=True)
        home, run = tmp / "home", tmp / "run"
        run.mkdir(mode=0o700)
        # Dossier personnel déjà habité : réglages à garder, fichiers à sauvegarder.
        (home / ".config/gtk-3.0").mkdir(parents=True)
        (home / ".config/gtk-3.0/settings.ini").write_text("[Settings]\ngtk-theme-name=Adwaita\ngtk-enable-animations=0\n")
        (home / ".config/mpv").mkdir()
        (home / ".config/mpv/mpv.conf").write_text("volume=50\n")
        (home / ".bashrc").write_text("alias ll='ls -l'\n")
        cache = pathlib.Path(os.environ.get("QS_TEST_CACHE", tmp / "cache"))
        env = {k: v for k, v in os.environ.items() if not k.startswith(("XDG_", "DBUS_", "SWAYSOCK", "I3SOCK", "HYPRLAND", "WAYLAND", "DISPLAY"))}
        env.update(HOME=str(home), XDG_RUNTIME_DIR=str(run), XDG_CACHE_HOME=str(cache), LANG="C.UTF-8")

        def install(*args):
            cmd = ["dbus-run-session", "--", "bash", "-c", 'dconf load / < "$0" 2>/dev/null; bash "$1" "${@:2}"; rc=$?; dconf dump / > "$0"; exit $rc',
                   str(tmp / "dconf.ini"), str(repo / "install.sh"), "--no-packages", "--no-system", *args]
            log = open(tmp / "last.log", "w")
            try:
                r = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=log, text=True, timeout=300)
            except subprocess.TimeoutExpired as e:
                out = (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
                print("BLOQUÉ (300 s) :", " ".join(args) or "installation", "\n" + out[-1500:], (tmp / "last.log").read_text()[-800:])
                raise
            if VERBOSE:
                print(r.stdout, (tmp / "last.log").read_text())
            r.stderr = (tmp / "last.log").read_text()
            return r

        (tmp / "dconf.ini").write_text("[org/gnome/desktop/interface]\nfont-name='Cantarell 11'\n")
        subprocess.run(["dbus-run-session", "--", "bash", "-c", 'dconf load / < "$0"; dconf dump / > "$0"', str(tmp / "dconf.ini")],
                       env=env, capture_output=True)   # forme normalisée par dconf, pour comparer
        before, dconf_before = snapshot(home), (tmp / "dconf.ini").read_text()

        r = install("--dry-run")
        check(r.returncode == 0, f"simulation : code {r.returncode} {r.stderr.strip()[-300:]}")
        now = snapshot(home)
        written = sorted(set(before) ^ set(now)) + sorted(k for k in before if k in now and before[k] != now[k])
        check(not written and (tmp / "dconf.ini").read_text() == dconf_before, f"simulation : rien d'écrit {written[:8]}")

        r = install()
        check(r.returncode == 0, f"installation : code {r.returncode} {r.stderr.strip()[-300:]}")
        cfg = home / ".config"
        check(os.readlink(cfg / "quickshell/desktop") == str(repo), "lien quickshell/desktop")
        check(os.readlink(cfg / "mpv") == str(repo / "dotfiles/mpv"), "lien mpv")
        check(any(p.name.startswith("mpv.bak-") for p in cfg.iterdir()), "ancien ~/.config/mpv sauvegardé")
        check(os.readlink(repo / "dotfiles/mpv/host.conf").startswith("hosts/"), "mpv : host.conf choisi")
        gtk3 = (cfg / "gtk-3.0/settings.ini").read_text()
        check("gtk-theme-name=catppuccin-mocha-green-standard+default" in gtk3 and "gtk-enable-animations=0" in gtk3,
              "gtk-3.0 : thème changé, autre réglage gardé")
        check("# qs-desktop (install.sh)" in (home / ".bashrc").read_text() and "alias ll" in (home / ".bashrc").read_text(),
              ".bashrc : bloc ajouté, alias gardé")
        check((home / ".local/share/themes/catppuccin-mocha-green-standard+default/gtk-3.0").is_dir(), "thème GTK installé")
        check((home / ".local/share/icons/catppuccin-mocha-green-cursors/cursors").is_dir(), "curseur installé")
        check((cfg / "Kvantum/catppuccin-mocha-green/catppuccin-mocha-green.kvconfig").is_file(), "Kvantum installé")
        folder = home / ".local/share/icons/Papirus/48x48/places/folder.svg"
        check(folder.is_symlink() and "cat-mocha-lavender" in os.readlink(folder), "Papirus : dossiers lavande")
        dconf = (tmp / "dconf.ini").read_text()
        check("accent-color='green'" in dconf and "gtk-theme='catppuccin-mocha-green-standard+default'" in dconf, "dconf appliqué")
        mime = (cfg / "mimeapps.list").read_text() if (cfg / "mimeapps.list").exists() else ""
        check("video/mp4=io.github.celluloid_player.Celluloid.desktop" in mime or "Celluloid" not in mime and not shutil.which("celluloid"),
              "applications par défaut")
        check(any((home / ".local/share/applications").glob("WebApp-*.desktop")), "web apps générées")

        r = install()
        # Un Deluge ouvert sur la machine de test (même compte) : install.sh ne doit pas écrire sous lui.
        if subprocess.run(["pgrep", "-u", str(os.getuid()), "-f", "(^|/)deluge(-gtk)?( |$)"], capture_output=True).returncode == 0:
            check("Deluge est ouvert" in r.stdout and not (cfg / "deluge/gtk3ui.conf").exists(),
                  "Deluge ouvert : réglage reporté, rien d'écrit")
        else:
            deluge = (cfg / "deluge/gtk3ui.conf").read_text()
            check('"enable_system_tray": false' in deluge and deluge.startswith("{"), "Deluge : pas d'icône dans la barre")
        changes = [l for l in r.stdout.splitlines() if l.startswith("+ ")]
        check(r.returncode == 0 and not changes, f"second passage sans changement {changes[:5]}")

        r = install("--uninstall")
        check(r.returncode == 0, f"retrait : code {r.returncode} {r.stderr.strip()[-300:]}")
        after = snapshot(home)
        diff = sorted(set(before) ^ set(after)) + sorted(k for k in before if k in after and before[k] != after[k])
        # Restes acceptés : dossiers vides créés en chemin.
        diff = [k for k in diff if not (k in after and after[k] == "<dir>" and k not in before)]
        check(not diff, f"retrait : dossier personnel comme avant {diff[:8]}")
        check("font-name='Cantarell 11'" in (tmp / "dconf.ini").read_text()
              and "accent-color" not in (tmp / "dconf.ini").read_text(), "retrait : dconf comme avant")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print(f"\n{len(failures)} échec(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
