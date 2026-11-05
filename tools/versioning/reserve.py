#!/usr/bin/env python3
"""Réserve un numéro avant build ; compteur CI versionné sur main."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BRANCH = 'main'
LEGACY_BRANCH = 'index-build-versions'
COUNTER_FILE = 'tools/versioning/counters.json'


def git(*args, input=None, env=None):
    # Le mode texte de stdin traduit LF en CRLF sur Windows. Pour la plomberie
    # Git, ce CR devient un octet du nom d'entree de l'arbre : utiliser UTF-8 brut.
    raw = None if input is None else input.encode('utf-8')
    return subprocess.run(['git', *args], cwd=ROOT, input=raw,
                          check=True, stdout=subprocess.PIPE, env=env).stdout.decode('utf-8').strip()


def validate_counters(counters):
    if not isinstance(counters, dict) or any(type(v) is not int or v < 0 for v in counters.values()):
        raise ValueError('Compteur Git invalide ; reservation refusee.')
    return counters


def read_counters(parent, legacy=False, missing_ok=False):
    # L'ancien nom CRLF Windows est accepté uniquement pendant la migration.
    entries = []
    paths = () if legacy else ('--', COUNTER_FILE)
    for entry in git('ls-tree', '-z', parent, *paths).split('\0'):
        if not entry:
            continue
        metadata, name = entry.split('\t', 1)
        mode, kind, oid = metadata.split()
        expected = ('counters.json', 'counters.json\r') if legacy else (COUNTER_FILE,)
        if name in expected and kind == 'blob':
            entries.append(oid)
    if not entries and missing_ok:
        return None
    if len(entries) != 1:
        raise ValueError('Compteur Git absent ou ambigu ; reservation refusee sans remise a zero.')
    return validate_counters(json.loads(git('cat-file', 'blob', entries[0])))


def fetch_head(branch):
    git('fetch', '--no-tags', 'origin', f'refs/heads/{branch}')
    return git('rev-parse', 'FETCH_HEAD')


def reserve_on_main(parent, legacy_parent, content, message):
    # Index temporaire : seul le compteur change sur main, jamais le checkout
    # ni les autres fichiers du dernier main (qui peut avoir avancé entre-temps).
    with tempfile.TemporaryDirectory(prefix='index-counter-') as directory:
        index_env = dict(os.environ, GIT_INDEX_FILE=str(Path(directory) / 'index'))
        git('read-tree', parent, env=index_env)
        blob = git('hash-object', '-w', '--stdin', input=content)
        git('update-index', '--add', '--cacheinfo', '100644', blob, COUNTER_FILE, env=index_env)
        tree = git('write-tree', env=index_env)
    identity = dict(os.environ, GIT_AUTHOR_NAME='IndeX build', GIT_AUTHOR_EMAIL='index-build@users.noreply.github.com',
                    GIT_COMMITTER_NAME='IndeX build', GIT_COMMITTER_EMAIL='index-build@users.noreply.github.com')
    commit = git('commit-tree', tree, '-p', parent, '-m', message, env=identity)
    # Migration transactionnelle : réservation ET retrait de l'ancien compteur,
    # ou aucun des deux. Le lease interdit de supprimer une branche qui a avancé.
    push = ['push', '--atomic']
    if legacy_parent:
        push.append(f'--force-with-lease=refs/heads/{LEGACY_BRANCH}:{legacy_parent}')
    push += ['origin', f'{commit}:refs/heads/{BRANCH}']
    if legacy_parent:
        push.append(f':refs/heads/{LEGACY_BRANCH}')
    git(*push)
    return commit


def reserve(ci=False):
    policy = json.loads((ROOT / 'tools/versioning/version.json').read_text())
    if policy['stage'] not in (0, 1) or policy['major'] < 0 or policy['first_minor'] < 0:
        raise ValueError('Politique de version invalide')
    build_base = policy.get('build_number_base', 0)
    if type(build_base) is not int or build_base < 0:
        raise ValueError('Base de build invalide')
    width = policy.get('minor_width', 2)
    if type(width) is not int or width < 1 or width > 6:
        raise ValueError('Largeur de version invalide')
    key = f"{policy['stage']}.{policy['major']}"
    parent = None
    state_path = ROOT / 'dist/build-version-counter.json'
    legacy_parent = None
    source_commit = None
    if ci:
        source_commit = git('rev-parse', 'HEAD')
        parent = fetch_head(BRANCH)
        counters = read_counters(parent, missing_ok=True)
        remote = git('ls-remote', '--heads', 'origin', f'refs/heads/{LEGACY_BRANCH}')
        if remote:
            legacy_parent = fetch_head(LEGACY_BRANCH)
            legacy_counters = read_counters(legacy_parent, legacy=True)
            counters = {} if counters is None else counters
            for series, value in legacy_counters.items():
                counters[series] = max(counters.get(series, 0), value)
        elif counters is None:
            raise ValueError('Compteur main absent ; reservation refusee sans remise a zero.')
    else:
        counters = validate_counters(json.loads(state_path.read_text())) if state_path.exists() else {}
    minor = max(policy['first_minor'], counters.get(key, policy['first_minor'] - 1) + 1)
    counters[key] = minor
    content = json.dumps(counters, indent=2) + '\n'
    if ci:
        commit = reserve_on_main(parent, legacy_parent, content, f'Réserver IndeX {key}.{minor:0{width}d}')
    else:
        state_path.parent.mkdir(parents=True, exist_ok=True)
        # Verrou exclusif : deux builds locaux ne réservent pas le même numéro.
        # L'appelant garde ce verrou pendant toute l'opération reserve().
        fd, temporary = tempfile.mkstemp(dir=state_path.parent)
        with os.fdopen(fd, 'w') as out:
            out.write(content)
        os.replace(temporary, state_path)
    result = {'display': f'{key}.{minor:0{width}d}', 'build_name': f'{key}.{minor}',
              'build_number': build_base + minor + (1 if policy['first_minor'] == 0 else 0)}
    if ci:
        result.update(source_commit=source_commit, counter_commit=commit)
    return result


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
                if args.ci:
                    out.write(f"INDEX_SOURCE_COMMIT={version['source_commit']}\nINDEX_COUNTER_COMMIT={version['counter_commit']}\n")
        print(json.dumps(version))
    finally:
        lock.unlink()


if __name__ == '__main__':
    main()
