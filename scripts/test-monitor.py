"""Membership fixtures and real signals against disposable children only."""
import importlib.util
from pathlib import Path
import os
import signal
import subprocess
import unittest
import sys
import tempfile
import time
spec = importlib.util.spec_from_file_location('monitor', Path(__file__).with_name('monitor-processes.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

def row(pid, args, parent=1, uid=None, start='10'):
    return dict(pid=pid, key=f'{pid}:{start}', start=start, ppid=parent, uid=os.getuid() if uid is None else uid, name=m.executable(args), args=args)

def entry(identity, *args):
    return dict(id=identity, name=identity, command=list(args))

class MonitorTests(unittest.TestCase):

    def setUp(self):
        self.entries = [entry('browser', 'chromium'), entry('chat', 'chromium', '--user-data-dir=/profiles/chat', '--app=https://chat'), entry('mail', 'chromium', '--user-data-dir=/profiles/mail', '--app=https://mail'), entry('terminal', 'terminal'), entry('editor', 'editor')]
        self.rows = [row(10, ['chromium']), row(11, ['chromium', '--type=renderer'], 10), row(20, ['chromium', '--user-data-dir=/profiles/chat', '--app=https://chat/deep']), row(21, ['chromium', '--type=renderer', '--user-data-dir=/profiles/chat'], 20), row(30, ['chromium', '--user-data-dir=/profiles/mail', '--app=https://mail']), row(40, ['terminal']), row(41, ['editor'], 40), row(42, ['worker'], 41), row(50, ['editor']), row(60, ['daemon']), row(70, ['editor'], uid=os.getuid() + 1)]

    def groups(self, rows=None, previous=None):
        return {g['id']: g for g in m.identify(self.rows if rows is None else rows, self.entries, previous or {})}

    def test_groups_and_boundaries(self):
        groups = self.groups()
        self.assertEqual(groups['browser']['members'], ['10:10', '11:10'])
        self.assertEqual(groups['chat']['members'], ['20:10', '21:10'])
        self.assertEqual(groups['mail']['members'], ['30:10'])
        self.assertEqual(groups['terminal']['members'], ['40:10'])
        self.assertEqual(groups['editor']['members'], ['41:10', '42:10', '50:10'])
        self.assertEqual(groups['editor']['roots'], ['41:10', '50:10'])

    def test_orphan_and_reused_pid(self):
        previous = {'21:10': dict(id='chat', name='chat')}
        self.assertEqual(self.groups([row(21, ['worker'])], previous)['chat']['members'], ['21:10'])
        self.assertEqual(self.groups([row(21, ['worker'], start='11')], previous), {})

    def test_ambiguous_launcher(self):
        self.entries.append(entry('other-browser', 'chromium'))
        self.assertNotIn('browser', self.groups())
        self.assertIn('chat', self.groups())

    def test_unknown_profile(self):
        groups = self.groups([row(80, ['chromium', '--app=https://unknown', '--user-data-dir=/profiles/new'])])
        self.assertEqual(list(groups), ['profile:/profiles/new'])

    def test_title_arguments(self):
        self.assertEqual(m.arguments(b'chromium --type=renderer --user-data-dir="/a b"\x00'), ['chromium', '--type=renderer', '--user-data-dir=/a b'])

    def test_window_wrappers_and_shared_host(self):
        rows = [row(80, ['/usr/lib/terminal-server']), row(81, ['worker'], 80)]
        groups = m.identify(rows, self.entries, {}, [dict(pid=80, appId='terminal')])
        self.assertEqual(groups[0]['members'], ['80:10', '81:10'])
        self.assertFalse(groups[0]['blocked'])
        groups = m.identify(rows, self.entries, {}, [dict(pid=80, appId='terminal'), dict(pid=80, appId='editor')])
        self.assertTrue(groups[0]['blocked'])
        self.assertTrue(m.stop(dict(application=groups[0]['id'], members=['80:10'], roots=['80:10']), rows, groups))

    def test_initial_orphan_crash_handler(self):
        rows = self.rows + [row(90, ['crashpad', '--database=/profiles/chat/Crash Reports'])]
        self.assertIn('90:10', self.groups(rows)['chat']['members'])

    def test_confirmation_scope(self):
        request = dict(application='editor', members=['41:10', '42:10'], roots=['41:10'])
        sent = []
        old = m.send_one
        m.send_one = lambda key, force: sent.append(key)
        try:
            rows = self.rows + [row(43, ['new-worker'], 41)]
            m.stop(request, rows, list(self.groups(rows).values()))
            self.assertEqual(set(sent), {'41:10', '42:10', '43:10'})
        finally:
            m.send_one = old

    def test_real_signals_and_identity(self):
        for force in (False, True):
            child = subprocess.Popen(['sleep', '30'])
            try:
                p = next((p for p in m.snapshot() if p['pid'] == child.pid))
                with self.assertRaises(PermissionError):
                    m.send_one(f'{child.pid}:0', force)
                self.assertIsNone(child.poll())
                m.send_one(p['key'], force)
                self.assertEqual(child.wait(timeout=3), -int(signal.SIGKILL if force else signal.SIGTERM))
            finally:
                if child.poll() is None:
                    child.kill()
                    child.wait()

class ChromiumIntegration(unittest.TestCase):

    @unittest.skipUnless('--chromium' in sys.argv, 'opt in with --chromium (three disposable Chromium profiles)')
    def test_isolated_profiles(self):
        children = []
        try:
            with tempfile.TemporaryDirectory(prefix='qs-monitor-chromium-') as directory:
                entries = []
                for name in ('browser', 'chat', 'mail'):
                    profile = directory + '/' + name
                    args = ['chromium', '--headless=new', '--disable-gpu', '--no-sandbox', '--no-first-run', '--no-default-browser-check', '--disable-background-networking', '--user-data-dir=' + profile]
                    if name != 'browser':
                        args += ['--app=about:blank']
                    else:
                        args += ['about:blank']
                    child = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                    children.append(child)
                    entries.append(dict(id=name, name=name, command=args))
                time.sleep(3)
                for force in (False, True):
                    rows = m.snapshot()
                    groups = m.identify(rows, entries, {})
                    byid = {g['id']: g for g in groups}
                    assert all((name in byid for name in ('browser', 'chat', 'mail') if name != 'browser' or not force)), byid.keys()
                    name = 'browser' if not force else 'chat'
                    g = byid[name]
                    error = m.stop(dict(application=name, members=g['members'], roots=g['roots'], force=force), rows, groups)
                    assert not error, error
                    time.sleep(1)
                    live = {p['key'] for p in m.snapshot()}
                    assert not live.intersection(g['members']), (name, live.intersection(g['members']))
                    assert children[2].poll() is None
                    if not force:
                        assert children[1].poll() is None
                print('Chromium isolation: TERM browser, KILL chat, mail survives; all selected children exited: OK')
        finally:
            for child in children:
                try:
                    os.killpg(child.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                child.wait()
if __name__ == '__main__':
    if '--chromium' in sys.argv:
        sys.argv.remove('--chromium')
    unittest.main()
