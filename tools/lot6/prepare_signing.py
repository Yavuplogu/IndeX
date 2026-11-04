#!/usr/bin/env python3
"""Décode le secret Actions dans RUNNER_TEMP, jamais dans le dépôt ni l’artefact."""
import base64
import os
from pathlib import Path


def main():
    required = ('INDEX_ANDROID_KEYSTORE_BASE64', 'INDEX_ANDROID_STORE_PASSWORD',
                'INDEX_ANDROID_KEY_ALIAS', 'INDEX_ANDROID_KEY_PASSWORD', 'INDEX_ANDROID_CERT_SHA256')
    if any(not os.environ.get(key, '').strip() for key in required):
        raise SystemExit('Secrets de signature Android incomplets ; voir le guide Lot 6D.')
    try:
        data = base64.b64decode(''.join(os.environ[required[0]].split()), validate=True)
    except ValueError:
        raise SystemExit('Secret keystore : Base64 invalide.') from None
    if not data:
        raise SystemExit('Secret keystore vide.')
    path = Path(os.environ['RUNNER_TEMP']) / 'index-release-signing.jks'
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'wb') as stream:
        stream.write(data)
    with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as stream:
        stream.write(f'INDEX_ANDROID_KEYSTORE={path}\n')


if __name__ == '__main__':
    main()
