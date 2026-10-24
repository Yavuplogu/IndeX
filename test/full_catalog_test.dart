import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:index_core/index_core.dart';
import 'package:index_core/index_io.dart';
import 'package:index_core/index_storage.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  test('Le builder refuse de remplacer un fichier source ou de sortir dans le dossier TXT', () async {
    final dir = await Directory.systemTemp.createTemp(
      'index-source-protection-',
    );
    addTearDown(() => dir.delete(recursive: true));
    final source = File('${dir.path}/source.sqlite');
    await source.writeAsBytes([1, 2, 3]);
    await expectLater(
      () => buildCatalog(
        txtDirectory: Directory('TXT_Files'),
        journal: source,
        output: source,
        version: 'x',
        generatedAt: DateTime.utc(2026),
        replace: true,
      ),
      throwsArgumentError,
    );
    expect(await source.readAsBytes(), [1, 2, 3]);
    await expectLater(
      () => buildCatalog(
        txtDirectory: Directory('TXT_Files'),
        output: File('TXT_Files/interdit.sqlite'),
        version: 'x',
        generatedAt: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
    expect(File('TXT_Files/interdit.sqlite').existsSync(), isFalse);
  });
  late CatalogPlan full;
  setUpAll(() async {
    full = CatalogPlanner().plan(
      await loadTxtDirectory(Directory('TXT_Files')),
      journalBytes: await File('Journal_Files/journal.csv').readAsBytes(),
    );
  });
  test(
    'Corpus corrigé : 716 identités, aucune erreur ni divergence CSV/TXT',
    () {
      expect(full.txtCount, 716);
      expect(full.journalRows, 716);
      expect(full.canApply, isTrue);
      expect(full.episodes, hasLength(716));
      expect(full.summary()['quarantined_txt'], 0);
      expect(full.summary()['errors'], 0);
      expect(full.episodes.where((e) => e.needsReview), isEmpty);
      expect(
        full.episodes
            .singleWhere((e) => e.originalName == 'mr_x_2013_04_27.mp3')
            .sourcePath,
        "2013-04-27 'Le Masque de fer' israélien.txt",
      );
      expect(full.issues.map((i) => i.code).toSet(), {
        'journal_source_error',
        'txt_nel_preserved',
      });
      expect(
        full.issues.where((i) => i.code == 'journal_source_error'),
        hasLength(23),
      );
      expect(
        full.issues.where((i) => i.code == 'txt_nel_preserved'),
        hasLength(6),
      );
      for (final date in [
        DateTime.utc(1998, 4, 25),
        DateTime.utc(2014, 2, 22),
        DateTime.utc(2014, 4, 12),
        DateTime.utc(2014, 5, 31),
        DateTime.utc(2014, 6, 14),
      ]) {
        final iso = date.toIso8601String().substring(0, 10);
        final episode = full.episodes.singleWhere(
          (e) => e.originalName == 'mr_x_${iso.replaceAll('-', '_')}.mp3',
        );
        expect(episode.document.broadcastDate, date, reason: iso);
      }
      expect(
        full.episodes
            .singleWhere((e) => e.originalName == 'mr_x_2014_06_14.mp3')
            .sourcePath,
        '2014-06-14 Boko Haram au Nigeria.txt',
      );
    },
  );
  test('Import du corpus puis scan réel des six MP3 ; réimport sans perte de liens', () async {
    final store = CatalogStore.inMemory();
    addTearDown(store.close);
    expect(store.importPlan(full, catalogVersion: 'full-test').inserted, 716);
    final scan = await scanAudioDirectory(Directory('MP3_Files'));
    expect(scan.complete, isTrue);
    expect(scan.audios, hasLength(6));
    expect(scan.issues, isEmpty);
    final decisions = const MatchingEngine().match(
      store.matchEpisodes(),
      scan.audios,
    );
    expect(
      decisions.every(
        (d) => d.status == MatchStatus.confirmed && d.method == 'id3_comment',
      ),
      isTrue,
    );
    store.applyAudioScan(scan);
    expect(
      store.database.select('SELECT * FROM local_audio_links'),
      hasLength(6),
    );
    expect(store.importPlan(full, catalogVersion: 'full-test').unchanged, 716);
    expect(
      store.database
          .select('SELECT count(*) n FROM source_records')
          .single['n'],
      1433,
      reason:
          'Un réimport identique ne doit pas dupliquer les octets du corpus.',
    );
    expect(
      store.database.select('SELECT * FROM local_audio_links'),
      hasLength(6),
    );
  });
  test('SQLite prérempli déterministe, sans audio ni liens locaux', () async {
    final dir = await Directory.systemTemp.createTemp('index-seed-');
    addTearDown(() => dir.delete(recursive: true));
    final a = File('${dir.path}/a.sqlite'), b = File('${dir.path}/b.sqlite');
    for (final output in [a, b]) {
      final report = await buildCatalog(
        txtDirectory: Directory('TXT_Files'),
        journal: File('Journal_Files/journal.csv'),
        output: output,
        version: 'full-test',
        generatedAt: DateTime.utc(2026, 10, 24),
      );
      expect((report['summary'] as Map<String, Object?>)['episodes'], 716);
      expect(
        (report['capabilities'] as Map<String, Object?>)['search_index'],
        isTrue,
      );
      final loaded = CatalogStore.inMemory();
      try {
        loaded.importReference(output.path);
        final engine = SqliteSearchEngine(loaded.database);
        engine.checkIndex();
        expect(engine.search('Pasolini'), isNotEmpty);
      } finally {
        loaded.close();
      }
      expect(
        report['sqlite_sha256'],
        (await sha256.bind(output.openRead()).first).toString(),
      );
    }
    expect(await a.readAsBytes(), await b.readAsBytes());
    final db = sqlite3.open(a.path, mode: OpenMode.readOnly);
    addTearDown(db.close);
    expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
    expect(db.select('PRAGMA foreign_key_check'), isEmpty);
    expect(db.select('SELECT count(*) n FROM episodes').single['n'], 716);
    expect(db.select('SELECT * FROM local_audio_links'), isEmpty);
    expect(db.select('SELECT * FROM user_episode_state'), isEmpty);
    expect(
      db.select(
        "SELECT * FROM source_records WHERE kind NOT IN ('txt','journal','journal_row')",
      ),
      isEmpty,
    );
    expect(
      db.select(
        "SELECT source_key FROM source_records WHERE source_key LIKE '/%' OR source_key LIKE 'file:%'",
      ),
      isEmpty,
    );
    expect(
      jsonDecode(await File('${a.path}.manifest.json').readAsString()),
      isA<Map<String, dynamic>>(),
    );
    expect(
      () => buildCatalog(
        txtDirectory: Directory('TXT_Files'),
        journal: File('Journal_Files/journal.csv'),
        output: a,
        version: 'other',
        generatedAt: DateTime.utc(2026),
      ),
      throwsStateError,
    );
  });
  test(
    'Scan audio d’un dossier inexistant : état incomplet explicite',
    () async {
      final dir = await Directory.systemTemp.createTemp('index-unavailable-');
      addTearDown(() => dir.delete(recursive: true));
      final scan = await scanAudioDirectory(Directory('${dir.path}/missing'));
      expect(scan.complete, isFalse);
      expect(scan.issues.single.code, 'audio_scope_unavailable');
    },
  );
}
