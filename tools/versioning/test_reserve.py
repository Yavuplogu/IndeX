import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
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
        policy.write_text('{"stage":0,"major":5,"first_minor":1}', encoding='utf-8')

    def test_local_increment_and_explicit_major(self):
        self.assertEqual(reserve.reserve()['display'], '0.5.01')
        self.assertEqual(reserve.reserve()['display'], '0.5.02')
        self.assertEqual(reserve.reserve()['build_name'], '0.5.3')
        self.assertEqual(reserve.reserve()['build_number'], 4)
        policy = reserve.ROOT / 'tools/versioning/version.json'
        policy.write_text('{"stage":1,"major":5,"first_minor":1}', encoding='utf-8')
        self.assertEqual(reserve.reserve()['display'], '1.5.01')

    def test_authorized_major_six_starts_at_zero_and_preserves_old_counter(self):
        self.assertEqual(reserve.reserve()['display'], '0.5.01')
        policy = reserve.ROOT / 'tools/versioning/version.json'
        policy.write_text('{"stage":0,"major":6,"first_minor":0,"minor_width":1}', encoding='utf-8')
        first = reserve.reserve()
        self.assertEqual(first, {'display': '0.6.0', 'build_name': '0.6.0', 'build_number': 1})
        self.assertEqual(reserve.reserve()['display'], '0.6.1')
        self.assertEqual(json.loads((reserve.ROOT / 'dist/build-version-counter.json').read_text(encoding='utf-8')), {'0.5': 1, '0.6': 1})

    def test_ci_major_six_does_not_reset_historical_counter(self):
        self.init_remote()
        self.assertEqual(reserve.reserve(True)['display'], '0.5.01')
        policy = reserve.ROOT / 'tools/versioning/version.json'
        policy.write_text('{"stage":0,"major":6,"first_minor":0,"minor_width":1}', encoding='utf-8')
        self.assertEqual(reserve.reserve(True)['display'], '0.6.0')
        self.assertEqual(reserve.reserve(True)['display'], '0.6.1')
        policy.write_text('{"stage":0,"major":6,"first_minor":0,"minor_width":2}', encoding='utf-8')
        self.assertEqual(reserve.reserve(True)['display'], '0.6.02')
        reserve.git('fetch', 'origin', reserve.BRANCH)
        self.assertEqual(json.loads(reserve.git('show', 'FETCH_HEAD:' + reserve.COUNTER_FILE)), {'0.5': 1, '0.6': 2})

    def test_padding_boundaries_preserve_counter_and_semver(self):
        policy = reserve.ROOT / 'tools/versioning/version.json'
        policy.write_text('{"stage":0,"major":6,"first_minor":0,"minor_width":2}', encoding='utf-8')
        counter = reserve.ROOT / 'dist/build-version-counter.json'
        counter.parent.mkdir()
        counter.write_text('{"0.5":42,"0.6":7}', encoding='utf-8')
        self.assertEqual(reserve.reserve(), {'display': '0.6.08', 'build_name': '0.6.8', 'build_number': 9})
        self.assertEqual(reserve.reserve()['display'], '0.6.09')
        self.assertEqual(reserve.reserve()['display'], '0.6.10')
        self.assertEqual(reserve.reserve()['display'], '0.6.11')
        self.assertEqual(json.loads(counter.read_text(encoding='utf-8')), {'0.5':42,'0.6':11})
        counter.write_text('{"0.5":42,"0.6":98}', encoding='utf-8')
        self.assertEqual(reserve.reserve()['display'], '0.6.99')
        self.assertEqual(reserve.reserve()['display'], '0.6.100')

    def test_major_seven_preserves_history_and_increases_android_code(self):
        policy = reserve.ROOT / 'tools/versioning/version.json'
        policy.write_text('{"stage":0,"major":7,"first_minor":1,"minor_width":2,"build_number_base":7000}', encoding='utf-8')
        counter = reserve.ROOT / 'dist/build-version-counter.json'
        counter.parent.mkdir()
        counter.write_text('{"0.6":60}', encoding='utf-8')
        self.assertEqual(reserve.reserve(), {'display':'0.7.01', 'build_name':'0.7.1', 'build_number':7001})
        self.assertEqual(reserve.reserve()['build_number'], 7002)
        self.assertEqual(json.loads(counter.read_text(encoding='utf-8')), {'0.6':60,'0.7':2})

    def init_remote(self):
        remote = Path(self.temporary.name) / 'origin.git'
        subprocess.run(['git', 'init', '--bare', str(remote)], check=True, capture_output=True)
        reserve.git('init', '-b', 'main')
        reserve.git('config', 'user.name', 'test')
        reserve.git('config', 'user.email', 'test@example.invalid')
        (reserve.ROOT / reserve.COUNTER_FILE).write_text('{}\n', encoding='utf-8')
        reserve.git('add', '.')
        reserve.git('commit', '-m', 'initial')
        reserve.git('remote', 'add', 'origin', str(remote))
        reserve.git('push', 'origin', 'main')

    def test_major_nine_shared_ci_starts_at_zero_and_preserves_history(self):
        policy = reserve.ROOT / 'tools/versioning/version.json'
        policy.write_text('{"stage":0,"major":9,"first_minor":0,"minor_width":2,"build_number_base":9000}', encoding='utf-8')
        self.init_remote()
        history = {'0.5':16, '0.6':29, '0.7':8}
        self.set_main_counters(history)
        for minor in range(11):
            result = reserve.reserve(True)
            self.assertEqual(result['display'], f'0.9.{minor:02d}')
            self.assertEqual(result['build_name'], f'0.9.{minor}')
            self.assertEqual(result['build_number'], 9001 + minor)
        reserve.git('fetch', 'origin', 'main')
        self.assertEqual(json.loads(reserve.git('show', 'FETCH_HEAD:' + reserve.COUNTER_FILE)),
                         {**history, '0.9':10})

    def test_persistent_ci_counter_updates_main_without_changing_checkout(self):
        self.init_remote()
        head = reserve.git('rev-parse', 'HEAD')
        self.assertEqual(reserve.reserve(True)['display'], '0.5.01')
        # Une nouvelle construction (même code, après échec ou relance) réserve 02.
        self.assertEqual(reserve.reserve(True)['display'], '0.5.02')
        self.assertEqual(reserve.git('rev-parse', 'HEAD'), head)
        reserve.git('fetch', 'origin', reserve.BRANCH)
        self.assertEqual(json.loads(reserve.git('show', 'FETCH_HEAD:' + reserve.COUNTER_FILE)), {'0.5': 2})


    def test_recovers_windows_cr_filename_without_reusing_version(self):
        self.init_remote()
        blob = reserve.git('hash-object', '-w', '--stdin', input='{\r\n  "0.5": 1\r\n}\r\n')
        # Reproduit exactement l'arbre errone observe dans les logs Windows.
        tree = reserve.git('mktree', input=f'100644 blob {blob}\tcounters.json\r\n')
        commit = reserve.git('commit-tree', tree, '-m', 'ancien compteur CRLF')
        reserve.git('push', 'origin', f'{commit}:refs/heads/{reserve.LEGACY_BRANCH}')
        self.assertEqual(reserve.reserve(True)['display'], '0.5.02')
        reserve.git('fetch', 'origin', reserve.BRANCH)
        self.assertEqual(reserve.git('ls-remote', '--heads', 'origin', f'refs/heads/{reserve.LEGACY_BRANCH}'), '')
        self.assertEqual(json.loads(reserve.git('show', 'FETCH_HEAD:' + reserve.COUNTER_FILE)), {'0.5': 2})
        self.assertEqual(reserve.reserve(True)['display'], '0.5.03')

    def test_missing_counter_is_not_silently_reset(self):
        self.init_remote()
        parent = reserve.git('rev-parse', 'HEAD')
        with self.assertRaisesRegex(ValueError, 'absent ou ambigu'):
            reserve.read_counters(parent, legacy=True)

    def set_main_counters(self, counters):
        path = reserve.ROOT / reserve.COUNTER_FILE
        path.write_text(json.dumps(counters) + '\n', encoding='utf-8')
        reserve.git('add', reserve.COUNTER_FILE)
        reserve.git('commit', '-m', 'compteur main')
        reserve.git('push', 'origin', 'main')

    def create_legacy(self, counters):
        blob = reserve.git('hash-object', '-w', '--stdin', input=json.dumps(counters))
        tree = reserve.git('mktree', '-z', input=f'100644 blob {blob}\tcounters.json\0')
        commit = reserve.git('commit-tree', tree, '-m', 'ancien compteur')
        reserve.git('push', 'origin', f'{commit}:refs/heads/{reserve.LEGACY_BRANCH}')
        return commit

    def test_migration_merges_live_legacy_maxima_and_removes_old_branch(self):
        policy = reserve.ROOT / 'tools/versioning/version.json'
        policy.write_text('{"stage":0,"major":7,"first_minor":1,"minor_width":2,"build_number_base":7000}', encoding='utf-8')
        self.init_remote()
        self.set_main_counters({'0.5':16, '0.6':29, '0.7':1})
        self.create_legacy({'0.5':15, '0.6':30, '0.7':4})
        result = reserve.reserve(True)
        self.assertEqual(result['display'], '0.7.05')
        self.assertEqual(result['build_number'], 7005)
        reserve.git('fetch', 'origin', 'main')
        self.assertEqual(json.loads(reserve.git('show', 'FETCH_HEAD:' + reserve.COUNTER_FILE)),
                         {'0.5':16, '0.6':30, '0.7':5})
        self.assertEqual(reserve.git('ls-remote', '--heads', 'origin', 'refs/heads/' + reserve.LEGACY_BRANCH), '')
        self.assertEqual(reserve.reserve(True)['display'], '0.7.06')

    def test_remote_new_code_and_local_index_are_preserved_with_exact_provenance(self):
        self.init_remote()
        source = reserve.git('rev-parse', 'HEAD')
        (reserve.ROOT / 'local-only.txt').write_text('ne pas toucher', encoding='utf-8')
        reserve.git('add', 'local-only.txt')
        index_before = reserve.git('write-tree')
        other = Path(self.temporary.name) / 'developer'
        def other_git(*args):
            return subprocess.run(['git', '-C', str(other), *args], check=True,
                                  capture_output=True, text=True, encoding='utf-8').stdout.strip()
        subprocess.run(['git', 'clone', '--branch', 'main', str(Path(self.temporary.name) / 'origin.git'), str(other)],
                       check=True, capture_output=True)
        other_git('config', 'user.name', 'developer')
        other_git('config', 'user.email', 'developer@example.invalid')
        (other / 'nouveau code.txt').write_text('nouvelle fonctionnalité', encoding='utf-8')
        other_git('add', '.')
        other_git('commit', '-m', 'avancement main')
        new_main = other_git('rev-parse', 'HEAD')
        other_git('push', 'origin', 'main')
        result = reserve.reserve(True)
        self.assertEqual(result['source_commit'], source)
        self.assertEqual(reserve.git('rev-parse', 'HEAD'), source)
        self.assertEqual(reserve.git('write-tree'), index_before)
        self.assertEqual((reserve.ROOT / 'local-only.txt').read_text(encoding='utf-8'), 'ne pas toucher')
        reserve.git('fetch', 'origin', 'main')
        self.assertEqual(reserve.git('rev-parse', 'FETCH_HEAD'), result['counter_commit'])
        self.assertEqual(reserve.git('rev-parse', 'FETCH_HEAD^'), new_main)
        self.assertEqual(reserve.git('diff-tree', '--no-commit-id', '--name-only', '-r', result['counter_commit']), reserve.COUNTER_FILE)
        self.assertEqual(reserve.git('show', 'FETCH_HEAD:nouveau code.txt'), 'nouvelle fonctionnalité')

    def test_missing_or_invalid_main_counter_fails_without_reset(self):
        self.init_remote()
        self.set_main_counters({'0.5':True})
        before = reserve.git('ls-remote', '--heads', 'origin', 'refs/heads/main')
        with self.assertRaisesRegex(ValueError, 'invalide'):
            reserve.reserve(True)
        self.assertEqual(reserve.git('ls-remote', '--heads', 'origin', 'refs/heads/main'), before)
        reserve.git('rm', reserve.COUNTER_FILE)
        reserve.git('commit', '-m', 'compteur manquant')
        reserve.git('push', 'origin', 'main')
        before = reserve.git('ls-remote', '--heads', 'origin', 'refs/heads/main')
        with self.assertRaisesRegex(ValueError, 'absent'):
            reserve.reserve(True)
        self.assertEqual(reserve.git('ls-remote', '--heads', 'origin', 'refs/heads/main'), before)

    def test_denied_deletion_aborts_the_entire_migration(self):
        self.init_remote()
        self.create_legacy({'0.5':4})
        remote = Path(self.temporary.name) / 'origin.git'
        subprocess.run(['git', '--git-dir', str(remote), 'config', 'receive.denyDeletes', 'true'], check=True)
        before = reserve.git('ls-remote', '--heads', 'origin')
        with self.assertRaises(subprocess.CalledProcessError):
            reserve.reserve(True)
        self.assertEqual(reserve.git('ls-remote', '--heads', 'origin'), before)

    def test_legacy_race_cannot_delete_new_counter_or_publish_duplicate(self):
        self.init_remote()
        legacy_parent = self.create_legacy({'0.5':4})
        original_git = reserve.git
        advanced = False
        def racing_git(*args, **kwargs):
            nonlocal advanced
            if args[:2] == ('push', '--atomic') and not advanced:
                advanced = True
                blob = original_git('hash-object', '-w', '--stdin', input='{"0.5":5}')
                tree = original_git('mktree', '-z', input=f'100644 blob {blob}\tcounters.json\0')
                commit = original_git('commit-tree', tree, '-p', legacy_parent, '-m', 'réservation concurrente')
                original_git('push', 'origin', f'{commit}:refs/heads/{reserve.LEGACY_BRANCH}')
            return original_git(*args, **kwargs)
        before = reserve.git('ls-remote', '--heads', 'origin', 'refs/heads/main')
        with patch.object(reserve, 'git', side_effect=racing_git):
            with self.assertRaises(subprocess.CalledProcessError):
                reserve.reserve(True)
        self.assertEqual(reserve.git('ls-remote', '--heads', 'origin', 'refs/heads/main'), before)
        self.assertEqual(reserve.reserve(True)['display'], '0.5.06')

    def test_concurrent_main_push_is_not_overwritten(self):
        self.init_remote()
        original_git = reserve.git
        advanced = False
        def racing_git(*args, **kwargs):
            nonlocal advanced
            if args[:2] == ('push', '--atomic') and not advanced:
                advanced = True
                parent = original_git('rev-parse', 'HEAD')
                tree = original_git('rev-parse', 'HEAD^{tree}')
                commit = original_git('commit-tree', tree, '-p', parent, '-m', 'commit concurrent')
                original_git('push', 'origin', f'{commit}:refs/heads/main')
            return original_git(*args, **kwargs)
        with patch.object(reserve, 'git', side_effect=racing_git):
            with self.assertRaises(subprocess.CalledProcessError):
                reserve.reserve(True)
        reserve.git('fetch', 'origin', 'main')
        self.assertEqual(reserve.git('log', '-1', '--format=%s', 'FETCH_HEAD'), 'commit concurrent')
        self.assertEqual(json.loads(reserve.git('show', 'FETCH_HEAD:' + reserve.COUNTER_FILE)), {})
        self.assertEqual(reserve.reserve(True)['display'], '0.5.01')

    def test_main_cli_exports_original_source_and_counter_commit(self):
        import os
        self.init_remote()
        source = reserve.git('rev-parse', 'HEAD')
        env_file = Path(self.temporary.name) / 'github-env'
        with patch.dict(os.environ, {'GITHUB_ENV':str(env_file)}), patch('sys.argv', ['reserve.py','--ci']):
            reserve.main()
        values = dict(line.split('=', 1) for line in env_file.read_text(encoding='utf-8').splitlines())
        self.assertEqual(values['INDEX_SOURCE_COMMIT'], source)
        self.assertEqual(values['INDEX_VERSION'], '0.5.01')
        reserve.git('fetch', 'origin', 'main')
        self.assertEqual(values['INDEX_COUNTER_COMMIT'], reserve.git('rev-parse', 'FETCH_HEAD'))
        self.assertFalse((reserve.ROOT / 'dist/version-reservation.lock').exists())

    def test_unicode_git_content_with_windows_default_encoding(self):
        # Simule Windows-1252 même sur Linux : sans encoding explicite, Path
        # écrit é en 0xe9 alors que le helper Git exige des octets UTF-8.
        def windows_encoding(encoding, stacklevel=2):
            return 'cp1252' if encoding is None else encoding
        with patch('pathlib.io.text_encoding', side_effect=windows_encoding):
            self.test_remote_new_code_and_local_index_are_preserved_with_exact_provenance()


if __name__ == '__main__':
    unittest.main()
