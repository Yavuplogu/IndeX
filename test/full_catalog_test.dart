import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:index_core/index_core.dart';
import 'package:index_core/index_io.dart';
import 'package:index_core/index_storage.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'support/id3_bytes.dart' as id3;

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
  test('Corpus actualisé : 716 identités, aucun nom TXT divergent', () {
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
  });
  test('Les onze noms corrigés figurent dans le seed intégré et le journal courant', () {
    final expected = {
      '2000_11_11': '2000-11-11 Le colonel B.',
      '2001_04_21': "2001-04-21 L'affaire L.",
      '2003_10_25': '2003-10-25 Les Hmongs du Laos et la C.I.A.',
      '2000_11_25': '2000-11-25 La mort de Jean Chiappe (27 novembre 1940)',
      '2005_06_25': '2005-06-25 Einstein harcelé par le F.B.I.',
      '2003_02_08': "2003-02-08 L'accord F.L.N.-O.A.S.",
      '2002_03_23': '2002-03-23 Le G.A.L.',
      '2007_10_13': '2007-10-13 Le L.S.D. et la C.I.A.',
      '2001_04_14': "2001-04-14 Le putsh d'Alger et La C.I.A.",
      '2003_02_15': '2003-02-15 Le Tibet et la C.I.A.',
      '2002_06_22': "2002-06-22 Les assassinats de l'O.A.S.",
    };
    final seed = CatalogStore.inMemory();
    addTearDown(seed.close);
    seed.importReference('assets/catalogue.sqlite');
    for (final entry in expected.entries) {
      final id = 'mrx:mr_x_${entry.key}.mp3';
      final row = seed.database.select(
        'SELECT source_path,system_name FROM episodes WHERE id=?',
        [id],
      ).single;
      expect(row['source_path'], '${entry.value}.txt');
      expect(row['system_name'], '${entry.value}.mp3');
      final episode = full.episodes.singleWhere((e) => e.id == id);
      expect(episode.sourcePath, row['source_path']);
      final d = const MatchingEngine().match(seed.matchEpisodes(), [
        AudioCandidate(
          reference: 'local',
          currentName: row['system_name'] as String,
        ),
      ]).single;
      expect(d.episodeId, id);
      expect(d.status, MatchStatus.confirmed);
    }
  });
  test('Le scan ignore COMM invalides/contradictoires et ID3 tronqués sans modifier les fichiers', () async {
    final dir = await Directory.systemTemp.createTemp('index-ignore-tags-');
    addTearDown(() => dir.delete(recursive: true));
    final episode = full.episodes.first;
    final path = File('${dir.path}/${episode.originalName}');
    for (final bytes in [
      id3.tag([
        id3.frame('COMM', id3.comment('mr_x_1999_01_01.mp3', language: '???')),
      ]),
      id3.tag([
        id3.frame('COMM', id3.comment('mr_x_1999_01_01.mp3')),
        id3.frame('COMM', id3.comment('mr_x_1999_01_01.mp3')),
      ]),
      <int>[73, 68, 51],
    ]) {
      await path.writeAsBytes(bytes);
      final before = await path.readAsBytes();
      final scan = await scanAudioDirectory(dir);
      expect(scan.complete, isTrue);
      expect(scan.issues, isEmpty);
      final store = CatalogStore.inMemory();
      try {
        store.importPlan(full);
        store.applyAudioScan(scan);
        final link = store.database
            .select('SELECT * FROM local_audio_links')
            .single;
        expect(link['episode_id'], episode.id);
        expect(link['method'], 'original_filename');
        expect(link['local_verification_status'], 'NON_VERIFIEE');
      } finally {
        store.close();
      }
      expect(await path.readAsBytes(), before);
    }
    await path.delete();
    final unknown = File('${dir.path}/nom-inconnu.mp3');
    await unknown.writeAsBytes(
      id3.tag([
        id3.frame('COMM', id3.comment(episode.originalName)),
        id3.frame('COMM', id3.comment(episode.originalName)),
      ]),
    );
    final scan = await scanAudioDirectory(dir);
    final store = CatalogStore.inMemory();
    try {
      store.importPlan(full);
      final issues = store.applyAudioScan(scan);
      expect(store.database.select('SELECT * FROM local_audio_links'), isEmpty);
      expect(issues.single.code, 'audio_unknown_filename');
    } finally {
      store.close();
    }
  });
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
        (d) =>
            d.status == MatchStatus.confirmed && d.method == 'catalog_filename',
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
