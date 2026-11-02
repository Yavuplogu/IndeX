import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:index_core/index_desktop.dart';
import 'package:index_windows/app_model.dart';

import 'support/fake_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final interruptedAck in [false, true]) {
    test(
      'Android : copie complète reprise avant association et acquittement, coupure ack=$interruptedAck',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'index-publication-full-',
        );
        const tree = 'content://provider/tree/MP3',
            ref = 'content://provider/tree/MP3/document/episode.mp3';
        String? id, name, profile;
        var scans = 0,
            acknowledgements = 0,
            acknowledged = false,
            failAck = interruptedAck;
        late AppModel model;
        Future<Object?> port(String method, Map<String, Object?> args) async {
          if (method == 'scan') {
            scans++;
            return {
              'complete': true,
              'files': <Map<String, String>>[],
              'errors': <String>[],
            };
          }
          if (method == 'publicationState')
            return {
              'errors': <String>[],
              'pending': <Map<String, Object?>>[
                if (!acknowledged)
                  {
                    'id': 'job-complet',
                    'uri': ref,
                    'tree': tree,
                    'name': name!,
                    'episode_id': id!,
                    'profile_id': profile!,
                    'previous': '',
                    'excluded_before': <String>[],
                    'verified': true,
                  },
              ],
            };
          if (method == 'ackPublication') {
            acknowledgements++;
            expect(
              model.session!.store.database.select(
                'SELECT audio_ref FROM local_audio_links WHERE episode_id=?',
                [id],
              ).single['audio_ref'],
              ref,
              reason: 'La base est engagée avant d’effacer le journal natif.',
            );
            if (failAck) throw StateError('Interruption après commit SQLite');
            acknowledged = true;
            return null;
          }
          throw StateError(method);
        }

        model = AppModel(
          portableDirectory: root,
          audioPort: FakeAudio(),
          android: true,
          documentOperation: port,
        );
        try {
          await model.configure('${root.path}/user', tree, false);
          final episode = model.catalog.first;
          id = episode.id;
          name = episode.systemName!;
          profile = ListeningSync(model.session!.store).deviceId;
          model.favorite(episode);
          model.session!.checkpoint(
            id,
            positionMs: 12345,
            durationMs: 120000,
            progressed: true,
            completed: false,
            playbackStatus: 'paused',
          );
          model.setSkipStartupScan(true);
          model.session!.setSetting('android_publication_pending', 'true');
          await model.release();
          model.dispose();
          final before = scans;
          model = AppModel(
            portableDirectory: root,
            audioPort: FakeAudio(),
            android: true,
            documentOperation: port,
          );
          await model.boot();
          expect(model.needsSetup, isFalse);
          expect(scans, before);
          final state = model.catalog.singleWhere((e) => e.id == id);
          expect(state.favorite, isTrue);
          expect(state.positionMs, 12345);
          expect(state.audioRef, ref);
          expect(state.audioAvailable, !interruptedAck);
          if (interruptedAck) {
            failAck = false;
            await model.release();
            model.dispose();
            model = AppModel(
              portableDirectory: root,
              audioPort: FakeAudio(),
              android: true,
              documentOperation: port,
            );
            await model.boot();
            expect(
              model.catalog.singleWhere((e) => e.id == id).audioAvailable,
              isTrue,
            );
          }
          expect(acknowledged, isTrue);
          expect(acknowledgements, interruptedAck ? 2 : 1);
          expect(
            model.session!.setting('android_publication_pending'),
            'false',
          );
        } finally {
          await model.release();
          model.dispose();
          await root.delete(recursive: true);
        }
      },
    );
  }
  test('Android : un nouveau grant vers le même document conserve l’association manuelle', () async {
    final root = await Directory.systemTemp.createTemp('index-saf-grants-');
    const a = 'content://provider/tree/a', b = 'content://provider/tree/b';
    const refA = '$a/document/stable-id', refB = '$b/document/stable-id';
    final model = AppModel(
      portableDirectory: root,
      audioPort: FakeAudio(),
      android: true,
      documentOperation: (method, args) async {
        if (method == 'scan')
          return {
            'complete': true,
            'files': [
              {
                'reference': args['tree'] == a ? refA : refB,
                'name': 'mr_x_1997_01_04.mp3',
              },
            ],
            'errors': <String>[],
          };
        throw StateError(method);
      },
    );
    try {
      await model.configure('${root.path}/user', a, false);
      final episode = model.catalog.singleWhere(
        (e) => e.originalName == 'mr_x_1997_01_04.mp3',
      );
      model.session!.store.recordManualLink(
        episode.id,
        refA,
        episode.originalName,
      );
      model.favorite(episode);
      await model.scan(b);
      expect(model.error, isEmpty);
      final after = model.catalog.singleWhere((e) => e.id == episode.id);
      expect(after.audioRef, refB);
      expect(after.audioAvailable, isTrue);
      expect(after.favorite, isTrue);
    } finally {
      await model.release();
      model.dispose();
      await root.delete(recursive: true);
    }
  });
}
