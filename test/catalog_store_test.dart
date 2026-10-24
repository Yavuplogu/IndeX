import 'dart:convert';
import 'dart:io';

import 'package:index_core/index_core.dart';
import 'package:index_core/index_io.dart';
import 'package:index_core/index_storage.dart';
import 'package:index_core/src/storage/migrations.dart' as schema;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'support/matching_fixtures.dart';
import 'support/catalog_fixtures.dart';

AudioScan scan(List<AudioCandidate> audios, {bool complete = true}) =>
    AudioScan(
      scope: 'file:///root/',
      complete: complete,
      recursive: true,
      audios: audios,
      issues: [],
    );

void main() {
  late CatalogStore store;
  setUp(() => store = CatalogStore.inMemory());
  tearDown(() => store.close());
  test('Catalogue SQLite malformé : types et provenance refusés avant mutation de la cible', () async {
    final dir = await Directory.systemTemp.createTemp('index-malformed-seed-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/seed.sqlite';
    final seed = CatalogStore.open(path);
    seed.importPlan(plan(), catalogVersion: 'v1');
    seed.close();
    store.importPlan(plan(description: 'Données locales à conserver'));
    final source = sqlite3.open(path);
    final original = source
        .select(
          "SELECT raw_bytes,source_key FROM source_records WHERE kind='txt'",
        )
        .single;
    source.execute(
      "UPDATE source_records SET fields_json='[]' WHERE kind='txt'",
    );
    source.close();
    expect(() => store.importReference(path), throwsFormatException);
    final wrongType = sqlite3.open(path);
    wrongType.execute(
      "UPDATE source_records SET fields_json=NULL,raw_bytes='pas un BLOB' WHERE kind='txt'",
    );
    wrongType.close();
    expect(() => store.importReference(path), throwsFormatException);
    final wrongPath = sqlite3.open(path);
    wrongPath.execute(
      "UPDATE source_records SET raw_bytes=?,source_key='../hors-dossier.txt' WHERE kind='txt'",
      [original['raw_bytes']],
    );
    wrongPath.close();
    expect(() => store.importReference(path), throwsFormatException);
    expect(
      store.database
          .select('SELECT description FROM episodes')
          .single['description'],
      'Données locales à conserver',
    );
    expect(store.database.select('SELECT * FROM import_runs'), hasLength(1));
  });
  test(
    'Un TXT déplacé actualise sa provenance et conserve les anciens alias',
    () {
      store.importPlan(CatalogPlanner().plan([input(path: 'avant.txt')]));
      expect(
        store
            .importPlan(
              CatalogPlanner().plan([input(path: 'sous-dossier/après.txt')]),
            )
            .updated,
        1,
      );
      expect(
        store.database
            .select('SELECT source_path FROM episodes')
            .single['source_path'],
        'sous-dossier/après.txt',
      );
      expect(
        store.database
            .select(
              "SELECT value FROM episode_aliases WHERE kind='txt_filename' ORDER BY value",
            )
            .map((r) => r['value']),
        ['après.txt', 'avant.txt'],
      );
    },
  );
  test('Import d’un seed SQLite sans CSV/TXT externes préserve le suivi et les liens', () async {
    final dir = await Directory.systemTemp.createTemp('index-reference-');
    addTearDown(() => dir.delete(recursive: true));
    store.importPlan(plan(), catalogVersion: 'v1');
    store.recordManualLink(firstId, 'file:///root/manuel.mp3', 'manuel.mp3');
    store.database.execute(
      'INSERT INTO user_episode_state(episode_id,position_ms,is_favorite) VALUES(?,4000,1)',
      [firstId],
    );
    final path = '${dir.path}/seed.sqlite';
    final seed = CatalogStore.open(path);
    final generated = DateTime.utc(2026, 10, 24);
    seed.importPlan(
      plan(description: 'Nouvelle référence SQLite'),
      catalogVersion: 'v2',
      now: generated,
    );
    seed.close();
    final before = await File(path).readAsBytes();
    expect(store.importReference(path).updated, 1);
    expect(
      store.database
          .select('SELECT description FROM episodes')
          .single['description'],
      'Nouvelle référence SQLite',
    );
    expect(
      store.database
          .select('SELECT position_ms,is_favorite FROM user_episode_state')
          .single
          .values,
      [4000, 1],
    );
    expect(
      store.database
          .select('SELECT audio_ref FROM local_audio_links')
          .single['audio_ref'],
      'file:///root/manuel.mp3',
    );
    expect(
      store.database
          .select(
            "SELECT generated_at FROM catalog_versions WHERE version='v2'",
          )
          .single['generated_at'],
      generated.toIso8601String(),
    );
    expect(await File(path).readAsBytes(), before);
    final bad = sqlite3.open(path);
    bad.execute("UPDATE catalog_versions SET source_digest='altéré'");
    bad.close();
    expect(() => store.importReference(path), throwsFormatException);
    expect(
      store.database
          .select('SELECT description FROM episodes')
          .single['description'],
      'Nouvelle référence SQLite',
    );
  });
  test('Un seed contenant des données personnelles est refusé', () async {
    final dir = await Directory.systemTemp.createTemp('index-private-seed-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/seed.sqlite';
    final seed = CatalogStore.open(path);
    seed.importPlan(plan(), catalogVersion: 'v1');
    seed.database.execute(
      'INSERT INTO user_episode_state(episode_id) VALUES(?)',
      [firstId],
    );
    seed.close();
    expect(() => store.importReference(path), throwsFormatException);
    expect(store.database.select('SELECT * FROM episodes'), isEmpty);
  });
  test(
    'Arrêt brutal pendant un import natif : reprise avec catalogue précédent intact',
    () async {
      final dir = await Directory.systemTemp.createTemp('index-kill-import-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/work.sqlite';
      final before = CatalogStore.open(path);
      before.importPlan(plan());
      before.close();
      final process = await Process.start(Platform.resolvedExecutable, [
        'run',
        'test/support/interrupted_import.dart',
        path,
      ]);
      final errors = process.stderr.transform(utf8.decoder).join();
      try {
        await process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .firstWhere((l) => l.contains('transaction-open'))
            .timeout(const Duration(seconds: 25));
      } finally {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
        await errors;
      }
      final after = CatalogStore.open(path);
      addTearDown(after.close);
      expect(
        after.database
            .select('SELECT description FROM episodes')
            .single['description'],
        'Description complète.',
      );
      expect(
        after.database.select('PRAGMA integrity_check').single.values.single,
        'ok',
      );
      final search = SqliteSearchEngine(after.database);
      search.checkIndex();
      expect(search.search('complète'), hasLength(1));
      expect(after.importPlan(plan(description: 'Reprise réussie')).updated, 1);
      search.checkIndex();
      expect(search.search('complète'), isEmpty);
      expect(search.search('réussie'), hasLength(1));
    },
    skip: Platform.isWindows
        ? 'SIGKILL est une sonde POSIX ; recette Windows distincte requise.'
        : false,
  );
  test('Import initial, réimport identique et actualisation sans doublon', () {
    final t = DateTime.utc(2026, 10, 24);
    expect(store.importPlan(plan(), now: t).inserted, 1);
    final again = store.importPlan(plan(), now: t.add(const Duration(days: 1)));
    expect(again.unchanged, 1);
    expect(again.updated, 0);
    expect(
      store.database
          .select('SELECT updated_at FROM episodes')
          .single['updated_at'],
      t.toIso8601String(),
    );
    expect(
      store.importPlan(plan(description: 'Contenu révisé.'), now: t).updated,
      1,
    );
    expect(
      store.database
          .select('SELECT description FROM episodes')
          .single['description'],
      'Contenu révisé.',
    );
    expect(store.database.select('SELECT * FROM episodes'), hasLength(1));
    expect(
      store.database.select('SELECT * FROM literary_sources'),
      hasLength(1),
    );
    expect(store.database.select('SELECT * FROM music_tracks'), hasLength(1));
    expect(store.database.select('SELECT * FROM import_runs'), hasLength(3));
  });
  test(
    'Source brute et statuts du journal conservés séparément des liens locaux',
    () {
      store.importPlan(plan());
      final row = store.database.select('SELECT * FROM episodes').single;
      expect(row['source_bytes'], input().bytes);
      expect(row['journal_status'], 'CONFIRMEE');
      expect(store.database.select('SELECT * FROM local_audio_links'), isEmpty);
      final raw = store.database
          .select("SELECT raw_bytes FROM source_records WHERE kind='journal'")
          .single['raw_bytes'];
      expect(raw, csv([journalRow()]));
    },
  );
  test(
    'Mise à jour de catalogue préserve choix manuel, position et favori',
    () {
      store.importPlan(plan(), catalogVersion: 'v1');
      store.recordManualLink(firstId, 'file:///root/manuel.mp3', 'manuel.mp3');
      store.database.execute(
        'INSERT INTO user_episode_state(episode_id,position_ms,listening_status,is_favorite) VALUES(?,?,?,?)',
        [firstId, 12345, 'EN_COURS', 1],
      );
      store.importPlan(
        plan(description: 'Référence mise à jour.'),
        catalogVersion: 'v2',
      );
      expect(
        store.database
            .select('SELECT audio_ref,manual FROM local_audio_links')
            .single
            .values,
        ['file:///root/manuel.mp3', 1],
      );
      final state = store.database
          .select('SELECT * FROM user_episode_state')
          .single;
      expect(state['position_ms'], 12345);
      expect(state['is_favorite'], 1);
      expect(state['listening_status'], 'EN_COURS');
      expect(
        store.database.select('SELECT * FROM catalog_versions'),
        hasLength(2),
      );
    },
  );
  test('Version publiée immuable, import utilisateur protégé des révisions de référence', () {
    store.importPlan(plan(), catalogVersion: 'v1');
    expect(
      () => store.importPlan(
        plan(description: 'Altération'),
        catalogVersion: 'v1',
      ),
      throwsStateError,
    );
    expect(
      store.database
          .select('SELECT description FROM episodes')
          .single['description'],
      'Description complète.',
    );
    store.importPlan(plan(description: 'Choix utilisateur'));
    store.importPlan(
      plan(description: 'Nouvelle référence'),
      catalogVersion: 'v2',
    );
    expect(
      store.database
          .select('SELECT description FROM episodes')
          .single['description'],
      'Choix utilisateur',
    );
    expect(
      store.database.select(
        "SELECT * FROM import_issues WHERE code='user_override_preserved'",
      ),
      hasLength(1),
    );
  });
  test('CSV absent au réimport conserve nom de référence et statut historiques connus', () {
    store.importPlan(plan());
    store.importPlan(plan(description: 'Nouveau TXT', withJournal: false));
    final row = store.database.select('SELECT * FROM episodes').single;
    expect(row['system_name'], '2013-04-27 Un titre.mp3');
    expect(row['journal_status'], 'CONFIRMEE');
    expect(store.matchEpisodes().single.systemNames, [
      '2013-04-27 Un titre.mp3',
    ]);
  });
  test(
    'Une erreur en milieu de transaction annule toutes les modifications',
    () {
      store.importPlan(plan());
      expect(
        () => store.importPlan(
          plan(description: 'Ne doit pas rester'),
          afterEpisode: (_) => throw StateError('Panne simulée'),
        ),
        throwsStateError,
      );
      expect(
        store.database
            .select('SELECT description FROM episodes')
            .single['description'],
        'Description complète.',
      );
      expect(
        store.database
            .select('SELECT status FROM import_runs ORDER BY id')
            .map((r) => r['status']),
        ['completed', 'failed'],
      );
      expect(
        store.database.select("SELECT * FROM source_records WHERE run_id=2"),
        isEmpty,
      );
      expect(
        store.database.select('PRAGMA integrity_check').single.values.single,
        'ok',
      );
    },
  );
  test('Annulation en milieu de lot : rollback complet et journal durable', () {
    final p = CatalogPlanner().plan([input(), input(original: secondOriginal)]);
    var cancel = false;
    expect(
      () => store.importPlan(
        p,
        isCancelled: () => cancel,
        afterEpisode: (_) => cancel = true,
      ),
      throwsA(isA<ImportCancelled>()),
    );
    expect(store.database.select('SELECT * FROM episodes'), isEmpty);
    expect(
      store.database.select('SELECT status FROM import_runs').single['status'],
      'cancelled',
    );
  });
  test('CSV illisible ne touche pas au catalogue existant', () {
    store.importPlan(plan());
    final p = CatalogPlanner().plan(
      [input(description: 'Pas appliquée')],
      journalBytes: [255],
    );
    expect(() => store.importPlan(p), throwsFormatException);
    expect(
      store.database
          .select('SELECT description FROM episodes')
          .single['description'],
      'Description complète.',
    );
    expect(
      store.database.select(
        "SELECT * FROM import_issues WHERE code='csv_invalid_utf8'",
      ),
      hasLength(1),
    );
  });
  test('Paire locale confirmée écrit les preuves sans changer le statut du journal', () {
    final p = CatalogPlanner().plan([
      input(),
    ], journalBytes: csv([journalRow(status: 'NON_VERIFIEE')]));
    store.importPlan(p);
    store.applyAudioScan(
      scan([
        audio(
          'file:///root/renommé.mp3',
          comments: [firstOriginal, firstOriginal, secondOriginal],
        ),
      ]),
    );
    final link = store.database
        .select('SELECT * FROM local_audio_links')
        .single;
    expect(link['method'], 'id3_comment');
    expect(link['local_verification_status'], 'CONFIRMEE');
    expect(
      (jsonDecode(link['evidence_json'] as String)
          as Map<String, dynamic>)['evidence_rule'],
      'comm_pair_v1',
    );
    expect(
      store.database
          .select('SELECT journal_status FROM episodes')
          .single['journal_status'],
      'NON_VERIFIEE',
    );
  });
  test('Association provisoire ne devient pas un lien confirmé', () {
    store.importPlan(plan());
    store.applyAudioScan(
      scan([audio('file:///root/un-titre.mp3', name: 'Un-titre.mp3')]),
    );
    expect(store.database.select('SELECT * FROM local_audio_links'), isEmpty);
    final item = store.database
        .select('SELECT decision_json FROM audio_scan_items')
        .single;
    expect(
      (jsonDecode(item['decision_json'] as String)
          as Map<String, dynamic>)['status'],
      'provisional',
    );
  });
  test('Déplacement audio détecté, données personnelles conservées', () {
    store.importPlan(plan());
    store.applyAudioScan(
      scan([
        audio('file:///root/avant.mp3', comments: [firstOriginal]),
      ]),
    );
    store.database.execute(
      'INSERT INTO user_episode_state(episode_id,is_favorite) VALUES(?,1)',
      [firstId],
    );
    store.applyAudioScan(
      scan([
        audio('file:///root/apres.mp3', comments: [firstOriginal]),
      ]),
    );
    expect(
      store.database
          .select('SELECT audio_ref FROM local_audio_links')
          .single['audio_ref'],
      'file:///root/apres.mp3',
    );
    expect(
      store.database
          .select('SELECT is_favorite FROM user_episode_state')
          .single['is_favorite'],
      1,
    );
  });
  test(
    'Scan préserve un choix manuel et refuse la réutilisation du même fichier',
    () {
      store.importPlan(
        CatalogPlanner().plan([input(), input(original: secondOriginal)]),
      );
      store.recordManualLink(firstId, 'file:///root/manual.mp3', 'manual.mp3');
      final issues = store.applyAudioScan(
        scan([
          audio('file:///root/autre.mp3', comments: [firstOriginal]),
        ]),
      );
      expect(issues.map((i) => i.code), contains('manual_link_preserved'));
      expect(
        store.database
            .select('SELECT audio_ref FROM local_audio_links')
            .single['audio_ref'],
        'file:///root/manual.mp3',
      );
      expect(
        () => store.recordManualLink(
          'mrx:$secondOriginal',
          'file:///root/manual.mp3',
          'manual.mp3',
        ),
        throwsStateError,
      );
    },
  );
  test('Dossier inaccessible conserve les liens ; scan complet vide marque seulement l’indisponibilité', () {
    store.importPlan(plan());
    store.recordManualLink(firstId, 'file:///root/manual.mp3', 'manual.mp3');
    store.applyAudioScan(scan([], complete: false));
    expect(
      store.database
          .select('SELECT available FROM local_audio_links')
          .single['available'],
      1,
    );
    store.applyAudioScan(scan([]));
    final row = store.database.select('SELECT * FROM local_audio_links').single;
    expect(row['available'], 0);
    expect(row['manual'], 1);
  });
  test('Réimport incomplet ne supprime pas les épisodes existants', () {
    store.importPlan(
      CatalogPlanner().plan([input(), input(original: secondOriginal)]),
    );
    store.importPlan(plan());
    expect(store.database.select('SELECT * FROM episodes'), hasLength(2));
  });

  test('Migration réelle v1 vers le schéma courant conserve les fiches et active les contraintes', () async {
    final dir = await Directory.systemTemp.createTemp('index-migration-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/v1.sqlite';
    final old = sqlite3.open(path);
    old.execute(schema.schemaV1);
    old.execute('PRAGMA application_id=${schema.applicationId}');
    old.execute('PRAGMA user_version=1');
    old.execute(
      "INSERT INTO episodes(id,original_name,original_raw,title,description,sources_text,music_text,source_path,source_bytes,raw_text,fingerprint,needs_review,origin,updated_at) VALUES('mrx:a.mp3','a.mp3','a.mp3','Avant migration','','','','a.txt',x'41','','ancien',0,'reference','2026-10-24')",
    );
    old.close();
    final migrated = CatalogStore.open(path);
    addTearDown(migrated.close);
    expect(
      migrated.database.select('PRAGMA user_version').single.values.single,
      schema.schemaVersion,
    );
    expect(
      migrated.database.select('SELECT title FROM episodes').single['title'],
      'Avant migration',
    );
    expect(
      migrated.database.select('PRAGMA foreign_keys').single.values.single,
      1,
    );
    expect(
      () => migrated.database.execute(
        "INSERT INTO user_episode_state(episode_id) VALUES('inconnu')",
      ),
      throwsA(isA<SqliteException>()),
    );
  });
  test('Base étrangère ou future refusée, sans réécriture', () async {
    final dir = await Directory.systemTemp.createTemp('index-foreign-');
    addTearDown(() => dir.delete(recursive: true));
    for (final future in [false, true]) {
      final path = '${dir.path}/$future.sqlite';
      final db = sqlite3.open(path);
      db.execute('CREATE TABLE preserve(value TEXT)');
      if (future) db.execute('PRAGMA user_version=99');
      db.close();
      final before = await File(path).readAsBytes();
      expect(() => CatalogStore.open(path), throwsStateError);
      expect(await File(path).readAsBytes(), before);
    }
  });
  test('Échec de migration revient à la version précédente', () async {
    final dir = await Directory.systemTemp.createTemp('index-migration-fail-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/v1.sqlite';
    final db = sqlite3.open(path);
    db.execute(schema.schemaV1);
    db.execute('PRAGMA application_id=${schema.applicationId}');
    db.execute('PRAGMA user_version=1');
    db.execute('CREATE TABLE user_episode_state(preserve TEXT)');
    db.close();
    expect(() => CatalogStore.open(path), throwsA(isA<SqliteException>()));
    final after = sqlite3.open(path);
    addTearDown(after.close);
    expect(after.select('PRAGMA user_version').single.values.single, 1);
    expect(
      after.select(
        "SELECT name FROM sqlite_master WHERE name='local_audio_links'",
      ),
      isEmpty,
    );
  });
}
