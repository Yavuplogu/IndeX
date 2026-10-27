#!/usr/bin/env python3
"""Réserve un numéro avant build ; compteur local ou branche Git dédiée en CI."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BRANCH = 'index-build-versions'


def git(*args, input=None, env=None):
    return subprocess.run(['git', *args], cwd=ROOT, input=input, text=True,
                          check=True, stdout=subprocess.PIPE, env=env).stdout.strip()


def reserve(ci=False):
    policy = json.loads((ROOT / 'tools/versioning/version.json').read_text())
    if policy['stage'] not in (0, 1) or policy['major'] < 0 or policy['first_minor'] < 1:
        raise ValueError('Politique de version invalide')
    key = f"{policy['stage']}.{policy['major']}"
    parent = None
    state_path = ROOT / 'dist/build-version-counter.json'
    if ci:
        remote = git('ls-remote', '--heads', 'origin', f'refs/heads/{BRANCH}')
        if remote:
            git('fetch', '--no-tags', 'origin', f'refs/heads/{BRANCH}')
            parent = git('rev-parse', 'FETCH_HEAD')
            counters = json.loads(git('show', f'{parent}:counters.json'))
        else:
            counters = {}
    else:
        counters = json.loads(state_path.read_text()) if state_path.exists() else {}
    minor = max(policy['first_minor'], counters.get(key, policy['first_minor'] - 1) + 1)
    counters[key] = minor
    content = json.dumps(counters, indent=2) + '\n'
    if ci:
        # La CI Windows sérialise les réservations. Un push concurrent est refusé
        # (pas de force), jamais réessayé avec un numéro déjà attribué.
        blob = git('hash-object', '-w', '--stdin', input=content)
        tree = git('mktree', input=f'100644 blob {blob}\tcounters.json\n')
        identity = dict(os.environ, GIT_AUTHOR_NAME='IndeX build', GIT_AUTHOR_EMAIL='index-build@users.noreply.github.com',
                        GIT_COMMITTER_NAME='IndeX build', GIT_COMMITTER_EMAIL='index-build@users.noreply.github.com')
        args = ['commit-tree', tree, '-m', f'Réserver IndeX {key}.{minor:02d}']
        if parent:
            args += ['-p', parent]
        commit = git(*args, env=identity)
        git('push', 'origin', f'{commit}:refs/heads/{BRANCH}')
    else:
        state_path.parent.mkdir(parents=True, exist_ok=True)
        # Verrou exclusif : deux builds locaux ne réservent pas le même numéro.
        # L'appelant garde ce verrou pendant toute l'opération reserve().
        fd, temporary = tempfile.mkstemp(dir=state_path.parent)
        with os.fdopen(fd, 'w') as out:
            out.write(content)
        os.replace(temporary, state_path)
    return {'display': f'{key}.{minor:02d}', 'build_name': f'{key}.{minor}', 'build_number': minor}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ci', action='store_true')
    args = parser.parse_args()
    lock = ROOT / 'dist/version-reservation.lock'
    lock.parent.mkdir(parents=True, exist_ok=True)
    os.close(os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600))
    try:
        version = reserve(args.ci)
        if os.environ.get('GITHUB_ENV'):
            with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as out:
                out.write(f"INDEX_VERSION={version['display']}\nINDEX_BUILD_NAME={version['build_name']}\nINDEX_BUILD_NUMBER={version['build_number']}\n")
        print(json.dumps(version))
    finally:
        lock.unlink()


if __name__ == '__main__':
    main()
