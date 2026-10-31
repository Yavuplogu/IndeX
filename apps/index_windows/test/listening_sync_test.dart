import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';
import 'package:index_core/index_desktop.dart';

import 'support/app_harness.dart';
import 'support/fake_audio.dart';

void main() {
  testWidgets(
    'Transfert : export, aperçu annulé, conflit résolu, sauvegarde et import répété',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('index-sync-ui-');
      final from = Directory('${root.path}/A')..createSync();
      final to = Directory('${root.path}/B')..createSync();
      Future<void> publish(File part, File target) async {
        expect(target.existsSync(), isFalse);
        await part.rename(target.path);
      }

      final a = AppModel(
        portableDirectory: from,
        audioPort: FakeAudio(),
        syncPublisher: publish,
      );
      final b = AppModel(
        portableDirectory: to,
        audioPort: FakeAudio(),
        syncPublisher: publish,
      );
      try {
        await tester.runAsync(() async {
          await a.configure('${from.path}/user', '', true);
          await b.configure('${to.path}/user', '', true);
        });
        final id = a.catalog.first.id;
        a.favorite(a.catalog.first);
        b.favorite(b.catalog.first);
        b.favorite(b.catalog.first);
        a.session!.checkpoint(
          id,
          positionMs: 60000,
          durationMs: 120000,
          progressed: true,
          completed: false,
          playbackStatus: 'paused',
        );
        b.session!.checkpoint(
          id,
          positionMs: 30000,
          durationMs: 120000,
          progressed: true,
          completed: false,
          playbackStatus: 'paused',
        );
        a.reload();
        b.reload();
        final file = await tester.runAsync(a.exportListeningSync);
        expect(file, isNotNull);
        expect(
          (await tester.runAsync(() => ListeningSync.readFile(file!)))!
              .episodes
              .single
              .id,
          id,
        );
        b.setTheme(true);
        await tester.pumpWidget(IndeXApp(model: b, window: FakeWindow()));
        await tester.pumpAndSettle();
        unawaited(
          showDialog<void>(
            context: tester.element(find.byType(LibraryPage)),
            builder: (_) => SettingsDialog(
              model: b,
              pickDirectory: () async => null,
              pickSyncFile: () async => file!.path,
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final cancel in [true, false]) {
          await tester.runAsync(() async {
            final raw =
                jsonDecode(await file!.readAsString()) as Map<String, dynamic>;
            raw['source_platform'] = cancel ? 'windows' : 'android';
            await file.writeAsString(jsonEncode(raw));
          });
          final import = find.text('Importer et fusionner un suivi JSON');
          await tester.ensureVisible(import);
          await tester.tap(import);
          await tester.pump();
          await waitForCondition(
            tester,
            () => b.syncPlan != null && !b.busy,
            'aperçu du transfert',
          );
          await tester.pumpAndSettle();
          final plan = b.syncPlan!;
          expect(plan.conflicts, hasLength(2));
          expect(
            find.textContaining(
              cancel
                  ? 'Appareil source : Windows'
                  : 'Appareil source : Android',
            ),
            findsOneWidget,
          );
          final scrollable = find
              .descendant(
                of: find.byKey(const ValueKey('sync-results-list')),
                matching: find.byType(Scrollable),
              )
              .first;
          final episodeCard = find.byKey(ValueKey('sync-episode-$id'));
          await tester.scrollUntilVisible(
            episodeCard,
            200,
            scrollable: scrollable,
          );
          expect(episodeCard, findsOneWidget);
          expect(find.byKey(ValueKey('sync-$id|status-file')), findsNothing);
          expect(find.byKey(ValueKey('sync-$id|position-file')), findsNothing);
          expect(b.catalog.first.favorite, isFalse);
          expect(
            b.session!.store.database.select('SELECT * FROM sync_imports'),
            isEmpty,
          );
          if (cancel) {
            await tester.tap(
              find.descendant(
                of: find.byType(ListeningImportDialog),
                matching: find.text('Fermer'),
              ),
            );
            await tester.pumpAndSettle();
            expect(b.catalog.first.favorite, isFalse);
          } else {
            final confirm = find.byKey(
              const ValueKey('confirm-listening-import'),
            );
            expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
            tester.state<ScrollableState>(scrollable).position.jumpTo(0);
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('sync-all-local')),
              200,
              scrollable: scrollable,
            );
            await tester.tap(find.byKey(const ValueKey('sync-all-local')));
            await tester.pumpAndSettle();
            final localChoice = find.byKey(
              ValueKey('sync-${plan.conflicts.first.key}-local'),
            );
            await tester.scrollUntilVisible(
              localChoice,
              200,
              scrollable: scrollable,
            );
            expect(
              tester
                  .widget<OutlinedButton>(localChoice)
                  .style!
                  .backgroundColor!
                  .resolve({}),
              Theme.of(tester.element(localChoice)).colorScheme.primary,
            );
            final allFile = find.byKey(const ValueKey('sync-all-file'));
            tester.state<ScrollableState>(scrollable).position.jumpTo(0);
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              allFile,
              200,
              scrollable: scrollable,
            );
            await tester.tap(allFile);
            await tester.pumpAndSettle();
            tester
                .state<ScrollableState>(
                  find
                      .descendant(
                        of: find.byKey(const ValueKey('sync-results-list')),
                        matching: find.byType(Scrollable),
                      )
                      .first,
                )
                .position
                .jumpTo(0);
            await tester.pumpAndSettle();
            final identicalFilter = find.byKey(
              const ValueKey('sync-filter-identical'),
            );
            await tester.ensureVisible(identicalFilter);
            await tester.tap(identicalFilter);
            await tester.pumpAndSettle();
            expect(
              find.byKey(ValueKey('sync-${plan.conflicts.first.key}-file')),
              findsNothing,
            );
            await tester.ensureVisible(
              find.byKey(const ValueKey('sync-filter-conflict')),
            );
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const ValueKey('sync-filter-conflict')),
            );
            await tester.pumpAndSettle();
            final choice = find.byKey(
              ValueKey('sync-${plan.conflicts.first.key}-file'),
            );
            await tester.scrollUntilVisible(
              choice,
              200,
              scrollable: scrollable,
            );
            await tester.ensureVisible(choice);
            await tester.pumpAndSettle();
            await tester.tap(choice);
            await tester.pumpAndSettle();
            await tester.tap(confirm);
            await waitForCondition(
              tester,
              () => !b.busy && b.syncPlan == null,
              'fusion terminée',
            );
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('confirm-listening-import')),
              findsNothing,
            );
            expect(
              find.descendant(
                of: find.byType(ListeningImportDialog),
                matching: find.widgetWithText(FilledButton, 'Fermer'),
              ),
              findsOneWidget,
            );
            expect(
              find.text(
                'Import terminé. Le suivi a été fusionné et la bibliothèque actualisée.',
              ),
              findsOneWidget,
            );
            expect(b.error, isEmpty);
            expect(b.catalog.first.favorite, isTrue);
            expect(b.catalog.first.positionMs, 60000);
            expect(b.session!.setting('theme'), 'dark');
            expect(
              File('${b.dataPath}/sauvegardes/IndeX_derniere_sauvegarde.sqlite')
                  .existsSync(),
              isTrue,
            );
            final again = ListeningSync(b.session!.store).preview(
              await tester.runAsync(() => ListeningSync.readFile(file!))
                  as SyncDocument,
            );
            expect(again.alreadyImported, isTrue);
            expect(tester.takeException(), isNull);
          }
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await a.release();
          await b.release();
        });
        a.dispose();
        b.dispose();
        root.deleteSync(recursive: true);
      }
    },
  );
}
