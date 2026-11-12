#!/usr/bin/env python3
"""Test des étapes du compte d'install.sh (sans paquets ni sudo) dans un dossier personnel jetable.

Copie du dépôt, HOME et XDG_RUNTIME_DIR temporaires, bus D-Bus privé (dconf isolé), dépôts des fonds et de DigitalMicrograph
remplacés par des dépôts locaux. Vérifie : simulation sans écriture, installation (profil jeux), second passage sans aucun
changement, retrait qui remet le dossier personnel et dconf dans leur état initial (clones gardés), puis profil travail choisi
par la question (sans terminal : travail) et écrit dans la config machine.
Réseau requis au premier passage (archives du thème, gardées dans QS_TEST_CACHE ou le cache du test).
Usage : python3 scripts/test-install.py [-v]
"""
import json
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


def fake_papirus(root):
    """Papirus d'origine en miniature : dossiers bleus, chaînes de liens, tailles servies par des liens, Papirus-Dark."""
    p = root / "Papirus"
    for size in ("16x16", "22x22", "24x24", "32x32", "48x48", "64x64"):
        d = p / size / "places"
        d.mkdir(parents=True)
        if size == "16x16":
            (d / "folder.svg").write_text("16")
            continue
        (d / "folder-blue.svg").write_text("blue")
        (d / "folder-blue-video.svg").write_text("blue video")
        (d / "folder.svg").symlink_to("folder-blue.svg")
        (d / "folder-video.svg").symlink_to("folder-blue-video.svg")
        (d / "folder-videos.svg").symlink_to("folder-video.svg")              # chaîne : videos → video → blue-video
        (d / "folder-blue-videos.svg").symlink_to("folder-blue-video.svg")    # bleu demandé explicitement
    for size, to in (("96x96", "48x48"), ("128x128", "64x64")):
        (p / size).mkdir()
        (p / size / "places").symlink_to(f"../{to}/places")
    for size in ("16x16", "22x22", "48x48", "64x64"):
        (p / f"{size}@2x").symlink_to(size)
    dirs = ["16x16/places", "22x22/places", "48x48/places", "48x48@2x/places", "64x64/places", "96x96/places", "128x128/places"]
    (p / "index.theme").write_text("[Icon Theme]\nName=Papirus\nDirectories=" + ",".join(dirs) + "\n")
    dark = root / "Papirus-Dark"
    (dark / "22x22").mkdir(parents=True)
    (dark / "22x22/places").symlink_to("../../Papirus/22x22/places")
    for size in ("48x48", "64x64", "96x96", "128x128"):
        (dark / size).symlink_to(f"../Papirus/{size}")
    (dark / "48x48@2x").symlink_to("48x48")
    (dark / "index.theme").write_text("[Icon Theme]\nName=Papirus-Dark\nInherits=breeze-dark,hicolor\nDirectories=" + ",".join(dirs) + "\n")
    return dirs


def icon(bases, theme, d, name):
    """Fichier qu'affiche GTK : premier dossier de base (compte, puis système) qui a ce nom, liens suivis."""
    for b in bases:
        f = b / theme / d / name
        if f.exists():
            return os.path.realpath(f)
    return ""


def git_repo(path, name):
    """Petit dépôt git local (un fichier, un commit) : remplace un dépôt GitHub cloné par install.sh."""
    path.mkdir(parents=True)
    (path / name).write_text(name + "\n")
    for cmd in (["init", "-q"], ["add", "."], ["-c", "user.name=test", "-c", "user.email=test@example.invalid", "commit", "-qm", "init"]):
        subprocess.run(["git", "-C", str(path), *cmd], check=True, capture_output=True)
    return str(path)


def main():
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="qs-install-test-"))
    try:
        repo = tmp / "repo"
        shutil.copytree(REPO, repo, symlinks=True, ignore=shutil.ignore_patterns(".git", ".shots", "__pycache__"))
        host_json = repo / "hosts" / (pathlib.Path("/proc/sys/kernel/hostname").read_text().strip() + ".json")
        host_config = json.loads(host_json.read_text()) if host_json.exists() else {}
        host_config["windows11"] = {"uri": "qemu:///system", "domain": "win11"}
        host_json.write_text(json.dumps(host_config))
        (repo / "dotfiles/mpv/host.conf").unlink(missing_ok=True)
        home, run = tmp / "home", tmp / "run"
        run.mkdir(mode=0o700)
        # Dossier personnel déjà habité : réglages à garder, fichiers à sauvegarder.
        (home / ".config/gtk-3.0").mkdir(parents=True)
        (home / ".config/gtk-3.0/settings.ini").write_text("[Settings]\ngtk-theme-name=Adwaita\ngtk-enable-animations=0\n")
        # Config gérée par un gestionnaire de dotfiles (stow) : un lien vers un autre dépôt.
        (home / "dots/qt6ct").mkdir(parents=True)
        (home / "dots/qt6ct/qt6ct.conf").write_text("[Appearance]\nstyle=Fusion\n")
        (home / ".config/qt6ct").mkdir()
        (home / ".config/qt6ct/qt6ct.conf").symlink_to(home / "dots/qt6ct/qt6ct.conf")
        # Profil Chromium existant, autre thème et autres réglages.
        (home / ".config/chromium/Default").mkdir(parents=True)
        (home / ".config/chromium/Default/Preferences").write_text('{"browser":{"x":1},"extensions":{"theme":{"system_theme":0}}}')
        # Web app déjà ouverte une fois : une extension externe refusée par l'utilisateur, à garder.
        (home / ".local/share/ice/profiles/DiscordWeb2996/Default").mkdir(parents=True)
        (home / ".local/share/ice/profiles/DiscordWeb2996/Default/Preferences").write_text(
            '{"extensions":{"external_uninstalls":["' + "a" * 32 + '"]}}')
        (home / ".config/mpv").mkdir()
        (home / ".config/mpv/mpv.conf").write_text("volume=50\n")
        (home / ".bashrc").write_text("alias ll='ls -l'\n")
        # Claude Code et Codex déjà utilisés : leurs autres réglages (et la mise en forme de settings.json) sont à garder.
        (home / ".claude").mkdir()
        (home / ".claude/settings.json").write_text('{\n  "theme": "dark",\n  "note": "réglage à garder"\n}\n')
        (home / ".codex").mkdir()
        (home / ".codex/config.toml").write_text(
            'model = "gpt-5"\n\n[tui]\nscreen_reader_detection_done = true\n\n[tui.model_availability_nux]\n"gpt-5" = 4\n')
        # Dossiers XDG par défaut d'un compte déjà connecté : Modèles et Projets vides, Public avec un fichier.
        xdg = {"DESKTOP": "Desktop", "DOWNLOAD": "Downloads", "TEMPLATES": "Templates", "PUBLICSHARE": "Public",
               "DOCUMENTS": "Documents", "MUSIC": "Music", "PICTURES": "Pictures", "VIDEOS": "Videos", "PROJECTS": "Projects"}
        (home / ".config/user-dirs.dirs").write_text("".join(f'XDG_{k}_DIR="$HOME/{v}"\n' for k, v in xdg.items()))
        for v in xdg.values():
            (home / v).mkdir()
        (home / "Public/partage.txt").write_text("à garder\n")
        icons = tmp / "system-icons"
        icon_dirs = fake_papirus(icons)
        cache = pathlib.Path(os.environ.get("QS_TEST_CACHE", tmp / "cache"))
        env = {k: v for k, v in os.environ.items() if not k.startswith(("XDG_", "DBUS_", "SWAYSOCK", "I3SOCK", "HYPRLAND", "WAYLAND", "DISPLAY"))}
        # Chromium factice si le vrai est là : lancé par l'import de nightTab et Stylus, il écrirait un profil complet dans le
        # dossier jetable (l'import est testé à part, scripts/extension-import.py sur une copie de profil).
        if shutil.which("chromium"):
            (tmp / "bin").mkdir()
            (tmp / "bin/chromium").write_text('#!/bin/sh\n[ "$1" = --version ] && echo "Chromium 0.0.0.0" && exit 0\nexit 1\n')
            (tmp / "bin/chromium").chmod(0o755)
            env["PATH"] = f"{tmp / 'bin'}:{env['PATH']}"
        # Import raté exprès (Chromium factice) : retenté à chaque passage, hors du test « sans changement ».
        IMPORTS = ("+ nightTab : ", "+ Stylus : ") if shutil.which("chromium") else ()
        env.update(HOME=str(home), XDG_RUNTIME_DIR=str(run), XDG_CACHE_HOME=str(cache), LANG="C.UTF-8", QS_INSTALL_ASSUME_CLOSED="1",
                   QS_PAPIRUS_DIR=str(icons / "Papirus"), QS_WALLPAPERS_REPO=git_repo(tmp / "src/wallpapers", "fond.png"),
                   QS_DM_REPO=git_repo(tmp / "src/gms", "install-all.sh"))

        def install(*args, profile=("--profil", "jeux"), path=None, system=False):
            cmd = ["dbus-run-session", "--", "bash", "-c", 'dconf load / < "$0" 2>/dev/null; bash "$1" "${@:2}"; rc=$?; dconf dump / > "$0"; exit $rc',
                   str(tmp / "dconf.ini"), str(repo / "install.sh"), "--no-packages", *(() if system else ("--no-system",)),
                   *profile, *args]
            log = open(tmp / "last.log", "w")
            try:
                # Nouvelle session sans terminal : les questions d'install.sh répondent « non » sans attendre.
                r = subprocess.run(cmd, env=dict(env, PATH=path) if path else env, stdout=subprocess.PIPE, stderr=log, stdin=subprocess.DEVNULL, text=True,
                                   timeout=300, start_new_session=True)
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

        # Arch minimal (archinstall, profil « minimal ») : pas encore de python3, installé à l'étape 1.
        nopy = tmp / "bin-nopython"
        nopy.mkdir()
        for d in os.environ["PATH"].split(":"):
            for exe in (pathlib.Path(d).iterdir() if pathlib.Path(d).is_dir() else []):
                if not exe.name.startswith("python") and not (nopy / exe.name).exists():
                    (nopy / exe.name).symlink_to(exe)
        host_saved = host_json.read_text() if host_json.exists() else None
        host_json.write_text('{\n  "profile": "travail"\n}\n')
        r = install("--dry-run", profile=(), path=str(nopy))
        check(r.returncode == 0 and "Profil : travail (hosts/" in r.stdout,
              f"sans python3 : simulation complète, profil lu dans hosts/ (code {r.returncode}) {r.stderr.strip()[-300:]}")
        host_json.write_text(host_saved) if host_saved is not None else host_json.unlink()

        # Écran de démarrage Plymouth (étape système, simulée) : profil travail seulement ; une machine jeux qui ne l'a jamais
        # eu n'est pas touchée.
        if not pathlib.Path("/usr/share/plymouth/themes/qs-corelab").exists():
            r = install("--dry-run", "--yes", profile=("--profil", "travail"), system=True)
            # Copie de test sans .git : le détail (git archive) n'est pas simulé ici ; essais réels en VM (docs/DEVELOPMENT.md).
            check(r.returncode == 0 and "Écran de démarrage Plymouth Core Lab (thème" in r.stdout,
                  f"simulation système, travail : Plymouth prévu (code {r.returncode})")
            r = install("--dry-run", "--yes", system=True)
            check(r.returncode == 0 and "plymouth" not in r.stdout.lower().replace("plymouth-vm", ""),
                  f"simulation système, jeux : rien de Plymouth (code {r.returncode})")
        # plymouth-setup.sh lui-même, depuis le dépôt (git archive), sur un hôte GRUB : install.sh avale ses échecs (sub).
        # Code 3 : hôte non pris en charge (pas de GRUB, pas de mkinitcpio), test sans objet.
        r = subprocess.run([str(REPO / "scripts/plymouth-setup.sh"), "--dry-run", "install"], capture_output=True, text=True)
        if r.returncode != 3:
            check(r.returncode == 0 and "Écran de démarrage Core Lab au prochain démarrage" in r.stdout
                  and ("+ mkinitcpio -P" in r.stdout or "= hook plymouth" in r.stdout),
                  f"plymouth-setup.sh --dry-run install (code {r.returncode}) {r.stderr.strip()[-300:]}")
            r = subprocess.run([str(REPO / "scripts/plymouth-setup.sh"), "--dry-run", "uninstall"], capture_output=True, text=True)
            check(r.returncode == 0, f"plymouth-setup.sh --dry-run uninstall (code {r.returncode}) {r.stderr.strip()[-300:]}")
        # Quirks libinput de la machine (étape système) : posés si dotfiles/libinput/hosts/<hostname>.quirks existe.
        if (REPO / f"dotfiles/libinput/hosts/{pathlib.Path('/proc/sys/kernel/hostname').read_text().strip()}.quirks").exists():
            r = subprocess.run([str(REPO / "scripts/system-setup.sh"), "--dry-run", "install"], capture_output=True, text=True)
            check(r.returncode == 0 and "/etc/libinput/local-overrides.quirks" in r.stdout,
                  f"system-setup.sh --dry-run install : quirks libinput de la machine (code {r.returncode})")

        r = install("--dry-run")
        check(r.returncode == 0, f"simulation : code {r.returncode} {r.stderr.strip()[-300:]}")
        if shutil.which("chromium"):
            check("+ nightTab : " in r.stdout and "+ Stylus : " in r.stdout,
                  "simulation : réglages de nightTab et styles de Stylus prévus (dotfiles/chromium/*.json lus)")
        now = snapshot(home)
        written = sorted(set(before) ^ set(now)) + sorted(k for k in before if k in now and before[k] != now[k])
        check(not written and (tmp / "dconf.ini").read_text() == dconf_before, f"simulation : rien d'écrit {written[:8]}")

        r = install()
        check(r.returncode == 0, f"installation : code {r.returncode} {r.stderr.strip()[-300:]}")
        desktop = home / ".local/share/applications/qs-windows11.desktop"
        check(desktop.is_file() and "Name=Windows 11" in desktop.read_text(), "Windows 11 : entrée native installée")
        cfg = home / ".config"
        check((home / "Pictures/Wallpapers/fond.png").is_file(), "fonds d'écran clonés sans question")
        check(json.loads(host_json.read_text()).get("profile") == "jeux", "config machine : profil jeux (--profil)")
        check(not (home / "GMSFreeAnalysis17").exists(), "profil jeux : dépôt de DigitalMicrograph non cloné")
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
        bases = [home / ".local/share/icons", icons]

        def papirus_ok():
            shown = {(t, d, n): os.path.basename(icon(bases, t, d, n)) for t in ("Papirus", "Papirus-Dark")
                     for d in icon_dirs if not d.startswith("16x16") for n in ("folder.svg", "folder-video.svg", "folder-videos.svg")}
            blue = [k for k, v in shown.items() if "cat-mocha-lavender" not in v]
            kept = {os.path.basename(icon(bases, "Papirus-Dark", d, "folder-blue-videos.svg")) for d in ("48x48/places", "96x96/places")}
            return blue, kept

        blue, kept = papirus_ok()
        check(not blue, f"Papirus : lavande à toutes les tailles (zoom 96/128, @2x), chaînes de liens comprises {blue[:4]}")
        check(kept == {"folder-blue-video.svg"}, f"Papirus : nom explicitement bleu gardé bleu {kept}")
        dirs = sorted(p.name for p in home.iterdir() if p.is_dir() and not p.name.startswith(".") and p.name != "dots")
        check(dirs == ["Applications", "Desktop", "Documents", "Downloads", "Music", "Pictures", "Public", "Videos"],
              f"dossiers du compte : Modèles et Projets vides retirés, Public non vide gardé, Applications créé {dirs}")
        ud = (cfg / "user-dirs.dirs").read_text()
        check(all(f'XDG_{k}_DIR="$HOME/"' in ud for k in ("TEMPLATES", "PUBLICSHARE", "PROJECTS"))
              and 'XDG_PICTURES_DIR="$HOME/Pictures"' in ud, "user-dirs.dirs : Modèles, Public, Projets désactivés, autres gardés")

        # Machine installée avec l'ancienne surcouche (marque = empreinte seule, sans 96x96) : refaite au passage suivant.
        for t in ("Papirus", "Papirus-Dark"):
            mark = home / ".local/share/icons" / t / ".qs-desktop"
            mark.write_text(mark.read_text().split("-r")[0] + "\n")
            target = home / ".local/share/icons" / t / "96x96"
            shutil.rmtree(target) if target.is_dir() and not target.is_symlink() else target.unlink()
        install()
        blue, _ = papirus_ok()
        check(not blue, f"Papirus : ancienne surcouche refaite {blue[:4]}")
        dconf = (tmp / "dconf.ini").read_text()
        check("accent-color='green'" in dconf and "gtk-theme='catppuccin-mocha-green-standard+default'" in dconf, "dconf appliqué")
        check("[org/cinnamon/desktop/applications/terminal]\nexec='gnome-terminal'" in dconf, "dconf : terminal de Nemo")
        mime = (cfg / "mimeapps.list").read_text() if (cfg / "mimeapps.list").exists() else ""
        check("video/mp4=io.github.celluloid_player.Celluloid.desktop" in mime or "Celluloid" not in mime and not shutil.which("celluloid"),
              "applications par défaut")
        check(any((home / ".local/share/applications").glob("WebApp-*.desktop")), "web apps générées")
        gs = home / ".local/share/applications/gammastep-indicator.desktop"
        check(gs.is_symlink() and "NoDisplay=true" in gs.read_text(), "lanceur : Gammastep Indicator masqué")
        # Barres d'état (réglées seulement si l'application est installée sur la machine de test).
        if shutil.which("claude"):
            text = (home / ".claude/settings.json").read_text()
            cs = json.loads(text)
            line = home / ".claude/statusline-command.sh"
            check(cs.get("note") == "réglage à garder" and cs.get("statusLine") == {"type": "command", "command": f"bash {line}"}
                  and text.startswith('{\n  "') and text.endswith("}\n") and "réglage" in text
                  and os.readlink(line) == str(repo / "dotfiles/claude/statusline-command.sh"),
                  "Claude Code : barre d'état déclarée, script lié, autres réglages et mise en forme gardés")
            payload = {"model": {"display_name": "Opus"}, "context_window": {"context_window_size": 200000, "used_percentage": 25,
                       "current_usage": {"input_tokens": 50000}}, "rate_limits": {"five_hour": {"used_percentage": 12, "resets_at": 1700000000},
                       "seven_day": {"used_percentage": 90, "resets_at": 1700000000}}}
            out = subprocess.run(["bash", str(line)], input=json.dumps(payload), capture_output=True, text=True, env=env).stdout
            check(out.startswith("Opus | [####------------] | 25% | 50k / 200k | ") and "5h 12%" in out and "Sem 90%" in out,
                  f"Claude Code : barre d'état affichée {out!r}")
        if shutil.which("codex"):
            import tomllib
            ct = tomllib.loads((home / ".codex/config.toml").read_text())
            check(ct.get("model") == "gpt-5" and ct["tui"].get("screen_reader_detection_done") is True
                  and ct["tui"].get("status_line", [""])[0] == "model-with-reasoning" and len(ct["tui"]["status_line"]) == 7
                  and ct["tui"]["model_availability_nux"] == {"gpt-5": 4}, "Codex : barre d'état réglée, autres réglages gardés")

        r = install()
        deluge = (cfg / "deluge/gtk3ui.conf").read_text()
        check('"enable_system_tray": false' in deluge and deluge.startswith("{"), "Deluge : pas d'icône dans la barre")
        prefs = json.loads((cfg / "chromium/Default/Preferences").read_text())
        webapp = home / ".local/share/ice/profiles/Whatsapp8699/Default/Preferences"
        wprefs = json.loads(webapp.read_text())
        ids = [l.split()[0] for l in (repo / "dotfiles/chromium/extensions.txt").read_text().splitlines() if l and l[0] != "#"]
        check(prefs["extensions"]["theme"]["system_theme"] == 1 and prefs["browser"] == {"x": 1, "custom_chrome_frame": False}
              and "external_uninstalls" not in prefs["extensions"]
              and wprefs["extensions"]["theme"]["system_theme"] == 1 and wprefs["browser"]["custom_chrome_frame"] is False,
              "Chromium et web apps : thème GTK, barre de titre du système, autres réglages gardés")
        discord = json.loads((home / ".local/share/ice/profiles/DiscordWeb2996/Default/Preferences").read_text())
        check(len(ids) == 9 and wprefs["extensions"]["external_uninstalls"] == ids
              and discord["extensions"]["external_uninstalls"] == ["a" * 32] + ids,
              "web apps : extensions du navigateur refusées, refus existant gardé")
        qt = home / ".config/qt6ct/qt6ct.conf"
        check(qt.is_symlink() and "style=kvantum" in (home / "dots/qt6ct/qt6ct.conf").read_text(),
              "config liée (stow) : lien gardé, réglage écrit à travers")
        check(gtk3.endswith("\n") and (cfg / "qt6ct/qt6ct.conf").read_text().endswith("\n"), "fichiers réglés : saut de ligne final")
        changes = [l for l in r.stdout.splitlines() if l.startswith("+ ") and not l.startswith(IMPORTS)]
        check(r.returncode == 0 and not changes, f"second passage sans changement {changes[:5]}")

        # Une application (Viewnior) réécrit son réglage après l'installation : sa version doit survivre au retrait.
        (cfg / "viewnior/viewnior.conf").write_text("[prefs]\nzoom-mode=3\n")
        r = install("--uninstall")
        kept_v = sorted((cfg / "viewnior").glob("viewnior.conf.uninstall-*"))
        check(len(kept_v) == 1 and "zoom-mode=3" in kept_v[0].read_text(), "retrait : réglage modifié par l'application gardé à côté")
        for k in kept_v: k.unlink()
        check(r.returncode == 0, f"retrait : code {r.returncode} {r.stderr.strip()[-300:]}")
        after = snapshot(home)
        diff = sorted(set(before) ^ set(after)) + sorted(k for k in before if k in after and before[k] != after[k])
        # Restes acceptés : dossiers vides créés en chemin, clones (tes données).
        diff = [k for k in diff if not (k in after and after[k] == "<dir>" and k not in before)
                and not k.startswith(("Pictures/Wallpapers", "GMSFreeAnalysis17"))]
        kept = sorted(k for k in diff if ".uninstall-" in k)
        check(not kept, f"retrait : aucune copie .uninstall- pour des fichiers inchangés depuis l'installation {kept[:4]}")
        check(not diff, f"retrait : dossier personnel comme avant {diff[:8]}")
        check(qt.is_symlink() and (home / "dots/qt6ct/qt6ct.conf").read_text() == "[Appearance]\nstyle=Fusion\n",
              "retrait : config liée (stow) remise, lien gardé")
        check(not webapp.exists(), "retrait : profil de web app créé pour ses réglages retiré")
        check("font-name='Cantarell 11'" in (tmp / "dconf.ini").read_text()
              and "accent-color" not in (tmp / "dconf.ini").read_text(), "retrait : dconf comme avant")

        # Profil absent de la config machine : question (sans terminal, réponse « non » → travail), écrit en tête du fichier.
        conf = json.loads(host_json.read_text())
        conf.pop("profile", None)
        host_json.write_text(json.dumps(conf, indent=2) + "\n")
        r = install(profile=())
        text = host_json.read_text()
        rest = json.loads(text)
        check(r.returncode == 0 and rest.pop("profile", None) == "travail" and rest == conf and text.startswith('{\n  "profile": "travail"'),
              f"profil travail par défaut, écrit dans la config machine, reste gardé {r.stderr.strip()[-200:]}")
        check(not (cfg / "deluge/gtk3ui.conf").exists(), "profil travail : Deluge non réglé")
        check((home / "GMSFreeAnalysis17/install-all.sh").is_file() and "DigitalMicrograph : copier le kit Gatan" in r.stdout,
              "profil travail : dépôt de DigitalMicrograph cloné, installation rappelée")
        r = install(profile=())
        changes = [l for l in r.stdout.splitlines() if l.startswith("+ ") and not l.startswith(IMPORTS)]
        check(r.returncode == 0 and not changes and "Profil : travail (hosts/" in r.stdout, f"profil travail : second passage sans changement {changes[:5]}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print(f"\n{len(failures)} échec(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
