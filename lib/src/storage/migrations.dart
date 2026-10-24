import 'package:sqlite3/sqlite3.dart';

const applicationId = 0x49445831;
const schemaVersion = 3;

// Version 1 réellement utilisable comme fixture de migration vers les données locales v2.
const schemaV1 = '''
CREATE TABLE episodes(
 id TEXT PRIMARY KEY, original_name TEXT NOT NULL UNIQUE, original_raw TEXT NOT NULL,
 title TEXT NOT NULL, broadcast_date TEXT, description TEXT NOT NULL,
 sources_text TEXT NOT NULL, music_text TEXT NOT NULL, page_url TEXT, mp3_url TEXT,
 source_path TEXT NOT NULL, source_bytes BLOB NOT NULL, raw_text TEXT NOT NULL,
 system_name TEXT, journal_status TEXT, journal_json TEXT, fingerprint TEXT NOT NULL,
 needs_review INTEGER NOT NULL CHECK(needs_review IN(0,1)),
 origin TEXT NOT NULL CHECK(origin IN('reference','user')), updated_at TEXT NOT NULL
);
CREATE TABLE episode_aliases(episode_id TEXT NOT NULL REFERENCES episodes(id),kind TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(episode_id,kind,value));
CREATE TABLE literary_sources(episode_id TEXT NOT NULL REFERENCES episodes(id),sequence INTEGER NOT NULL,raw_text TEXT NOT NULL,title TEXT,author TEXT,publisher TEXT,PRIMARY KEY(episode_id,sequence));
CREATE TABLE music_tracks(episode_id TEXT NOT NULL REFERENCES episodes(id),sequence INTEGER NOT NULL,raw_text TEXT NOT NULL,artist TEXT,title TEXT,album TEXT,label TEXT,PRIMARY KEY(episode_id,sequence));
CREATE TABLE import_runs(id INTEGER PRIMARY KEY,started_at TEXT NOT NULL,completed_at TEXT,status TEXT NOT NULL,source_digest TEXT NOT NULL,summary_json TEXT,error TEXT);
CREATE TABLE import_issues(id INTEGER PRIMARY KEY,run_id INTEGER NOT NULL REFERENCES import_runs(id),code TEXT NOT NULL,severity TEXT NOT NULL,source TEXT,original_name TEXT,message TEXT NOT NULL);
CREATE TABLE source_records(id INTEGER PRIMARY KEY,run_id INTEGER NOT NULL REFERENCES import_runs(id),kind TEXT NOT NULL,source_key TEXT NOT NULL,disposition TEXT NOT NULL,original_name TEXT,raw_bytes BLOB,fields_json TEXT);
CREATE TABLE catalog_versions(version TEXT PRIMARY KEY,source_digest TEXT NOT NULL,generated_at TEXT NOT NULL,schema_version INTEGER NOT NULL);
''';
const schemaV2 = '''
ALTER TABLE import_runs ADD COLUMN snapshot_run_id INTEGER REFERENCES import_runs(id);
CREATE TABLE local_audio_links(
 episode_id TEXT PRIMARY KEY REFERENCES episodes(id),audio_ref TEXT NOT NULL UNIQUE,
 current_name TEXT NOT NULL,method TEXT NOT NULL,matching_status TEXT NOT NULL,
 local_verification_status TEXT NOT NULL,evidence_json TEXT NOT NULL,
 manual INTEGER NOT NULL DEFAULT 0 CHECK(manual IN(0,1)),
 available INTEGER NOT NULL DEFAULT 1 CHECK(available IN(0,1)),updated_at TEXT NOT NULL
);
CREATE TABLE user_episode_state(
 episode_id TEXT PRIMARY KEY REFERENCES episodes(id),position_ms INTEGER NOT NULL DEFAULT 0 CHECK(position_ms>=0),
 duration_ms INTEGER CHECK(duration_ms>=0),listening_status TEXT NOT NULL DEFAULT 'NON_ECOUTE' CHECK(listening_status IN('NON_ECOUTE','EN_COURS','ECOUTE')),
 is_favorite INTEGER NOT NULL DEFAULT 0 CHECK(is_favorite IN(0,1)),updated_at TEXT
);
CREATE TABLE audio_scan_runs(id INTEGER PRIMARY KEY,scope TEXT NOT NULL,completed INTEGER NOT NULL,scanned_at TEXT NOT NULL,summary_json TEXT NOT NULL);
CREATE TABLE audio_scan_items(run_id INTEGER NOT NULL REFERENCES audio_scan_runs(id),audio_ref TEXT NOT NULL,decision_json TEXT NOT NULL);
''';

// Index externe : les rowid sont toujours ceux des épisodes, jamais des identités métier.
const schemaV3 = '''
CREATE VIRTUAL TABLE episodes_fts USING fts5(
 title, description, sources_text, music_text,
 content='episodes', content_rowid='rowid',
 tokenize='unicode61 remove_diacritics 2'
);
CREATE TRIGGER episodes_fts_insert AFTER INSERT ON episodes BEGIN
 INSERT INTO episodes_fts(rowid,title,description,sources_text,music_text)
 VALUES(new.rowid,new.title,new.description,new.sources_text,new.music_text);
END;
CREATE TRIGGER episodes_fts_delete AFTER DELETE ON episodes BEGIN
 INSERT INTO episodes_fts(episodes_fts,rowid,title,description,sources_text,music_text)
 VALUES('delete',old.rowid,old.title,old.description,old.sources_text,old.music_text);
END;
CREATE TRIGGER episodes_fts_update AFTER UPDATE OF title,description,sources_text,music_text ON episodes BEGIN
 INSERT INTO episodes_fts(episodes_fts,rowid,title,description,sources_text,music_text)
 VALUES('delete',old.rowid,old.title,old.description,old.sources_text,old.music_text);
 INSERT INTO episodes_fts(rowid,title,description,sources_text,music_text)
 VALUES(new.rowid,new.title,new.description,new.sources_text,new.music_text);
END;
INSERT INTO episodes_fts(episodes_fts) VALUES('rebuild');
''';

void migrate(Database db) {
  db.execute('PRAGMA foreign_keys=ON');
  final version = db.select('PRAGMA user_version').single.values.single as int;
  final app = db.select('PRAGMA application_id').single.values.single as int;
  if (version > schemaVersion)
    throw StateError('Schéma futur non pris en charge : $version.');
  if (version == 0) {
    if (app != 0 ||
        db
            .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
            )
            .isNotEmpty) {
      throw StateError('Base existante non reconnue ; aucune modification.');
    }
  } else if (app != applicationId) {
    throw StateError('Cette base n’appartient pas à IndeX.');
  }
  db.execute('BEGIN IMMEDIATE');
  try {
    if (version < 1) {
      db.execute(schemaV1);
      db.execute('PRAGMA application_id=$applicationId');
      db.execute('PRAGMA user_version=1');
    }
    if (version < 2) {
      db.execute(schemaV2);
      db.execute('PRAGMA user_version=2');
    }
    if (version < 3) {
      db.execute(schemaV3);
      db.execute('PRAGMA user_version=3');
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
  db.execute('PRAGMA journal_mode=WAL');
  db.execute('PRAGMA synchronous=FULL');
}
