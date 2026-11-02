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
      // Menu Android sur une seule ligne, avec libellés accessibles via tooltip.
      final menu = find.byKey(const ValueKey('android-bottom-menu'));
      expect(menu, findsOneWidget);
      expect(
        find.descendant(of: menu, matching: find.byType(IconButton)),
        findsNWidgets(5),
      );
      final icons = ['library', 'favorites', 'files', 'settings', 'about'];
      final rows = icons
          .map(
            (name) =>
                tester.getCenter(find.byKey(ValueKey('android-nav-$name'))).dy,
          )
          .toSet();
      expect(rows, hasLength(1));
      await tester.tap(find.byKey(const ValueKey('android-nav-settings')));
      await tester.pumpAndSettle();
      final settingsSize = tester.getSize(
        find.byKey(const ValueKey('settings-dialog-size')),
      );
      await tester.tap(
        find
            .descendant(
              of: find.byType(SettingsDialog),
              matching: find.text('Fermer'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final first = model.visible.first;
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const ValueKey('episode-list')),
              matching: find.text(first.title),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('episode-dialog-size'))),
        settingsSize,
      );
      final dialog = find.byType(EpisodeDialog);
      final close = find.descendant(of: dialog, matching: find.text('Fermer'));
      expect(close, findsOneWidget);
      expect(
        tester.getCenter(close).dy,
        greaterThan(tester.getCenter(find.byType(EpisodeDetail)).dy),
      );
      final heading = find
          .descendant(
            of: find.byKey(const ValueKey('episode-detail-heading')),
            matching: find.byType(SelectableText),
          )
          .first;
      expect(tester.widget<SelectableText>(heading).style!.fontSize, 24);
      await tester.tap(close);
      await tester.pumpAndSettle();
      // L’apparition du clavier ne remonte pas le lecteur et la navigation.
      final beforeKeyboard = tester.getRect(menu);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getRect(menu), beforeKeyboard);
      expect(
        tester
            .widget<Scaffold>(find.byType(Scaffold).first)
            .resizeToAvoidBottomInset,
        isFalse,
      );
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      // La liste/filtres se trouvent uniquement dans le panneau dédié Android.
      model.report = {
        'decisions': [
          {
            'status': 'blocked',
            'reason': 'Fichier de recette sans association',
            'current_name': 'exemple.mp3',
            'audio_reference': 'content://recette/exemple.mp3',
          },
        ],
        'issues': [],
      };
      await tester.tap(find.byKey(const ValueKey('android-nav-files')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('scan-associations-list')),
        findsNothing,
      );
      final openFiles = find.byKey(const ValueKey('open-android-associations'));
      await tester.ensureVisible(openFiles);
      await tester.tap(openFiles);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('android-associations-dialog')),
        findsOneWidget,
      );
      expect(find.text('exemple.mp3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('audio-files-associated')));
      await tester.pumpAndSettle();
      expect(find.text('exemple.mp3'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('audio-files-unassociated')));
      await tester.pumpAndSettle();
      expect(find.text('exemple.mp3'), findsOneWidget);
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('android-nav-about')));
      await tester.pumpAndSettle();
      final signature = find.text('Bonne écoute,\n\nMonsieur K.');
      await tester.scrollUntilVisible(
        signature,
        250,
        scrollable: find
            .descendant(
              of: find.byType(IndexAboutDialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(signature, findsOneWidget);
      await tester.tap(
        find
            .descendant(
              of: find.byType(IndexAboutDialog),
              matching: find.text('Fermer'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('android-nav-library')));
      await tester.pumpAndSettle();
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
