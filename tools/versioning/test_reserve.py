import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import reserve


class Versions(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.original_root = reserve.ROOT
        self.addCleanup(setattr, reserve, 'ROOT', self.original_root)
        reserve.ROOT = Path(self.temporary.name) / 'checkout'
        reserve.ROOT.mkdir()
        policy = reserve.ROOT / 'tools/versioning/version.json'
        policy.parent.mkdir(parents=True)
        policy.write_text('{"stage":0,"major":5,"first_minor":1}')

    def test_local_increment_and_explicit_major(self):
        self.assertEqual(reserve.reserve()['display'], '0.5.01')
        self.assertEqual(reserve.reserve()['display'], '0.5.02')
        self.assertEqual(reserve.reserve()['build_name'], '0.5.3')
        self.assertEqual(reserve.reserve()['build_number'], 4)
        policy = reserve.ROOT / 'tools/versioning/version.json'
        policy.write_text('{"stage":1,"major":5,"first_minor":1}')
        self.assertEqual(reserve.reserve()['display'], '1.5.01')

    def test_authorized_major_six_starts_at_zero_and_preserves_old_counter(self):
        self.assertEqual(reserve.reserve()['display'], '0.5.01')
        policy = reserve.ROOT / 'tools/versioning/version.json'
        policy.write_text('{"stage":0,"major":6,"first_minor":0,"minor_width":1}')
        first = reserve.reserve()
        self.assertEqual(first, {'display': '0.6.0', 'build_name': '0.6.0', 'build_number': 1})
        self.assertEqual(reserve.reserve()['display'], '0.6.1')
        self.assertEqual(json.loads((reserve.ROOT / 'dist/build-version-counter.json').read_text()), {'0.5': 1, '0.6': 1})

    def test_ci_major_six_does_not_reset_historical_counter(self):
        self.init_remote()
        self.assertEqual(reserve.reserve(True)['display'], '0.5.01')
        policy = reserve.ROOT / 'tools/versioning/version.json'
        policy.write_text('{"stage":0,"major":6,"first_minor":0,"minor_width":1}')
        self.assertEqual(reserve.reserve(True)['display'], '0.6.0')
        self.assertEqual(reserve.reserve(True)['display'], '0.6.1')
        reserve.git('fetch', 'origin', reserve.BRANCH)
        self.assertEqual(json.loads(reserve.git('show', 'FETCH_HEAD:counters.json')), {'0.5': 1, '0.6': 1})

    def init_remote(self):
        remote = Path(self.temporary.name) / 'origin.git'
        subprocess.run(['git', 'init', '--bare', str(remote)], check=True, capture_output=True)
        reserve.git('init', '-b', 'main')
        reserve.git('config', 'user.name', 'test')
        reserve.git('config', 'user.email', 'test@example.invalid')
        reserve.git('add', '.')
        reserve.git('commit', '-m', 'initial')
        reserve.git('remote', 'add', 'origin', str(remote))
        reserve.git('push', 'origin', 'main')

    def test_persistent_ci_counter_does_not_modify_main(self):
        self.init_remote()
        head = reserve.git('rev-parse', 'HEAD')
        self.assertEqual(reserve.reserve(True)['display'], '0.5.01')
        # Une nouvelle construction (même code, après échec ou relance) réserve 02.
        self.assertEqual(reserve.reserve(True)['display'], '0.5.02')
        self.assertEqual(reserve.git('rev-parse', 'HEAD'), head)
        reserve.git('fetch', 'origin', reserve.BRANCH)
        self.assertEqual(json.loads(reserve.git('show', 'FETCH_HEAD:counters.json')), {'0.5': 2})


    def test_recovers_windows_cr_filename_without_reusing_version(self):
        self.init_remote()
        blob = reserve.git('hash-object', '-w', '--stdin', input='{\r\n  "0.5": 1\r\n}\r\n')
        # Reproduit exactement l'arbre errone observe dans les logs Windows.
        tree = reserve.git('mktree', input=f'100644 blob {blob}\tcounters.json\r\n')
        commit = reserve.git('commit-tree', tree, '-m', 'ancien compteur CRLF')
        reserve.git('push', 'origin', f'{commit}:refs/heads/{reserve.BRANCH}')
        self.assertEqual(reserve.reserve(True)['display'], '0.5.02')
        reserve.git('fetch', 'origin', reserve.BRANCH)
        self.assertEqual(reserve.git('ls-tree', '--name-only', '-z', 'FETCH_HEAD'), 'counters.json\0')
        self.assertEqual(json.loads(reserve.git('show', 'FETCH_HEAD:counters.json')), {'0.5': 2})
        self.assertEqual(reserve.reserve(True)['display'], '0.5.03')

    def test_missing_counter_is_not_silently_reset(self):
        self.init_remote()
        parent = reserve.git('rev-parse', 'HEAD')
        with self.assertRaisesRegex(ValueError, 'absent ou ambigu'):
            reserve.read_counters(parent)


if __name__ == '__main__':
    unittest.main()
