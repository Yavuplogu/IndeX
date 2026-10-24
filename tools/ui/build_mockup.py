#!/usr/bin/env python3
"""Actualise le catalogue intégré au HTML de référence, avec Python standard."""
import json
from pathlib import Path
import re
import sqlite3
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HTML = ROOT / 'docs/ui/maquettes.html'
SEED = ROOT / 'assets/catalogue.sqlite'


def main():
    with sqlite3.connect(SEED.as_uri() + '?mode=ro', uri=True) as db:
        db.row_factory = sqlite3.Row
        if db.execute('PRAGMA application_id').fetchone()[0] != 0x49445831:
            raise ValueError('Le seed ne correspond pas à IndeX.')
        sources, music = {}, {}
        for row in db.execute('SELECT * FROM literary_sources ORDER BY episode_id,sequence'):
            related = re.findall(r'\(([^()]+\.mp3)\)', row['raw_text'].partition('Liste des épisodes connexes :')[2])
            sources.setdefault(row['episode_id'], []).append({
                'title': row['title'], 'author': row['author'],
                'publisher': row['publisher'], 'related': related,
            })
        for row in db.execute('SELECT * FROM music_tracks ORDER BY episode_id,sequence'):
            music.setdefault(row['episode_id'], []).append({
                key: row[key] for key in ('artist', 'title', 'album', 'label')
            })
        episodes = []
        for index, row in enumerate(db.execute(
            'SELECT id,original_name,title,broadcast_date,description FROM episodes ORDER BY broadcast_date,id'
        )):
            original = row['original_name']
            episodes.append({
                'id': row['id'], 'originalName': original, 'title': row['title'],
                'date': row['broadcast_date'], 'description': row['description'],
                'sources': sources.get(row['id'], []), 'music': music.get(row['id'], []),
                # États fictifs et reproductibles : aucune donnée personnelle du seed.
                'status': 'progress' if original == 'mr_x_2004_12_25.mp3' else 'heard' if index % 5 == 0 else 'new',
                'favorite': False,
                'audio': index % 3 == 0 or original == 'mr_x_2004_12_25.mp3',
            })
    names = {episode['originalName'] for episode in episodes}
    for episode in episodes:
        for source in episode['sources']:
            if not set(source['related']) <= names:
                raise ValueError('Un épisode connexe manque au catalogue ; vérifier les sources.')
    data = json.dumps(episodes, ensure_ascii=False, indent=2).replace('<', '\\u003c')
    text = HTML.read_text(encoding='utf-8')
    pattern = r'(<script id="catalogue-data" type="application/json">\n).*?(\n</script>)'
    updated, count = re.subn(pattern, lambda match: match[1] + data + match[2], text, count=1, flags=re.S)
    if count != 1:
        raise ValueError('Bloc catalogue-data introuvable ; HTML inchangé.')
    if updated != text:
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=HTML.parent, delete=False) as output:
                temporary = Path(output.name)
                output.write(updated)
            temporary.replace(HTML)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
    print(f'{len(episodes)} épisodes, {sum(map(len, sources.values()))} références, '
          f'{sum(map(len, music.values()))} musiques : HTML actualisé.')


if __name__ == '__main__':
    main()
