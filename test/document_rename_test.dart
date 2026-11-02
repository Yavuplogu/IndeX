import 'dart:io';

import 'package:index_core/index_desktop.dart';
import 'package:index_core/index_storage.dart';
import 'package:test/test.dart';

String reference(String name) => Uri(
  scheme: 'content',
  host: 'fr.index.index_windows.documents',
  pathSegments: ['tree', 'mp3:', 'document', 'mp3:$name'],
).toString();

void main() {
  late Directory root;
  late CatalogStore store;
  late DocumentMp3Renamer renamer;
  late String id, original, system, before, after;
  late Map<String, Map<String, Object?>> documents;
  var supported = true, failAfterMove = false, moves = 0;
  const tree = 'content://fr.index.index_windows.documents/tree/mp3%3A';
  Future<Object?> call(String method, Map<String, Object?> args) async {
    final ref = args['reference'] as String?;
    switch (method) {
      case 'scan':
        return {
          'complete': true,
          'files': [
            for (final entry in documents.entries)
              {'reference': entry.key, 'name': entry.value['name']},
          ],
        };
      case 'renameInfo':
        return supported
            ? {
                'supported': true,
                'after': reference(args['name'] as String),
                'collision': documents.containsKey(
                  reference(args['name'] as String),
                ),
                ...documents[ref]!,
              }
            : {
                'supported': false,
                'reason': 'Fournisseur sans garantie de non-écrasement.',
              };
      case 'fingerprint':
        return documents[ref] == null ? null : {...documents[ref]!};
      case 'renameDocument':
        expect(
          store.database.select(
            "SELECT status FROM rename_items WHERE before_ref=?",
            [ref],
          ).single['status'],
          anyOf('moving', 'blocked'),
          reason: 'Journal durable avant la mutation.',
        );
        moves++;
        final target = reference(args['name'] as String),
            source = documents[ref]!;
        if (documents[target] != null &&
            documents[target]!['identity'] != source['identity'])
          throw StateError('Cible existante.');
        expect(source['digest'], args['digest']);
        documents[target] = {...source, 'name': args['name']};
        documents.remove(ref);
        if (failAfterMove) throw StateError('Interruption après mutation.');
        return target;
      default:
        throw StateError(method);
    }
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('index-document-rename-');
    store = CatalogStore.open('${root.path}/user.sqlite');
    store.importReference('assets/catalogue.sqlite');
    final row = store.database
        .select(
          "SELECT * FROM episodes WHERE original_name='mr_x_1997_01_04.mp3'",
        )
        .single;
    id = row['id'] as String;
    original = row['original_name'] as String;
    system = row['system_name'] as String;
    before = reference(original);
    after = reference(system);
    documents = {
      before: {
        'name': original,
        'bytes': 42,
        'modified': '1234',
        'digest': 'a' * 64,
        'identity': '12:34',
      },
    };
    supported = true;
    failAfterMove = false;
    moves = 0;
    renamer = DocumentMp3Renamer(store, call);
    store.recordManualLink(id, before, original);
    store.database.execute(
      "INSERT INTO user_episode_state(episode_id,position_ms,listening_status,is_favorite) VALUES(?,42000,'EN_COURS',1)",
      [id],
    );
  });
  tearDown(() async {
    store.close();
    await root.delete(recursive: true);
  });
  void preserved() {
    final state = store.database.select(
      'SELECT * FROM user_episode_state WHERE episode_id=?',
      [id],
    ).single;
    expect(state['position_ms'], 42000);
    expect(state['listening_status'], 'EN_COURS');
    expect(state['is_favorite'], 1);
  }

  test('Identité SAF opaque conservée entre grants, même pour un documentId littéral document', () {
    expect(
      documentReferenceKey('content://f/tree/a/document/document'),
      documentReferenceKey('content://f/tree/b/document/document'),
    );
    expect(
      documentReferenceKey('content://f/document/a%2Fb'),
      documentReferenceKey('content://f/tree/x/document/a%2Fb'),
    );
    expect(
      documentReferenceKey('content://autre/document/a%2Fb'),
      isNot(documentReferenceKey('content://f/document/a%2Fb')),
    );
  });
  test('SAF : réassociation explicite sous un autre grant lève le retrait du même document', () async {
    final alias = Uri.parse(before)
        .replace(
          pathSegments: [
            'tree',
            'autre',
            'document',
            Uri.parse(before).pathSegments.last,
          ],
        )
        .toString();
    store.unlinkAudio(before);
    store.recordManualLink(id, alias, original);
    expect(store.unlinkedAudioReferences, isEmpty);
    final plan = await renamer.preview(tree, recursive: false);
    expect(plan.planned, 1);
    final inUse = await renamer.preview(tree, recursive: false, inUse: alias);
    expect(inUse.planned, 0);
    final other =
        store.database.select('SELECT id FROM episodes WHERE id<>? LIMIT 1', [
              id,
            ]).single['id']
            as String;
    expect(
      () => store.recordManualLink(other, before, original),
      throwsStateError,
    );
  });
  test('SAF : même journal, référence opaque actualisée, favori et reprise préservés', () async {
    final plan = await renamer.preview(tree, recursive: true);
    expect(plan.planned, 1);
    final run = await renamer.execute(plan);
    expect(renamer.report(run).single['status'], 'succeeded');
    expect(moves, 1);
    final link = store.database.select(
      'SELECT * FROM local_audio_links WHERE episode_id=?',
      [id],
    ).single;
    expect(link['audio_ref'], after);
    expect(link['current_name'], system);
    expect(link['manual'], 1);
    preserved();
    final second = await renamer.preview(tree, recursive: true);
    expect(second.planned, 0);
    expect(second.entries.single.status, 'unchanged');
  });
  test('SAF : choix manuel vers un autre épisode prioritaire sur le nom du fichier', () async {
    final other =
        store.database.select('SELECT id FROM episodes WHERE id<>? LIMIT 1', [
              id,
            ]).single['id']
            as String;
    store.unlinkAudio(before);
    store.recordManualLink(other, before, original);
    final plan = await renamer.preview(tree, recursive: false);
    expect(plan.planned, 0);
    expect(plan.entries.single.status, 'ignored');
    expect(moves, 0);
    expect(
      store.database.select(
        'SELECT episode_id FROM local_audio_links WHERE audio_ref=?',
        [before],
      ).single['episode_id'],
      other,
    );
  });
  test('SAF : fournisseur non sûr refusé, aucune tentative', () async {
    supported = false;
    final plan = await renamer.preview(tree, recursive: false);
    expect(plan.planned, 0);
    expect(plan.entries.single.reason, contains('sans garantie'));
    expect(moves, 0);
    preserved();
  });
  test('SAF : collision apparue après aperçu, cible conservée', () async {
    final plan = await renamer.preview(tree, recursive: false);
    documents[after] = {
      ...documents[before]!,
      'name': system,
      'identity': 'autre',
      'digest': 'b' * 64,
    };
    final run = await renamer.execute(plan);
    expect(renamer.report(run).single['status'], 'failed');
    expect(moves, 0);
    expect(documents[after]!['digest'], 'b' * 64);
    expect(documents.containsKey(before), isTrue);
    preserved();
  });
  test('SAF : source modifiée après aperçu refusée', () async {
    final plan = await renamer.preview(tree, recursive: false);
    documents[before]!['digest'] = 'b' * 64;
    final run = await renamer.execute(plan);
    expect(renamer.report(run).single['status'], 'failed');
    expect(moves, 0);
    preserved();
  });
  test('SAF : lecteur actif refusé dans aperçu et avant exécution', () async {
    final blocked = await renamer.preview(
      tree,
      recursive: false,
      inUse: before,
    );
    expect(blocked.planned, 0);
    final plan = await renamer.preview(tree, recursive: false);
    final run = await renamer.execute(plan, inUse: () => before);
    expect(renamer.report(run).single['status'], 'failed');
    expect(moves, 0);
  });
  test(
    'SAF : interruption après déplacement, récupération et suivi intact',
    () async {
      final plan = await renamer.preview(tree, recursive: false);
      failAfterMove = true;
      final run = await renamer.execute(plan);
      expect(renamer.unresolved, isTrue);
      await Mp3Renamer(store).recover();
      expect(
        renamer.report(run).single['status'],
        'moving',
        reason: 'Le récupérateur Windows ignore content://.',
      );
      await renamer.recover();
      expect(renamer.report(run).single['status'], 'succeeded');
      expect(renamer.unresolved, isFalse);
      preserved();
    },
  );
  for (final withdrawn in [false, true]) {
    test(
      'SAF : choix manuel modifié après interruption, retrait=$withdrawn',
      () async {
        final plan = await renamer.preview(tree, recursive: false);
        failAfterMove = true;
        final run = await renamer.execute(plan);
        if (withdrawn) {
          store.unlinkAudio(before);
        } else {
          store.recordManualLink(id, 'content://autre/document', 'autre.mp3');
        }
        await renamer.recover();
        expect(renamer.report(run).single['status'], 'blocked');
        final links = store.database.select(
          'SELECT audio_ref FROM local_audio_links WHERE episode_id=?',
          [id],
        );
        if (withdrawn) {
          expect(links, isEmpty);
          expect(
            store.database.select(
              'SELECT * FROM user_episode_state WHERE episode_id=?',
              [id],
            ),
            isEmpty,
          );
        } else {
          expect(links.single['audio_ref'], 'content://autre/document');
          preserved();
        }
      },
    );
  }
  for (final identical in [true, false]) {
    test(
      'SAF : interruption entre lien et retrait ; même inode=$identical',
      () async {
        final plan = await renamer.preview(tree, recursive: false);
        failAfterMove = true;
        final copy = {...documents[before]!};
        final run = await renamer.execute(plan);
        documents[before] = {
          ...copy,
          'identity': identical ? '12:34' : 'autre',
        };
        failAfterMove = false;
        moves = 0;
        await renamer.recover();
        expect(
          renamer.report(run).single['status'],
          identical ? 'succeeded' : 'blocked',
        );
        expect(moves, identical ? 1 : 0);
        expect(documents.containsKey(before), !identical);
        preserved();
      },
    );
  }
}
