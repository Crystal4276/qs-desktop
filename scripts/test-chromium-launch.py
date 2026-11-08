#!/usr/bin/env python3
"""Private sockets and a fake wrapper; never launch the user's browser."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import unittest

SCRIPT = Path(__file__).with_name('chromium-launch.sh')

class Handoff(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='ch-')
        self.root = Path(self.tmp.name)
        self.env = os.environ.copy()
        for k in ('CHROME_USER_DATA_DIR', 'CHROME_CONFIG_HOME', 'XDG_ACTIVATION_TOKEN', 'DESKTOP_STARTUP_ID'):
            self.env.pop(k, None)
        self.env['XDG_CONFIG_HOME'] = str(self.root)
        (self.root/'chromium').mkdir()
        self.flags = self.root/'chromium-flags.conf'
        self.flags.write_text('# comment\n--enable-features=Example\n')
        self.path = self.root/'chromium/SingletonSocket'

    def tearDown(self):
        self.tmp.cleanup()

    def call(self, args=(), **env):
        return subprocess.run(['bash', '-c', 'source "$1"; shift; handoff "$@"', 'test', str(SCRIPT), 'chromium', *args],
                              env={**self.env, **env}, capture_output=True, timeout=4)

    def exchange(self, args, reply=b'ACK', delay=False, **env):
        messages = []
        with socket.socket(socket.AF_UNIX) as server:
            server.bind(str(self.path))
            server.listen(1)
            server.settimeout(.25)
            def serve():
                try:
                    client = server.accept()[0]
                except socket.timeout:
                    return
                with client:
                    data = b''
                    while chunk := client.recv(4096):
                        data += chunk
                    messages.append(data)
                    if delay:
                        threading.Event().wait(2.3)
                    try:
                        client.sendall(reply)
                    except BrokenPipeError:
                        pass
            thread = threading.Thread(target=serve)
            thread.start()
            result = self.call(args, **env)
            thread.join(timeout=4)
            self.assertFalse(thread.is_alive())
        self.path.unlink()
        return result, messages[0] if messages else None

    def test_arguments_and_ack(self):
        for args in [(), ('--new-window', 'about:blank'), ('--incognito', 'https://example.test/a b?x=é'), ('--profile-directory=Profile 1', 'relative file')]:
            result, data = self.exchange(args)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(data, b'\0'.join(os.fsencode(s) for s in ('START', os.getcwd(), 'browser', *args)))

    def test_refusals(self):
        for args in [('--user-data-dir=/elsewhere',), ('--user-data-dir', '/elsewhere'), ('x'*33000,)]:
            self.assertNotEqual(self.exchange(args)[0].returncode, 0)
        for key in ('CHROME_USER_DATA_DIR', 'CHROME_CONFIG_HOME', 'XDG_ACTIVATION_TOKEN', 'DESKTOP_STARTUP_ID'):
            self.assertNotEqual(self.exchange((), **{key: 'override'})[0].returncode, 0)
        for line in ['--new-window', '--incognito', '--profile-directory="Profile 1"', '--enable-features=A --new-window']:
            self.flags.write_text(line+'\n')
            self.assertNotEqual(self.exchange(())[0].returncode, 0)

    def test_missing_stale_and_unacknowledged(self):
        self.assertNotEqual(self.call().returncode, 0)
        with socket.socket(socket.AF_UNIX) as server:
            server.bind(str(self.path))
        self.assertNotEqual(self.call().returncode, 0)
        self.path.unlink()
        for reply, delay in [(b'NO', False), (b'', False), (b'ACK', True)]:
            result, _ = self.exchange(('about:blank',), reply, delay)
            self.assertNotEqual(result.returncode, 0)

    def test_wrapper_fallback_preserves_arguments_cwd_and_status(self):
        wrapper = self.root/'wrapper'
        wrapper.write_text('#!/usr/bin/env python3\nimport os,sys,json\nprint(json.dumps([os.getcwd(),sys.argv[1:]]))\nsys.exit(17)\n')
        wrapper.chmod(0o755)
        args = ['--user-data-dir=/isolated', 'https://example.test/a b', '--incognito']
        result = subprocess.run(['bash', str(SCRIPT), str(wrapper), *args], env=self.env, cwd=self.root, capture_output=True, text=True, timeout=4)
        self.assertEqual(result.returncode, 17)
        self.assertEqual(json.loads(result.stdout), [str(self.root), args])

if __name__ == '__main__':
    unittest.main()
