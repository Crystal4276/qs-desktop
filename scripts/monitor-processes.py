#!/usr/bin/env python3
"""Short-lived /proc sampler and identity-checked signal sender. JSON on stdin/stdout."""
import json
import os
from pathlib import Path
import pwd
import shlex
import signal
import sys
import subprocess


def arguments(raw):
    args = raw.decode(errors='replace').rstrip('\0').split('\0')
    # Chromium rewrites its process title into a single argv slot.
    if len(args) == 1:
        try:
            return shlex.split(args[0])
        except ValueError:
            return []
    return args


def options(args):
    result = {}
    for i, arg in enumerate(args):
        if arg.startswith('--'):
            key, sep, value = arg.partition('=')
            result[key] = value if sep else (args[i + 1] if i + 1 < len(args) and not args[i + 1].startswith('-') else '')
    return result


def executable(args):
    args = list(args)
    if args and os.path.basename(args[0]) == 'env':
        args.pop(0)
        while args and ('=' in args[0] or args[0].startswith('-')):
            args.pop(0)
    return os.path.basename(args[0]) if args else ''


def snapshot():
    rows = []
    names = {}
    for path in Path('/proc').iterdir():
        if not path.name.isdecimal() or int(path.name) == os.getpid():
            continue
        try:
            stat = (path / 'stat').read_text()
            left, right = stat.index('('), stat.rindex(')')
            fields = stat[right + 2:].split()
            if fields[0] == 'Z':
                continue
            uid = path.stat().st_uid
            if uid not in names:
                try:
                    names[uid] = pwd.getpwuid(uid).pw_name
                except KeyError:
                    names[uid] = str(uid)
            pid, start = int(path.name), fields[19]
            args = arguments((path / 'cmdline').read_bytes()) if uid == os.getuid() else []
            rows.append(dict(pid=pid, key=f'{pid}:{start}', start=start, ppid=int(fields[1]), uid=uid,
                             user=names[uid], name=stat[left + 1:right], ticks=int(fields[11]) + int(fields[12]),
                             memory=int(fields[21]) * os.sysconf('SC_PAGE_SIZE'), args=args))
        except (OSError, ValueError, IndexError):
            continue
    return rows


def identify(rows, entries, previous, windows=()):
    """Specific launch arguments outrank executable matches; ambiguity never merges apps."""
    catalog = []
    for entry in entries:
        args = entry.get('command', [])
        exe = executable(args)
        if exe:
            catalog.append((entry, exe, options(args)))
    assigned = {}
    bypid = {p['pid']: p for p in rows}
    labels = {}
    for p in rows:
        if p['uid'] != os.getuid():
            continue
        args, opts = p['args'], options(p['args'])
        exe = executable(args)
        # A worker's launch command must not make it an independent application.
        if '--type' in opts:
            continue
        candidates = []
        for entry, wanted, flags in catalog:
            if exe != wanted and p['name'] != wanted:
                continue
            discriminants = [k for k in ('--user-data-dir', '--class', '--name', '--app-id', '--app') if k in flags]
            # The URL may change (deep links); profile is the webapp identity.
            if '--user-data-dir' in flags:
                discriminants = ['--user-data-dir']
            if any(opts.get(k) != flags[k] for k in discriminants):
                continue
            # Generic Chromium launcher cannot claim an unknown webapp/profile.
            if not discriminants and any(k in opts for k in ('--app', '--app-id', '--user-data-dir')):
                continue
            candidates.append((len(discriminants), entry))
        if candidates:
            score = max(c[0] for c in candidates)
            best = [e for s, e in candidates if s == score]
            ids = {e['id'] for e in best}
            if len(ids) == 1:
                entry = best[0]
                assigned[p['key']] = entry['id']
                labels[entry['id']] = entry['name']
        if p['key'] not in assigned and ('--app' in opts or '--app-id' in opts) and opts.get('--user-data-dir'):
            identity = 'profile:' + opts['--user-data-dir']
            assigned[p['key']] = identity
            labels[identity] = 'Web app (' + os.path.basename(opts['--user-data-dir']) + ')'
    # Window PID is authoritative for wrappers (terminal server, Steam, scripts).
    for window in windows:
        p = bypid.get(window['pid'])
        if not p or p['uid'] != os.getuid() or p['key'] in assigned:
            continue
        app = window['appId']
        matches = [e for e in entries if app.lower() in
                   (e['id'].removesuffix('.desktop').lower(), e.get('startupClass', '').lower())]
        identity = matches[0]['id'] if len(matches) == 1 else 'window:' + app
        assigned[p['key']] = identity
        labels[identity] = matches[0]['name'] if len(matches) == 1 else app
    # Crash handlers may be reparented before the very first sample.
    profiles = {}
    for p in rows:
        profile = options(p['args']).get('--user-data-dir')
        if not profile and executable(p['args']) == 'chromium':
            profile = str(Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'chromium')
        if profile and p['key'] in assigned:
            profiles[profile] = assigned[p['key']]
    for p in rows:
        opts = options(p['args'])
        matches = {identity for profile, identity in profiles.items()
                   if opts.get('--user-data-dir') == profile
                   or opts.get('--database', '').startswith(profile.rstrip('/') + '/')}
        if len(matches) == 1 and p['uid'] == os.getuid() and p['key'] not in assigned:
            assigned[p['key']] = matches.pop()
    # Recover known orphans, preserving start time as part of their identity.
    for p in rows:
        old = previous.get(p['key'])
        if old and p['uid'] == os.getuid() and p['key'] not in assigned:
            assigned[p['key']] = old['id']
            labels.setdefault(old['id'], old['name'])
    def owner(p, seen):
        key = p['key']
        if key in assigned:
            return assigned[key]
        if key in seen or p['uid'] != os.getuid():
            return None
        parent = bypid.get(p['ppid'])
        result = owner(parent, seen | {key}) if parent else None
        if result:
            assigned[key] = result
        return result
    for p in rows:
        owner(p, set())
    groups = {}
    for p in rows:
        identity = assigned.get(p['key'])
        if not identity:
            continue
        group = groups.setdefault(identity, dict(id=identity, name=labels[identity], members=[], roots=[]))
        group['members'].append(p['key'])
        parent = bypid.get(p['ppid'])
        if not parent or assigned.get(parent['key']) != identity:
            group['roots'].append(p['key'])
    window_apps = {}
    for window in windows:
        window_apps.setdefault(window['pid'], set()).add(window['appId'])
    for group in groups.values():
        group['blocked'] = any(len(window_apps.get(bypid[int(key.split(':')[0])]['pid'], set())) > 1
                               for key in group['members'])
    return list(groups.values())


def send_one(member, force):
    pid, start = member.split(':')
    fd = os.pidfd_open(int(pid))
    try:
        path = Path('/proc') / pid
        if path.stat().st_uid != os.getuid() or path.joinpath('stat').read_text().rsplit(')', 1)[1].split()[19] != start:
            raise PermissionError('Process identity changed')
        signal.pidfd_send_signal(fd, signal.SIGKILL if force else signal.SIGTERM)
    finally:
        os.close(fd)


def stop(request, rows, groups):
    allowed = {p['key'] for p in rows if p['uid'] == os.getuid()}
    targets = set(request['members']) & allowed
    if request.get('application'):
        group = next((g for g in groups if g['id'] == request['application']), None)
        if group and group.get('blocked'):
            return ['This process hosts multiple applications; grouped termination is unavailable']
        targets &= set(group['members']) if group else set()
        if group:
            bykey = {p['key']: p for p in rows}
            bypid = {p['pid']: p for p in rows}
            roots = set(request['roots'])
            # Fresh descendants of confirmed roots, excluding newly launched instances.
            for key in group['members']:
                p, seen = bykey[key], set()
                while p and p['key'] not in seen:
                    if p['key'] in roots:
                        targets.add(key)
                        break
                    seen.add(p['key'])
                    p = bypid.get(p['ppid'])
    errors = []
    for key in sorted(targets, key=lambda k: k in request.get('roots', [])):
        try:
            send_one(key, request.get('force', False))
        except ProcessLookupError:
            pass
        except OSError as error:
            errors.append(f'{key.split(":")[0]}: {error.strerror or str(error)}')
    return errors


def windows(request):
    if os.environ.get('SWAYSOCK'):
        try:
            result = subprocess.run(['swaymsg', '-t', 'get_tree', '-r'], capture_output=True, timeout=2, check=True)
            found = []
            def walk(node):
                app = node.get('app_id') or (node.get('window_properties') or {}).get('class')
                if app and node.get('pid'):
                    found.append(dict(pid=node['pid'], appId=app))
                for child in node.get('nodes', []) + node.get('floating_nodes', []):
                    walk(child)
            walk(json.loads(result.stdout))
            return found
        except (OSError, ValueError, subprocess.SubprocessError):
            return []
    return request.get('windows', [])


def cpu_total(text):
    # guest/guest_nice are subsets of user/nice, not additional elapsed time.
    return sum(map(int, text.splitlines()[0].split()[1:9]))


def main():
    request = json.load(sys.stdin)
    rows = snapshot()
    groups = identify(rows, request.get('entries', []), request.get('previous', {}), windows(request))
    if request.get('action') == 'stop':
        print(json.dumps(dict(errors=stop(request, rows, groups))))
    else:
        total = cpu_total(Path('/proc/stat').read_text())
        # Raw arguments never leave the helper.
        print(json.dumps(dict(total=total, processes=[{k:v for k,v in p.items() if k != 'args'} for p in rows], applications=groups)))


if __name__ == '__main__':
    main()
