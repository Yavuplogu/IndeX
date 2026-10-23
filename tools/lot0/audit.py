"""Sonde Lot 0 en lecture seule du corpus, sans module applicatif.

Usage : python3 tools/lot0/audit.py > /tmp/index-audit.json
Installer auparavant requirements.txt dans un venv externe au dépôt.
"""

import csv
import hashlib
import io
import json
import re
import sqlite3
import sys
import unittest
from datetime import datetime
from pathlib import Path

from mutagen.mp3 import MP3


ROOT = Path(__file__).resolve().parents[2]
HEADERS = [
    "TITRE", "DATE DE DIFFUSION", "DATE ISO", "FICHIER MP3 D'ORIGINE",
    "PAGE DE L'EMISSION", "URL MP3", "DESCRIPTION DE L'EPISODE",
    "LIVRES ET SOURCES", "MUSIQUES DIFFUSÉES",
]
PATTERN = re.compile(r"^(" + "|".join(re.escape(h) for h in HEADERS) + r")\s*:\s*", re.M)


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def examine():
    paths = sorted(p for directory in ("TXT_Files", "MP3_Files", "Journal_Files")
                   for p in (ROOT / directory).iterdir() if p.is_file())
    before = {str(p.relative_to(ROOT)): digest(p) for p in paths}
    raw = (ROOT / "Journal_Files/journal.csv").read_bytes()
    reader = csv.DictReader(io.StringIO(raw.decode("utf-8-sig")), delimiter=";")
    rows = list(reader)
    required = {"FICHIER MP3 D'ORIGINE", "TITRE SYSTEME", "TITRE WEB",
                "DATE DE DIFFUSION", "URL MP3", "FICHIER TXT",
                "CORRESPONDANCE ID3", "Statut", "Erreur", "DateExecution"}
    assert required <= set(reader.fieldnames), "En-têtes requis absents"
    assert len(reader.fieldnames) == len(set(reader.fieldnames)), "En-têtes dupliqués"
    assert rows and all(None not in r and None not in r.values() for r in rows)
    assert len({r["FICHIER MP3 D'ORIGINE"] for r in rows}) == len(rows), "Identifiants dupliqués"
    report = {"host_sqlite": sqlite3.sqlite_version,
              "csv_columns": reader.fieldnames, "csv_bom": raw.startswith(b"\xef\xbb\xbf"),
              "episodes": [], "source_sha256": before}
    for row in rows:
        # Les noms de cet échantillon doivent être des noms simples, jamais des chemins.
        for key in ("FICHIER TXT", "TITRE SYSTEME"):
            assert "/" not in row[key] and "\\" not in row[key] and row[key] not in (".", "..")
        txt = ROOT / "TXT_Files" / row["FICHIER TXT"]
        audio = ROOT / "MP3_Files" / row["TITRE SYSTEME"]
        text = txt.read_bytes().decode("utf-8-sig")
        matches = list(PATTERN.finditer(text))
        assert [m[1] for m in matches] == HEADERS, f"Rubriques inattendues : {txt.name}"
        fields = {m[1]: text[m.end():matches[i + 1].start() if i + 1 < len(matches) else len(text)]
                  for i, m in enumerate(matches)}
        assert fields["FICHIER MP3 D'ORIGINE"].strip() == row["FICHIER MP3 D'ORIGINE"]
        assert fields["TITRE"].strip() == row["TITRE WEB"]
        assert fields["DATE ISO"].strip() == row["DATE DE DIFFUSION"]
        assert datetime.strptime(fields["DATE DE DIFFUSION"].strip(), "%d/%m/%Y").date().isoformat() == row["DATE DE DIFFUSION"]
        assert fields["URL MP3"].strip() == row["URL MP3"]
        assert fields["DESCRIPTION DE L'EPISODE"].strip()
        mp3 = MP3(audio)
        comments = [{"language": c.lang, "description": c.desc, "texts": list(c.text)}
                    for c in mp3.tags.getall("COMM")]
        candidates = {s.strip().strip('\"') for c in comments for s in c["texts"]
                      if re.fullmatch(r"[^/\\\r\n]+\.mp3", s.strip().strip('\"'), re.I)}
        assert candidates == {row["FICHIER MP3 D'ORIGINE"]}, f"COMM discordants : {audio.name}"
        assert mp3.info.length > 0
        report["episodes"].append({
            "original_name": row["FICHIER MP3 D'ORIGINE"],
            "current_name": audio.name, "txt_name": txt.name,
            "txt_bom": txt.read_bytes().startswith(b"\xef\xbb\xbf"),
            "id3_version": list(mp3.tags.version), "comments": comments,
            "journal_status": row["CORRESPONDANCE ID3"],
            "audit_verification_status": "CONFIRMEE_PAR_MUTAGEN",
            "duration_seconds": round(mp3.info.length, 3),
            "description_characters": len(fields["DESCRIPTION DE L'EPISODE"].strip()),
            "literary_references": len(re.findall(r"^Référence\s*:", fields["LIVRES ET SOURCES"], re.M)),
            "music_tracks": len(re.findall(r"^Artiste\s*:", fields["MUSIQUES DIFFUSÉES"], re.M)),
            "nel_characters": text.count("\u0085"),
        })
    assert {p.name for p in (ROOT / "MP3_Files").glob("*.mp3")} == {r["TITRE SYSTEME"] for r in rows}
    assert {p.name for p in (ROOT / "TXT_Files").glob("*.txt")} == {r["FICHIER TXT"] for r in rows}
    after = {str(p.relative_to(ROOT)): digest(p) for p in paths}
    assert before == after, "Un fichier source a changé pendant l'audit"
    report["sources_unchanged"] = True
    return report


class Feasibility(unittest.TestCase):
    """Sondes SQLite sur l'hôte, pas une recette Windows/Android."""

    def test_fts5_french_and_real_fixture(self):
        with sqlite3.connect(":memory:") as db:
            db.execute("CREATE VIRTUAL TABLE probe USING fts5(title, body, tokenize='unicode61 remove_diacritics 2')")
            fixture = next((ROOT / "TXT_Files").glob("2013-04-27*.txt")).read_bytes().decode("utf-8-sig")
            db.executemany("INSERT INTO probe VALUES (?,?)", [
                ("Le Masque de fer israélien", fixture),
                ("Échiquier", "Un récit"), ("Autre titre", "Un échiquier et des sources")])
            self.assertEqual(db.execute("SELECT rowid FROM probe WHERE probe MATCH ?", ('"israelien"',)).fetchall(), [(1,)])
            self.assertEqual(db.execute("SELECT rowid FROM probe WHERE probe MATCH ?", ('"Paris" AND "Diamonds"',)).fetchall(), [(1,)])
            ranked = db.execute("SELECT rowid FROM probe WHERE probe MATCH ? ORDER BY bm25(probe,10,1)", ('"echiquier"',)).fetchall()
            self.assertEqual(ranked[0], (2,))
            # Paramétrage SQL seul ne neutralise pas la grammaire MATCH.
            with self.assertRaises(sqlite3.OperationalError):
                db.execute("SELECT * FROM probe WHERE probe MATCH ?", ('"',)).fetchall()

    def test_transaction_rollback(self):
        db = sqlite3.connect(":memory:")
        self.addCleanup(db.close)
        db.execute("CREATE TABLE probe (id INTEGER PRIMARY KEY, favorite INTEGER CHECK(favorite IN(0,1)))")
        db.execute("INSERT INTO probe VALUES(1,1)")
        db.commit()
        with self.assertRaises(sqlite3.IntegrityError):
            with db:
                db.execute("UPDATE probe SET favorite=0 WHERE id=1")
                db.execute("INSERT INTO probe VALUES(1,1)")
        self.assertEqual(db.execute("SELECT favorite FROM probe").fetchone(), (1,))

    def test_killed_writer_preserves_last_commit(self):
        import subprocess
        import tempfile
        with tempfile.TemporaryDirectory(prefix="index-lot0-") as tmp:
            path = str(Path(tmp) / "probe.sqlite")
            with sqlite3.connect(path) as db:
                self.assertEqual(db.execute("PRAGMA journal_mode=WAL").fetchone()[0], "wal")
                db.execute("PRAGMA synchronous=FULL")
                db.execute("CREATE TABLE state(position_ms INTEGER)")
                db.execute("INSERT INTO state VALUES(5000)")
            code = """import sqlite3,sys,time
db=sqlite3.connect(sys.argv[1])
db.execute('PRAGMA synchronous=FULL')
db.execute('UPDATE state SET position_ms=10000')
db.commit()
db.execute('BEGIN IMMEDIATE')
db.execute('UPDATE state SET position_ms=15000')
print('pending', flush=True)
sys.stdin.read()
"""
            child = subprocess.Popen([sys.executable, "-c", code, path],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
            try:
                import selectors
                with selectors.DefaultSelector() as selector:
                    selector.register(child.stdout, selectors.EVENT_READ)
                    self.assertTrue(selector.select(timeout=10), "Le processus n'a pas atteint la transaction")
                self.assertEqual(child.stdout.readline().strip(), "pending")
            finally:
                child.kill()
                child.wait(timeout=10)
                child.stdin.close()
                child.stdout.close()
            with sqlite3.connect(path) as db:
                self.assertEqual(db.execute("SELECT position_ms FROM state").fetchone(), (10000,))
                self.assertEqual(db.execute("PRAGMA integrity_check").fetchone(), ("ok",))


if __name__ == "__main__":
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Feasibility))
    if not result.wasSuccessful():
        raise SystemExit(1)
    report = examine()
    report["feasibility_checks_passed"] = result.testsRun
    report["not_validated"] = ["Flutter/Dart", "Windows", "Android", "lecture audio réelle", "fusion JSON", "renommage"]
    print(json.dumps(report, ensure_ascii=False, indent=2))
