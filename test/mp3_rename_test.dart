import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:index_core/index_desktop.dart';
import 'package:index_core/index_storage.dart';
import 'package:index_core/src/io/catalog_sources.dart';
import 'package:test/test.dart';

// Réservé aux copies de test. La production utilise MoveFileExW sans remplacement.
Future<void> testMove(File source, File target) async {
  if (await FileSystemEntity.type(target.path, followLinks: false) !=
      FileSystemEntityType.notFound)
    throw StateError('cible existante');
  await source.rename(target.path);
}

void main() {
  late Directory root;
  late CatalogStore store;
  late Mp3Renamer renamer;
  late String id, name, system;
  late File source;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('index-rename-');
    store = CatalogStore.open('${root.path}/user.sqlite');
    store.importReference('assets/catalogue.sqlite');
    renamer = Mp3Renamer(store);
    final row = store.database
        .select(
          "SELECT * FROM episodes WHERE original_name='mr_x_1997_01_04.mp3'",
        )
        .single;
    id = row['id'] as String;
    name = row['original_name'] as String;
    system = row['system_name'] as String;
    source = File('${root.path}/$name')
      ..writeAsStringSync('audio et tags conservés');
  });
  tearDown(() async {
    store.close();
    await root.delete(recursive: true);
  });

  Future<File> aliasSource() async {
    // Windows CI fournit déjà le parent court RUNNER~1 et son équivalent long.
    // Sous POSIX, créer un alias explicite pour reproduire la différence.
    if (Platform.isWindows) return source;
    final alias = Link('${root.path}-alias');
    await alias.create(root.path);
    addTearDown(() => alias.delete());
    return File('${alias.path}/$name');
  }

  test('Alias du parent : association et diagnostic réparés même après disparition du nom source', () async {
    final alias = await aliasSource();
    store.applyAudioScan(await scanAudioDirectory(alias.parent));
    store.recordManualLink(id, alias.uri.toString(), name);
    final plan = await renamer.preview(root, recursive: false);
    expect(
      plan.planned,
      1,
      reason: plan.entries.map((e) => e.reason).join(' ; '),
    );
    final run = await renamer.execute(
      plan,
      move: (from, to) async {
        await testMove(from, to);
        throw StateError('interruption avec ancien chemin aliasé');
      },
    );
    expect(alias.existsSync(), isFalse);
    await renamer.recover();
    expect(renamer.report(run).single['status'], 'succeeded');
    final target = File('${root.path}/$system');
    final link = store.database
        .select('SELECT * FROM local_audio_links')
        .single;
    expect(link['manual'], 1);
    expect(
      FileSystemEntity.identicalSync(
        File.fromUri(Uri.parse(link['audio_ref'] as String)).path,
        target.path,
      ),
      isTrue,
    );
    final diagnostic = jsonDecode(
      store.database
              .select('SELECT decision_json FROM audio_scan_items')
              .single['decision_json']
          as String,
    ) as Map;
    expect(diagnostic['current_name'], system);
    expect(
      FileSystemEntity.identicalSync(
        File.fromUri(Uri.parse(diagnostic['audio_reference'] as String)).path,
        target.path,
      ),
      isTrue,
    );
  });

  test(
    'Alias du parent : une exclusion reste respectée et inchangée',
    () async {
      final alias = await aliasSource();
      store.recordManualLink(id, alias.uri.toString(), name);
      store.unlinkAudio(alias.uri.toString());
      final plan = await renamer.preview(root, recursive: false);
      expect(plan.planned, 0);
      expect(plan.entries.single.reason, contains('retirée'));
      expect(store.unlinkedAudioReferences, contains(alias.uri.toString()));
      expect(source.existsSync(), isTrue);
    },
  );

  test(
    'Alias du parent : cible déjà associée à un autre épisode toujours refusée',
    () async {
      final alias = await aliasSource();
      final otherId =
          store.database.select('SELECT id FROM episodes WHERE id<>? LIMIT 1', [
                id,
              ]).single['id']
              as String;
      final reservedName = Platform.isWindows ? system.toUpperCase() : system;
      final reserved = File('${alias.parent.path}/$reservedName');
      store.recordManualLink(otherId, reserved.uri.toString(), system);
      final plan = await renamer.preview(root, recursive: false);
      expect(plan.planned, 1);
      final run = await renamer.execute(
        plan,
        move: (_, _) async =>
            fail('Une cible liée à un autre épisode est protégée'),
      );
      expect(renamer.report(run).single['status'], 'failed');
      expect(
        renamer.report(run).single['error'],
        contains('cible déjà associée'),
      );
      expect(source.existsSync(), isTrue);
      expect(
        store.database
            .select('SELECT audio_ref FROM local_audio_links')
            .single['audio_ref'],
        reserved.uri.toString(),
      );
    },
  );

  test('Aperçu sans effet, copie MP3 réelle, conservation des liens manuels/suivi et idempotence', () async {
    // Aucun octet des fixtures du dépôt n’est modifié.
    final real = File("MP3_Files/2013-04-27 'Le Masque de fer' israélien.mp3");
    await real.copy(source.path);
    final digest = await sha256.bind(real.openRead()).first;
    store.recordManualLink(id, source.uri.toString(), name);
    store.database.execute(
      "INSERT INTO user_episode_state(episode_id,position_ms,listening_status,is_favorite) VALUES(?,42000,'EN_COURS',1)",
      [id],
    );
    final preview = await renamer.preview(root, recursive: false);
    expect(preview.planned, 1);
    expect(source.existsSync(), isTrue);
    expect(store.database.select('SELECT * FROM rename_runs'), isEmpty);
    final run = await renamer.execute(preview, move: testMove);
    expect(renamer.report(run).single['status'], 'succeeded');
    expect(source.existsSync(), isFalse);
    final target = File('${root.path}/$system');
    expect(await sha256.bind(target.openRead()).first, digest);
    expect(await sha256.bind(real.openRead()).first, digest);
    final link = store.database
        .select('SELECT * FROM local_audio_links')
        .single;
    expect(
      FileSystemEntity.identicalSync(
        File.fromUri(Uri.parse(link['audio_ref'] as String)).path,
        target.path,
      ),
      isTrue,
    );
    expect(link['manual'], 1);
    final state = store.database
        .select('SELECT * FROM user_episode_state')
        .single;
    expect(state['position_ms'], 42000);
    expect(state['is_favorite'], 1);
    expect(state['listening_status'], 'EN_COURS');
    expect((await renamer.preview(root, recursive: false)).planned, 0);
  });

  test(
    'Cible déjà présente, Unicode/casse, inconnus et doublons ignorés',
    () async {
      final target = File('${root.path}/${system.toUpperCase()}')
        ..writeAsStringSync('ne pas écraser');
      File('${root.path}/inconnu.mp3').writeAsStringSync('inconnu');
      final preview = await renamer.preview(root, recursive: false);
      expect(preview.planned, 0);
      expect(preview.entries.where((e) => e.status == 'conflict'), isNotEmpty);
      expect(target.readAsStringSync(), 'ne pas écraser');
      expect(source.existsSync(), isTrue);
      final sub = Directory('${root.path}/sous dossier')..createSync();
      await source.copy('${sub.path}/$name');
      final duplicate = await renamer.preview(root, recursive: true);
      expect(duplicate.planned, 0);
    },
  );

  test('Récursivité, exclusion et fichier utilisé par le lecteur', () async {
    final sub = Directory('${root.path}/sous dossier')..createSync();
    final nested = await source.rename('${sub.path}/$name');
    expect((await renamer.preview(root, recursive: false)).planned, 0);
    expect((await renamer.preview(root, recursive: true)).planned, 1);
    expect(
      (await renamer.preview(
        root,
        recursive: true,
        inUse: nested.uri.toString(),
      )).planned,
      0,
    );
    store.recordManualLink(id, nested.uri.toString(), name);
    store.unlinkAudio(nested.uri.toString());
    expect((await renamer.preview(root, recursive: true)).planned, 0);
  });

  test(
    'Changement de contenu et cible apparue après aperçu : aucun déplacement',
    () async {
      var preview = await renamer.preview(root, recursive: false);
      source.writeAsStringSync('contenu modifié');
      var run = await renamer.execute(
        preview,
        move: (_, _) async => fail('Aucun déplacement autorisé'),
      );
      expect(renamer.report(run).single['status'], 'failed');
      preview = await renamer.preview(root, recursive: false);
      final target = File('${root.path}/$system')
        ..writeAsStringSync('existant');
      run = await renamer.execute(
        preview,
        move: (_, _) async => fail('Aucun écrasement autorisé'),
      );
      expect(renamer.report(run).single['status'], 'failed');
      expect(target.readAsStringSync(), 'existant');
      expect(source.readAsStringSync(), 'contenu modifié');
    },
  );

  test('Refus de permission et lecteur devenu actif après aperçu', () async {
    final preview = await renamer.preview(root, recursive: false);
    var run = await renamer.execute(
      preview,
      move: (_, _) async => throw const FileSystemException('Access denied'),
    );
    await renamer.recover();
    expect(renamer.report(run).single['status'], 'failed');
    expect(source.existsSync(), isTrue);
    final next = await renamer.preview(root, recursive: false);
    run = await renamer.execute(
      next,
      inUse: () => source.uri.toString(),
      move: (_, _) async => fail('Fichier en lecture'),
    );
    expect(renamer.report(run).single['status'], 'failed');
  });

  test('Interruption après déplacement : nouvelle connexion répare le lien et le suivi', () async {
    store.recordManualLink(id, source.uri.toString(), name);
    store.database.execute(
      "INSERT INTO user_episode_state(episode_id,position_ms,is_favorite) VALUES(?,12345,1)",
      [id],
    );
    final preview = await renamer.preview(root, recursive: false);
    final run = await renamer.execute(
      preview,
      move: (from, to) async {
        await testMove(from, to);
        throw StateError('Interruption après opération native');
      },
    );
    expect(renamer.report(run).single['status'], 'moving');
    expect(
      store.database
          .select('SELECT audio_ref FROM local_audio_links')
          .single['audio_ref'],
      source.uri.toString(),
    );
    store.close();
    store = CatalogStore.open('${root.path}/user.sqlite');
    renamer = Mp3Renamer(store);
    await renamer.recover();
    expect(renamer.report(run).single['status'], 'succeeded');
    expect(
      FileSystemEntity.identicalSync(
        File.fromUri(
          Uri.parse(
            store.database
                    .select('SELECT audio_ref FROM local_audio_links')
                    .single['audio_ref']
                as String,
          ),
        ).path,
        File('${root.path}/$system').path,
      ),
      isTrue,
    );
    expect(
      store.database
          .select('SELECT position_ms,is_favorite FROM user_episode_state')
          .single
          .values,
      [12345, 1],
    );
    await renamer.recover();
    expect(renamer.unresolved, isFalse);
  });

  test(
    'Interruption avec deux noms présents : aucune réparation incertaine',
    () async {
      final preview = await renamer.preview(root, recursive: false);
      final run = await renamer.execute(
        preview,
        move: (from, to) async {
          to.writeAsStringSync('fichier concurrent');
          throw StateError('collision au dernier instant');
        },
      );
      await renamer.recover();
      expect(renamer.report(run).single['status'], 'blocked');
      expect(renamer.unresolved, isTrue);
      expect(source.existsSync(), isTrue);
      expect(
        File('${root.path}/$system').readAsStringSync(),
        'fichier concurrent',
      );
      await expectLater(
        renamer.preview(root, recursive: false),
        throwsStateError,
      );
    },
  );

  test('Nom système invalide et association manuelle vers une autre piste préservés', () async {
    final other = File('${root.path}/autre.mp3')..writeAsStringSync('autre');
    store.recordManualLink(id, other.uri.toString(), 'autre.mp3');
    expect((await renamer.preview(root, recursive: false)).planned, 0);
    store.database.execute('DELETE FROM local_audio_links');
    final fields = jsonDecode(
      store.database.select('SELECT journal_json FROM episodes WHERE id=?', [
            id,
          ]).single['journal_json']
          as String,
    ) as Map;
    fields['TITRE SYSTEME'] = '../interdit.mp3';
    store.database.execute('UPDATE episodes SET journal_json=? WHERE id=?', [
      jsonEncode(fields),
      id,
    ]);
    expect((await renamer.preview(root, recursive: false)).planned, 0);
    expect(source.existsSync(), isTrue);
  });
  test('Lot interrompu : succès récupéré, éléments non tentés conservés puis nouvel aperçu', () async {
    final second = File('${root.path}/mr_x_1997_01_11.mp3')
      ..writeAsStringSync('autre audio');
    final plan = await renamer.preview(root, recursive: false);
    expect(plan.planned, 2);
    var moves = 0;
    final run = await renamer.execute(
      plan,
      move: (from, to) async {
        await testMove(from, to);
        moves++;
        throw StateError('interruption du lot');
      },
    );
    expect(moves, 1);
    await renamer.recover();
    expect(renamer.report(run).map((r) => r['status']), [
      'succeeded',
      'skipped',
    ]);
    expect(second.existsSync(), isTrue);
    final next = await renamer.preview(root, recursive: false);
    expect(next.planned, 1);
    final nextRun = await renamer.execute(next, move: testMove);
    expect(renamer.report(nextRun).single['status'], 'succeeded');
    expect(second.existsSync(), isFalse);
    expect((await renamer.preview(root, recursive: false)).planned, 0);
  });

  test('Nouveau doublon après aperçu : association recontrôlée avant toute tentative', () async {
    final plan = await renamer.preview(root, recursive: true);
    final nested = Directory('${root.path}/nouveau')..createSync();
    await source.copy('${nested.path}/$name');
    final run = await renamer.execute(
      plan,
      move: (_, _) async => fail('Association ambiguë'),
    );
    expect(renamer.report(run).single['status'], 'failed');
    expect(source.existsSync(), isTrue);
  });
  test('Migration réelle v5 vers le schéma courant : tous les champs du suivi et liens sont conservés', () async {
    store.recordManualLink(id, source.uri.toString(), name);
    store.database.execute(
      "INSERT INTO user_episode_state(episode_id,position_ms,duration_ms,listening_status,is_favorite,last_played_at,completed_at,playback_status) VALUES(?,45678,120000,'ECOUTE',1,'2026-10-30T12:00:00Z','2026-10-30T12:02:00Z','paused')",
      [id],
    );
    final before = Map<String, Object?>.from(
      store.database.select('SELECT * FROM user_episode_state').single,
    );
    final link = Map<String, Object?>.from(
      store.database.select('SELECT * FROM local_audio_links').single,
    );
    for (final trigger in store.database.select(
      "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'sync_%'",
    )) {
      store.database.execute('DROP TRIGGER ${trigger['name']}');
    }
    store.database.execute(
      'DROP TABLE sync_fields; DROP TABLE sync_imports; DROP TABLE sync_device;',
    );
    // Reconstitue exactement le schéma utilisateur v5, sans les deux tables du v6.
    store.database.execute(
      'DROP TABLE rename_items; DROP TABLE rename_runs; PRAGMA user_version=5;',
    );
    store.close();
    store = CatalogStore.open('${root.path}/user.sqlite');
    expect(
      store.database.select('PRAGMA user_version').single.values.single,
      7,
    );
    expect(
      Map<String, Object?>.from(
        store.database.select('SELECT * FROM user_episode_state').single,
      ),
      before,
    );
    expect(
      Map<String, Object?>.from(
        store.database.select('SELECT * FROM local_audio_links').single,
      ),
      link,
    );
    expect(store.database.select('SELECT * FROM rename_runs'), isEmpty);
  });
}
