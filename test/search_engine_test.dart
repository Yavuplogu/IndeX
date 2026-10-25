import 'dart:io';

import 'package:index_core/index_core.dart';
import 'package:index_core/index_io.dart';
import 'package:index_core/index_storage.dart';
import 'package:index_core/src/storage/migrations.dart' as schema;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'support/catalog_fixtures.dart' as f;

void main() {
  late CatalogStore store;
  late SqliteSearchEngine search;
  setUp(() {
    store = CatalogStore.inMemory();
    search = SqliteSearchEngine(store.database);
  });
  tearDown(() => store.close());

  void load(String title, String description) => store.importPlan(
    CatalogPlanner().plan([f.input(title: title, description: description)]),
  );

  test('Français : casse, accents, décomposition et apostrophes', () {
    load("L'été d'une révolution", "L'histoire de l’Algérie.");
    for (final query in [
      'ETE',
      'e\u0301te\u0301',
      "l'été",
      "l’été",
      'ALGERIE',
      'révolution été',
    ]) {
      expect(search.search(query), hasLength(1), reason: query);
    }
    expect(
      search.search('revolutions'),
      isEmpty,
      reason: 'Aucune lemmatisation promise.',
    );
  });

  test(
    'Tous les termes sont requis ; ponctuation et syntaxe restent littérales',
    () {
      load('Révolution française', 'Une histoire documentée.');
      expect(search.search('révolution française'), hasLength(1));
      for (final query in [
        '',
        '   ',
        '"',
        '***',
        '()',
        'inconnu',
        'révolution AND inexistant',
        'title:révolution',
        '" OR 1=1 --',
        "'); DROP TABLE episodes; --",
        'NEAR(révolution française)',
        'révolution NOT histoire',
      ]) {
        expect(search.search(query), isEmpty, reason: query);
      }
      search.checkIndex();
      expect(store.database.select('SELECT * FROM episodes'), hasLength(1));
    },
  );

  test('Préfixes sûrs, champs exacts et surlignage FTS accentué', () {
    load('La Yougoslavie', 'Un été en Yougoslavie.');
    expect(search.search('Yougo'), isEmpty);
    final hit = search
        .search('Yougo', options: const SearchOptions(prefix: true))
        .single;
    expect(hit.matchedFields, {SearchField.title, SearchField.description});
    expect(hit.markedExcerpt, contains('\u0001Yougoslavie\u0002'));
    expect(hit.excerpt, isNot(contains('\u0001')));
    expect(
      hit.markedFields[SearchField.description],
      'Un été en \u0001Yougoslavie\u0002.',
    );
    final accent = search
        .search(
          'ete',
          options: const SearchOptions(
            prefix: true,
            fields: {SearchField.description},
          ),
        )
        .single;
    expect(accent.markedExcerpt, contains('\u0001été\u0002'));
    expect(accent.matchedFields, {SearchField.description});
    expect(
      search.search(
        'Yougo OR inconnu',
        options: const SearchOptions(prefix: true),
      ),
      isEmpty,
    );
    expect(
      search.search('goslavie', options: const SearchOptions(prefix: true)),
      isEmpty,
    );
    final source = search
        .search(
          'aute',
          options: const SearchOptions(
            prefix: true,
            fields: {SearchField.sources},
          ),
        )
        .single;
    expect(source.matchedFields, {SearchField.sources});
    search.checkIndex();
  });

  test('Classement : titre prioritaire, ordre stable, pagination', () {
    store.importPlan(
      CatalogPlanner().plan([
        f.input(title: 'Espionnage', description: 'Une histoire.'),
        f.input(
          original: f.secondOriginal,
          title: 'Une histoire',
          description: 'Espionnage.',
        ),
      ]),
    );
    final hits = search.search('espionnage');
    expect(hits, hasLength(2));
    expect(hits.first.episodeId, f.firstId);
    expect(hits.first.score, lessThan(hits.last.score));
    expect(
      search
          .search(
            'espionnage',
            options: const SearchOptions(limit: 1, offset: 1),
          )
          .single
          .episodeId,
      hits.last.episodeId,
    );
    expect(
      search.search('espionnage').map((h) => h.episodeId),
      hits.map((h) => h.episodeId),
    );
  });

  test('Sources et musiques indexées ; extraits en texte brut', () {
    load('Un épisode', 'Description <script>texte</script> secret.');
    for (final term in [
      'livre',
      'auteur',
      'maison',
      'artiste',
      'chanson',
      'album',
      'label',
    ]) {
      expect(search.search(term).single.excerpt.toLowerCase(), contains(term));
    }
    expect(
      search.search('secret').single.excerpt,
      contains('<script>texte</script>'),
    );
    expect(search.search('secret').single.excerpt, isNot(contains('<b>')));
  });

  test('Filtres dates, sources et audio sans MP3 requis', () {
    load('Espionnage', 'Un récit.');
    expect(
      search.search(
        'espionnage',
        options: SearchOptions(
          fromDate: DateTime(2013, 4, 27),
          toDate: DateTime(2013, 4, 27),
          hasSources: true,
          audioAvailable: false,
        ),
      ),
      hasLength(1),
    );
    expect(
      search.search(
        'espionnage',
        options: SearchOptions(fromDate: DateTime(2014)),
      ),
      isEmpty,
    );
    expect(
      search.search(
        'espionnage',
        options: const SearchOptions(hasSources: false),
      ),
      isEmpty,
    );
    expect(
      search.search(
        'espionnage',
        options: const SearchOptions(audioAvailable: true),
      ),
      isEmpty,
    );
    store.recordManualLink(f.firstId, '/local.mp3', 'local.mp3');
    expect(
      search
          .search(
            'espionnage',
            options: const SearchOptions(audioAvailable: true),
          )
          .single
          .audioAvailable,
      isTrue,
    );
    store.database.execute('UPDATE local_audio_links SET available=0');
    expect(
      search.search(
        'espionnage',
        options: const SearchOptions(audioAvailable: true),
      ),
      isEmpty,
    );
  });

  test('Bornes explicites sur requêtes et pagination', () {
    for (final query in ['a' * 513, List.filled(33, 'mot').join(' ')]) {
      expect(() => search.search(query), throwsArgumentError);
    }
    for (final options in [
      const SearchOptions(limit: 0),
      const SearchOptions(limit: 101),
      const SearchOptions(offset: -1),
      const SearchOptions(offset: 10001),
      SearchOptions(fromDate: DateTime(2020), toDate: DateTime(2019)),
    ]) {
      expect(() => search.search('mot', options: options), throwsArgumentError);
    }
  });

  test('Réimport, update direct, delete et rollback maintiennent FTS', () {
    load('Ancienterme', 'Description.');
    load('Nouveauterme', 'Description.');
    expect(search.search('ancienterme'), isEmpty);
    expect(search.search('nouveauterme'), hasLength(1));
    search.checkIndex();
    store.database.execute('BEGIN');
    store.database.execute("UPDATE episodes SET title='Temporaire'");
    expect(search.search('temporaire'), hasLength(1));
    store.database.execute('ROLLBACK');
    expect(search.search('temporaire'), isEmpty);
    expect(search.search('nouveauterme'), hasLength(1));
    expect(
      () => store.importPlan(
        CatalogPlanner().plan([f.input(title: 'Annulation')]),
        afterEpisode: (_) => throw const ImportCancelled(),
      ),
      throwsA(isA<ImportCancelled>()),
    );
    expect(search.search('annulation'), isEmpty);
    expect(search.search('nouveauterme'), hasLength(1));
    store.database.execute('DELETE FROM episode_aliases');
    store.database.execute('DELETE FROM literary_sources');
    store.database.execute('DELETE FROM music_tracks');
    store.database.execute('DELETE FROM episodes');
    expect(search.search('nouveauterme'), isEmpty);
    search.checkIndex();
  });

  test(
    'Reconstruction répare un index désynchronisé sans toucher au suivi',
    () {
      load('Révolution', 'Un récit.');
      store.database.execute(
        "INSERT INTO user_episode_state(episode_id,position_ms,is_favorite) VALUES(?,12345,1)",
        [f.firstId],
      );
      store.database.execute(
        "INSERT INTO episodes_fts(episodes_fts,rowid,title,description,sources_text,music_text) SELECT 'delete',rowid,title,description,sources_text,music_text FROM episodes",
      );
      expect(search.search('révolution'), isEmpty);
      expect(search.checkIndex, throwsA(isA<SqliteException>()));
      search.rebuildIndex();
      expect(search.search('révolution'), hasLength(1));
      expect(
        store.database
            .select('SELECT position_ms,is_favorite FROM user_episode_state')
            .single
            .values,
        [12345, 1],
      );
    },
  );

  test(
    'Migration réelle v2 vers v3 indexe les fiches et conserve le suivi',
    () {
      final db = sqlite3.openInMemory();
      db.execute(schema.schemaV1);
      db.execute(schema.schemaV2);
      db.execute('PRAGMA application_id=${schema.applicationId}');
      db.execute('PRAGMA user_version=2');
      db.execute(
        "INSERT INTO episodes(id,original_name,original_raw,title,description,sources_text,music_text,source_path,source_bytes,raw_text,fingerprint,needs_review,origin,updated_at) VALUES('a','a.mp3','a.mp3','Migration révolution','','','','a.txt',x'41','','old',0,'reference','2026')",
      );
      db.execute(
        "INSERT INTO user_episode_state(episode_id,position_ms,is_favorite) VALUES('a',42,1)",
      );
      final migrated = CatalogStore.fromDatabase(db);
      addTearDown(migrated.close);
      final engine = SqliteSearchEngine(db);
      expect(engine.search('revolution').single.episodeId, 'a');
      engine.checkIndex();
      expect(
        db.select('PRAGMA user_version').single.values.single,
        schema.schemaVersion,
      );
      expect(
        db
            .select('SELECT position_ms,is_favorite FROM user_episode_state')
            .single
            .values,
        [42, 1],
      );
    },
  );

  test('Échec FTS5 pendant migration : schéma v2 intact', () {
    final db = sqlite3.openInMemory();
    db.execute(schema.schemaV1);
    db.execute(schema.schemaV2);
    db.execute('PRAGMA application_id=${schema.applicationId}');
    db.execute('PRAGMA user_version=2');
    db.execute('CREATE TABLE episodes_fts(dummy TEXT)');
    expect(() => schema.migrate(db), throwsA(isA<SqliteException>()));
    expect(db.select('PRAGMA user_version').single.values.single, 2);
    expect(
      db.select("SELECT name FROM sqlite_master WHERE type='trigger'"),
      isEmpty,
    );
    db.close();
  });

  test('Seed v2 importé en lecture seule vers une base v3 indexée', () async {
    final dir = await Directory.systemTemp.createTemp('index-v2-reference-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/old.sqlite';
    final seed = CatalogStore.open(path);
    seed.importPlan(f.plan(), catalogVersion: 'v2-reference');
    seed.database.execute('DROP TRIGGER episodes_fts_insert');
    seed.database.execute('DROP TRIGGER episodes_fts_update');
    seed.database.execute('DROP TRIGGER episodes_fts_delete');
    seed.database.execute('DROP TABLE episodes_fts');
    seed.database.execute('PRAGMA user_version=2');
    seed.database.execute('UPDATE catalog_versions SET schema_version=2');
    seed.close();
    expect(store.importReference(path).inserted, 1);
    expect(search.search('complète'), hasLength(1));
    search.checkIndex();
    final unchanged = sqlite3.open(path, mode: OpenMode.readOnly);
    expect(unchanged.select('PRAGMA user_version').single.values.single, 2);
    unchanged.close();
  });

  test(
    'Sélection des champs FTS : auteur seul, termes répartis et exclusion',
    () {
      load('Révolution', 'Diplomatie secrète.');
      expect(
        search.search(
          'auteur',
          options: const SearchOptions(fields: {SearchField.sources}),
        ),
        hasLength(1),
      );
      expect(
        search.search(
          'auteur',
          options: const SearchOptions(fields: {SearchField.title}),
        ),
        isEmpty,
      );
      expect(
        search.search(
          'révolution diplomatie',
          options: const SearchOptions(
            fields: {SearchField.title, SearchField.description},
          ),
        ),
        hasLength(1),
      );
      expect(
        search.search(
          'révolution diplomatie',
          options: const SearchOptions(fields: {SearchField.title}),
        ),
        isEmpty,
      );
      expect(
        search.search(
          'chanson',
          options: const SearchOptions(fields: {SearchField.music}),
        ),
        hasLength(1),
      );
      expect(
        search.search(
          'chanson',
          options: const SearchOptions(fields: {SearchField.sources}),
        ),
        isEmpty,
      );
      expect(
        () => search.search('mot', options: const SearchOptions(fields: {})),
        throwsArgumentError,
      );
    },
  );

  test('Corpus complet : recherche, extrait, import du seul seed et index cohérent', () async {
    store.importPlan(
      CatalogPlanner().plan(
        await loadTxtDirectory(Directory('TXT_Files')),
        journalBytes: await File('Journal_Files/journal.csv').readAsBytes(),
      ),
    );
    expect(
      search.search('Pasolini').any((h) => h.title.contains('Pasolini')),
      isTrue,
    );
    expect(search.search('rwanda'), isNotEmpty);
    expect(search.search('Bizerte'), isNotEmpty);
    search.checkIndex();
    final target = CatalogStore.inMemory();
    addTearDown(target.close);
    expect(target.importReference('assets/catalogue.sqlite').inserted, 716);
    final imported = SqliteSearchEngine(target.database);
    expect(imported.search('Pasolini'), isNotEmpty);
    imported.checkIndex();
  });
}
