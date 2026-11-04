import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';

import 'support/app_harness.dart';
import 'support/fake_audio.dart';

void main() {
  Future<void> doubleClick(WidgetTester tester, Finder row) async {
    await tester.tap(row, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(row, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Windows : simple clic ouvre, double clic écoute/reprend ; MP3 absent sans effet sur le lecteur',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('index-double-click-');
      final audio = FakeAudio();
      final model = AppModel(
        portableDirectory: root,
        audioPort: audio,
        pollAudio: false,
      );
      try {
        await tester.runAsync(
          () => model.configure(
            '${root.path}/user',
            Directory('../../MP3_Files').absolute.path,
            false,
          ),
        );
        model.sort = CatalogSort.audioFirst;
        model.reload();
        final available = model.visible.where((e) => e.audioAvailable).toList();
        final first = available[0], second = available[1];
        model.favorite(first);
        model.session!.checkpoint(
          first.id,
          positionMs: 12000,
          durationMs: 120000,
          progressed: true,
          completed: false,
          playbackStatus: 'paused',
        );
        model.reload();
        model.select(second);
        await tester.pumpWidget(IndeXApp(model: model, window: FakeWindow()));
        await tester.pumpAndSettle();
        Finder row(String id) => find.byKey(ValueKey('episode-row-$id'));
        await tester.tap(row(first.id), kind: PointerDeviceKind.mouse);
        await tester.pump();
        expect(model.selected!.id, first.id);
        expect(find.byKey(ValueKey('detail-${first.id}')), findsOneWidget);
        expect(model.playback.episodeId, isNull);
        // Cliquer rapidement sur deux lignes ne constitue pas un double clic.
        await tester.tap(row(second.id), kind: PointerDeviceKind.mouse);
        await tester.pump();
        expect(model.selected!.id, second.id);
        expect(model.playback.episodeId, isNull);
        await tester.tap(row(first.id), kind: PointerDeviceKind.mouse);
        await tester.pump();
        expect(model.playback.episodeId, isNull);
        // Un glissement annule la paire de clics en cours.
        final drag = await tester.startGesture(
          tester.getCenter(row(first.id)),
          kind: PointerDeviceKind.mouse,
        );
        await drag.moveBy(const Offset(0, 40));
        await drag.up();
        await tester.pump();
        await tester.tap(row(first.id), kind: PointerDeviceKind.mouse);
        await tester.pump();
        expect(model.playback.episodeId, isNull);
        await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 20));
        // Deux clics isolés ne doivent pas lancer de lecture.
        await tester.tap(row(first.id), kind: PointerDeviceKind.mouse);
        await tester.pump();
        expect(model.playback.episodeId, isNull);
        await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 20));
        final ids = model.visible.map((e) => e.id).toList();
        await doubleClick(tester, row(second.id));
        expect(model.selected!.id, second.id);
        expect(model.playback.episodeId, second.id);
        expect(model.playback.state.playing, isTrue);
        expect(model.playback.sourceRevision, 1);
        // Changer de fiche reste immédiat et n'interrompt pas la piste en cours.
        await tester.tap(row(first.id), kind: PointerDeviceKind.mouse);
        await tester.pump();
        expect(model.selected!.id, first.id);
        expect(find.byKey(ValueKey('detail-${first.id}')), findsOneWidget);
        expect(model.playback.episodeId, second.id);
        expect(model.playback.sourceRevision, 1);
        await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 20));
        await doubleClick(tester, row(first.id));
        expect(model.selected!.id, first.id);
        expect(model.playback.episodeId, first.id);
        expect(model.playback.state.position, 12000);
        expect(model.playback.sourceRevision, 2);
        expect(
          model.catalog.firstWhere((e) => e.id == first.id).favorite,
          isTrue,
        );
        expect(model.visible.map((e) => e.id).toList(), ids);
        expect(model.sort, CatalogSort.audioFirst);
        final missing = model.visible.firstWhere((e) => !e.audioAvailable);
        final listing = tester.widget<ListView>(
          find.byKey(const ValueKey('episode-list')),
        );
        listing.controller!.jumpTo(
          model.visible.indexWhere((e) => e.id == missing.id) * 52.0,
        );
        await tester.pumpAndSettle();
        await doubleClick(tester, row(missing.id));
        expect(model.selected!.id, missing.id);
        expect(model.playback.episodeId, first.id);
        expect(model.playback.sourceRevision, 2);
        expect(model.downloading, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        await tester.runAsync(model.release);
        model.dispose();
        root.deleteSync(recursive: true);
      }
    },
  );

  testWidgets(
    'Android : une ligne associée conserve le simple appui et ne propose pas le double clic',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync(
        'index-no-double-android-',
      );
      final files = <Map<String, String>>[];
      final model = AppModel(
        portableDirectory: root,
        android: true,
        audioPort: FakeAudio(),
        pollAudio: false,
        documentOperation: (method, args) async {
          if (method == 'scan')
            return {'complete': true, 'files': files, 'errors': <String>[]};
          throw StateError(method);
        },
      );
      try {
        await tester.runAsync(
          () => model.configure('${root.path}/user', '', true),
        );
        final first = model.catalog.first;
        files.add({
          'name': first.originalName,
          'reference': 'content://provider/tree/MP3/document/MP3%2Ffirst.mp3',
        });
        await tester.runAsync(() => model.scan('content://provider/tree/MP3'));
        expect(model.error, isEmpty);
        model.sort = CatalogSort.audioFirst;
        model.reload();
        expect(model.visible.first.audioAvailable, isTrue);
        await tester.pumpWidget(IndeXApp(model: model, window: FakeWindow()));
        await tester.pumpAndSettle();
        final row = find.byKey(ValueKey('episode-row-${first.id}'));
        expect(tester.widget<InkWell>(row).onDoubleTap, isNull);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.byType(EpisodeDialog), findsOneWidget);
        expect(model.playback.episodeId, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        await tester.runAsync(model.release);
        model.dispose();
        root.deleteSync(recursive: true);
      }
    },
  );
}
