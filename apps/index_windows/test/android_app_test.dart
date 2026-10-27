import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';

import 'support/app_harness.dart';

void main() {
  testWidgets(
    'Android : données privées proposées, pas de barre Windows, retour sauvegardé',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('index-android-widget-');
      final model = AppModel(portableDirectory: root, android: true);
      final window = FakeWindow();
      await tester.runAsync(model.boot);
      await tester.pumpWidget(IndeXApp(model: model, window: window));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('window-title-bar')), findsNothing);
      final data = find.widgetWithText(
        TextFormField,
        'Dossier des données utilisateur',
      );
      expect(tester.widget<TextFormField>(data).enabled, isFalse);
      await tester.tap(find.text('Préciser le dossier MP3 plus tard'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ouvrir la bibliothèque'));
      await tester.tap(find.text('Ouvrir la bibliothèque'));
      await waitForCondition(
        tester,
        () => !model.busy && !model.needsSetup,
        'catalogue Android',
      );
      await tester.pumpAndSettle();
      expect(model.catalog, hasLength(716));
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Lecture / reprise',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Lecture aléatoire',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await waitForCondition(
        tester,
        () => window.destroyed == 1,
        'retour sauvegardé',
      );
      await tester.pump();
      expect(
        File('${model.dataPath}/sauvegardes/IndeX_derniere_sauvegarde.sqlite')
            .existsSync(),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(model.release);
      model.dispose();
      root.deleteSync(recursive: true);
    },
  );
}
