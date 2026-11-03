import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:index_windows/app_model.dart';
import 'package:index_windows/audio_player.dart';

// Appareil réel uniquement : lit les copies choisies, aucun MP3 modifié.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android 6C : service, progression en arrière-plan, fin/suivant et pause durable',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'Recette 6C : choisissez un dossier de copies MP3 contenant au moins deux épisodes reconnus. '
                'Le test place ensuite IndeX en arrière-plan, lit quelques secondes puis teste la fin et la pause.',
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final path = await AppModel.androidChannel.invokeMethod<String>(
          'privateDirectory',
        );
        final root = await Directory(path!).createTemp('lot6c-');
        final model = AppModel(portableDirectory: root, android: true);
        Future<Map<String, dynamic>> diagnostics() async =>
            Map<String, dynamic>.from(
              (await NativeAudioPort.channel.invokeMapMethod<String, dynamic>(
                'diagnostics',
              ))!,
            );
        try {
          final tree = await AppModel.androidChannel.invokeMethod<String>(
            'pickTree',
          );
          expect(tree, isNotNull);
          await model.configure('${root.path}/user', tree!, false);
          expect(model.error, isEmpty);
          final queue = model.visible.where((e) => e.audioAvailable).toList();
          expect(queue.length, greaterThanOrEqualTo(2));
          await model.playEpisode(queue.first);
          expect(model.playback.error, isEmpty);
          expect(model.playback.state.duration, greaterThan(20000));
          final service = await diagnostics();
          expect(service['foreground'], isTrue);
          expect(service['wakeHeld'], isTrue);
          expect(service['title'], queue.first.title);
          await AppModel.androidChannel.invokeMethod<void>('backgroundTask');
          await Future<void>.delayed(const Duration(seconds: 7));
          expect(model.playback.state.playing, isTrue);
          expect(
            model.session!.listeningState(queue.first.id)!['position_ms']
                as int,
            greaterThanOrEqualTo(5000),
          );
          expect((await diagnostics())['playing'], isTrue);
          await model.playback.seekFromPlayer(model.playback.state.duration);
          final watch = Stopwatch()..start();
          while (model.playback.episodeId == queue.first.id &&
              watch.elapsed < const Duration(seconds: 15)) {
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }
          expect(model.playback.error, isEmpty);
          expect(
            model.catalog.firstWhere((e) => e.id == queue.first.id).status,
            'ECOUTE',
          );
          expect(model.playback.episodeId, queue[1].id);
          expect((await diagnostics())['title'], queue[1].title);
          expect(model.playback.state.playing, isTrue);
          await model.playback.pause();
          final position = model.playback.state.position;
          await Future<void>.delayed(const Duration(seconds: 2));
          final paused = await NativeAudioPort.channel
              .invokeMapMethod<String, dynamic>('snapshot');
          expect(paused!['playing'], isFalse);
          expect(((paused['position'] as int) - position).abs(), lessThan(200));
          expect(
            model.session!.listeningState(queue[1].id)!['position_ms'],
            position,
          );
          expect((await diagnostics())['wakeHeld'], isFalse);
        } finally {
          await model.release();
          model.dispose();
          await root.delete(recursive: true);
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
