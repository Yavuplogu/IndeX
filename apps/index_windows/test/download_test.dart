import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';

import 'support/fake_audio.dart';
import 'support/app_harness.dart';

class RealHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Fiche : Télécharger, progression, annulation et Écouter après réception',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await HttpOverrides.runWithHttpOverrides(() async {
        final root = Directory.systemTemp.createTempSync('index-download-ui-');
        final folder = Directory('${root.path}/MP3')..createSync();
        final first = Completer<void>();
        final server = await tester.runAsync(
          () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
        );
        final bytes = List<int>.filled(834, 0);
        for (final at in [0, 417])
          bytes.setRange(at, at + 4, [255, 251, 144, 0]);
        var requests = 0;
        server!.listen((request) {
          unawaited(
            () async {
              final number = ++requests;
              request.response.bufferOutput = false;
              request.response.headers.contentType = ContentType(
                'audio',
                'mpeg',
              );
              request.response.add(bytes.sublist(0, 417));
              await request.response.flush();
              if (number == 1) await first.future;
              request.response.add(bytes.sublist(417));
              await request.response.close();
            }().catchError((Object _) {}),
          );
        });
        final model = AppModel(
          portableDirectory: root,
          audioPort: FakeAudio(),
          downloadPublisher: (part, target) async => part.rename(target.path),
        );
        try {
          await tester.runAsync(
            () => model.configure('${root.path}/user', '', true),
          );
          final id = model.selected!.id;
          final row = model.session!.store.database.select(
            'SELECT journal_json FROM episodes WHERE id=?',
            [id],
          ).single;
          final journal = jsonDecode(row['journal_json'] as String) as Map;
          journal['URL MP3'] = 'http://127.0.0.1:${server.port}/episode.mp3';
          model.session!.store.database.execute(
            'UPDATE episodes SET journal_json=? WHERE id=?',
            [jsonEncode(journal), id],
          );
          model.reload();
          await tester.pumpWidget(
            IndeXApp(
              model: model,
              window: FakeWindow(),
              pickDirectory: () async => folder.path,
            ),
          );
          await tester.pumpAndSettle();
          expect(requests, 0);
          await tester.tap(find.byKey(const ValueKey('download-episode')));
          await waitForCondition(
            tester,
            () => model.downloadReceived > 0,
            'réception démarrée',
          );
          await tester.pump();
          expect(
            find.byKey(const ValueKey('download-progress')),
            findsOneWidget,
          );
          await tester.tap(find.text('Annuler le téléchargement'));
          await waitForCondition(
            tester,
            () => !model.downloading,
            'annulation',
          );
          await tester.pumpAndSettle();
          expect(folder.listSync(), isEmpty);
          await tester.tap(find.byKey(const ValueKey('download-episode')));
          await waitForCondition(
            tester,
            () => !model.downloading && model.selected!.audioAvailable,
            'MP3 associé',
          );
          await tester.pumpAndSettle();
          expect(find.text('Écouter'), findsOneWidget);
          expect(find.byKey(const ValueKey('download-progress')), findsNothing);
          expect(requests, 2);
          expect(model.playback.episodeId, isNull);
          expect(tester.takeException(), isNull);
        } finally {
          if (!first.isCompleted) first.complete();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(() async {
            await model.release();
            await server.close(force: true);
          });
          model.dispose();
          root.deleteSync(recursive: true);
        }
      }, RealHttp());
    },
  );
  test('Téléchargement explicite depuis le journal, association immédiate et suivi conservé', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final root = Directory.systemTemp.createTempSync('index-download-model-');
      final folder = Directory('${root.path}/MP3')..createSync();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final bytes = List<int>.filled(834, 0);
      for (final offset in [0, 417])
        bytes.setRange(offset, offset + 4, [255, 251, 144, 0]);
      var requests = 0;
      server.listen((r) {
        requests++;
        r.response.headers.contentType = ContentType('audio', 'mpeg');
        r.response.add(bytes);
        unawaited(r.response.close());
      });
      final model = AppModel(
        portableDirectory: root,
        audioPort: FakeAudio(),
        downloadPublisher: (part, target) async {
          expect(await target.exists(), isFalse);
          await part.rename(target.path);
        },
      );
      try {
        await model.configure('${root.path}/user', folder.path, false);
        final episode = model.catalog.first;
        final row = model.session!.store.database.select(
          'SELECT journal_json FROM episodes WHERE id=?',
          [episode.id],
        ).single;
        final journal = jsonDecode(row['journal_json'] as String) as Map;
        final url = 'http://127.0.0.1:${server.port}/episode.mp3';
        journal['URL MP3'] = url;
        model.session!.store.database.execute(
          'UPDATE episodes SET journal_json=? WHERE id=?',
          [jsonEncode(journal), episode.id],
        );
        model.favorite(episode);
        model.session!.checkpoint(
          episode.id,
          positionMs: 12000,
          durationMs: 120000,
          progressed: true,
          completed: false,
          playbackStatus: 'paused',
        );
        model.reload();
        final latest = model.catalog.firstWhere((e) => e.id == episode.id);
        expect(
          latest.downloadUrl,
          url,
        ); // La colonne TXT mp3_url n'a pas changé.
        expect(requests, 0);
        await model.downloadEpisode(latest, folder.path);
        expect(model.error, isEmpty);
        expect(requests, 1);
        expect(model.downloading, isFalse);
        final downloaded = model.catalog.firstWhere((e) => e.id == episode.id);
        expect(downloaded.audioAvailable, isTrue);
        final expectedName =
            model.session!.store.database.select(
                  'SELECT system_name FROM episodes WHERE id=?',
                  [episode.id],
                ).single['system_name']
                as String;
        expect(downloaded.systemName, expectedName);
        expect(
          File.fromUri(Uri.parse(downloaded.audioRef!)).uri.pathSegments.last,
          expectedName,
        );
        expect(
          File('${folder.path}/${episode.originalName}').existsSync(),
          isFalse,
        );
        expect(
          File.fromUri(Uri.parse(downloaded.audioRef!)).readAsBytesSync(),
          bytes,
        );
        expect(downloaded.favorite, isTrue);
        expect(downloaded.positionMs, 12000);
        expect(downloaded.status, 'EN_COURS');
        expect(folder.listSync().whereType<File>(), hasLength(1));
        // Une cible système déjà présente ne doit jamais être écrasée,
        // même si le lien n'est plus disponible dans le modèle.
        model.session!.store.database.execute(
          'UPDATE local_audio_links SET available=0 WHERE episode_id=?',
          [episode.id],
        );
        model.reload();
        await model.downloadEpisode(
          model.catalog.firstWhere((e) => e.id == episode.id),
          folder.path,
        );
        expect(model.error, contains('Téléchargement impossible'));
        expect(requests, 1);
        expect(
          File.fromUri(Uri.parse(downloaded.audioRef!)).readAsBytesSync(),
          bytes,
        );
      } finally {
        await model.release();
        model.dispose();
        await server.close(force: true);
        root.deleteSync(recursive: true);
      }
    }, RealHttp());
  });

  test('Fermeture immédiate et erreur URL : aucun blocage ni téléchargement tardif', () async {
    final root = Directory.systemTemp.createTempSync('index-download-close-');
    final folder = Directory('${root.path}/MP3')..createSync();
    final model = AppModel(
      portableDirectory: root,
      audioPort: FakeAudio(),
      downloadPublisher: (_, _) async => fail('Aucune publication attendue'),
    );
    try {
      await model.configure('${root.path}/user', folder.path, false);
      final episode = model.catalog.first;
      final row = model.session!.store.database.select(
        'SELECT journal_json FROM episodes WHERE id=?',
        [episode.id],
      ).single;
      final journal = jsonDecode(row['journal_json'] as String) as Map;
      journal['URL MP3'] = 'file:///interdit.mp3';
      model.session!.store.database.execute(
        'UPDATE episodes SET journal_json=? WHERE id=?',
        [jsonEncode(journal), episode.id],
      );
      model.reload();
      await model.downloadEpisode(model.catalog.first, folder.path);
      expect(model.error, contains('URL MP3 valide'));
      expect(model.downloading, isFalse);
      journal['URL MP3'] = 'http://127.0.0.1:1/audio.mp3';
      model.session!.store.database.execute(
        'UPDATE episodes SET journal_json=? WHERE id=?',
        [jsonEncode(journal), episode.id],
      );
      model.reload();
      final job = model.downloadEpisode(model.catalog.first, folder.path);
      await model.closeSafely();
      await job;
      expect(model.session, isNull);
      expect(model.downloading, isFalse);
      expect(folder.listSync(), isEmpty);
    } finally {
      await model.release();
      model.dispose();
      root.deleteSync(recursive: true);
    }
  });
}
