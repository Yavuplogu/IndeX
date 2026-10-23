"""Revérifie les archives exactes inspectées au Lot 0, sans les installer."""

import hashlib
import io
import json
import tarfile
import urllib.request
from pathlib import Path

report = Path(__file__).resolve().parents[2] / "docs/lot0/dependances-observees.json"
for item in json.loads(report.read_text(encoding="utf-8")):
    with urllib.request.urlopen(item["archive_url"], timeout=30) as response:
        archive = response.read(32 * 1024 * 1024 + 1)
    assert len(archive) <= 32 * 1024 * 1024
    assert hashlib.sha256(archive).hexdigest() == item["archive_sha256"], item["package"]
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as tar:
        # Lecture en mémoire uniquement, aucune extraction de chemins non fiables.
        for name in item["licenses"]:
            with tar.extractfile(name) as source:
                assert source.read().decode("utf-8").startswith(item["licenses"][name])
        if item["package"] == "audio_metadata_reader":
            source = tar.extractfile("lib/src/parsers/tags/id3v2.dart").read().decode()
            assert '"COMM" =>' not in source
            assert "metadata.customMetadata[frameId] =" in source
        if item["package"] == "sqlite3":
            source = tar.extractfile("lib/src/hook/compile/description.dart").read().decode()
            assert "SQLITE_ENABLE_FTS5" in source
    print("OK", item["package"], item["version"], "SHA-256 et extraits de licence vérifiés")
