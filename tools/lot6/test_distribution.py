"""Garde-fous de distribution : refus explicites, sans clé de production."""
import base64
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from inspect_apk import ROOT, PERMISSIONS, inspect, validate_release_output
import prepare_signing

CERT = 'ab' * 32
BADGING = "package: name='fr.index.app' versionCode='31' versionName='0.6.30'\nsdkVersion:'24'\ntargetSdkVersion:'36'"
XML = 'A: android:allowBackup(0x01010280)=(type 0x12)0x0'
SIGNATURE = f'Signer #1 certificate SHA-256 digest: {CERT}\nSigner #1 certificate DN: CN=IndeX'
PERMS = '\n'.join(f"uses-permission: name='{p}'" for p in PERMISSIONS)


class DistributionTest(unittest.TestCase):
    def check_output(self, **changes):
        args = dict(badging=BADGING, xml=XML, permissions=PERMS, signature=SIGNATURE,
                    expected_cert=CERT, build_name='0.6.30', build_number=31)
        args.update(changes)
        return validate_release_output(**args)

    def test_release_requires_identity_version_permissions_and_certificate(self):
        self.assertEqual(self.check_output(), CERT)
        for change in [dict(expected_cert='cd' * 32), dict(build_number=32),
                       dict(badging=BADGING.replace('fr.index.app', 'fr.index.index_windows')),
                       dict(xml=XML + '\nA: android:authorities="fr.index.app.documents"'),
                       dict(build_name='0.6.31'), dict(badging=BADGING.replace('24', '23')),
                       dict(permissions=PERMS + "\nuses-permission: name='android.permission.READ_PHONE_STATE'"),
                       dict(permissions=PERMS.replace('INTERNET', 'CAMERA')),
                       dict(signature=SIGNATURE.replace('CN=IndeX', 'CN=Android Debug')),
                       dict(xml=''), dict(badging=BADGING + '\napplication-debuggable'),
                       dict(xml=XML + '\nA: android:testOnly(0x01010272)=(type 0x12)0xffffffff')]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.check_output(**change)

    def apk(self, path, extra=None, debug=False, corrupt_seed=False):
        with zipfile.ZipFile(path, 'w') as archive:
            for name in ['catalogue.sqlite', 'catalogue.sqlite.manifest.json']:
                data = (ROOT / 'assets' / name).read_bytes()
                if corrupt_seed and name == 'catalogue.sqlite':
                    data = data[:-1] + bytes([data[-1] ^ 1])
                archive.writestr('assets/flutter_assets/assets/' + name, data)
            for name in ['libflutter.so', 'libsqlite3.so']:
                archive.writestr('lib/arm64-v8a/' + name, b'test')
            archive.writestr('assets/flutter_assets/kernel_blob.bin' if debug else 'lib/arm64-v8a/libapp.so', b'test')
            archive.writestr('assets/flutter_assets/NOTICES.Z', b'notice')
            archive.writestr('assets/flutter_assets/assets/icons/LICENSE-octicons.txt', b'notice')
            if extra:
                archive.writestr(extra, b'forbidden')

    def test_release_refuses_debug_and_sensitive_files_before_signature(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'test.apk'
            self.apk(path, debug=True)
            self.assertEqual(inspect(path)['mode'], 'diagnostic')
            with self.assertRaisesRegex(ValueError, 'libapp.so'):
                inspect(path, release=True)
            for extra in ['assets/test.mp3', 'assets/index-utilisateur.sqlite', 'assets/signing.jks',
                          'assets/key.properties', 'lib/x86_64/libapp.so']:
                self.apk(path, extra=extra)
                with self.subTest(extra=extra), self.assertRaises(ValueError):
                    inspect(path, release=True)

    def test_bad_catalogue_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'test.apk'
            self.apk(path, corrupt_seed=True)
            with self.assertRaisesRegex(ValueError, 'Catalogue'):
                inspect(path)

    def test_signing_secret_is_private_and_outside_artifact(self):
        with tempfile.TemporaryDirectory() as folder:
            env = {'RUNNER_TEMP': folder, 'GITHUB_ENV': str(Path(folder) / 'env'),
                   'INDEX_ANDROID_KEYSTORE_BASE64': base64.b64encode(b'only-test').decode(),
                   'INDEX_ANDROID_STORE_PASSWORD': 'test', 'INDEX_ANDROID_KEY_ALIAS': 'test',
                   'INDEX_ANDROID_KEY_PASSWORD': 'test', 'INDEX_ANDROID_CERT_SHA256': CERT}
            with patch.dict(os.environ, env, clear=True):
                prepare_signing.main()
                path = Path(folder) / 'index-release-signing.jks'
                self.assertEqual(path.read_bytes(), b'only-test')
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
                with self.assertRaises(FileExistsError):
                    prepare_signing.main()
                del os.environ['INDEX_ANDROID_KEY_PASSWORD']
                with self.assertRaisesRegex(SystemExit, 'incomplets'):
                    prepare_signing.main()

    def test_release_script_stops_before_flutter_without_signing(self):
        env = {k: v for k, v in os.environ.items() if not k.startswith('INDEX_')}
        result = subprocess.run(['bash', str(ROOT / 'tools/lot6/build_release.sh')],
                                env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Configuration release absente', result.stderr)


if __name__ == '__main__':
    unittest.main()
