import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';
import 'package:index_windows/window_port.dart';

final class FakeWindow implements WindowPort {
  FakeWindow({this.destroyGate});
  final Future<void>? destroyGate;
  bool closeRequested = false;
  int destroyed = 0;
  @override
  Future<void> destroy() async {
    closeRequested = true;
    if (destroyGate != null) await destroyGate;
    destroyed++;
  }

  @override
  Future<void> minimize() async {}
  @override
  Future<void> maximizeOrRestore() async {}
}

// pumpAndSettle ne fait pas attendre les E/S réelles : leur laisser progresser
// jusqu'à l'état attendu, avec un délai maximal, puis terminer les animations.
Future<void> waitForCondition(
  WidgetTester tester,
  bool Function() condition,
  String description,
) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 20)) {
      fail('État attendu non atteint : $description');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

Future<void> waitForWidget(WidgetTester tester, Finder finder) =>
    waitForCondition(
      tester,
      () => finder.evaluate().isNotEmpty,
      finder.toString(),
    );

void main() {
  testWidgets(
    'Démarrage : aucun contournement HTML, dossiers et report explicite',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('index-widget-start-');
      final model = AppModel(portableDirectory: root);
      final window = FakeWindow();
      await tester.pumpWidget(
        IndeXApp(model: model, window: window, pickDirectory: () async => null),
      );
      expect(find.text('Bienvenue dans IndeX'), findsOneWidget);
      expect(find.textContaining('Test HTML'), findsNothing);
      expect(find.text('Préciser le dossier MP3 plus tard'), findsOneWidget);
      await tester.tap(find.text('Ouvrir la bibliothèque'));
      await tester.pump();
      expect(find.text('Ce dossier est obligatoire.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
      root.deleteSync(recursive: true);
    },
  );
  testWidgets(
    'Catalogue intégré, sources, filtres FTS, favoris et paramètres',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('index-widget-library-');
      final portable = Directory('${root.path}/app')..createSync(),
          data = Directory('${root.path}/data')..createSync();
      final model = AppModel(portableDirectory: portable);
      final window = FakeWindow();
      await tester.runAsync(() => model.configure(data.path, '', true));
      expect(model.error, isEmpty);
      expect(model.catalog.length, 716);
      await tester.pumpWidget(
        IndeXApp(model: model, window: window, pickDirectory: () async => null),
      );
      await tester.pump();
      expect(find.text('Bibliothèque'), findsWidgets);
      expect(find.text('Aucun dossier MP3 paramétré'), findsWidgets);
      final bizerte = model.catalog.singleWhere((e) => e.title == 'Bizerte');
      model.select(bizerte);
      await tester.pump();
      await tester.tap(find.text('Sources').last);
      await tester.pump();
      expect(
        find.text('Un Premier Ministre de Bourguiba témoigne'),
        findsOneWidget,
      );
      expect(find.text('Fiche précédente'), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Favori'));
      await tester.pump();
      expect(model.selected!.favorite, isTrue);
      model.search('Mzali');
      expect(model.selected?.excerpt, isNotEmpty);
      await tester.pump();
      expect(model.visible.any((e) => e.title == 'Bizerte'), isTrue);
      model.fields = {};
      model.reload();
      await tester.pump();
      expect(model.queryError, isNotEmpty);
      model.fields = Set.of(fieldNames.keys);
      model.search('');
      await tester.pump();
      await tester.tap(find.text('Paramètres'));
      await tester.pumpAndSettle();
      expect(find.text('Dossiers'), findsOneWidget);
      expect(find.text('Transfert du suivi'), findsOneWidget);
      expect(find.text('Préciser le dossier MP3 plus tard'), findsNothing);
      expect(find.text('Fermer'), findsNWidgets(2));
      await tester.tap(find.text('Fermer').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(model.release);
      model.dispose();
      root.deleteSync(recursive: true);
    },
  );
  testWidgets(
    'Échec de sauvegarde à la croix : la fenêtre reste ouverte puis réessai',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('index-widget-close-');
      final portable = Directory('${root.path}/app')..createSync(),
          data = Directory('${root.path}/data')..createSync();
      final model = AppModel(portableDirectory: portable);
      final destroyGate = Completer<void>();
      final window = FakeWindow(destroyGate: destroyGate.future);
      await tester.runAsync(() => model.configure(data.path, '', true));
      final blocker = File('${data.path}/sauvegardes')
        ..writeAsStringSync('blocage');
      await tester.pumpWidget(IndeXApp(model: model, window: window));
      await tester.runAsync(() => tester.tap(find.byTooltip('Fermer')));
      await waitForWidget(tester, find.text('Sauvegarde impossible'));
      await tester.pumpAndSettle();
      expect(find.text('Sauvegarde impossible'), findsOneWidget);
      expect(window.destroyed, 0);
      expect(window.closeRequested, isFalse);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      blocker.deleteSync();
      await tester.runAsync(() => tester.tap(find.byTooltip('Fermer')));
      await waitForCondition(
        tester,
        () => window.closeRequested,
        'sauvegarde validée puis demande de fermeture',
      );
      // La sauvegarde doit être validée avant même de demander la destruction.
      expect(
        File('${data.path}/sauvegardes/IndeX_derniere_sauvegarde.sqlite')
            .existsSync(),
        isTrue,
      );
      expect(model.session, isNull);
      expect(window.destroyed, 0);
      // Le système de fenêtre peut lui aussi répondre de manière asynchrone.
      destroyGate.complete();
      await tester.pump();
      await waitForCondition(
        tester,
        () => window.destroyed == 1,
        'fermeture effective',
      );
      await tester.pumpAndSettle();
      expect(window.destroyed, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(model.release);
      model.dispose();
      root.deleteSync(recursive: true);
    },
  );
}
