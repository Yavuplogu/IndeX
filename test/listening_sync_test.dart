import 'dart:convert';
import 'dart:io';

import 'package:index_core/index_desktop.dart';
import 'package:index_core/index_storage.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:index_core/src/storage/migrations.dart' as schema;

void main() {
  late CatalogStore a, b;
  late ListeningSync sa, sb;
  const id = 'mrx:mr_x_1997_01_04.mp3';
  setUp(() {
    a = CatalogStore.inMemory()..importReference('assets/catalogue.sqlite');
    b = CatalogStore.inMemory()..importReference('assets/catalogue.sqlite');
    sa = ListeningSync(a);
    sb = ListeningSync(b);
    sa.deviceId;
    sb.deviceId;
  });
  tearDown(() {
    a.close();
    b.close();
  });
  void state(CatalogStore store, String sql) {
    store.database.execute(
      'INSERT OR IGNORE INTO user_episode_state(episode_id) VALUES(?)',
      [id],
    );
    store.database.execute(
      'UPDATE user_episode_state SET $sql WHERE episode_id=?',
      [id],
    );
  }

  Map<String, Object?> row(CatalogStore store) => Map.from(
    store.database.select(
      'SELECT * FROM user_episode_state WHERE episode_id=?',
      [id],
    ).single,
  );
  Future<void> transfer(ListeningSync from, ListeningSync to) async {
    final document = SyncDocument.decode(from.encode(from.exportDocument()));
    final plan = to.preview(document);
    expect(plan.conflicts, isEmpty);
    await to.apply(plan, {}, backup: () async {});
  }

  Map<String, dynamic> payload() =>
      jsonDecode(utf8.decode(sa.encode(sa.exportDocument())))
          as Map<String, dynamic>;

  test('Deux profils indépendants : favori et lecture fusionnent par champ, sans métadonnées locales', () async {
    state(
      a,
      "listening_status='EN_COURS',position_ms=42000,duration_ms=120000,last_played_at='2026-10-30T11:00:00Z'",
    );
    state(b, 'is_favorite=1');
    b.database.execute("INSERT INTO local_settings VALUES('theme','dark')");
    b.recordManualLink(id, 'file:///mes-mp3/manuel.mp3', 'manuel.mp3');
    await transfer(sa, sb);
    expect(row(b)['position_ms'], 42000);
    expect(row(b)['listening_status'], 'EN_COURS');
    expect(row(b)['is_favorite'], 1);
    await transfer(sb, sa);
    expect(row(a)['is_favorite'], 1);
    final json = utf8.decode(sb.encode(sb.exportDocument()));
    expect(json, isNot(contains('mes-mp3')));
    expect(json, isNot(contains('theme')));
    expect(json, isNot(contains('audio_ref')));
    expect(
      b.database
          .select("SELECT value FROM local_settings WHERE key='theme'")
          .single['value'],
      'dark',
    );
    expect(
      b.database
          .select('SELECT audio_ref FROM local_audio_links')
          .single['audio_ref'],
      'file:///mes-mp3/manuel.mp3',
    );
  });

  test(
    'Retrait de favori et reset causal résistent à un ancien export',
    () async {
      state(
        a,
        "is_favorite=1,listening_status='ECOUTE',position_ms=120000,duration_ms=120000,completed_at='2026-10-30T12:00:00Z'",
      );
      final old = sa.exportDocument();
      await transfer(sa, sb);
      state(
        b,
        "is_favorite=0,listening_status='NON_ECOUTE',position_ms=0,completed_at=NULL",
      );
      await transfer(sb, sa);
      final plan = sa.preview(old);
      expect(plan.conflicts, isEmpty);
      await sa.apply(plan, {}, backup: () async {});
      expect(row(a)['is_favorite'], 0);
      expect(row(a)['listening_status'], 'NON_ECOUTE');
      expect(row(a)['position_ms'], 0);
    },
  );

  test('Écoutes concurrentes : conflit explicite, retour arrière choisi et résolution durable', () async {
    state(
      a,
      "listening_status='EN_COURS',position_ms=10000,duration_ms=120000",
    );
    await transfer(sa, sb);
    state(a, 'position_ms=90000');
    state(b, 'position_ms=20000');
    final remote = sb.exportDocument();
    final plan = sa.preview(remote);
    expect(plan.conflicts.single.field, 'listening');
    await expectLater(
      sa.apply(
        plan,
        {},
        backup: () async => fail('Pas de sauvegarde avant résolution'),
      ),
      throwsStateError,
    );
    await sa.apply(plan, {
      plan.conflicts.single.key: SyncChoice.file,
    }, backup: () async {});
    expect(row(a)['position_ms'], 20000, reason: 'Le maximum ne décide pas.');
    await transfer(sa, sb);
    expect(row(b)['position_ms'], 20000);
    final before = row(a);
    final again = sa.preview(remote);
    expect(again.alreadyImported, isTrue);
    await sa.apply(
      again,
      {},
      backup: () async => fail('Import répété sans effet'),
    );
    expect(row(a), before);
  });

  test('Conserver cet appareil résout le conflit et empêche une réintroduction ultérieure', () async {
    state(a, 'position_ms=1000');
    await transfer(sa, sb);
    state(a, 'position_ms=2000');
    state(b, 'position_ms=3000');
    final plan = sa.preview(sb.exportDocument());
    await sa.apply(plan, {
      plan.conflicts.single.key: SyncChoice.local,
    }, backup: () async {});
    expect(row(a)['position_ms'], 2000);
    await transfer(sa, sb);
    expect(row(b)['position_ms'], 2000);
  });

  test('Horloges désynchronisées : les dates ne départagent pas les écritures concurrentes', () async {
    state(a, "position_ms=1000,last_played_at='2099-01-01T00:00:00Z'");
    state(b, "position_ms=5000,last_played_at='1999-01-01T00:00:00Z'");
    final plan = sa.preview(sb.exportDocument());
    expect(plan.conflicts.single.field, 'listening');
    expect(row(a)['position_ms'], 1000, reason: 'L’aperçu n’applique rien.');
  });

  test('Suppression du suivi par désassociation : tombstones exportés, favoris non rétablis', () async {
    state(a, 'is_favorite=1,position_ms=30000');
    await transfer(sa, sb);
    b.recordManualLink(id, 'file:///temp/episode.mp3', 'episode.mp3');
    b.unlinkAudio('file:///temp/episode.mp3');
    expect(b.database.select('SELECT * FROM user_episode_state'), isEmpty);
    await transfer(sb, sa);
    expect(row(a)['is_favorite'], 0);
    expect(row(a)['position_ms'], 0);
    expect(row(a)['listening_status'], 'NON_ECOUTE');
    expect(b.unlinkedAudioReferences, {'file:///temp/episode.mp3'});
  });

  test('Aperçu périmé et échec de sauvegarde : aucune fusion', () async {
    state(a, 'is_favorite=1');
    var plan = sb.preview(sa.exportDocument());
    state(b, 'position_ms=1234');
    await expectLater(
      sb.apply(plan, {}, backup: () async => fail('Aperçu périmé')),
      throwsStateError,
    );
    plan = sb.preview(sa.exportDocument());
    final before = row(b);
    await expectLater(
      sb.apply(
        plan,
        {},
        backup: () async => throw const FileSystemException('Disque plein'),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(row(b), before);
    expect(b.database.select('SELECT * FROM sync_imports'), isEmpty);
  });

  test('Modification pendant sauvegarde et erreur au milieu de la transaction : rollback complet', () async {
    state(a, 'is_favorite=1');
    var plan = sb.preview(sa.exportDocument());
    await expectLater(
      sb.apply(
        plan,
        {},
        backup: () async {
          state(b, 'position_ms=1234');
        },
      ),
      throwsStateError,
    );
    expect(row(b)['is_favorite'], 0);
    plan = sb.preview(sa.exportDocument());
    final before = row(b);
    final clocks = b.database
        .select('SELECT * FROM sync_fields')
        .map((r) => Map<String, Object?>.from(r))
        .toList();
    b.database.execute(
      "CREATE TRIGGER fail_sync BEFORE INSERT ON sync_imports BEGIN SELECT RAISE(ABORT,'échec simulé'); END;",
    );
    await expectLater(
      sb.apply(plan, {}, backup: () async {}),
      throwsA(anything),
    );
    expect(row(b), before);
    expect(
      b.database
          .select('SELECT * FROM sync_fields')
          .map((r) => Map<String, Object?>.from(r))
          .toList(),
      clocks,
    );
    expect(
      b.database.select('SELECT suppress FROM sync_device').single['suppress'],
      0,
    );
    expect(b.database.select('SELECT * FROM sync_imports'), isEmpty);
  });

  test('Épisodes inconnus signalés, jamais réaffectés et catalogue différent accepté', () async {
    state(a, 'is_favorite=1');
    final data = payload();
    ((data['episodes'] as List).single as Map)['episode_id'] =
        'mrx:mr_x_2099_01_01.mp3';
    data['catalog_version'] = 'catalogue-autre';
    final plan = sb.preview(SyncDocument.decode(utf8.encode(jsonEncode(data))));
    expect(plan.unknown, ['mrx:mr_x_2099_01_01.mp3']);
    expect(plan.changes, isEmpty);
    await sb.apply(plan, {}, backup: () async {});
    expect(b.database.select('SELECT * FROM user_episode_state'), isEmpty);
  });

  test('JSON invalide, tronqué, futur, répété, excessif ou contenant des chemins : refus sans effet', () {
    state(a, 'is_favorite=1');
    final raw = payload();
    final bad = <Object>[
      {...raw, 'schema_version': 99},
      {...raw, 'audio_ref': 'file:///secret'},
      {
        ...raw,
        'episodes': [
          ...(raw['episodes'] as List),
          ...(raw['episodes'] as List),
        ],
      },
      {...raw, 'episodes': 'invalide'},
      {...raw, 'exported_at': '2026-02-31T00:00:00Z'},
    ];
    for (final data in bad) {
      expect(
        () => SyncDocument.decode(utf8.encode(jsonEncode(data))),
        throwsFormatException,
      );
    }
    expect(() => SyncDocument.decode(utf8.encode('{')), throwsFormatException);
    expect(
      () => SyncDocument.decode(List.filled(syncMaxBytes + 1, 32)),
      throwsFormatException,
    );
    expect(
      () => SyncDocument.decode(
        utf8.encode(
          '${List.filled(20, '[').join()}0${List.filled(20, ']').join()}',
        ),
      ),
      throwsFormatException,
    );
    expect(b.database.select('SELECT * FROM user_episode_state'), isEmpty);
    expect(b.database.select('SELECT * FROM sync_imports'), isEmpty);
  });

  test('Identifiant d’export réutilisé et même version avec valeurs contradictoires : refus', () async {
    state(a, 'is_favorite=1');
    final data = payload();
    final doc = SyncDocument.decode(utf8.encode(jsonEncode(data)));
    await sb.apply(sb.preview(doc), {}, backup: () async {});
    data['catalog_version'] = 'modifié';
    expect(
      () => sb.preview(SyncDocument.decode(utf8.encode(jsonEncode(data)))),
      throwsFormatException,
    );
    final altered = payload();
    (((altered['episodes'] as List).single as Map)['fields']
            as Map)['favorite']['value'] =
        false;
    expect(
      () => sb.preview(SyncDocument.decode(utf8.encode(jsonEncode(altered)))),
      throwsFormatException,
    );
  });

  test('Export en fichier : contenu borné, nom sans espaces, états intacts et nettoyage en échec', () async {
    state(a, 'is_favorite=1,position_ms=12000');
    final data = await Directory.systemTemp.createTemp('index-sync-export-');
    addTearDown(() => data.delete(recursive: true));
    final before = row(a);
    var now = DateTime.utc(2026, 10, 31, 21, 51, 34);
    final exporter = ListeningSync(a, now: () => now);
    final result = await exporter.exportFile(
      data,
      publish: (part, target) async {
        expect(target.existsSync(), isFalse);
        await part.rename(target.path);
      },
    );
    expect(
      FileSystemEntity.identicalSync(
        result.parent.path,
        Directory('${data.path}/exports').path,
      ),
      isTrue,
      reason: 'Le JSON doit être publié dans le dossier exports réel, quel que soit le séparateur ou alias Windows.',
    );
    expect(
      result.uri.pathSegments.last,
      matches(RegExp(r'^IndeX_suivi_[0-9]{8}_[0-9]{6}\.json$')),
    );
    expect(result.uri.pathSegments.last, isNot(contains(' ')));
    expect((await ListeningSync.readFile(result)).episodes.single.id, id);
    expect(row(a), before);
    final content = result.readAsStringSync();
    await expectLater(
      exporter.exportFile(
        data,
        publish: (_, _) async => fail('Ne jamais écraser un export existant'),
      ),
      throwsStateError,
    );
    expect(result.readAsStringSync(), content);
    now = now.add(const Duration(seconds: 1));
    await expectLater(
      exporter.exportFile(
        data,
        publish: (_, _) async =>
            throw const FileSystemException('Accès refusé'),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(result.parent.listSync().whereType<Directory>(), isEmpty);
    expect(result.readAsStringSync(), contains('index-listening-sync'));
  });
  test('Migration v6 : suivi historique conservé et exportable, identifiant stable après réouverture', () async {
    final root = await Directory.systemTemp.createTemp('index-sync-migration-');
    addTearDown(() => root.delete(recursive: true));
    final file = await File('assets/catalogue.sqlite')
        .copy('${root.path}/user.sqlite');
    final old = sqlite3.open(file.path);
    old.execute(schema.schemaV5);
    old.execute(schema.schemaV6);
    old.execute('PRAGMA user_version=6');
    old.execute(
      "INSERT INTO user_episode_state(episode_id,is_favorite,position_ms,duration_ms,listening_status,last_played_at) VALUES(?,1,34567,120000,'EN_COURS','2026-10-30T10:00:00Z')",
      [id],
    );
    final before = Map<String, Object?>.from(
      old.select('SELECT * FROM user_episode_state').single,
    );
    old.close();
    var migrated = CatalogStore.open(file.path);
    final engine = ListeningSync(migrated);
    final device = engine.deviceId;
    expect(
      Map<String, Object?>.from(
        migrated.database.select('SELECT * FROM user_episode_state').single,
      ),
      before,
    );
    expect(
      engine.exportDocument().episodes.single.fields.values.every(
        (v) => v.clock.containsKey(device),
      ),
      isTrue,
    );
    migrated.close();
    migrated = CatalogStore.open(file.path);
    expect(ListeningSync(migrated).deviceId, device);
    expect(
      migrated.database.select('PRAGMA user_version').single.values.single,
      7,
    );
    migrated.close();
  });

  test(
    'Renommage local : aucun changement des versions ou du JSON de suivi',
    () async {
      state(a, 'is_favorite=1,position_ms=45678');
      final root = await Directory.systemTemp.createTemp('index-sync-rename-');
      addTearDown(() => root.delete(recursive: true));
      final source = File('${root.path}/mr_x_1997_01_04.mp3')
        ..writeAsStringSync('audio');
      a.recordManualLink(
        id,
        source.uri.toString(),
        source.uri.pathSegments.last,
      );
      final before = sa.exportDocument();
      final renamer = Mp3Renamer(a);
      final plan = await renamer.preview(root, recursive: false);
      await renamer.execute(
        plan,
        move: (from, to) async {
          await from.rename(to.path);
        },
      );
      final after = sa.exportDocument();
      for (final field in ['favorite', 'status', 'position']) {
        expect(
          after.episodes.single.fields[field]!.valueJson,
          before.episodes.single.fields[field]!.valueJson,
        );
        expect(
          after.episodes.single.fields[field]!.clock,
          before.episodes.single.fields[field]!.clock,
        );
      }
      b.recordManualLink(
        id,
        'file:///autre-machine/mr_x_1997_01_04.mp3',
        'mr_x_1997_01_04.mp3',
      );
      await sb.apply(sb.preview(before), {}, backup: () async {});
      expect(row(b)['position_ms'], 45678);
      expect(row(b)['is_favorite'], 1);
      expect(
        b.database
            .select('SELECT audio_ref FROM local_audio_links')
            .single['audio_ref'],
        'file:///autre-machine/mr_x_1997_01_04.mp3',
      );
    },
  );

  test('Reset explicite déjà à zéro : une ancienne écoute devient conflictuelle, jamais rétablie silencieusement', () {
    state(a, 'is_favorite=1');
    sa.markExplicit(id, ['status', 'position']);
    state(b, "listening_status='ECOUTE',position_ms=120000,duration_ms=120000");
    final plan = sa.preview(sb.exportDocument());
    expect(plan.conflicts.map((c) => c.field).toSet(), {'listening'});
    expect(row(a)['listening_status'], 'NON_ECOUTE');
  });

  test(
    'Types et bornes des champs/versions invalides : rejet avant aperçu',
    () {
      state(a, 'is_favorite=1');
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (e) => e['favorite']['value'] = 1,
        (e) => e['status']['value']['listening_status'] = 'INCONNU',
        (e) => e['position']['value']['position_ms'] = -1,
        (e) => e['position']['value']['duration_ms'] = 0,
        (e) => e['favorite']['clock'] = <String, int>{sa.deviceId: 0},
        (e) => e['favorite']['clock'] = <String, Object>{sa.deviceId: 1.5},
        (e) => e['favorite']['clock'] = <String, int>{},
        (e) => e['favorite']['clock'] = <String, int>{
          for (var i = 0; i < 33; i++)
            'd_${i.toRadixString(16).padLeft(32, '0')}': 1,
        },
      ]) {
        final data = payload();
        mutate(
          ((data['episodes'] as List).single as Map<String, dynamic>)['fields']
              as Map<String, dynamic>,
        );
        expect(
          () => SyncDocument.decode(utf8.encode(jsonEncode(data))),
          throwsFormatException,
        );
      }
    },
  );
  test('Désassociation sans ligne de suivi : retrait causal explicite et non état vierge', () {
    a.recordManualLink(
      id,
      'file:///temp/jamais-ecoute.mp3',
      'jamais-ecoute.mp3',
    );
    a.unlinkAudio('file:///temp/jamais-ecoute.mp3');
    expect(a.database.select('SELECT * FROM user_episode_state'), isEmpty);
    state(b, "is_favorite=1,listening_status='ECOUTE',position_ms=5000");
    final plan = sa.preview(sb.exportDocument());
    expect(plan.conflicts.map((c) => c.field).toSet(), {
      'favorite',
      'listening',
    });
    expect(a.database.select('SELECT * FROM user_episode_state'), isEmpty);
  });

  test('L’exemple JSON documenté respecte le contrat du parseur', () {
    final document = SyncDocument.decode(
      File('docs/lot5ter/exemple.json').readAsBytesSync(),
    );
    expect(document.episodes.single.id, id);
    expect(document.episodes.single.fields['favorite']!.value, isTrue);
  });
  for (final choice in SyncChoice.values) {
    test(
      'Écoute couplée : statut et reprise proviennent toujours de la même source (${choice.name})',
      () async {
        state(
          a,
          "is_favorite=1,listening_status='ECOUTE',position_ms=120000,duration_ms=120000,completed_at='2026-10-31T20:00:00Z'",
        );
        await transfer(sa, sb);
        state(a, 'position_ms=119000');
        state(
          b,
          "is_favorite=0,listening_status='EN_COURS',position_ms=1200,completed_at=NULL",
        );
        final plan = sa.preview(sb.exportDocument());
        expect(plan.conflicts, hasLength(1));
        final conflict = plan.conflicts.single;
        expect(conflict.field, 'listening');
        await expectLater(
          sa.apply(plan, {
            '$id|position': SyncChoice.file,
            '$id|status': SyncChoice.local,
          }, backup: () async => fail('Choix séparés interdits')),
          throwsStateError,
        );
        await sa.apply(plan, {conflict.key: choice}, backup: () async {});
        expect(
          row(a)['listening_status'],
          choice == SyncChoice.file ? 'EN_COURS' : 'ECOUTE',
        );
        expect(
          row(a)['position_ms'],
          choice == SyncChoice.file ? 1200 : 119000,
        );
        expect(
          row(a)['completed_at'],
          choice == SyncChoice.file ? isNull : '2026-10-31T20:00:00Z',
        );
        expect(
          row(a)['is_favorite'],
          0,
          reason: 'Le favori peut évoluer indépendamment de l’écoute.',
        );
        await transfer(sa, sb);
        expect(row(b)['listening_status'], row(a)['listening_status']);
        expect(row(b)['position_ms'], row(a)['position_ms']);
      },
    );
  }

  test('Versions croisées sans conflit par champ : demander un choix global d’écoute', () async {
    state(
      a,
      "listening_status='EN_COURS',position_ms=50000,duration_ms=120000",
    );
    final baseline = sa.exportDocument();
    await sb.apply(sb.preview(baseline), {}, backup: () async {});
    // A est plus récent pour le statut ; B est plus récent pour la reprise.
    state(a, "listening_status='ECOUTE',completed_at='2026-10-31T20:00:00Z'");
    state(b, 'position_ms=1000');
    final plan = sa.preview(sb.exportDocument());
    expect(plan.conflicts.single.field, 'listening');
    await sa.apply(plan, {
      plan.conflicts.single.key: SyncChoice.file,
    }, backup: () async {});
    expect(row(a)['listening_status'], 'EN_COURS');
    expect(row(a)['position_ms'], 1000);
  });

  test(
    'Provenance v2 Windows/Android et anciens exports v1 sans plateforme',
    () async {
      state(a, 'is_favorite=1');
      for (final platform in ['windows', 'android', 'unknown']) {
        final data = payload();
        expect(data['schema_version'], 2);
        data['source_platform'] = platform;
        final doc = SyncDocument.decode(utf8.encode(jsonEncode(data)));
        expect(doc.sourcePlatform, platform);
        expect(doc.schemaVersion, 2);
      }
      final invalid = payload()..['source_platform'] = 'plateforme-inconnue';
      expect(
        () => SyncDocument.decode(utf8.encode(jsonEncode(invalid))),
        throwsFormatException,
      );
      final old = payload()..remove('source_platform');
      old['schema_version'] = 1;
      final legacy = SyncDocument.decode(utf8.encode(jsonEncode(old)));
      expect(legacy.sourcePlatform, 'unknown');
      expect(legacy.schemaVersion, 1);
      expect(SyncDocument.decode(sa.encode(legacy)).digest, legacy.digest);
      await sb.apply(sb.preview(legacy), {}, backup: () async {});
      expect(sb.preview(legacy).alreadyImported, isTrue);
      expect(row(b)['is_favorite'], 1);
    },
  );
}
