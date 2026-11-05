#!/usr/bin/env python3
"""Contrôles APK hors appareil ; le mode release vérifie aussi la signature réelle."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[2]
PERMISSIONS = {
    'android.permission.INTERNET', 'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK', 'android.permission.WAKE_LOCK',
    'fr.index.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
}


def fingerprint(value):
    result = value.replace(':', '').strip().lower()
    if not re.fullmatch('[0-9a-f]{64}', result):
        raise ValueError('Empreinte SHA-256 de certificat invalide.')
    return result


def validate_release_output(badging, xml, permissions, signature, expected_cert,
                            build_name, build_number):
    package = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging)
    if not package or package.groups() != ('fr.index.app', str(build_number), build_name):
        raise ValueError('Identité ou version Android inattendue.')
    if "sdkVersion:'24'" not in badging or "targetSdkVersion:'36'" not in badging:
        raise ValueError('Versions Android minimum/cible inattendues.')
    if 'application-debuggable' in badging or re.search(
            r'android:(?:debuggable|testOnly)\([^\n]*\)=(?:\(type 0x12\))?0xffffffff', xml):
        raise ValueError('APK debuggable ou testOnly interdit en release.')
    if not re.search(r'android:allowBackup\([^\n]*\)=\(type 0x12\)0x0\b', xml):
        raise ValueError('La sauvegarde automatique Android doit rester désactivée.')
    if 'fr.index.app.documents' in xml or 'IndeXDocumentsProvider' in xml:
        raise ValueError('Ancien fournisseur MP3 privé interdit dans le manifeste.')
    found = set(re.findall(r"uses-permission: name='([^']+)'", permissions))
    if found != PERMISSIONS:
        raise ValueError(f'Permissions inattendues : ajoutées={sorted(found - PERMISSIONS)}, absentes={sorted(PERMISSIONS - found)}')
    certs = re.findall(r'^Signer #\d+ certificate SHA-256 digest: (\S+)$', signature, re.M)
    if len(certs) != 1 or fingerprint(certs[0]) != fingerprint(expected_cert):
        raise ValueError('Certificat de signature différent de l’empreinte attendue.')
    if 'CN=Android Debug' in signature:
        raise ValueError('Certificat debug interdit en release.')
    return fingerprint(certs[0])


def inspect(apk, release=False, sdk_tools=None, expected_cert=None,
            build_name=None, build_number=None):
    manifest = json.loads((ROOT / 'assets/catalogue.sqlite.manifest.json').read_text())
    expected = manifest['sqlite_sha256']
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError('Entrées ZIP dupliquées.')
        forbidden = [n for n in names if n.lower().endswith(('.mp3', '.jks', '.keystore', '.p12', '.pfx')) or
                     Path(n).name in {'index-utilisateur.sqlite', 'index-portable.json', 'key.properties'}]
        if forbidden:
            raise ValueError(f'Contenu interdit : {forbidden}')
        data = archive.read('assets/flutter_assets/assets/catalogue.sqlite')
        if hashlib.sha256(data).hexdigest() != expected or data != (ROOT / 'assets/catalogue.sqlite').read_bytes():
            raise ValueError('Catalogue embarqué différent du seed de référence.')
        embedded = json.loads(archive.read('assets/flutter_assets/assets/catalogue.sqlite.manifest.json'))
        if embedded != manifest:
            raise ValueError('Manifeste embarqué différent de la référence.')
        for library in ['libflutter.so', 'libapp.so', 'libsqlite3.so']:
            if f'lib/arm64-v8a/{library}' not in names:
                if not release and library == 'libapp.so' and 'assets/flutter_assets/kernel_blob.bin' in names:
                    continue
                raise ValueError(f'Bibliothèque ARM64 absente : {library}')
        if release:
            if 'assets/flutter_assets/kernel_blob.bin' in names or any(
                    n.startswith('lib/') and not n.startswith('lib/arm64-v8a/') for n in names):
                raise ValueError('Release attendue : AOT et ARM64 seulement.')
            for notice in ['assets/flutter_assets/NOTICES.Z', 'assets/flutter_assets/assets/icons/LICENSE-octicons.txt']:
                if not archive.read(notice):
                    raise ValueError(f'Notice vide : {notice}')
    report = {'apk': apk.name, 'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
              'seed_sha256': expected, 'mp3_embarques': 0,
              'mode': 'release' if release else 'diagnostic',
              'validation': 'contrôles hors appareil ; aucune recette physique'}
    if release:
        if not all([sdk_tools, expected_cert, build_name, build_number]):
            raise ValueError('Release : outils SDK, certificat et version attendus obligatoires.')
        def run(tool, *args):
            return subprocess.run([str(sdk_tools / tool), *map(str, args)], check=True,
                                  text=True, capture_output=True).stdout
        signature = run('apksigner', 'verify', '--verbose', '--print-certs', apk)
        cert = validate_release_output(
            run('aapt', 'dump', 'badging', apk),
            run('aapt', 'dump', 'xmltree', apk, 'AndroidManifest.xml'),
            run('aapt', 'dump', 'permissions', apk), signature, expected_cert,
            build_name, build_number)
        report.update(certificate_sha256=cert, version_name=build_name,
                      version_code=int(build_number), permissions=sorted(PERMISSIONS))
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--release', action='store_true')
    parser.add_argument('--sdk-tools', type=Path)
    parser.add_argument('--certificate-sha256')
    parser.add_argument('--build-name')
    parser.add_argument('--build-number', type=int)
    args = parser.parse_args()
    print(json.dumps(inspect(args.apk, args.release, args.sdk_tools,
                             args.certificate_sha256, args.build_name, args.build_number),
                     ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
