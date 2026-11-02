import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app_model.dart';

import 'support/fake_audio.dart';

class LocalHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> publish(File part, File target) async {
    expect(await target.exists(), isFalse);
    await part.rename(target.path);
  }

  test('Android JSON : import Windows, retour, idempotence, sauvegarde et chemins locaux conservés', () async {
    final root = await Directory.systemTemp.createTemp('index-android-json-');
    late AppModel android;
    Uint8List? incoming;
    var denied = false;
    Future<Object?> documents(String method, Map<String, Object?> args) async {
      if (denied) throw const FileSystemException('Permission révoquée');
      if (method == 'publishPrivate') {
        await publish(
          File(args['partial'] as String),
          File(args['target'] as String),
        );
        return null;
      }
      if (method == 'readDocument') return incoming!;
      if (method == 'exportJson') return 'content://exports/IndeX_suivi.json';
      throw StateError(method);
    }

    final windows = AppModel(
      portableDirectory: Directory('${root.path}/windows')..createSync(),
      audioPort: FakeAudio(),
      syncPublisher: publish,
    );
    android = AppModel(
      portableDirectory: Directory('${root.path}/android')..createSync(),
      audioPort: FakeAudio(),
      android: true,
      documentOperation: documents,
    );
    try {
      await windows.configure('${root.path}/windows/user', '', true);
      await android.configure('${root.path}/android/user', '', true);
      final id = windows.catalog.first.id;
      windows.favorite(windows.catalog.first);
      windows.session!.checkpoint(
        id,
        positionMs: 30000,
        durationMs: 120000,
        progressed: true,
        completed: false,
        playbackStatus: 'paused',
      );
      final exported = await windows.exportListeningSync();
      expect(exported, isNotNull);
      incoming = await exported!.readAsBytes();
      // Une association locale Android ne doit jamais être remplacée par l’import.
      const local = 'content://documents/arbre/episode.mp3';
      android.session!.store.recordManualLink(id, local, 'local.mp3');
      await android.previewListeningSync('content://imports/Windows.json');
      expect(android.error, isEmpty);
      expect(android.syncPlan, isNotNull);
      final plan = android.syncPlan!;
      await android.applyListeningSync(plan, {});
      expect(android.error, isEmpty);
      expect(android.session!.listeningState(id)!['position_ms'], 30000);
      expect(android.catalog.singleWhere((e) => e.id == id).favorite, isTrue);
      expect(
        android.session!.store.database.select(
          'SELECT audio_ref FROM local_audio_links WHERE episode_id=?',
          [id],
        ).single['audio_ref'],
        local,
      );
      expect(
        File('${android.dataPath}/sauvegardes/IndeX_derniere_sauvegarde.sqlite')
            .existsSync(),
        isTrue,
      );
      await android.previewListeningSync('content://imports/Windows.json');
      expect(android.syncPlan!.alreadyImported, isTrue);
      final back = await android.exportListeningSync();
      expect(back, isNotNull);
      expect(
        await android.saveListeningSync(back!),
        'content://exports/IndeX_suivi.json',
      );
      await windows.previewListeningSync(back.path);
      expect(windows.syncPlan!.conflicts, isEmpty);
      await windows.applyListeningSync(windows.syncPlan!, {});
      expect(windows.error, isEmpty);
      denied = true;
      await android.previewListeningSync('content://imports/Windows.json');
      expect(android.syncPlan, isNull);
      expect(android.error, contains('Permission révoquée'));
      expect(android.session!.listeningState(id)!['position_ms'], 30000);
    } finally {
      await android.release();
      android.dispose();
      await windows.release();
      windows.dispose();
      await root.delete(recursive: true);
    }
  });
  test('Android JSON : entrée hostile rejetée sans fusion et lecteur actif protégé', () async {
    final root = await Directory.systemTemp.createTemp(
      'index-android-json-bad-',
    );
    var reads = 0;
    final model = AppModel(
      portableDirectory: root,
      audioPort: FakeAudio(),
      android: true,
      documentOperation: (method, args) async {
        reads++;
        return Uint8List.fromList(utf8.encode('{"schema_version":999}'));
      },
    );
    try {
      await model.configure('${root.path}/user', '', true);
      model.favorite(model.catalog.first);
      await model.previewListeningSync('content://imports/invalide.json');
      expect(model.syncPlan, isNull);
      expect(model.error, isNotEmpty);
      expect(model.catalog.first.favorite, isTrue);
      expect(
        model.session!.store.database.select('SELECT * FROM sync_imports'),
        isEmpty,
      );
      await model.playback.start(
        model.catalog.first.id,
        'content://audio/actif.mp3',
        0,
      );
      await model.previewListeningSync('content://imports/invalide.json');
      expect(reads, 1);
      expect(model.error, contains('libérez la piste'));
    } finally {
      await model.release();
      model.dispose();
      await root.delete(recursive: true);
    }
  });
  for (final scenario in ['success', 'permission', 'ownership']) {
    final fails = scenario != 'success';
    test(
      'Android téléchargement : publication SAF et association seulement après succès, scénario=$scenario',
      () async {
        await HttpOverrides.runWithHttpOverrides(() async {
          final root = await Directory.systemTemp.createTemp(
            'index-android-download-',
          );
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          final bytes = List<int>.filled(834, 0);
          for (final at in [0, 417])
            bytes.setRange(at, at + 4, [255, 251, 144, 0]);
          server.listen((r) {
            r.response.headers.contentType = ContentType('audio', 'mpeg');
            r.response.add(bytes);
            unawaited(r.response.close());
          });
          const tree = 'content://provider/tree/MP3',
              ref = 'content://provider/tree/MP3/document/episode.mp3';
          var published = false, copies = 0;
          String? system;
          late AppModel model;
          String? otherId;
          model = AppModel(
            portableDirectory: root,
            audioPort: FakeAudio(),
            android: true,
            downloadSourcePolicy: (_) => true,
            documentOperation: (method, args) async {
              if (method == 'checkDestination' || method == 'ackPublication')
                return null;
              if (method == 'publicationState')
                return {
                  'pending': <Map<String, Object?>>[],
                  'errors': <String>[],
                };
              if (method == 'scan')
                return {
                  'complete': true,
                  'errors': <String>[],
                  'files': <Map<String, String>>[
                    if (published) {'name': system!, 'reference': ref},
                  ],
                };
              if (method == 'publishPrivate') {
                await publish(
                  File(args['partial'] as String),
                  File(args['target'] as String),
                );
                return null;
              }
              if (method == 'publishDocument') {
                copies++;
                expect(
                  await File(args['source'] as String).readAsBytes(),
                  bytes,
                );
                expect(args['tree'], tree);
                expect(args['name'], system);
                if (scenario == 'permission')
                  throw StateError('Permission ou collision SAF');
                if (scenario == 'ownership') {
                  expect(
                    model.session!.store.database.select(
                      'SELECT available FROM local_audio_links WHERE episode_id=?',
                      [otherId],
                    ).single['available'],
                    0,
                    reason: 'La référence périmée ne peut pas lire une copie en cours.',
                  );
                }
                published = true;
                return {'reference': ref, 'id': 'publication-test'};
              }
              throw StateError(method);
            },
          );
          try {
            await model.configure('${root.path}/user', tree, false);
            final episode = model.catalog.first;
            system = episode.systemName;
            final journal = jsonDecode(
              model.session!.store.database.select(
                    'SELECT journal_json FROM episodes WHERE id=?',
                    [episode.id],
                  ).single['journal_json']
                  as String,
            ) as Map;
            journal['URL MP3'] = 'http://127.0.0.1:${server.port}/episode.mp3';
            model.session!.store.database.execute(
              'UPDATE episodes SET journal_json=? WHERE id=?',
              [jsonEncode(journal), episode.id],
            );
            model.reload();
            if (scenario == 'ownership') {
              final other = model.catalog.firstWhere((e) => e.id != episode.id);
              otherId = other.id;
              model.session!.store.recordManualLink(other.id, ref, system!);
              model.session!.checkpoint(
                other.id,
                positionMs: 54321,
                durationMs: 120000,
                progressed: true,
                completed: false,
                playbackStatus: 'paused',
              );
              model.reload();
            }
            model.favorite(model.catalog.first);
            expect(
              model.catalog.singleWhere((e) => e.id == episode.id).favorite,
              isTrue,
            );
            await model.downloadEpisode(
              model.catalog.singleWhere((e) => e.id == episode.id),
              tree,
            );
            expect(copies, 1);
            expect(model.downloading, isFalse);
            final updated = model.catalog.singleWhere(
              (e) => e.id == episode.id,
            );
            expect(
              updated.favorite,
              isTrue,
              reason:
                  'Erreur modèle : ${model.error} ; ${model.session!.listeningState(episode.id)}',
            );
            expect(updated.audioAvailable, !fails, reason: model.error);
            if (scenario == 'permission') {
              expect(model.error, contains('Permission ou collision'));
              expect(
                model.session!.store.database.select(
                  'SELECT * FROM local_audio_links',
                ),
                isEmpty,
              );
            } else if (scenario == 'ownership') {
              expect(model.error, contains('autre épisode'));
              final owner = model.session!.store.database.select(
                'SELECT episode_id,available FROM local_audio_links WHERE audio_ref=?',
                [ref],
              ).single;
              expect(owner['episode_id'], otherId);
              expect(owner['available'], 0);
              expect(
                model.session!.listeningState(otherId!)!['position_ms'],
                54321,
              );
            } else {
              expect(model.error, isEmpty);
              expect(updated.audioRef, ref);
            }
            expect(
              Directory(model.dataPath)
                  .listSync()
                  .whereType<Directory>()
                  .where((d) => d.path.contains('.index-android-download-')),
              isEmpty,
            );
          } finally {
            await model.release();
            model.dispose();
            await server.close(force: true);
            await root.delete(recursive: true);
          }
        }, LocalHttp());
      },
    );
  }
  for (final mode in ['reference', 'nom', 'illisible']) {
    test(
      'Android : publication interrompue au démarrage sans scan, mode=$mode',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'index-publication-recovery-',
        );
        const tree = 'content://provider/tree/MP3',
            ref = 'content://provider/tree/MP3/document/episode.mp3';
        var pending = false, scans = 0;
        String? name;
        Future<Object?> port(String method, Map<String, Object?> args) async {
          if (method == 'scan') {
            scans++;
            return {
              'complete': true,
              'errors': <String>[],
              'files': <Map<String, String>>[
                {'reference': ref, 'name': name ?? 'mr_x_1997_01_04.mp3'},
              ],
            };
          }
          if (method == 'publicationState') {
            if (mode == 'illisible')
              throw const FileSystemException('Journal inaccessible');
            return {
              'pending': [
                if (pending)
                  {
                    'uri': mode == 'nom' ? '' : ref,
                    'name': name!,
                    'tree': tree,
                  },
              ],
              'errors': [if (pending) 'Publication à vérifier'],
            };
          }
          throw StateError(method);
        }

        var model = AppModel(
          portableDirectory: root,
          audioPort: FakeAudio(),
          android: true,
          documentOperation: port,
        );
        try {
          await model.configure('${root.path}/user', tree, false);
          final episode = model.catalog.singleWhere(
            (e) => e.originalName == 'mr_x_1997_01_04.mp3',
          );
          name = episode.originalName;
          model.favorite(episode);
          model.session!.checkpoint(
            episode.id,
            positionMs: 12345,
            durationMs: 120000,
            progressed: true,
            completed: false,
            playbackStatus: 'paused',
          );
          model.session!.setSetting('android_publication_pending', 'true');
          model.setSkipStartupScan(true);
          await model.release();
          model.dispose();
          pending = true;
          final scansBefore = scans;
          model = AppModel(
            portableDirectory: root,
            audioPort: FakeAudio(),
            android: true,
            documentOperation: port,
          );
          await model.boot();
          expect(model.needsSetup, isFalse);
          expect(scans, scansBefore);
          final updated = model.catalog.singleWhere((e) => e.id == episode.id);
          expect(updated.favorite, isTrue);
          expect(updated.positionMs, 12345);
          expect(updated.audioAvailable, isFalse);
          expect(model.error, isNotEmpty);
          expect(model.audioState, AudioFolderState.incomplete);
        } finally {
          await model.release();
          model.dispose();
          await root.delete(recursive: true);
        }
      },
    );
  }
}
