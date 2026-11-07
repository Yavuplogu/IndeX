"""Exercise the actual CMake version calculation without compiling the app."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
CMAKE = shutil.which('cmake')


@unittest.skipUnless(CMAKE, 'CMake requis pour vérifier les métadonnées Windows')
class WindowsPublicVersion(unittest.TestCase):
    def calculate(self, stage='0', major='9', minor='2', width=None):
        with tempfile.TemporaryDirectory(prefix='index public version ') as directory:
            folder = Path(directory)
            script = folder / 'check.cmake'
            result = folder / 'result.txt'
            cmake = ROOT / 'apps/index_windows/windows/public_version.cmake'
            lines = [f'include("{cmake.as_posix()}")']
            if width is not None:
                policy = folder / 'policy.json'
                policy.write_text(json.dumps({'minor_width':width}), encoding='utf-8')
                lines.append(f'set(INDEX_WINDOWS_VERSION_POLICY "{policy.as_posix()}")')
            lines += [
                'set(FLUTTER_VERSION_BUILD 9003)',
                f'index_windows_public_version(version "{stage}" "{major}" "{minor}")',
                f'file(WRITE "{result.as_posix()}" "${{version}}")',
            ]
            script.write_text('\n'.join(lines), encoding='utf-8')
            # Native debug tests may inherit the current CI INDEX_VERSION while
            # Flutter builds pubspec's version. Only the selected semver matters.
            env = dict(os.environ, INDEX_VERSION='0.9.99')
            completed = subprocess.run([CMAKE, '-P', str(script)], env=env,
                                       capture_output=True, text=True, encoding='utf-8')
            return completed, result.read_text(encoding='utf-8') if result.exists() else None

    def test_public_version_has_padding_and_no_technical_build_number(self):
        for minor, expected in [('0','0.9.00'), ('2','0.9.02'), ('9','0.9.09'),
                                ('10','0.9.10'), ('100','0.9.100')]:
            with self.subTest(minor=minor):
                completed, result = self.calculate(minor=minor)
                self.assertEqual(completed.returncode, 0, completed.stderr)
                self.assertEqual(result, expected)

    def test_padding_is_read_from_policy(self):
        for width, expected in [(1,'0.9.2'), (2,'0.9.02'), (3,'0.9.002')]:
            with self.subTest(width=width):
                completed, result = self.calculate(width=width)
                self.assertEqual(completed.returncode, 0, completed.stderr)
                self.assertEqual(result, expected)

    def test_invalid_resource_numbers_and_padding_are_refused(self):
        for arguments in [dict(stage='-1'), dict(major='abc'), dict(minor='02'),
                          dict(minor='65536'), dict(width=0), dict(width=7)]:
            with self.subTest(arguments=arguments):
                completed, result = self.calculate(**arguments)
                self.assertNotEqual(completed.returncode, 0)
                self.assertIsNone(result)


if __name__ == '__main__':
    unittest.main()
