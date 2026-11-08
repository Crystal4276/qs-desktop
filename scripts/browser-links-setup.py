#!/usr/bin/env python3
"""Install the user Chromium desktop override, preserving its MIME identity."""
import argparse
import fcntl
import os
from pathlib import Path
import stat


def desktop(source, script):
    # Keep translations, actions and Chromium's own desktop identity intact.
    value = str(script)
    if any(c in value for c in '\n\r='):
        raise ValueError('Unsupported path for a desktop Exec key')
    quoted = value.replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$')
    quoted = quoted.replace('\\', '\\\\').replace('%', '%%')
    result = []
    section = ''
    replaced = False
    for line in source.splitlines(keepends=True):
        if line.startswith('['):
            section = line.strip()
        if section == '[Desktop Entry]' and line.startswith('Exec='):
            if line.strip() not in ('Exec=chromium %U', 'Exec=/usr/bin/chromium %U'):
                raise ValueError('Custom Chromium Exec: preserve it and review before installation')
            line = f'Exec=python3 "{quoted}" %U\n'
            replaced = True
        result.append(line)
    if not replaced:
        raise ValueError('Chromium desktop entry has no supported Exec')
    return ''.join(result).encode()


def setup(action, target, state, source, script, dry=False):
    if action == 'uninstall' and not (state/'ready').is_file():
        raise ValueError('No recorded browser-links installation')
    if state.is_symlink() or target.is_symlink():
        raise ValueError('Refusing a symlink at the override or state destination')
    expected = desktop(source.read_text(), script) if action == 'install' else (state/'installed').read_bytes()
    if action == 'install' and not state.exists() and target.exists():
        desktop(target.read_text(), script)  # Refuse to replace a custom launcher.
    if dry:
        print(action, target, '(dry run)')
        return
    state.parent.mkdir(parents=True, exist_ok=True)
    # Stable lock outside the removable registry, including install/uninstall races.
    fd = os.open(state.parent/'browser-links.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if state.exists():
            if not (state/'ready').is_file():
                raise ValueError('Incomplete registry: preserve it for recovery')
            if target.exists() and target.read_bytes() != (state/'installed').read_bytes():
                raise ValueError('Local desktop override was edited; preserving it')
        elif action == 'install':
            state.mkdir(mode=0o700)
            if target.exists():
                desktop(target.read_text(), script)
                (state/'original').write_bytes(target.read_bytes())
                (state/'original').chmod(0o600)
                (state/'mode').write_text(str(stat.S_IMODE(target.stat().st_mode)))
            (state/'installed').write_bytes(expected)
            (state/'ready').touch()
        else:
            raise ValueError('No recorded browser-links installation')
        if action == 'install':
            target.parent.mkdir(parents=True, exist_ok=True)
            temp = target.with_name(target.name + '.qs-tmp')
            temp.write_bytes(expected)
            temp.chmod(0o644)
            temp.replace(target)
            (state/'installed').write_bytes(expected)
        else:
            if (state/'original').exists():
                target.write_bytes((state/'original').read_bytes())
                target.chmod(int((state/'mode').read_text()))
            else:
                target.unlink(missing_ok=True)
            for name in ('original', 'mode', 'installed', 'ready'):
                (state/name).unlink(missing_ok=True)
            state.rmdir()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('action', choices=['install', 'uninstall'])
    args = parser.parse_args()
    target = Path(os.environ.get('XDG_DATA_HOME', str(Path.home()/'.local/share')))/'applications/chromium.desktop'
    state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state')))/'qs-desktop/browser-links'
    setup(args.action, target, state, Path('/usr/share/applications/chromium.desktop'),
          Path(__file__).resolve().with_name('browser-link.py'), args.dry_run)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        raise SystemExit(str(error))
