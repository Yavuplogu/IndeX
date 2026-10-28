import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';
import 'package:index_windows/just_audio_port.dart';
import 'package:index_windows/window_port.dart';
import 'package:window_manager/window_manager.dart';

final class TestWindow implements WindowPort {
  @override
  Future<void> destroy() async {}
  @override
  Future<void> minimize() async {}
  @override
  Future<void> maximizeOrRestore() async {}
}

final class CloseProbe with WindowListener {
  final closed = Completer<void>();
  @override
  void onWindowClose() {
    if (!closed.isCompleted) closed.complete();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows natif : seed, FTS5, écriture/reprise, scan et interception fermeture',
    (tester) async {
      expect(Platform.isWindows, isTrue);
      await windowManager.ensureInitialized();
      await windowManager.waitUntilReadyToShow(
        const WindowOptions(
          title: 'IndeX — recette native',
          size: Size(1280, 900),
        ),
      );
      await windowManager.show();
      await windowManager.setPreventClose(true);
      final probe = CloseProbe();
      windowManager.addListener(probe);
      final root = Directory.systemTemp.createTempSync('index-windows-smoke-');
      final portable = Directory('${root.path}/app')..createSync(),
          data = Directory('${root.path}/donnees')..createSync();
      var model = AppModel(portableDirectory: portable);
      expect(model.playback.port, isA<JustAudioPort>());
      try {
        // Vérifie que le runner expose bien le canal natif de dossiers.
        await tester.runAsync(() async {
          await expectLater(
            const MethodChannel('index/local_folders').invokeMethod<void>(
              'openDirectory',
              '${root.path}/dossier-absent',
            ),
            throwsA(
              isA<PlatformException>().having(
                (e) => e.code,
                'code',
                'missing_directory',
              ),
            ),
          );
        });
        await tester.runAsync(() => model.configure(data.path, '', true));
        expect(model.error, isEmpty);
        expect(model.catalog, hasLength(716));
        await tester.pumpWidget(IndeXApp(model: model, window: TestWindow()));
        await tester.pumpAndSettle();
        model.search('Pasolini');
        expect(model.visible, isNotEmpty);
        model.search('');
        final episode = model.catalog.first;
        model.favorite(episode);
        await tester.runAsync(
          () => model.listened(
            model.catalog.firstWhere((e) => e.id == episode.id),
          ),
        );
        const fixture = String.fromEnvironment('INDEX_TEST_MP3_DIR');
        expect(fixture, isNotEmpty);
        // Ce scénario historique couvre les six fixtures racine ; les huit
        // MP3_Bugs sont exercés séparément ci-dessous en recette audio.
        model.setRecursive(false);
        await tester.runAsync(() => model.scan(fixture));
        expect(model.error, isEmpty);
        expect(model.catalog.where((e) => e.audioAvailable), hasLength(6));
        // Recette matérielle séparée : les runners CI peuvent être sans sortie audio.
        const exerciseAudio = bool.fromEnvironment('INDEX_TEST_AUDIO');
        final audible = model.catalog.firstWhere((e) => e.audioAvailable);
        int? audioPosition;
        if (exerciseAudio) {
          // Décode réellement un MP3 local, sans son audible sur le runner CI.
          await tester.runAsync(() => model.playback.setVolume(0));
          await tester.runAsync(() => model.playEpisode(audible));
          expect(model.playback.error, isEmpty);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1500)),
          );
          await tester.runAsync(model.playback.poll);
          await tester.runAsync(model.playback.stop);
          expect(model.playback.error, isEmpty);
          expect(model.playback.state.duration, greaterThan(0));
          expect(model.playback.state.position, greaterThan(0));
          // Exercices natifs : pause repetee, seek, volume et reprise.
          // Aucun faux AudioPort ici : un pointeur MCI invalide fait echouer
          // ce processus, meme si les tests Dart avec doubles passent.
          await tester.runAsync(model.playback.stop);
          final seekWatch = Stopwatch()..start();
          await tester.runAsync(() => model.playback.seek(500));
          seekWatch.stop();
          // Mesure de l'acquittement de commande, pas de la reprise audible.
          debugPrint(
            'WinRT seek : ${seekWatch.elapsedMilliseconds} ms (commande)',
          );
          expect(model.playback.error, isEmpty);
          expect(model.playback.state.playing, isFalse);
          await tester.runAsync(() => model.playback.setVolume(0.1));
          await tester.runAsync(() => model.playback.setVolume(0));
          await tester.runAsync(model.playback.toggle);
          expect(model.playback.error, isEmpty);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1000)),
          );
          await tester.runAsync(model.playback.poll);
          await tester.runAsync(model.playback.stop);
          expect(model.playback.error, isEmpty);
          expect(model.playback.state.position, greaterThan(500));
          audioPosition = model.playback.state.position;
          final bugs =
              Directory('$fixture/MP3_Bugs')
                  .listSync()
                  .whereType<File>()
                  .where((f) => f.path.toLowerCase().endsWith('.mp3'))
                  .toList()
                ..sort((a, b) => a.path.compareTo(b.path));
          expect(bugs, hasLength(8));
          for (final file in bugs) {
            final probe = JustAudioPort(
              onDiagnostic: (event) => debugPrint(event.toString()),
            );
            try {
              await tester.runAsync(
                () => probe.open(file.absolute.uri.toString()),
              );
              await tester.runAsync(() => probe.volume(0));
              await tester.runAsync(probe.play);
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 1200)),
              );
              var snapshot = await tester.runAsync(probe.snapshot);
              expect(snapshot!.duration, greaterThan(0), reason: file.path);
              expect(snapshot.position, greaterThan(0), reason: file.path);
              await tester.runAsync(() => probe.seek(10000));
              snapshot = await tester.runAsync(probe.snapshot);
              expect(snapshot!.ended, isFalse, reason: file.path);
            } finally {
              await tester.runAsync(probe.dispose);
            }
          }
        }
        await tester.runAsync(() => windowManager.close());
        await tester.runAsync(
          () => probe.closed.future.timeout(const Duration(seconds: 5)),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(model.closeSafely);
        model.dispose();
        model = AppModel(portableDirectory: portable);
        await tester.runAsync(model.boot);
        expect(model.error, isEmpty);
        if (audioPosition != null)
          expect(
            model.session!.listeningState(audible.id)!['position_ms'],
            audioPosition,
          );
        final saved = model.catalog.firstWhere((e) => e.id == episode.id);
        expect(saved.favorite, isTrue);
        expect(saved.status, 'ECOUTE');
        expect(
          File('${data.path}/sauvegardes/IndeX_derniere_sauvegarde.sqlite')
              .existsSync(),
          isTrue,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(model.release);
        model.dispose();
        windowManager.removeListener(probe);
        await windowManager.setPreventClose(false);
        root.deleteSync(recursive: true);
      }
    },
  );
}
