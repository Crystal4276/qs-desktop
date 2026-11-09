#!/usr/bin/env python3
"""Clés GSettings (dconf) du compte, pour install.sh.

apply <réglages.ini> <anciennes.ini> <HOME> : écrit seulement les clés qui diffèrent ; l'ancienne valeur de chaque clé changée
    est notée une seule fois dans <anciennes.ini> (« @unset » si elle n'était pas définie), pour `restore`.
restore <anciennes.ini> : remet ces valeurs (et efface les clés qui n'existaient pas), sauf pour une clé modifiée depuis
    l'installation (valeur écrite notée dans <anciennes.ini>.written) : elle est gardée.
--dry-run : affiche sans écrire. Format des .ini : sections = chemins dconf sans « / » initial, valeurs GVariant texte
(comme `dconf dump`) ; @HOME@ remplacé par le dossier personnel.
"""
import configparser
import os
import subprocess
import sys

from gi.repository import GLib


def read_ini(path):
    ini = configparser.RawConfigParser(delimiters=("=",), comment_prefixes=("#",), interpolation=None, strict=False)
    ini.optionxform = str
    ini.read(path, encoding="utf-8")
    return ini


def same(a, b):
    try:
        return GLib.Variant.parse(None, a, None, None).equal(GLib.Variant.parse(None, b, None, None))
    except GLib.Error:
        return a.strip() == b.strip()


def dconf(*args):
    return subprocess.run(["dconf", *args], check=True, capture_output=True, text=True).stdout.strip()


def act(dry, *args):
    print("+ dconf " + " ".join(args))
    if not dry:
        dconf(*args)


def apply(dry, settings, old_path, home):
    wanted, old, new = read_ini(settings), read_ini(old_path), read_ini(old_path + ".written")
    todo = []
    for section in wanted.sections():
        for key, value in wanted.items(section):
            value = value.replace("@HOME@", home)
            current = dconf("read", f"/{section}/{key}")
            if current and same(current, value):
                continue
            if not old.has_section(section):
                old.add_section(section)
            if not old.has_option(section, key):
                old.set(section, key, current or "@unset")
            if not new.has_section(section):
                new.add_section(section)
            new.set(section, key, value)
            todo.append((f"/{section}/{key}", value))
    if not todo:
        print(f"= dconf : {settings.rsplit('/', 2)[-2]}/{settings.rsplit('/', 1)[-1]} déjà appliqué")
        return
    # Anciennes valeurs enregistrées avant la première écriture : une écriture qui échoue en route reste réversible.
    if not dry:
        os.makedirs(os.path.dirname(old_path), exist_ok=True)
        with open(old_path, "w", encoding="utf-8") as f:
            old.write(f)
        with open(old_path + ".written", "w", encoding="utf-8") as f:
            new.write(f)
    for path, value in todo:
        act(dry, "write", path, value)


def restore(dry, old_path):
    old, new = read_ini(old_path), read_ini(old_path + ".written")
    for section in old.sections():
        for key, value in old.items(section):
            path = f"/{section}/{key}"
            written = new.get(section, key, fallback=None)
            current = dconf("read", path)
            if written is not None and current and not same(current, written):
                print(f"! dconf {path} modifié depuis l'installation : gardé ({current})")
                continue
            if value == "@unset":
                act(dry, "reset", path)
            else:
                act(dry, "write", path, value)


def main(argv):
    dry = argv[:1] == ["--dry-run"]
    argv = argv[1:] if dry else argv
    if argv[:1] == ["apply"] and len(argv) == 4:
        apply(dry, *argv[1:])
    elif argv[:1] == ["restore"] and len(argv) == 2:
        restore(dry, argv[1])
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
