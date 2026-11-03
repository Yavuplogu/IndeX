import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';

import 'support/app_harness.dart';
import 'support/fake_audio.dart';

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets(
      'Android paysage : recherche fixe, liste visible, texte ×$scale',
      (tester) async {
        tester.view.physicalSize = const Size(844, 390);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final root = Directory.systemTemp.createTempSync('index-landscape-');
        final model = AppModel(
          portableDirectory: root,
          android: true,
          audioPort: FakeAudio(),
          pollAudio: false,
        );
        try {
          await tester.runAsync(
            () => model.configure('${root.path}/user', '', true),
          );
          model.sort = CatalogSort.audioFirst;
          model.setTheme(scale == 1.5);
          await model.playback.start(
            model.catalog.first.id,
            'content://test/audio',
            0,
          );
          await tester.pumpWidget(IndeXApp(model: model, window: FakeWindow()));
          await tester.pumpAndSettle();
          final search = find.byKey(const ValueKey('library-search-panel'));
          final listing = find.byKey(const ValueKey('episode-list'));
          final left = find.byKey(const ValueKey('android-landscape-search'));
          final header = find.byKey(
            const ValueKey('android-landscape-library-header'),
          );
          expect(header, findsOneWidget);
          expect(
            tester.getRect(listing).left,
            greaterThan(tester.getRect(left).right),
          );
          expect(
            tester.getSize(listing).width,
            greaterThan(tester.getSize(left).width),
          );
          expect(tester.getSize(listing).height, greaterThan(40));
          for (final key in ['sort-filter', 'status-filter']) {
            expect(
              find.descendant(of: header, matching: find.byKey(ValueKey(key))),
              findsOneWidget,
            );
          }
          final position = tester.getRect(search);
          final scroll = tester.widget<ListView>(listing).controller!;
          await tester.drag(listing, const Offset(0, -180));
          await tester.pumpAndSettle();
          expect(scroll.offset, greaterThan(0));
          expect(tester.getRect(search), position);
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await tester.enterText(find.byType(TextField), 'guerre');
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pumpAndSettle();
            expect(model.query, 'guerre');
            expect(model.visible, isNotEmpty);
            // La rotation conserve saisie et critères ; le portrait garde sa présentation.
            final ids = model.visible.map((e) => e.id).toList();
            tester.view.physicalSize = const Size(390, 844);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('android-landscape-library')),
              findsNothing,
            );
            expect(
              tester.widget<TextField>(find.byType(TextField)).controller!.text,
              'guerre',
            );
            expect(model.visible.map((e) => e.id).toList(), ids);
            tester.view.physicalSize = const Size(740, 360);
            await tester.pumpAndSettle();
            expect(header, findsOneWidget);
            expect(tester.getSize(listing).height, greaterThan(40));
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        } finally {
          await tester.runAsync(model.release);
          model.dispose();
          root.deleteSync(recursive: true);
        }
      },
    );
  }
}
