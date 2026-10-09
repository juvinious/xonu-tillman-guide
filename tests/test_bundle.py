"""Offline contract tests. No ONT, network, firmware writes or root needed."""
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'


def shell(path, *args, env=None):
    return subprocess.run(['sh', str(path), *args], capture_output=True,
                          text=True, env=env, timeout=20)


class BundleTests(unittest.TestCase):
    def test_shell_syntax(self):
        for path in SCRIPTS.glob('*.sh'):
            with self.subTest(path=path.name):
                result = subprocess.run(['sh', '-n', str(path)], capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_relative_document_links(self):
        for path in ROOT.rglob('*.md'):
            for target in re.findall(r'\]\(([^)]+)\)', path.read_text()):
                if '://' in target or target.startswith('#'):
                    continue
                self.assertTrue((path.parent / target.split('#')[0]).exists(),
                                f'{path.relative_to(ROOT)} -> {target}')

    def test_final_evidence_has_traffic_without_new_key_errors(self):
        text = (ROOT / 'evidence/xonu-final-counters.txt').read_text()
        rows = [line.split() for line in text.splitlines()
                if re.match(r'^2\s+1028\s', line)]
        self.assertEqual(len(rows), 2)
        self.assertGreater(int(rows[1][4]), int(rows[0][4]))
        self.assertGreater(int(rows[1][2]), int(rows[0][2]))
        self.assertEqual([row[6] for row in rows], ['4', '4'])

    def test_collector_rejects_invalid_input_without_commands(self):
        for args in [('bad',), ('0',), ('65535',), ('1028', '0'),
                     ('1028', '61'), ('1028', '1;echo bad'), ('1', '1', 'extra')]:
            with self.subTest(args=args):
                result = shell(SCRIPTS / 'collect-status.sh', *args)
                self.assertEqual(result.returncode, 2)
                self.assertNotIn('COMMAND:', result.stdout)

    def test_prepare_profile_refuses_mismatch_and_existing_target(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            source, target = base / 'source.ini', base / 'result.ini'
            source.write_text('329 0x0101 0 0\n')
            script = (SCRIPTS / 'prepare-profile.sh').read_text()
            script = script.replace('SOURCE=/etc/mibs/prx300_1V.ini', f'SOURCE={source}')
            script = script.replace('TARGET=/tmp/veip-aligned.ini', f'TARGET={target}')
            path = base / 'prepare.sh'
            path.write_text(script)
            result = shell(path)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('differs', result.stderr)
            self.assertFalse(target.exists())
            target.write_text('preserve me\n')
            result = shell(path)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(target.read_text(), 'preserve me\n')

    def test_prepare_profile_remaps_references_together(self):
        # Synthetic minimal contract fixture; no vendor template distributed.
        source_text = ('# comment 0x0101\n256 0 INTC OLD 0\n'
                       '5 0x0101 0\n6 0x0101 0\n329 0x0101 0\n'
                       '? 11 0x0101 0\n277 0x0080 0x01010000\n')
        expected = ('# comment 0x0101\n256 0 ALCL 3FE49691AABA 00000000 2 0 0 0 0\n'
                    '5 0x0100 0\n6 0x0100 0\n329 0x0001 0\n'
                    '? 11 0x0001 0\n277 0x0080 0x00010000\n')
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            source, target = base / 'source.ini', base / 'result.ini'
            source.write_text(source_text)
            script = (SCRIPTS / 'prepare-profile.sh').read_text()
            script = script.replace('SOURCE=/etc/mibs/prx300_1V.ini', f'SOURCE={source}')
            script = script.replace('TARGET=/tmp/veip-aligned.ini', f'TARGET={target}')
            script = re.sub(r'^EXPECTED=.*$', 'EXPECTED=' + hashlib.sha256(expected.encode()).hexdigest(),
                            script, flags=re.M)
            path = base / 'prepare.sh'
            path.write_text(script)
            result = shell(path)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(target.read_text(), expected)


class HookTests(unittest.TestCase):
    def run_case(self, case):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            script = (SCRIPTS / 'xonu-persist.sh').read_text()
            hook = script.split("<<'XONU_HOOK'\n", 1)[1].split('\nXONU_HOOK', 1)[0]
            hook_path = base / 'hook.sh'
            hook_path.write_text(hook + '\n')
            shim = '''#!/bin/sh
name=${0##*/}
case "$name" in
ip)
    [ "$*" = '-d link show dev gem1028' ] || exit 91
    [ "$CASE" != absent ] || exit 1
    enc=0; dir=3; mc=0; gem=1028
    [ "$CASE" != correct ] || enc=3
    [ ! -f "$MOCK_STATE/applied" ] || enc=3
    [ "$CASE" != wrong_direction ] || dir=2
    [ "$CASE" != multicast ] || mc=1
    [ "$CASE" != wrong_id ] || gem=2046
    echo "gem idx: 2 id: $gem traffic type: 0 dir: $dir enc: $enc max size: 4095 tcont: tcont32768 mc: $mc bp: 11"
    ;;
omci_pipe.sh)
    echo "$*" >> "$MOCK_STATE/writes"
    [ "$*" = 'meads 268 1028 10 3' ] || exit 92
    [ "$CASE" != command_failure ] || exit 1
    if [ "$CASE" = error_response ]; then echo errorcode=1; exit 0; fi
    [ "$CASE" = unchanged_kernel ] || touch "$MOCK_STATE/applied"
    echo errorcode=0
    ;;
logger) echo "$*" >> "$MOCK_STATE/logs";;
timeout) shift; exec "$@";;
*) exit 93;;
esac
'''
            for name in ['ip', 'omci_pipe.sh', 'logger', 'timeout']:
                path = base / name
                path.write_text(shim)
                path.chmod(0o700)
            env = dict(os.environ, CASE=case, MOCK_STATE=str(base),
                       PATH=str(base) + os.pathsep + os.environ['PATH'])
            result = shell(hook_path, env=env)
            writes = (base / 'writes').read_text() if (base / 'writes').exists() else ''
            logs = (base / 'logs').read_text() if (base / 'logs').exists() else ''
            return result, writes, logs

    def test_already_correct_does_not_write(self):
        result, writes, logs = self.run_case('correct')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(writes, '')
        self.assertEqual(logs, '')

    def test_wrong_gem_or_absent_retries_without_write(self):
        for case in ['absent', 'wrong_direction', 'multicast', 'wrong_id']:
            with self.subTest(case=case):
                result, writes, logs = self.run_case(case)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(writes, '')
                self.assertEqual(logs, '')

    def test_corrects_expected_gem_and_logs(self):
        result, writes, logs = self.run_case('apply')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(writes, 'meads 268 1028 10 3\n')
        self.assertIn('Applied downstream-only encryption', logs)

    def test_failed_set_or_confirmation_does_not_report_success(self):
        for case in ['command_failure', 'error_response', 'unchanged_kernel']:
            with self.subTest(case=case):
                result, writes, logs = self.run_case(case)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(writes)
                self.assertEqual(logs, '')


class BackupTests(unittest.TestCase):
    def test_backup_stream_is_an_archive_and_uses_private_fixture_only(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            fixture = base / 'fixtures'
            fixture.mkdir()
            for name in ['version.lua', 'rc.local', 'profile.ini']:
                (fixture / name).write_text('synthetic private fixture\n')
            (fixture / '8311').mkdir()
            (fixture / '8311/hook.sh').write_text('# synthetic hook\n')
            shim = '''#!/bin/sh
case "${0##*/}" in
id) echo 0;;
fw_printenv) echo 'synthetic_key=synthetic_value';;
uci)
    if [ "$1" = export ]; then echo "config $2 synthetic";
    else echo "$FIXTURE/profile.ini"; fi;;
esac
'''
            for name in ['id', 'fw_printenv', 'uci']:
                path = base / name
                path.write_text(shim)
                path.chmod(0o700)
            script = (SCRIPTS / 'backup-private.sh').read_text()
            for old, new in [('/usr/lib/lua/8311/version.lua', fixture / 'version.lua'),
                             ('/etc/rc.local', fixture / 'rc.local'),
                             ('/ptconf/8311', fixture / '8311')]:
                script = script.replace(old, str(new))
            path = base / 'backup.sh'
            path.write_text(script)
            env = dict(os.environ, FIXTURE=str(fixture),
                       PATH=str(base) + os.pathsep + os.environ['PATH'])
            archive = base / 'result.tgz'
            with archive.open('wb') as stream:
                result = subprocess.run(['sh', str(path)], stdout=stream,
                                        stderr=subprocess.PIPE, env=env, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)
            with tarfile.open(archive) as tar:
                names = tar.getnames()
                self.assertIn('./fwenv.txt', names)
                self.assertIn('./ptconf-8311/hook.sh', names)
                self.assertEqual(tar.extractfile('./active-profile.ini').read(),
                                 b'synthetic private fixture\n')


if __name__ == '__main__':
    unittest.main()
