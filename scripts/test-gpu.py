#!/usr/bin/env python3
"""GPU measurements from disposable sysfs/proc fixtures only."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('gpu', Path(__file__).with_name('gpu-stats.py'))
gpu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gpu)

class GpuTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.card = self.root / 'card1'
        self.card.mkdir()
        self.device = self.root / '0000:00:02.0'
        self.device.mkdir()
        (self.card / 'device').symlink_to(self.device)
        self.proc = self.root / 'proc'
        self.proc.mkdir()

    def write(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(str(text))

    def client(self, pid, fd, identity='7', device='0000:00:02.0', memory='2048 KiB'):
        self.write(self.proc / str(pid) / 'stat', f'{pid} (worker (GPU)) S ' + ' '.join(['0']*18 + ['10']))
        self.write(self.proc / str(pid) / 'fdinfo' / str(fd),
                   f'drm-driver: i915\ndrm-pdev: {device}\ndrm-client-id: {identity}\ndrm-resident-system0: {memory}\n')
        return dict(pid=pid, key=f'{pid}:10')

    def sample(self, vendor='intel', processes=()):
        return gpu.sample(self.card, vendor, processes, self.proc)

    def test_intel_frequency_without_temperature_and_zero(self):
        for value in (1200, 0):
            self.write(self.card / 'gt_act_freq_mhz', value)
            stats = self.sample()['gpu']
            self.assertEqual(stats['clock'], value)
            self.assertEqual(stats['load'], -1)
            self.assertEqual(stats['temperature'], -1)
            self.assertEqual(stats['memTotal'], -1)
        (self.card / 'gt_act_freq_mhz').unlink()
        self.assertIsNone(self.sample()['gpu'])

    def test_no_requested_frequency_fallback(self):
        self.write(self.card / 'gt_cur_freq_mhz', 1200)
        self.assertIsNone(self.sample()['gpu'])

    def test_amd_without_temperature(self):
        self.write(self.device / 'gpu_busy_percent', 32)
        self.write(self.device / 'mem_info_vram_used', 1048576)
        self.write(self.device / 'mem_info_vram_total', 2097152)
        self.write(self.device / 'hwmon/hwmon2/freq1_input', 600000000)
        s = self.sample('amd')['gpu']
        self.assertEqual((s['load'],s['memUsed'],s['memTotal'],s['clock']), (32,1,2,600))
        self.assertEqual(s['temperature'], -1)

    def test_temperature_priority_and_missing_values(self):
        self.write(self.device / 'hwmon/hwmon0/temp1_input', 45000)
        self.write(self.device / 'hwmon/hwmon0/temp2_input', 52000)
        self.write(self.device / 'hwmon/hwmon0/temp2_label', 'edge')
        self.assertEqual(self.sample('amd')['gpu']['temperature'], 52)
        for value in ('nan', 'inf', '-1', 'broken'):
            self.write(self.card / 'gt_act_freq_mhz', value)
            self.assertEqual(self.sample()['gpu']['clock'], -1)

    def test_duplicate_clients_and_other_device(self):
        p = self.client(10, 3)
        self.client(10, 4)
        self.client(10, 5, device='0000:03:00.0')
        self.client(10, 6, identity='8', memory='1 MiB')
        s = self.sample(processes=[p])
        self.assertEqual(s['clients'][p['key']], {'0000:00:02.0:7': 2, '0000:00:02.0:8': 1})
        self.assertIsNone(s['gpu'])  # never infer global memory from clients

    def test_missing_process_reused_pid_and_unreadable_fd(self):
        p = self.client(10, 3)
        (self.proc / '10/fdinfo/3').unlink()
        (self.proc / '10/fdinfo/3').symlink_to('/missing-gpu-fixture')
        self.assertEqual(self.sample(processes=[p])['clients'], {})
        self.client(10, 4)
        self.assertEqual(self.sample(processes=[dict(pid=10,key='10:20'),dict(pid=99,key='99:10')])['clients'], {})

    def test_memory_units_and_invalid_memory(self):
        for text, result in [('1048576 B',1),('1024 KiB',1),('1 MiB',1),('1 GiB',1024),('0',0),('n/a',None)]:
            self.assertEqual(gpu.memory(text), result)
        p = self.client(10, 3, memory='n/a')
        self.assertEqual(self.sample(processes=[p])['clients'], {})
        (self.proc / '10/fdinfo/3').write_text('drm-pdev: 0000:00:02.0\ndrm-client-id: 7\ndrm-total-system0: 2 MiB\n')
        self.assertEqual(self.sample(processes=[p])['clients'], {})

if __name__ == '__main__':
    unittest.main()
