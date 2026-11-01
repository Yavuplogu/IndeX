import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:index_windows/app_model.dart';

// Essai physique supervisé. Le dossier sélectionné est uniquement lu ; le profil
// de recette est temporaire et séparé des données utilisateur de l’application.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android 6A : SQLite, SAF persistant, MP3 et reprise', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Recette IndeX 6A : choisissez un dossier de copies MP3.',
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final private = await AppModel.androidChannel.invokeMethod<String>(
        'privateDirectory',
      );
      final root = await Directory(private!).createTemp('lot6a-');
      var model = AppModel(
        portableDirectory: root,
        android: true,
        pollAudio: false,
      );
      try {
        await model.configure('${root.path}/user', '', true);
        expect(model.catalog, hasLength(716));
        model.search('Yougo');
        expect(
          model.visible,
          isNotEmpty,
          reason: 'Recherche FTS5 partielle sur le vrai SQLite Android.',
        );
        model.search('');
        final tree = await AppModel.androidChannel.invokeMethod<String>(
          'pickTree',
        );
        expect(
          tree,
          isNotNull,
          reason: 'Choisir un dossier de copies de MP3 pour cette recette.',
        );
        expect(Uri.parse(tree!).scheme, 'content');
        await model.scan(tree);
        expect(model.error, isEmpty);
        expect(model.audioKnown, isTrue, reason: 'Le scan doit être complet.');
        const name = String.fromEnvironment('INDEX_TEST_MP3_NAME');
        final candidates = model.catalog
            .where(
              (e) =>
                  e.audioAvailable &&
                  (name.isEmpty ||
                      e.originalName == name ||
                      e.systemName == name),
            )
            .toList();
        expect(
          candidates,
          isNotEmpty,
          reason: 'Un MP3 du catalogue doit être présent, au nom historique ou système.',
        );
        final episode = candidates.first;
        expect(Uri.parse(episode.audioRef!).scheme, 'content');
        await model.playEpisode(episode).timeout(const Duration(seconds: 30));
        expect(model.playback.error, isEmpty);
        await Future<void>.delayed(const Duration(seconds: 3));
        await model.playback.poll();
        expect(model.playback.state.duration, greaterThan(30000));
        expect(model.playback.state.position, greaterThan(0));
        final watch = Stopwatch()..start();
        await model.playback.seek(10000);
        watch.stop();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await model.playback.poll();
        expect(model.playback.error, isEmpty);
        expect(model.playback.state.position, inInclusiveRange(9000, 14000));
        await model.playback
            .stop(); // Pause avec checkpoint, pas remise à zéro.
        final saved = model.session!.listeningState(episode.id)!['position_ms'];
        expect(saved, greaterThan(0));
        // Information locale de recette ; aucune donnée n’est envoyée à un serveur.
        debugPrint(
          '6A : ${episode.originalName}, seek=${watch.elapsedMilliseconds} ms, position=$saved',
        );
        await model.release();
        model.dispose();
        model = AppModel(
          portableDirectory: root,
          android: true,
          pollAudio: false,
        );
        await model.boot();
        expect(model.needsSetup, isFalse);
        expect(model.mp3Path, tree);
        expect(
          model.session!.listeningState(episode.id)!['position_ms'],
          saved,
        );
        // Pas de nouveau sélecteur : vérifie la réutilisation de l’autorisation.
        await model.scan(tree);
        expect(model.audioKnown, isTrue);
        expect(
          model.catalog.singleWhere((e) => e.id == episode.id).audioAvailable,
          isTrue,
        );
      } finally {
        await model.release();
        model.dispose();
        await root.delete(recursive: true);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}
