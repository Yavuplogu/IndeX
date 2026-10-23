"""Oracle indépendant Mutagen 1.47.0, sans lecture ID3v1 synthétisée en COMM.

Depuis la racine : PYTHONPATH=<mutagen> python3 tools/lot1/generate_id3_oracle.py
Écrit uniquement test/fixtures/id3-oracle.json ; ne modifie jamais le corpus.
"""

import hashlib
import json
from pathlib import Path

from mutagen.id3 import ID3

root = Path(__file__).resolve().parents[2]
baseline = json.loads((root / "docs/lot0/audit-resultats.json").read_text())
result = []
for item in baseline["episodes"]:
    path = root / "MP3_Files" / item["current_name"]
    with path.open("rb") as stream:
        before = hashlib.file_digest(stream, "sha256").hexdigest()
    assert before == baseline["source_sha256"][str(path.relative_to(root))]
    tags = ID3(path, load_v1=False)
    physical = sorted(
        [{"language": c.lang, "description": c.desc, "texts": list(c.text)}
         for c in tags.getall("COMM")],
        key=lambda c: (c["language"], c["description"]),
    )
    result.append({"file": item["current_name"], "sha256": before,
                   "id3_version": list(tags.version), "comments": physical})
    with path.open("rb") as stream:
        assert hashlib.file_digest(stream, "sha256").hexdigest() == before
output = root / "test/fixtures/id3-oracle.json"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps({"oracle": "Mutagen 1.47.0, ID3(load_v1=False)",
                             "episodes": result}, ensure_ascii=False, indent=2) + "\n")
print(f"Oracle généré : {len(result)} MP3, sans changement des sources.")
