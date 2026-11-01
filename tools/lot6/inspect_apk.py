#!/usr/bin/env python3
"""Contrôles hors appareil de l’APK de diagnostic, sans extraire ses fichiers."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('apk', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
seed = root / 'assets/catalogue.sqlite'
manifest = json.loads((root / 'assets/catalogue.sqlite.manifest.json').read_text())
expected = manifest['sqlite_sha256']
with zipfile.ZipFile(args.apk) as archive:
    names = archive.namelist()
    if len(names) != len(set(names)):
        raise ValueError('Entrées ZIP dupliquées.')
    forbidden = [n for n in names if n.lower().endswith('.mp3') or
                 Path(n).name in {'index-utilisateur.sqlite', 'index-portable.json'}]
    if forbidden:
        raise ValueError(f'Contenu interdit : {forbidden}')
    data = archive.read('assets/flutter_assets/assets/catalogue.sqlite')
    if hashlib.sha256(data).hexdigest() != expected or data != seed.read_bytes():
        raise ValueError('Catalogue embarqué différent du seed de référence.')
    embedded = json.loads(archive.read('assets/flutter_assets/assets/catalogue.sqlite.manifest.json'))
    if embedded != manifest:
        raise ValueError('Manifeste embarqué différent de la référence.')
    for library in ['libflutter.so', 'libapp.so', 'libsqlite3.so']:
        if f'lib/arm64-v8a/{library}' not in names:
            # Les APK debug utilisent le kernel Dart et non libapp.so AOT.
            if library == 'libapp.so' and 'assets/flutter_assets/kernel_blob.bin' in names:
                continue
            raise ValueError(f'Bibliothèque ARM64 absente : {library}')
print(json.dumps({'apk': args.apk.name, 'sha256': hashlib.sha256(args.apk.read_bytes()).hexdigest(),
                  'seed_sha256': expected, 'mp3_embarques': 0,
                  'validation': 'contenu APK seulement, aucune recette physique'}, ensure_ascii=False, indent=2))
