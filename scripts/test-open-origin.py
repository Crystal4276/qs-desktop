#!/usr/bin/env python3
"""Origin-based policy, independent of URI scheme, suffix, source workspace or viewer."""
import importlib.util
import os
from pathlib import Path
import time
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('origin',Path(__file__).with_name('open-origin.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


class Policy(unittest.TestCase):
    def setUp(self):
        self.rows=[];self.moves=[]
        class Desktop:
            sway=True
            def windows(inner):return self.rows
            def place(inner,window,primary):self.moves.append((window['id'],primary))
        self.policy=m.Policy(Desktop(),lambda:'PRIMARY')
        self.pid=os.getpid()

    def window(self,id='viewer',pid=None,title='video',app='arbitrary-viewer'):
        return dict(id=id,pid=pid or self.pid,title=title,app=app,output='SECONDARY',rank=0)

    def test_hyprland_publishes_before_map_without_late_new_window_move(self):
        self.policy.desktop.sway=False
        publications=[]
        self.policy.publish=lambda:publications.append(dict(self.policy.routed))
        self.policy.track(self.pid,'deluge-gtk')
        self.assertIn(self.pid,publications[0])
        self.rows.append(self.window())
        self.policy.poll()
        self.assertFalse(self.moves)

    def test_hyprland_reused_viewer_moves_at_request_without_title_wait(self):
        self.policy.desktop.sway=False
        self.rows=[self.window()]
        self.policy.track(self.pid,'deluge-gtk')
        self.assertEqual(self.moves,[('viewer','PRIMARY')])
        self.assertFalse(self.policy.pending)

    def test_new_window_of_target_pid_only(self):
        self.rows=[self.window('manual',pid=self.pid+100)]
        self.policy.track(self.pid,'deluge-gtk')
        self.rows.append(self.window())
        self.policy.poll()
        self.assertEqual(self.moves,[('viewer','PRIMARY')])

    def test_reused_video_document_and_other_viewers(self):
        for source,title in [('deluge-gtk','movie.mkv'),('thunderbird','attachment.pdf'),('steam','folder')]:
            self.rows=[self.window('viewer',title='before')]
            self.policy.track(self.pid,source)
            self.rows=[self.window('viewer',title=title)]
            self.policy.poll()
        self.assertEqual(self.moves,[('viewer','PRIMARY')]*3)

    def test_unchanged_existing_window_after_open_request(self):
        self.rows=[self.window()];self.policy.track(self.pid,'deluge-gtk')
        self.policy.pending[0]['begin']-=.3
        self.policy.poll()
        self.assertEqual(self.moves,[('viewer','PRIMARY')])

    def test_unrelated_manual_windows_never_matched(self):
        self.policy.track(self.pid,'steam')
        self.rows=[self.window(pid=self.pid+100)]
        self.policy.poll();self.assertFalse(self.moves)
        self.policy.pending[0]['until']=0;self.policy.poll();self.assertFalse(self.moves)

    def test_source_app_main_window_not_relocated(self):
        for app in m.SOURCE_CLASSES:
            with patch.object(m,'source_of',return_value='thunderbird'):
                self.policy.opened(self.window(app=app))
        self.assertFalse(self.moves)

    def test_direct_children_route_manual_launches_do_not(self):
        with patch.object(m,'source_of',return_value='steam'):
            self.policy.opened(self.window())
        with patch.object(m,'source_of',return_value=''),patch.object(m,'startup_source',return_value=''):
            self.policy.opened(self.window('manual'))
        self.assertEqual(self.moves,[('viewer','PRIMARY')])

    def test_manual_new_window_of_existing_viewer_does_not_inherit_old_origin(self):
        self.rows=[self.window('existing')]
        with patch.object(m,'source_of',return_value='deluge-gtk'):
            self.policy.opened(self.window('manual-new'))
        self.assertFalse(self.moves)

    def test_reused_pid_does_not_inherit_a_pending_open(self):
        self.policy.track(self.pid,'steam');self.rows=[self.window()]
        with patch.object(m,'identity',return_value={'start':'different'}):self.policy.poll()
        self.assertFalse(self.moves)

    def test_uri_context_is_temporary_and_only_selected_sources(self):
        self.policy.remember(['file:///tmp/a.mkv'],'deluge-gtk')
        self.assertEqual(self.policy.request_source(['file:///tmp/a.mkv']),'deluge-gtk')
        self.assertEqual(self.policy.request_source(['file:///tmp/manual.mkv']),'')
        self.assertNotIn('file:///tmp/a.mkv',str(self.policy.requests))
        self.policy.requests={k:(0,v[1]) for k,v in self.policy.requests.items()}
        self.assertEqual(self.policy.request_source(['file:///tmp/a.mkv']),'')

    def test_startup_ipc_diagnostic_is_not_an_output_name(self):
        observer=m.Observer.__new__(m.Observer)
        observer.desktop=self.policy.desktop
        observer.cached_primary=''
        with patch.object(m.subprocess,'check_output',return_value='Not ready to accept queries yet.\n'),patch.object(m,'query',return_value=[{'name':'PRIMARY','active':True}]):
            with self.assertRaises(RuntimeError):observer.primary()
            self.assertEqual(observer.cached_primary,'')

    def test_ancestor_resolution(self):
        rows={10:dict(name='viewer',ppid=11),11:dict(name='gio',ppid=12),12:dict(name='deluge-gtk',ppid=1)}
        with patch.object(m,'identity',side_effect=lambda pid:rows.get(pid)):
            self.assertEqual(m.source_of(10),'deluge-gtk')
            self.assertEqual(m.source_of(999),'')


if __name__=='__main__':unittest.main()
