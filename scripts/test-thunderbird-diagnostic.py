#!/usr/bin/env python3
"""Diagnostic plumbing tests; the surviving process below is a simulation, not the reported bug."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).with_name('thunderbird-diagnostic.py')
spec = importlib.util.spec_from_file_location('diagnostic', SCRIPT)
diag = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diag)


class DiagnosticTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='tb-diagnostic-test-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, XDG_STATE_HOME=str(self.root / 'state'),
                        PATH=str(self.bin) + os.pathsep + os.environ['PATH'])
        self.program('loginctl', '#!/bin/sh\nprintf "State=closing\\nActive=no\\n"\n')

    def program(self, name, text):
        path = self.bin / name
        path.write_text(text)
        path.chmod(0o700)
        return path

    def run_diag(self, *args, **kwargs):
        return subprocess.run([sys.executable, str(SCRIPT), *args], env=self.env,
                              capture_output=True, text=True, timeout=10, **kwargs)

    def records(self, kind):
        base = self.root / 'state/qs-desktop/thunderbird-diagnostic'
        return sorted(base.glob(kind + '-*'))

    def test_launch_outputs_status_and_arguments(self):
        received = self.root / 'received.json'
        self.program('thunderbird', f'#!{sys.executable}\nimport json,sys\nfrom pathlib import Path\nPath({str(received)!r}).write_text(json.dumps(sys.argv[1:]))\nprint("stdout captured")\nprint("stderr captured", file=sys.stderr)\nsys.exit(7)\n')
        secret = 'mailto:private@example.invalid?body=private text'
        result = self.run_diag('run', secret)
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertEqual(json.loads(received.read_text()), [secret])
        record, = self.records('launch')
        self.assertEqual(json.loads((record / 'exit.json').read_text())['returncode'], 7)
        output = (record / 'output.log').read_text()
        self.assertIn('stdout captured', output)
        self.assertIn('stderr captured', output)
        for path in record.glob('*.json'):
            self.assertNotIn(secret, path.read_text())

    def test_permissions_and_retention(self):
        with patch.dict(os.environ, self.env):
            for _ in range(8):
                path, active = diag.new_record('snapshot')
                diag.write_json(path / 'before.json', {'test': True})
                active.close()
        records = self.records('snapshot')
        self.assertEqual(len(records), 5)
        base = records[0].parent
        self.assertEqual(stat.S_IMODE(base.stat().st_mode), 0o700)
        for record in records:
            self.assertEqual(stat.S_IMODE(record.stat().st_mode), 0o700)
            for path in record.iterdir():
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)

    def test_live_recorder_survives_rotation(self):
        with patch.dict(os.environ, self.env):
            path, active = diag.new_record('launch')
            try:
                for _ in range(8):
                    _, finished = diag.new_record('launch')
                    finished.close()
                self.assertTrue(path.exists())
                self.assertEqual(len(self.records('launch')), 6)
            finally:
                active.close()

    def test_failed_diagnostics_still_launch(self):
        self.program('thunderbird', '#!/bin/sh\necho fallback-launched\nexit 9\n')
        blocked = self.root / 'not-a-directory'
        blocked.write_text('file')
        self.env['XDG_STATE_HOME'] = str(blocked)
        result = self.run_diag('run')
        self.assertEqual(result.returncode, 9)
        self.assertIn('fallback-launched', result.stdout)

    def test_metadata_failure_does_not_interrupt_launch(self):
        self.program('thunderbird', '#!/bin/sh\nexit 8\n')
        original = diag.write_json
        def fail_after_launch(path, data):
            if path.name in ('launch.json', 'exit.json'):
                raise OSError('simulated disk failure')
            original(path, data)
        with patch.dict(os.environ, self.env), patch.object(sys, 'argv', [str(SCRIPT), 'run']), \
                patch.object(diag, 'write_json', side_effect=fail_after_launch):
            self.assertEqual(diag.main(), 8)

    def test_snapshot_surviving_process_and_lock_without_mail_access(self):
        # Real executable with a Thunderbird basename, holding a real advisory profile lock.
        binary = self.bin / 'thunderbird'
        shutil.copyfile(sys.executable, binary)
        binary.chmod(0o700)
        profile = self.root / 'profile'
        profile.mkdir()
        mail = profile / 'Inbox'
        mail.write_text('PRIVATE MAIL CONTENT MUST NOT BE COLLECTED')
        lock = profile / '.parentlock'
        ready = self.root / 'ready'
        code = ('import fcntl,time; from pathlib import Path; '
                f'f=open({str(lock)!r},"w"); fcntl.lockf(f,fcntl.LOCK_EX); '
                f'Path({str(ready)!r}).touch(); time.sleep(60)')
        env = dict(self.env, XDG_SESSION_ID='simulated-old-session',
                   WAYLAND_DISPLAY='simulated-disconnected-display', PRIVATE_DIAGNOSTIC_TEST='secret')
        child = subprocess.Popen([str(binary), '-c', code], env=env)
        try:
            deadline = time.monotonic() + 4
            while not ready.exists() and time.monotonic() < deadline:
                time.sleep(.05)
            self.assertTrue(ready.exists())
            # A short-lived fake compositor has exited, while the fixture remains alive.
            subprocess.run([sys.executable, '-c', 'pass'], check=True)
            result = self.run_diag('snapshot')
            self.assertEqual(result.returncode, 0, result.stderr)
            record, = self.records('snapshot')
            data = json.loads((record / 'before.json').read_text())
            process, = [p for p in data['processes'] if p['pid'] == child.pid]
            self.assertEqual(process['environment']['XDG_SESSION_ID'], 'simulated-old-session')
            self.assertEqual(data['sessions']['simulated-old-session']['State'], 'closing')
            self.assertTrue(process['threads'])
            self.assertTrue(any(p['path'] == str(lock) for p in process['lock_files']))
            text = (record / 'before.json').read_text()
            self.assertNotIn('PRIVATE MAIL CONTENT', text)
            self.assertNotIn('PRIVATE_DIAGNOSTIC_TEST', text)
            self.assertIsNone(child.poll(), 'snapshot must not stop the process')
            self.assertEqual(mail.read_text(), 'PRIVATE MAIL CONTENT MUST NOT BE COLLECTED')
        finally:
            child.terminate()
            child.wait(timeout=5)

    def test_missing_logind_is_nonfatal(self):
        with patch.object(diag.subprocess, 'run', side_effect=FileNotFoundError):
            self.assertEqual(diag.session_info('test')['query_error'], 'FileNotFoundError')


if __name__ == '__main__':
    unittest.main()
