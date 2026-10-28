#!/usr/bin/env python3
"""Audit en lecture seule des huit MP3 de régression, jamais utilisé par le scan applicatif."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
FAILURES = ('2007-10-20', '2007-04-28', '2003-09-06')


def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def clean(data):
    return re.sub(r'0x[0-9a-fA-F]+', '0x…', data.decode('utf-8', errors='replace')).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--decode', action='store_true', help='Décoder intégralement vers la sortie nulle, sans fichier audio produit.')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    files = sorted((ROOT / 'MP3_Files/MP3_Bugs').glob('*.mp3'))
    if len(files) != 8:
        raise ValueError('Les huit fichiers de régression sont requis.')
    rows = []
    for path in files:
        before = digest(path)
        result = subprocess.run(['ffprobe', '-v', 'warning', '-show_format', '-show_streams', '-of', 'json', str(path)], check=True, capture_output=True)
        data = json.loads(result.stdout.decode('utf-8', errors='replace'))
        with path.open('rb') as file:
            head = file.read(10)
            file.seek(-128, 2)
            tail = file.read(128)
        row = {'file': path.name, 'sha256': before, 'bytes': path.stat().st_size,
               'windows_user_report': 'timeout' if path.name.startswith(FAILURES) else 'ok',
               'id3v2_present': head.startswith(b'ID3'), 'id3v1_present': tail.startswith(b'TAG'),
               'duration_seconds': float(data['format']['duration']),
               'streams': [{k: s.get(k) for k in ('codec_name', 'sample_rate', 'channels', 'bit_rate')} for s in data['streams']],
               'probe_warnings': clean(result.stderr)}
        if args.decode:
            decode = subprocess.run(['ffmpeg', '-nostdin', '-hide_banner', '-v', 'warning', '-i', str(path), '-map', '0:a:0', '-f', 'null', '-'], capture_output=True)
            row['linux_ffmpeg_decode_exit_code'] = decode.returncode
            row['decode_warnings'] = clean(decode.stderr)
        if digest(path) != before:
            raise RuntimeError('Le fichier a changé pendant l’audit : ' + path.name)
        rows.append(row)
    output = {'date': '2026-10-28', 'dataset_commit': 'f13f098',
              'scope': 'Audit Linux ; signalement Windows utilisateur conservé, aucune lecture WinRT validée ici.',
              'mp3_unchanged': True, 'files': rows}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(files)} fichiers audités sans modification ; rapport : {args.output}')


if __name__ == '__main__':
    main()
