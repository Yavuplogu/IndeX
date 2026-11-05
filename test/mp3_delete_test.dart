import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:index_core/index_storage.dart';
import 'package:index_core/index_desktop.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late CatalogStore store;
  late HeardAudioDeletion deletion;
  late List<String> episodeIds;
  late Map<String, File> files;
  late Map<String, String> identities;
  late Set<String> denied;
  late List<String> removed;
  String? loaded;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('index-audio-delete-');
    store = CatalogStore.open('${root.path}/user.sqlite')
      ..importReference('assets/catalogue.sqlite');
    episodeIds = store.database
        .select('SELECT id FROM episodes LIMIT 4')
        .map((r) => r['id'] as String)
        .toList();
    files = {};
    identities = {};
    denied = {};
    removed = [];
    loaded = null;
    deletion = HeardAudioDeletion(
      store,
      inspect: (scope, ref) async {
        final f = files[ref];
        if (f == null || !f.existsSync())
          return {
            'exists': false,
            'eligible': false,
            'identity': ref,
            'signature': 'missing',
          };
        return {
          'exists': true,
          'eligible': !denied.contains(ref),
          'identity': identities[ref] ?? ref,
          'signature': sha256.convert(f.readAsBytesSync()).toString(),
          'name': f.uri.pathSegments.last,
          'reason': 'Fournisseur sans droit de suppression ou hors périmètre.',
        };
      },
      remove: (scope, ref, signature) async {
        // Vérifier qu’un journal durable et l’indisponibilité précèdent l’effacement.
        final row = store.database.select(
          'SELECT available FROM local_audio_links WHERE audio_ref=?',
          [ref],
        ).single;
        expect(row['available'], 0);
        final journal = jsonDecode(
          store.database.select(
                'SELECT value FROM local_settings WHERE key=?',
                [HeardAudioDeletion.journalKey],
              ).single['value']
              as String,
        ) as Map;
        expect(
          (journal['entries'] as List).any(
            (e) => e['reference'] == ref && e['status'] == 'deleting',
          ),
          isTrue,
        );
        if (denied.contains('execute') || denied.contains('execute:$ref'))
          throw const FileSystemException('Permission retirée');
        await files[ref]!.delete();
        removed.add(ref);
      },
    );
  });
  tearDown(() async {
    store.close();
    await root.delete(recursive: true);
  });
  String link(int at, {String status = 'ECOUTE', String? reference}) {
    final file = File('${root.path}/episode-$at.mp3')
      ..writeAsStringSync('audio-$at');
    final ref = reference ?? file.uri.toString();
    files[ref] = file;
    store.database.execute(
      "INSERT INTO local_audio_links(episode_id,audio_ref,current_name,method,matching_status,local_verification_status,evidence_json,manual,available,updated_at) VALUES(?,?,?,'manual','confirmed','verified','{}',1,1,'2026-11-05')",
      [episodeIds[at], ref, file.uri.pathSegments.last],
    );
    store.database.execute(
      "INSERT INTO user_episode_state(episode_id,position_ms,duration_ms,listening_status,is_favorite) VALUES(?,42000,80000,?,1)",
      [episodeIds[at], status],
    );
    return ref;
  }

  List<Map<String, Object?>> state() => [
    for (final r in store.database.select(
      'SELECT * FROM user_episode_state ORDER BY episode_id',
    ))
      Map<String, Object?>.from(r),
  ];
  Future<void> execute(AudioDeletionPlan plan) =>
      deletion.execute(plan, currentScope: root.path, inUse: () => loaded);

  test('Aperçu sans effet ; suppression des seuls écoutés, journal préalable et suivi intégral conservé', () async {
    final heard = link(0);
    final unheard = link(1, status: 'NON_ECOUTE');
    final progress = link(2, status: 'EN_COURS');
    final before = state();
    final plan = await deletion.preview(root.path);
    expect(plan.planned, 1);
    expect(removed, isEmpty);
    expect(state(), before);
    await execute(plan);
    expect(files[heard]!.existsSync(), isFalse);
    expect(files[unheard]!.existsSync(), isTrue);
    expect(files[progress]!.existsSync(), isTrue);
    expect(state(), before);
    expect(plan.entries.single.status, 'deleted');
    expect(
      store.database.select(
        'SELECT audio_ref,available FROM local_audio_links WHERE episode_id=?',
        [episodeIds[0]],
      ).single['available'],
      0,
    );
    await expectLater(execute(plan), throwsStateError);
  });
  test('Piste chargée exclue, y compris un alias physique et un grant SAF différent', () async {
    final ref = link(
      0,
      reference: 'content://local/tree/root/document/root%3Ae.mp3',
    );
    loaded = 'content://local/tree/other/document/root%3Ae.mp3';
    files[loaded!] = files[ref]!;
    identities[loaded!] = 'same';
    identities[ref] = 'same';
    final plan = await deletion.preview(root.path, inUse: loaded);
    expect(plan.planned, 0);
    expect(plan.entries.single.status, 'excluded');
    expect(removed, isEmpty);
  });
  test('État devenu non écouté, nouvelle piste chargée ou fichier remplacé : aucun effacement', () async {
    final ref = link(0);
    var plan = await deletion.preview(root.path);
    store.database.execute(
      "UPDATE user_episode_state SET listening_status='NON_ECOUTE'",
    );
    await execute(plan);
    expect(removed, isEmpty);
    store.database.execute(
      "UPDATE user_episode_state SET listening_status='ECOUTE'",
    );
    plan = await deletion.preview(root.path);
    loaded = ref;
    await execute(plan);
    expect(removed, isEmpty);
    loaded = null;
    plan = await deletion.preview(root.path);
    files[ref]!.writeAsStringSync('autre contenu');
    await execute(plan);
    expect(removed, isEmpty);
    expect(files[ref]!.existsSync(), isTrue);
  });
  test(
    'Alias de deux épisodes et dossier non autorisé exclus avant confirmation',
    () async {
      final a = link(0);
      final b = link(1, status: 'NON_ECOUTE');
      identities[a] = 'shared';
      identities[b] = 'shared';
      final c = link(2);
      denied.add(c);
      final plan = await deletion.preview(root.path);
      expect(plan.planned, 0);
      expect(plan.entries.every((e) => e.status == 'excluded'), isTrue);
    },
  );
  test(
    'Association modifiée et alias ajouté après aperçu sont refusés',
    () async {
      final a = link(0);
      var plan = await deletion.preview(root.path);
      store.database.execute(
        "UPDATE local_audio_links SET matching_status='unknown' WHERE episode_id=?",
        [episodeIds[0]],
      );
      await execute(plan);
      expect(removed, isEmpty);
      store.database.execute(
        "UPDATE local_audio_links SET matching_status='confirmed' WHERE episode_id=?",
        [episodeIds[0]],
      );
      plan = await deletion.preview(root.path);
      final b = link(1, status: 'EN_COURS');
      identities[a] = a;
      identities[b] = a;
      await execute(plan);
      expect(removed, isEmpty);
    },
  );
  test('Permission perdue : échec détaillé, disponibilité restaurée et suivi intact', () async {
    final ref = link(0);
    final before = state();
    final plan = await deletion.preview(root.path);
    denied.add('execute');
    await execute(plan);
    expect(plan.entries.single.status, 'failed');
    expect(files[ref]!.existsSync(), isTrue);
    expect(state(), before);
    expect(
      store.database
          .select('SELECT available FROM local_audio_links')
          .single['available'],
      1,
    );
  });
  test('Dossier ou profil changé invalide le plan, sans opération', () async {
    link(0);
    final plan = await deletion.preview(root.path);
    await expectLater(
      deletion.execute(plan, currentScope: 'autre dossier', inUse: () => null),
      throwsStateError,
    );
    expect(removed, isEmpty);
    expect(plan.used, isFalse);
  });
  test(
    'Fichier absent conservé comme diagnostic, aucune suppression proposée',
    () async {
      final ref = link(0);
      await files[ref]!.delete();
      final plan = await deletion.preview(root.path);
      expect(plan.planned, 0);
      expect(plan.entries.single.status, 'missing');
      expect(state().single['is_favorite'], 1);
    },
  );
  test('Échec partiel : les autres suppressions réussissent, tous les suivis restent intacts', () async {
    final a = link(0);
    final b = link(1);
    final before = state();
    final plan = await deletion.preview(root.path);
    denied.add('execute:$b');
    await execute(plan);
    expect(files[a]!.existsSync(), isFalse);
    expect(files[b]!.existsSync(), isTrue);
    expect(plan.entries.map((e) => e.status).toSet(), {'deleted', 'failed'});
    expect(state(), before);
  });
  test('Interruption après effacement : intention durable, suivi conservé et aucune reprise automatique', () async {
    final ref = link(0);
    final before = state();
    final plan = await deletion.preview(root.path);
    final interrupted = HeardAudioDeletion(
      store,
      inspect: deletion.inspect,
      remove: (scope, reference, signature) async {
        await files[reference]!.delete();
        store.close();
        throw StateError('Processus interrompu');
      },
    );
    await expectLater(
      interrupted.execute(plan, currentScope: root.path, inUse: () => null),
      throwsA(anything),
    );
    store = CatalogStore.open('${root.path}/user.sqlite');
    expect(files[ref]!.existsSync(), isFalse);
    expect(state(), before);
    final journal = jsonDecode(
      store.database.select('SELECT value FROM local_settings WHERE key=?', [
            HeardAudioDeletion.journalKey,
          ]).single['value']
          as String,
    ) as Map;
    expect((journal['entries'] as List).single['status'], 'deleting');
    expect(
      store.database
          .select('SELECT available FROM local_audio_links')
          .single['available'],
      0,
    );
    expect(removed, isEmpty);
  });
}
