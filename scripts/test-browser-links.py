#!/usr/bin/env python3
"""Routing and installation tests: fake compositor/native launcher, temporary files."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(file))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


b = load('browser', 'browser-link.py')
s = load('setup', 'browser-links-setup.py')


class Routing(unittest.TestCase):
    def test_reuse_central_without_moving_manual_windows(self):
        class Backend:
            def windows(self):
                return [dict(id='left', output='LEFT', pid=1, rank=0),
                        dict(id='old-central', output='CENTER', pid=2, rank=4),
                        dict(id='recent-central', output='CENTER', pid=2, rank=1),
                        dict(id='isolated', output='CENTER', pid=3, rank=0)]
            def focus(self, output, window):
                actions.append(('focus', output, window['id'] if window else None))
        actions = []
        urls = ['https://example.test/a b?x=é&y=$(false)', 'http://example.test/other']
        with patch.object(b, 'default_profile', side_effect=lambda pid: pid != 3):
            b.open_links(urls, Backend(), 'CENTER', lambda args: actions.append(args))
        self.assertEqual(actions, [('focus', 'CENTER', 'recent-central'), ['chromium', '--', *urls]])

    def test_new_window_if_none_on_primary(self):
        class Backend:
            def windows(self): return [dict(id='manual', output='RIGHT', pid=1, rank=0)]
            def focus(self, output, window): actions.append((output, window))
        actions = []
        with patch.object(b, 'default_profile', return_value=True):
            b.open_links(['https://example.test'], Backend(), 'CENTER', lambda args: actions.append(args))
        self.assertEqual(actions, [('CENTER', None), ['chromium', '--new-window', '--', 'https://example.test']])

    def test_manual_and_local_file_launch_do_not_route(self):
        for args in [[], ['/tmp/a file.html'], ['file:///tmp/page.html']]:
            with patch.object(b.os, 'execvp', side_effect=SystemExit), patch.object(b, 'query') as query:
                with self.assertRaises(SystemExit): b.main(args)
                b.os.execvp.assert_called_once_with('chromium', ['chromium', *(['--', *args] if args else [])])
                query.assert_not_called()

    def test_native_fallback_if_shell_unavailable(self):
        with patch.object(b, 'selected_origin', return_value=True), patch.object(b.subprocess, 'check_output', side_effect=OSError), patch.object(b.os, 'execvp', side_effect=SystemExit):
            with self.assertRaises(SystemExit): b.main(['https://example.test'])
            b.os.execvp.assert_called_once_with('chromium', ['chromium', '--', 'https://example.test'])

    def test_other_source_http_keeps_native_behavior(self):
        with patch.object(b, 'selected_origin', return_value=False), patch.object(b.os, 'execvp', side_effect=SystemExit):
            with self.assertRaises(SystemExit): b.main(['https://example.test'])
            b.os.execvp.assert_called_once_with('chromium', ['chromium', '--', 'https://example.test'])

    def test_sway_traverses_floating_windows_and_focus_order(self):
        tree = dict(type='root', nodes=[dict(id=10, type='output', name='CENTER', focus=[12, 11], nodes=[
            dict(id=11, app_id='chromium', pid=2), dict(id=12, app_id='chromium', pid=2)], floating_nodes=[
            dict(id=13, app_id='chrome-webapp', pid=3)])])
        with patch.object(b, 'query', return_value=tree):
            self.assertEqual([w['id'] for w in b.Sway().windows()], [12, 11])


class Installation(unittest.TestCase):
    source_text = '[Desktop Entry]\nName=Chromium\nExec=chromium %U\nActions=new-window;\n\n[Desktop Action new-window]\nExec=chromium\n'

    def test_install_idempotence_restore_and_dry_run(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); target = root/'applications/chromium.desktop'; state = root/'state/browser-links'
            source = root/'system.desktop'; source.write_text(self.source_text); script = root/'repo with spaces/browser-link.py'
            s.setup('install', target, state, source, script, True)
            self.assertFalse(state.exists()); self.assertFalse(target.exists())
            s.setup('install', target, state, source, script)
            installed = target.read_bytes()
            self.assertIn(b'Exec=chromium\n', installed)  # Manual desktop action stays native.
            self.assertIn(str(script).encode(), installed)
            s.setup('install', target, state, source, script)
            self.assertEqual(target.read_bytes(), installed)
            s.setup('uninstall', target, state, source, script)
            self.assertFalse(target.exists())
            target.write_text(self.source_text); target.chmod(0o640)
            s.setup('install', target, state, source, script)
            s.setup('uninstall', target, state, source, script)
            self.assertEqual(target.read_text(), self.source_text)
            self.assertEqual(target.stat().st_mode & 0o777, 0o640)

    def test_preserves_custom_launchers_and_later_edits(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); target = root/'chromium.desktop'; state = root/'state/browser-links'
            source = root/'system.desktop'; source.write_text(self.source_text)
            target.write_text('[Desktop Entry]\nExec=custom-browser %U\n')
            with self.assertRaises(ValueError): s.setup('install', target, state, source, root/'script')
            self.assertIn('custom-browser', target.read_text())
            target.unlink(); s.setup('install', target, state, source, root/'script')
            target.write_text('user edited')
            with self.assertRaises(ValueError): s.setup('uninstall', target, state, source, root/'script')
            self.assertEqual(target.read_text(), 'user edited')


if __name__ == '__main__':
    unittest.main()
