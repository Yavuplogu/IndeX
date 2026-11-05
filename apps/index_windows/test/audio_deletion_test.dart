import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';

import 'support/fake_audio.dart';
import 'support/app_harness.dart';

void main() {
  for (final android in [false, true]) {
    testWidgets(
      'Suppression ${android ? 'Android SAF' : 'Windows'} : aperçu, filtres, annulation et suivi conservé',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final root = Directory.systemTemp.createTempSync(
          'index-delete-widget-',
        );
        final folder = Directory('${root.path}/mp3')..createSync();
        var deleted = 0;
        var present = true;
        final scope = android ? 'content://local/tree/root' : folder.path;
        final reference = android
            ? 'content://local/tree/root/document/root%3Aepisode.mp3'
            : File('${folder.path}/episode.mp3').uri.toString();
        final file = File('${folder.path}/episode.mp3')
          ..writeAsStringSync('audio de test');
        Future<Object?> operation(
          String method,
          Map<String, Object?> args,
        ) async {
          if (method == 'inspectAudioDeletion')
            return {
              'exists': present,
              'eligible': present,
              'identity': 'file-id',
              'signature': 'unchanged',
              'name': 'episode.mp3',
            };
          if (method == 'deleteHeardAudio') {
            deleted++;
            present = false;
            await file.delete();
            return null;
          }
          if (method == 'scan')
            return {
              'complete': true,
              'files': <Map<String, String>>[],
              'errors': <String>[],
            };
          if (method == 'publicationState')
            return {'errors': <String>[], 'pending': <Object>[]};
          return null;
        }

        const channel = MethodChannel('index/local_folders');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              channel,
              (call) async => operation(
                call.method,
                Map<String, Object?>.from(call.arguments as Map),
              ),
            );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        final model = AppModel(
          portableDirectory: root,
          android: android,
          audioPort: FakeAudio(),
          documentOperation: operation,
        );
        await tester.runAsync(
          () => model.configure('${root.path}/user', '', true),
        );
        final id = model.catalog.first.id;
        model.mp3Path = scope;
        model.session!.setSetting('mp3_directory', scope);
        model.session!.store.recordManualLink(id, reference, 'episode.mp3');
        model.session!.store.database.execute(
          "INSERT INTO user_episode_state(episode_id,listening_status,is_favorite,position_ms) VALUES(?,'ECOUTE',1,12345)",
          [id],
        );
        model.reload();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsDialog(
                model: model,
                pickDirectory: () async => null,
              ),
            ),
          ),
        );
        final open = find.byKey(const ValueKey('open-heard-audio-deletion'));
        await tester.ensureVisible(open);
        await tester.tap(open);
        await tester.pumpAndSettle();
        await waitForCondition(
          tester,
          () => model.deletionPlan != null && !model.busy,
          'aperçu suppression',
        );
        expect(deleted, 0);
        expect(model.deletionPlan!.planned, 1);
        // Dimensions constantes sous filtrage, y compris le mode paysage Android.
        for (final size in [const Size(390, 844), const Size(844, 390)]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          final dimensions = tester.getSize(
            find.byKey(const ValueKey('audio-deletion-dialog-size')),
          );
          final filter = find.byKey(
            const ValueKey('audio-delete-filter-excluded'),
          );
          await tester.ensureVisible(filter);
          await tester.tap(filter);
          await tester.pumpAndSettle();
          expect(
            tester.getSize(
              find.byKey(const ValueKey('audio-deletion-dialog-size')),
            ),
            dimensions,
          );
          expect(tester.takeException(), isNull);
        }
        tester.view.physicalSize = const Size(1100, 1000);
        await tester.pumpAndSettle();
        final confirm = find.byKey(
          const ValueKey('confirm-heard-audio-deletion'),
        );
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('sans passage garanti par une corbeille'),
          findsOneWidget,
        );
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
        expect(deleted, 0);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Supprimer définitivement'));
        await tester.pump();
        await waitForCondition(
          tester,
          () => !model.busy && deleted == 1,
          'suppression confirmée',
        );
        expect(file.existsSync(), isFalse);
        final state = model.session!.store.database.select(
          'SELECT listening_status,is_favorite,position_ms FROM user_episode_state WHERE episode_id=?',
          [id],
        ).single;
        expect(state['listening_status'], 'ECOUTE');
        expect(state['is_favorite'], 1);
        expect(state['position_ms'], 12345);
        expect(model.deletionPlan!.used, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => model.closeSafely());
        model.dispose();
        root.deleteSync(recursive: true);
      },
    );
  }
}
