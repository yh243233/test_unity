"""Exercise the actual PowerShell entrypoint with a process-level Unity double.
POSIX only: the double uses an executable Python shebang, not Unity/Windows.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

PWSH = os.environ.get('PWSH', 'pwsh')
ENTRY = Path(__file__).resolve().parents[1] / 'unity.ps1'

@unittest.skipUnless(os.name == 'posix' and shutil.which(PWSH), 'requires POSIX and pwsh')
class HarnessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='Unity harness 日本語 space ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'ProjectSettings').mkdir()
        (self.root / 'ProjectSettings/ProjectVersion.txt').write_text('m_EditorVersion: 2022.3.22f1\n')
        (self.root / 'Packages').mkdir()
        (self.root / 'Packages/manifest.json').write_text('{}')
        (self.root / 'Assets').mkdir()
        self.editor = self.root / 'fake Unity'
        self.editor.write_text('''#!/usr/bin/env python3
import sys, os, time
from pathlib import Path
a=sys.argv[1:]
def value(k): return a[a.index(k)+1]
mode=os.environ.get('HARNESS_FAKE_MODE','pass')
with (Path(value('-projectPath'))/'calls.jsonl').open('a') as f:
 import json
 f.write(json.dumps(a)+'\\n')
if mode=='timeout': time.sleep(10)
if mode=='slow': time.sleep(2)
Path(value('-logFile')).write_text('fake log\\n')
if '-batchmode' not in a: sys.exit(0)
if mode=='nonzero': sys.exit(7)
if '-executeMethod' in a:
 if mode!='no-marker': Path(value('-harnessMarker')).write_text('ok')
else:
 assert '-quit' not in a
 assert '-nographics' not in a
 if mode=='no-xml': sys.exit(0)
 xml='<test-run total="1" failed="0" result="Passed" />'
 if mode=='failed': xml='<test-run total="1" failed="1" result="Failed" />'
 if mode=='zero': xml='<test-run total="0" failed="0" result="Passed" />'
 if mode=='malformed': xml='bad xml'
 Path(value('-testResults')).write_text(xml)
''')
        self.editor.chmod(0o755)

    def command(self, task, timeout=30):
        return [PWSH, '-NoProfile', '-File', str(ENTRY), '-Task', task,
                '-ProjectPath', str(self.root), '-UnityPath', str(self.editor),
                '-TimeoutSeconds', str(timeout)]

    def run_task(self, task='Check', mode='pass', timeout=30):
        env = dict(os.environ, HARNESS_FAKE_MODE=mode)
        result = subprocess.run(self.command(task, timeout), env=env,
                                capture_output=True, text=True, timeout=45)
        return result

    def summary(self):
        latest = json.loads((self.root / 'artifacts/harness/latest.json').read_text(encoding='utf-8-sig'))
        return json.loads((Path(latest['directory'])/'summary.json').read_text(encoding='utf-8-sig'))

    def test_check_success_and_arguments_with_spaces(self):
        p = self.run_task()
        self.assertEqual(p.returncode, 0, p.stdout+p.stderr)
        s = self.summary()
        self.assertEqual(s['status'], 'passed')
        self.assertEqual([x['name'] for x in s['steps']], ['Compile','EditMode','PlayMode'])
        calls = [json.loads(x) for x in (self.root/'calls.jsonl').read_text().splitlines()]
        self.assertIn('-quit', calls[0])
        self.assertIn('-nographics', calls[0])
        self.assertEqual(calls[0][1], str(self.root))

    def test_failures_stop_and_report(self):
        for mode, task in [('nonzero','Check'),('no-marker','Check'),('no-xml','EditMode'),
                           ('failed','EditMode'),('zero','PlayMode'),('malformed','PlayMode')]:
            with self.subTest(mode=mode):
                p = self.run_task(task, mode)
                self.assertNotEqual(p.returncode, 0)
                s = self.summary()
                self.assertEqual(s['status'], 'failed')
                self.assertTrue(s['error'])
                self.assertEqual(len(s['steps']), 1)
                self.assertEqual(s['steps'][0]['status'], 'failed')

    def test_timeout(self):
        p = self.run_task('Compile', 'timeout', 1)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('Timeout', self.summary()['error'])

    def test_project_lock_prevents_launch(self):
        (self.root/'Temp').mkdir()
        (self.root/'Temp/UnityLockfile').touch()
        p = self.run_task()
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('UnityLockfile', self.summary()['error'])
        self.assertFalse((self.root/'calls.jsonl').exists())

    def test_doctor_and_logs_need_no_unity_execution(self):
        p = self.run_task('Doctor')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertFalse((self.root/'calls.jsonl').exists())
        self.editor.unlink()
        p = self.run_task('Logs')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('passed', p.stdout)

    def test_stale_results_are_not_reused(self):
        self.assertEqual(self.run_task('EditMode').returncode, 0)
        old = self.summary()['directory']
        self.assertNotEqual(self.run_task('EditMode','no-xml').returncode, 0)
        self.assertNotEqual(self.summary()['directory'], old)

    def test_missing_editor_replaces_old_success_with_failure(self):
        self.assertEqual(self.run_task('Doctor').returncode, 0)
        self.editor.unlink()
        self.assertNotEqual(self.run_task('Doctor').returncode, 0)
        self.assertEqual(self.summary()['status'], 'failed')

    def test_open_reports_launch_only(self):
        p = self.run_task('Open')
        self.assertEqual(p.returncode, 0, p.stderr)
        s = self.summary()
        self.assertEqual(s['status'], 'launched')
        self.assertEqual(s['steps'], [])
        self.assertGreater(s['editorPid'], 0)

    def test_concurrent_invocation_is_rejected(self):
        env = dict(os.environ, HARNESS_FAKE_MODE='slow')
        first = subprocess.Popen(self.command('Check'), env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            import time
            for _ in range(100):
                if (self.root/'calls.jsonl').exists(): break
                time.sleep(.05)
            second = self.run_task('Compile')
            self.assertNotEqual(second.returncode, 0)
            out, err = first.communicate(timeout=40)
            self.assertEqual(first.returncode, 0, out+err)
            self.assertEqual(self.summary()['status'], 'passed')
            self.assertEqual(self.summary()['task'], 'Check')
        finally:
            if first.poll() is None:
                first.kill()
                first.communicate()

if __name__ == '__main__':
    unittest.main()
