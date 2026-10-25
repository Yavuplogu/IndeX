#!/usr/bin/env python3
"""Prépare les assets Flutter depuis l'unique seed versionné, sans le modifier."""
import hashlib
import json
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[2]
source = root / 'assets/catalogue.sqlite'
manifest = root / 'assets/catalogue.sqlite.manifest.json'
metadata = json.loads(manifest.read_text(encoding='utf-8'))
if hashlib.sha256(source.read_bytes()).hexdigest() != metadata['sqlite_sha256']:
    raise ValueError('Empreinte du seed documentaire invalide.')
target = root / 'apps/index_windows/assets'
target.mkdir(parents=True, exist_ok=True)
for path in (source, manifest):
    destination = target / path.name
    if not destination.exists() or destination.read_bytes() != path.read_bytes():
        shutil.copyfile(path, destination)
print('Assets Flutter préparés : seed et manifeste vérifiés, aucun MP3.')
