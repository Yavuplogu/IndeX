import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';
import 'package:index_windows/document_text.dart';

import 'support/app_harness.dart';

void main() {
  testWidgets('Android À propos : version sous le logo et ouverture GitHub', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final root = Directory.systemTemp.createTempSync('index-about-android-');
    final model = AppModel(portableDirectory: root, android: true);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppModel.androidChannel, (call) async {
          calls.add(call);
          if (call.method == 'openGithub' && calls.length == 2) {
            throw PlatformException(
              code: 'no_browser',
              message: 'Navigateur absent',
            );
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AppModel.androidChannel, null),
    );
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      tester.view.physicalSize = size;
      for (final dark in [false, true]) {
        model.dark = dark;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: IndexAboutDialog(model: model)),
          ),
        );
        await tester.pumpAndSettle();
        final brand = find.byKey(const ValueKey('about-brand'));
        final version = find.byKey(const ValueKey('about-version'));
        final github = find.byKey(const ValueKey('about-github'));
        expect(
          tester.getTopLeft(version).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(brand).dy),
        );
        expect(
          tester.getTopLeft(github).dx,
          greaterThan(tester.getTopRight(brand).dx),
        );
        expect(
          tester.getTopLeft(github).dy,
          lessThan(tester.getBottomLeft(brand).dy),
        );
        expect(tester.takeException(), isNull);
      }
    }
    await tester.tap(find.byKey(const ValueKey('about-github')));
    await tester.pumpAndSettle();
    expect(calls.single.method, 'openGithub');
    await tester.tap(find.byKey(const ValueKey('about-github')));
    await tester.pumpAndSettle();
    expect(find.text('Ouverture du lien impossible'), findsOneWidget);
    expect(
      find.textContaining('https://github.com/Yavuplogu/IndeX'),
      findsOneWidget,
    );
    expect(find.byType(SelectableText), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
    root.deleteSync(recursive: true);
  });

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
      for (final label in [
        'Exporter le suivi JSON',
        'Importer et fusionner un suivi JSON',
      ]) {
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, label),
              )
              .onPressed,
          isNotNull,
        );
      }
      expect(find.text(AppModel.renameWindowsOnly), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(
                OutlinedButton,
                'Prévisualiser le renommage des MP3',
              ),
            )
            .onPressed,
        isNull,
      );
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
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('download-episode')),
            )
            .onPressed,
        isNotNull,
      );
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
      // Un titre très long ne masque pas les commandes à l’ouverture d’un résultat.
      final longTitle =
          '${List.filled(14, 'Un titre volontairement très long').join(' ')} recetteunique';
      model.session!.store.database.execute(
        'UPDATE episodes SET title=?, description=? WHERE id=?',
        [
          longTitle,
          'La recetteunique de cet épisode. Une deuxième recetteunique.',
          first.id,
        ],
      );
      model.search('recetteunique');
      for (final dark in [false, true]) {
        model.setTheme(dark);
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .descendant(
                of: find.byKey(const ValueKey('episode-list')),
                matching: find.text(longTitle),
              )
              .first,
        );
        await tester.pumpAndSettle();
        final colors = EditorialColors(dark);
        final episodeDialog = tester.widget<Dialog>(
          find.descendant(
            of: find.byType(EpisodeDialog),
            matching: find.byType(Dialog),
          ),
        );
        expect(episodeDialog.backgroundColor, colors.panel);
        expect(episodeDialog.surfaceTintColor, Colors.transparent);
        expect(
          DefaultTextStyle.of(tester.element(find.byType(EpisodeDetail)))
              .style
              .color,
          colors.ink,
        );
        final guide =
            tester
                    .widget<Container>(
                      find.byKey(const ValueKey('search-match-guide')),
                    )
                    .decoration!
                as BoxDecoration;
        expect(guide.color, colors.hitBackground);
        expect((guide.border! as Border).top.color, colors.hitInk);
        for (final match in tester.widgetList<DocumentText>(
          find.byType(DocumentText),
        )) {
          expect(match.ink, colors.hitInk);
          expect(match.fill, colors.hitBackground);
        }
        expect(find.text('Résultat précédent').hitTestable(), findsOneWidget);
        expect(find.text('Résultat suivant').hitTestable(), findsOneWidget);
        final header = tester
            .widget<SingleChildScrollView>(
              find.byKey(ValueKey('detail-header-${first.id}')),
            )
            .controller!;
        expect(header.position.maxScrollExtent, greaterThan(0));
        expect(header.offset, header.position.maxScrollExtent);
        await tester.tap(find.text('Résultat suivant'));
        await tester.pumpAndSettle();
        expect(header.offset, header.position.maxScrollExtent);
        header.jumpTo(0);
        model.changed();
        await tester.pumpAndSettle();
        expect(
          header.offset,
          0,
          reason: 'Les rafraîchissements ne doivent pas forcer le défilement après ouverture.',
        );
        await tester.tap(
          find.descendant(
            of: find.byType(EpisodeDialog),
            matching: find.text('Fermer'),
          ),
        );
        await tester.pumpAndSettle();
      }
      model.setTheme(false);
      model.search('');
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
          {
            'status': 'confirmed',
            'reason': 'Association de recette',
            'current_name': 'associe.mp3',
            'audio_reference': 'content://recette/associe.mp3',
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
      final fileTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('exemple.mp3'),
          matching: find.byType(ListTile),
        ),
      );
      expect(fileTile.trailing, isNull);
      expect(
        tester.getTopLeft(find.text('Associer…')).dy,
        greaterThan(
          tester.getBottomLeft(find.text('content://recette/exemple.mp3')).dy,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('audio-files-associated')));
      await tester.pumpAndSettle();
      expect(find.text('exemple.mp3'), findsNothing);
      expect(find.text('associe.mp3'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byTooltip('Enlever l’association')).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.text('content://recette/associe.mp3')).dy,
        ),
      );
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
