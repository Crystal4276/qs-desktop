#!/usr/bin/env python3
"""Private Thunderbird launch logs and read-only snapshots; never stops an application."""
import argparse
import datetime
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ENV_KEYS = ('XDG_SESSION_ID', 'XDG_SESSION_TYPE', 'XDG_CURRENT_DESKTOP',
            'XDG_RUNTIME_DIR', 'WAYLAND_DISPLAY', 'DISPLAY', 'SWAYSOCK',
            'HYPRLAND_INSTANCE_SIGNATURE', 'MOZ_ENABLE_WAYLAND', 'GDK_BACKEND')
SESSION_KEYS = ('Id', 'State', 'Active', 'Type', 'Class', 'Service', 'Seat', 'Leader')


def stamp():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def private_file(path, mode='w'):
    fd = os.open(path, os.O_CREAT | os.O_WRONLY | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    os.fchmod(fd, 0o600)
    return os.fdopen(fd, mode)


def write_json(path, data):
    with private_file(path) as stream:
        json.dump(data, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def save_metadata(path, data):
    try:
        write_json(path, data)
    except OSError as error:
        print(f'Thunderbird metadata unavailable: {type(error).__name__}', file=sys.stderr)


def new_record(kind):
    base = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state') / 'qs-desktop/thunderbird-diagnostic'
    base.mkdir(parents=True, exist_ok=True, mode=0o700)
    if base.is_symlink() or base.stat().st_uid != os.getuid():
        raise OSError('Diagnostic directory must belong to this user and not be a symlink')
    base.chmod(0o700)
    # Serialize retention with manual captures and simultaneous launches. Never prune a live recorder.
    with private_file(base / '.rotation.lock') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        path = base / f'{kind}-{time.time_ns()}-{os.getpid()}'
        path.mkdir(mode=0o700)
        active = private_file(path / '.active')
        fcntl.flock(active, fcntl.LOCK_EX)
        finished = []
        for old in sorted(base.glob(f'{kind}-*'), reverse=True):
            if old == path or old.is_symlink() or not old.is_dir():
                continue
            try:
                with (old / '.active').open('r') as stream:
                    fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    finished.append(old)
            except (OSError, BlockingIOError):
                continue
        for old in finished[4:]:
            shutil.rmtree(old)
    return path, active


def session_info(session):
    try:
        result = subprocess.run(['loginctl', 'show-session', session, '--no-pager',
                                 *[f'--property={key}' for key in SESSION_KEYS]],
                                capture_output=True, text=True, timeout=2)
        fields = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
        return {key: fields[key] for key in SESSION_KEYS if key in fields} | {'query_returncode': result.returncode}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {'query_error': type(error).__name__}


def identity(path):
    fields = (path / 'stat').read_text().rsplit(')', 1)[1].split()
    return {'state': fields[0], 'ppid': int(fields[1]), 'start_ticks': fields[19]}


def snapshot():
    result = {'time': stamp(), 'uid': os.getuid(),
              'environment': {key: os.environ[key] for key in ENV_KEYS if key in os.environ},
              'sessions': {}, 'processes': []}
    own_session = os.environ.get('XDG_SESSION_ID')
    if own_session:
        result['sessions'][own_session] = session_info(own_session)
    try:
        kernel_locks = Path('/proc/locks').read_text().splitlines()
    except OSError:
        kernel_locks = []
    for path in Path('/proc').iterdir():
        if not path.name.isdecimal():
            continue
        try:
            if path.stat().st_uid != os.getuid():
                continue
            exe = os.readlink(path / 'exe').removesuffix(' (deleted)')
            if Path(exe).name not in ('thunderbird', 'thunderbird-bin'):
                continue
            item = {'pid': int(path.name), 'exe': exe, **identity(path)}
        except (OSError, ValueError, IndexError):
            continue
        try:
            item['cgroup'] = (path / 'cgroup').read_text().splitlines()
            sessions = set(re.findall(r'/session-([^/]+)\.scope(?:/|$)', '\n'.join(item['cgroup'])))
            item['cgroup_sessions'] = sorted(sessions)
            raw = (path / 'environ').read_bytes().split(b'\0')
            item['environment'] = {key.decode(): value.decode(errors='replace')
                                   for entry in raw if b'=' in entry
                                   for key, value in [entry.split(b'=', 1)] if key.decode(errors='replace') in ENV_KEYS}
            # Environment is recorded separately: it is inherited and is not proof of session membership.
            for session in sessions | {item['environment'].get('XDG_SESSION_ID', '')}:
                if session and session not in result['sessions']:
                    result['sessions'][session] = session_info(session)
            item['lock_files'] = []
            for fd in (path / 'fd').iterdir():
                try:
                    target = os.readlink(fd)
                    if Path(target).name not in ('.parentlock', 'parent.lock', 'lock'):
                        continue
                    stat = fd.stat()
                    item['lock_files'].append({'fd': int(fd.name), 'path': target,
                                               'device': stat.st_dev, 'inode': stat.st_ino})
                except OSError:
                    continue
            item['kernel_locks'] = [line for line in kernel_locks
                                    if len(line.split()) > 4 and line.split()[4] == path.name]
            item['threads'] = []
            for task in (path / 'task').iterdir():
                try:
                    item['threads'].append({'tid': int(task.name), **identity(task),
                                            'wchan': (task / 'wchan').read_text().strip()})
                except (OSError, ValueError, IndexError):
                    continue
            if identity(path)['start_ticks'] != item['start_ticks']:
                continue
        except (OSError, ValueError, IndexError) as error:
            item['collection_error'] = type(error).__name__
        result['processes'].append(item)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('run', 'snapshot'))
    parser.add_argument('arguments', nargs=argparse.REMAINDER, help='Thunderbird arguments, only with run')
    args = parser.parse_args()
    if args.action == 'snapshot' and args.arguments:
        parser.error('snapshot takes no Thunderbird arguments')
    command = ['thunderbird', *args.arguments]
    try:
        record, active = new_record('launch' if args.action == 'run' else 'snapshot')
        write_json(record / 'before.json', snapshot())
    except (OSError, ValueError) as error:
        print(f'Thunderbird diagnostic unavailable: {type(error).__name__}', file=sys.stderr)
        if args.action == 'snapshot':
            return 1
        os.execvp(command[0], command)
    print(f'Thunderbird diagnostic: {record}', flush=True)
    with active:
        if args.action == 'snapshot':
            return 0
        started = stamp()
        # Keep arguments out of the metadata (a mailto URL can contain private message text).
        try:
            output = private_file(record / 'output.log')
        except OSError as error:
            print(f'Thunderbird output log unavailable: {type(error).__name__}', file=sys.stderr)
            os.execvp(command[0], command)
        with output:
            try:
                child = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT)
            except OSError as error:
                save_metadata(record / 'exit.json', {'time': stamp(), 'error': type(error).__name__})
                return 127
            save_metadata(record / 'launch.json', {'started': started, 'pid': child.pid})
            code = child.wait()
        save_metadata(record / 'exit.json', {'time': stamp(), 'returncode': code})
        return code if code >= 0 else 128 - code


if __name__ == '__main__':
    sys.exit(main())
