import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:index_windows/app_model.dart';

// Recette native : scan en lecture seule et export/import JSON sur profil temporaire.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android 6B : renommage désactivé, JSON SAF et conservation du suivi',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'Recette 6B : choisir un dossier contenant des copies MP3 reconnues.',
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
          await model.configure('${root.path}/user', tree!, false);
          expect(model.error, isEmpty);
          // Régression EACCES : publication réelle sans création de lien dur.
          final partial = File('${root.path}/export.partial');
          final published = File('${root.path}/export.json');
          await partial.writeAsString('{"test":"complet"}', flush: true);
          await AppModel.androidChannel.invokeMethod<void>('publishPrivate', {
            'partial': partial.path,
            'target': published.path,
          });
          expect(await partial.exists(), isFalse);
          expect(await published.readAsString(), '{"test":"complet"}');
          await partial.writeAsString('ne pas remplacer', flush: true);
          await expectLater(
            AppModel.androidChannel.invokeMethod<void>('publishPrivate', {
              'partial': partial.path,
              'target': published.path,
            }),
            throwsA(isA<Exception>()),
          );
          expect(await partial.readAsString(), 'ne pas remplacer');
          expect(await published.readAsString(), '{"test":"complet"}');
          await model.previewRename();
          expect(model.error, contains(AppModel.renameWindowsOnly));
          expect(model.renamePlan, isNull);
          final episode = model.catalog.firstWhere((e) => e.audioAvailable);
          model.favorite(episode);
          model.session!.checkpoint(
            episode.id,
            positionMs: 10000,
            durationMs: 120000,
            progressed: true,
            completed: false,
            playbackStatus: 'paused',
          );
          model.reload();
          final original = Map<String, Object?>.from(
            await model.documentOperation('fingerprint', {
              'reference': episode.audioRef,
            }) as Map,
          );
          await model.executeRename();
          expect(model.error, contains(AppModel.renameWindowsOnly));
          final renamed = model.catalog.singleWhere((e) => e.id == episode.id);
          expect(renamed.audioAvailable, isTrue);
          expect(renamed.audioRef, episode.audioRef);
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
