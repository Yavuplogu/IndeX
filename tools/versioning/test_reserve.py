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

    def test_persistent_ci_counter_does_not_modify_main(self):
        remote = Path(self.temporary.name) / 'origin.git'
        subprocess.run(['git', 'init', '--bare', str(remote)], check=True, capture_output=True)
        reserve.git('init', '-b', 'main')
        reserve.git('config', 'user.name', 'test')
        reserve.git('config', 'user.email', 'test@example.invalid')
        reserve.git('add', '.')
        reserve.git('commit', '-m', 'initial')
        head = reserve.git('rev-parse', 'HEAD')
        reserve.git('remote', 'add', 'origin', str(remote))
        reserve.git('push', 'origin', 'main')
        self.assertEqual(reserve.reserve(True)['display'], '0.5.01')
        # Une nouvelle construction (même code, après échec ou relance) réserve 02.
        self.assertEqual(reserve.reserve(True)['display'], '0.5.02')
        self.assertEqual(reserve.git('rev-parse', 'HEAD'), head)
        reserve.git('fetch', 'origin', reserve.BRANCH)
        self.assertEqual(json.loads(reserve.git('show', 'FETCH_HEAD:counters.json')), {'0.5': 2})


if __name__ == '__main__':
    unittest.main()
