import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';

import 'support/app_harness.dart';
import 'support/fake_audio.dart';

void main() {
  testWidgets(
    'Renommage : aperçu annulable, confirmation, journal et suivi conservé',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('index-rename-ui-');
      final folder = Directory('${root.path}/MP3')..createSync();
      final source = File('${folder.path}/mr_x_1997_01_04.mp3')
        ..writeAsStringSync('contenu audio et tags');
      final configured = Platform.isWindows
          ? folder
          : Directory('${root.path}/MP3-alias');
      if (!Platform.isWindows) Link(configured.path).createSync(folder.path);
      File('${folder.path}/inconnu.mp3').writeAsStringSync('inconnu');
      var moves = 0;
      final model = AppModel(
        portableDirectory: root,
        audioPort: FakeAudio(),
        pollAudio: false,
        renameFile: (from, to) async {
          expect(await to.exists(), isFalse);
          moves++;
          await from.rename(to.path);
        },
      );
      try {
        await tester.runAsync(
          () => model.configure('${root.path}/user', configured.path, false),
        );
        final episode = model.catalog.firstWhere(
          (e) => e.originalName == 'mr_x_1997_01_04.mp3',
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
        await tester.pumpWidget(IndeXApp(model: model, window: FakeWindow()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Paramètres'));
        await tester.pumpAndSettle();
        for (final cancel in [true, false]) {
          final open = find.text('Prévisualiser le renommage des MP3');
          await tester.ensureVisible(open);
          await tester.tap(open);
          await tester.pump();
          await waitForCondition(
            tester,
            () => model.renamePlan != null && !model.busy,
            'aperçu terminé',
          );
          await tester.pumpAndSettle();
          expect(find.byType(Mp3RenameDialog), findsOneWidget);
          expect(model.renamePlan!.planned, cancel ? 1 : 0);
          expect(source.existsSync(), isTrue);
          expect(moves, 0);
          if (cancel) {
            await tester.tap(
              find.byKey(const ValueKey('rename-filter-ignored')),
            );
            await tester.pumpAndSettle();
            expect(find.text('Prévu'), findsNothing);
            expect(find.text('Ignoré'), findsOneWidget);
            await tester.tap(find.byKey(const ValueKey('rename-filter-all')));
            await tester.pumpAndSettle();
            expect(find.text('Prévu'), findsOneWidget);
            await tester.tap(
              find.descendant(
                of: find.byType(Mp3RenameDialog),
                matching: find.text('Fermer'),
              ),
            );
            await tester.pumpAndSettle();
            expect(source.existsSync(), isTrue);
            model.setTheme(true);
            await tester.runAsync(
              () => model.playEpisode(
                model.catalog.firstWhere((e) => e.id == episode.id),
              ),
            );
          } else {
            await tester.tap(find.text('Mettre en pause et libérer la piste'));
            await waitForCondition(
              tester,
              () => !model.busy && model.renamePlan?.planned == 1,
              'piste libérée et aperçu recalculé',
            );
            await tester.pumpAndSettle();
            expect(model.playback.reference, isNull);
            await tester.tap(find.byKey(const ValueKey('confirm-mp3-rename')));
            await waitForCondition(
              tester,
              () => !model.busy && model.renameReport.isNotEmpty,
              'renommage terminé',
            );
            await tester.pumpAndSettle();
            expect(moves, 1);
            expect(source.existsSync(), isFalse);
            final updated = model.catalog.firstWhere((e) => e.id == episode.id);
            expect(
              File.fromUri(Uri.parse(updated.audioRef!)).uri.pathSegments.last,
              episode.systemName,
            );
            expect(updated.audioAvailable, isTrue);
            expect(updated.favorite, isTrue);
            expect(updated.positionMs, 12000);
            expect(model.renameReport.single['status'], 'succeeded');
            expect(find.text('Renommé'), findsOneWidget);
            expect(model.error, isEmpty);
            expect(tester.takeException(), isNull);
          }
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(model.release);
        model.dispose();
        root.deleteSync(recursive: true);
      }
    },
  );
}
