import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:index_windows/app_model.dart';

// Ne lancer que sur des copies : le renommage natif est réellement exécuté.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android 6B : copie MP3 gérée, renommage, JSON SAF et conservation du suivi',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      expect(
        const bool.fromEnvironment('INDEX_CONFIRM_RENAME_COPIES'),
        isTrue,
        reason: 'Ce test modifie les noms des copies MP3 choisies. Lire RECETTE_ANDROID.md et confirmer par dart-define.',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'Recette 6B : choisir un sous-dossier de copies dans IndeX · MP3.',
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final private = await AppModel.androidChannel.invokeMethod<String>(
          'privateDirectory',
        );
        final root = await Directory(private!).createTemp('lot6b-');
        final model = AppModel(
          portableDirectory: root,
          android: true,
          pollAudio: false,
        );
        try {
          final tree = await AppModel.androidChannel.invokeMethod<String>(
            'pickTree',
          );
          expect(tree, isNotNull);
          expect(
            Uri.parse(tree!).authority,
            'fr.index.index_windows.documents',
            reason: 'Le test de renommage exige le fournisseur sûr IndeX.',
          );
          // Les copies doivent être dans un sous-dossier, jamais la racine de la collection.
          expect(Uri.parse(tree).pathSegments.last, startsWith('mp3:'));
          expect(
            Uri.parse(tree).pathSegments.last,
            isNot('mp3:'),
            reason: 'Choisir un sous-dossier de copies.',
          );
          await model.configure('${root.path}/user', tree, false);
          expect(model.error, isEmpty);
          await model.previewRename();
          expect(model.error, isEmpty);
          expect(model.renamePlan!.planned, greaterThan(0));
          final planned = model.renamePlan!.entries.firstWhere(
            (e) => e.planned,
          );
          final episode = model.catalog.singleWhere(
            (e) => e.id == planned.episodeId,
          );
          model.favorite(episode);
          model.session!.checkpoint(
            episode.id,
            positionMs: 10000,
            durationMs: 120000,
            progressed: true,
            completed: false,
            playbackStatus: 'paused',
          );
          final original = Map<String, Object?>.from(
            await model.documentOperation('fingerprint', {
              'reference': episode.audioRef,
            }) as Map,
          );
          await model.executeRename();
          expect(model.error, isEmpty);
          final renamed = model.catalog.singleWhere((e) => e.id == episode.id);
          expect(renamed.audioAvailable, isTrue);
          expect(renamed.audioRef, isNot(episode.audioRef));
          final after = Map<String, Object?>.from(
            await model.documentOperation('fingerprint', {
              'reference': renamed.audioRef,
            }) as Map,
          );
          expect(after['digest'], original['digest']);
          expect(after['bytes'], original['bytes']);
          expect(renamed.favorite, isTrue);
          expect(renamed.positionMs, 10000);
          final file = await model.exportListeningSync();
          expect(file, isNotNull);
          // Le sélecteur demande un emplacement externe pour le JSON (ex. Documents).
          final uri = await model.saveListeningSync(file!);
          expect(uri, isNotNull);
          await model.previewListeningSync(uri!);
          expect(model.error, isEmpty);
          expect(model.syncPlan, isNotNull);
          final source = model.syncPlan!.document;
          expect(source.sourcePlatform, 'android');
          expect(source.schemaVersion, 2);
          await model.applyListeningSync(model.syncPlan!, {});
          expect(model.error, isEmpty);
          expect(
            model.catalog.singleWhere((e) => e.id == episode.id).positionMs,
            10000,
          );
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
