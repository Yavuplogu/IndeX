import 'dart:async';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';

import 'support/app_harness.dart';

import 'package:index_windows/document_text.dart';
import 'package:index_windows/episode_search.dart';
import 'package:index_windows/audio_player.dart';

import 'support/fake_audio.dart';

void main() {
  testWidgets(
    'À propos : logo, liens, version, thèmes et vue compacte sans perte de liste',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final contactCalls = <MethodCall>[];
      const contactChannel = SystemChannels.platform;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(contactChannel, (call) async {
            contactCalls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(contactChannel, null),
      );
      final root = Directory.systemTemp.createTempSync('index-about-widget-');
      final model = AppModel(portableDirectory: root, audioPort: FakeAudio());
      try {
        await tester.runAsync(
          () => model.configure('${root.path}/user', '', true),
        );
        model.search('Yougo');
        final ids = model.visible.map((e) => e.id).toList();
        for (final compact in [false, true]) {
          tester.view.physicalSize = compact
              ? const Size(480, 800)
              : const Size(1440, 1000);
          for (final dark in [false, true]) {
            model.setTheme(dark);
            await tester.pumpWidget(
              IndeXApp(model: model, window: FakeWindow()),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('À propos'));
            await tester.pumpAndSettle();
            final dialog = find.byType(IndexAboutDialog);
            expect(dialog, findsOneWidget);
            expect(
              find.descendant(of: dialog, matching: find.byType(Brand)),
              findsOneWidget,
            );
            expect(find.text('Fonctions prévues'), findsNothing);
            expect(
              tester
                  .widget<Brand>(
                    find.descendant(of: dialog, matching: find.byType(Brand)),
                  )
                  .showSubtitle,
              isFalse,
            );
            expect(find.text('Voir sur GitHub'), findsOneWidget);
            final githubPosition = tester.getTopLeft(
              find.byKey(const ValueKey('about-github')),
            );
            final versionPosition = tester.getTopLeft(
              find.byKey(const ValueKey('about-version')),
            );
            expect(versionPosition.dx, lessThan(githubPosition.dx));
            final brandCenter = tester.getCenter(
              find.byKey(const ValueKey('about-brand')),
            );
            expect(
              (brandCenter.dy -
                      tester
                          .getCenter(find.byKey(const ValueKey('about-github')))
                          .dy)
                  .abs(),
              lessThan(1),
            );
            expect(
              (githubPosition.dy - versionPosition.dy).abs(),
              lessThan(24),
            );
            expect(find.text('Version : $applicationVersion'), findsOneWidget);
            final material = tester.widget<Dialog>(
              find.descendant(of: dialog, matching: find.byType(Dialog)),
            );
            expect(material.backgroundColor, EditorialColors(dark).panel);
            await tester.tap(find.byKey(const ValueKey('about-github')));
            await tester.pumpAndSettle();
            expect(
              find.text(
                'Lien GitHub de démonstration : aucun site n’est ouvert.',
              ),
              findsOneWidget,
            );
            final contact = find.byKey(const ValueKey('about-contact'));
            await tester.ensureVisible(contact);
            await tester.pumpAndSettle();
            await tester.tap(contact);
            await tester.pumpAndSettle();
            expect(contactCalls.last.method, 'Clipboard.setData');
            expect(contactCalls.last.arguments, {
              'text': 'index.en9nr@passinbox.com',
            });
            expect(
              find.text('Adresse mail copiée dans le presse-papiers.'),
              findsOneWidget,
            );
            expect(
              find.widgetWithText(OutlinedButton, 'Voir sur GitHub'),
              findsOneWidget,
            );
            await tester.drag(
              find.byKey(const ValueKey('about-scroll')),
              const Offset(0, -3000),
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.text('Vos données restent chez vous'),
            );
            expect(
              find.text('Vos données restent chez vous').hitTestable(),
              findsOneWidget,
            );
            expect(find.text('Fermer'), findsNWidgets(2));
            await tester.tap(find.text('Fermer').first);
            await tester.pumpAndSettle();
            expect(find.byType(IndexAboutDialog), findsNothing);
            expect(model.query, 'Yougo');
            expect(model.visible.map((e) => e.id), ids);
            expect(tester.takeException(), isNull);
            ScaffoldMessenger.of(tester.element(find.byType(LibraryPage)))
                .clearSnackBars();
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
  testWidgets('Recherche restaurée visible et case de reprise à gauche', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final root = Directory.systemTemp.createTempSync('index-list-view-widget-');
    final model = AppModel(portableDirectory: root, audioPort: FakeAudio());
    try {
      await tester.runAsync(
        () => model.configure('${root.path}/user', '', true),
      );
      model.search('Yougo');
      await tester.pumpWidget(IndeXApp(model: model, window: FakeWindow()));
      await tester.pumpAndSettle();
      final searchField = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == 'Yougo',
      );
      expect(searchField, findsOneWidget);
      await tester.tap(find.text('Paramètres'));
      await tester.pumpAndSettle();
      final resume = find.widgetWithText(
        CheckboxListTile,
        'Reprendre à la dernière position sauvegardée',
      );
      expect(
        tester.widget<CheckboxListTile>(resume).controlAffinity,
        ListTileControlAffinity.leading,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(model.release);
      model.dispose();
      root.deleteSync(recursive: true);
    }
  });
  testWidgets(
    'Lecteur indépendant de la fiche, progression durable et mise en page téléphone',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('index-player-widget-');
      final data = Directory('${root.path}/user')..createSync();
      final audio = FakeAudio();
      final model = AppModel(
        portableDirectory: root,
        audioPort: audio,
        pollAudio: false,
      );
      await tester.runAsync(
        () => model.configure(
          data.path,
          Directory('../../MP3_Files').absolute.path,
          false,
        ),
      );
      final episode = model.catalog.firstWhere((e) => e.audioAvailable);
      model.select(episode);
      await tester.pumpWidget(IndeXApp(model: model, window: FakeWindow()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Écouter'));
      await waitForCondition(tester, () => !model.playback.busy, 'audio prêt');
      await tester.pumpAndSettle();
      expect(model.playingEpisode!.id, episode.id);
      model.select(model.catalog.firstWhere((e) => e.id != episode.id));
      await tester.pumpAndSettle();
      expect(model.playingEpisode!.id, episode.id);
      audio.value = const AudioSnapshot(1000, 120000, true);
      await model.playback.poll();
      audio.value = const AudioSnapshot(2000, 120000, true);
      await model.playback.poll();
      audio.value = const AudioSnapshot(3000, 120000, true);
      await model.playback.poll();
      audio.value = const AudioSnapshot(4000, 120000, true);
      await model.playback.poll();
      audio.value = const AudioSnapshot(5000, 120000, true);
      await model.playback.poll();
      expect(model.session!.listeningState(episode.id)!['position_ms'], 5000);
      expect(
        model.session!.listeningState(episode.id)!['listening_status'],
        'EN_COURS',
      );
      model.search('guerre');
      model.sort = CatalogSort.titleAZ;
      model.reload();
      await tester.pumpAndSettle();
      final beforeIds = model.visible.map((e) => e.id).toList();
      final controller = tester
          .widget<ListView>(find.byKey(const ValueKey('episode-list')))
          .controller!;
      controller.jumpTo(150.0.clamp(0.0, controller.position.maxScrollExtent));
      await tester.pump();
      final offset = controller.offset;
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      await pointer.moveTo(
        tester.getCenter(find.byKey(const ValueKey('player-episode-title'))),
      );
      await tester.pumpAndSettle();
      final richFinder = find.descendant(
        of: find.byKey(const ValueKey('player-episode-title')),
        matching: find.byType(RichText),
      );
      final rich = tester.widget<RichText>(richFinder);
      final measured = TextPainter(
        text: rich.text,
        textDirection: rich.textDirection ?? TextDirection.ltr,
        textScaler: rich.textScaler,
        locale: rich.locale,
        maxLines: 1,
      )..layout();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('player-title-outline')))
            .width,
        closeTo(measured.width + 10, 1.1),
      );
      measured.dispose();
      final outline =
          tester
                  .widget<Container>(
                    find.byKey(const ValueKey('player-title-outline')),
                  )
                  .decoration
              as BoxDecoration;
      expect(
        (outline.border as Border).top.color,
        Theme.of(
          tester.element(find.byKey(const ValueKey('player-title-outline'))),
        ).colorScheme.primary,
      );
      await pointer.removePointer();
      await tester.tap(find.byKey(const ValueKey('player-episode-title')));
      await tester.pumpAndSettle();
      expect(model.selected!.id, episode.id);
      expect(model.query, 'guerre');
      expect(model.sort, CatalogSort.titleAZ);
      expect(model.visible.map((e) => e.id), beforeIds);
      expect(controller.offset, offset);
      expect(find.text('En cours (4 %)'), findsOneWidget);
      Focus.of(tester.element(find.byKey(const ValueKey('episode-list'))))
          .requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(model.playback.state.position, 15000);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(model.playback.state.position, 5000);
      await tester.tap(find.text('En cours (4 %)'));
      await tester.pumpAndSettle();
      expect(find.text('Marquer comme écouté ?'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(model.playingEpisode!.status, 'EN_COURS');
      model.playback.error = 'Erreur audio sélectionnable';
      model.error = 'Erreur principale sélectionnable';
      model.changed();
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(SelectableText, 'Erreur audio sélectionnable'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SelectableText, 'Erreur principale sélectionnable'),
        findsOneWidget,
      );
      model.playback.error = '';
      model.error = '';
      model.changed();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('player-episode-title')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(EpisodeDetail), findsOneWidget);
      expect(model.query, 'guerre');
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(model.release);
      model.dispose();
      root.deleteSync(recursive: true);
    },
  );

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
      expect(model.dataPath, endsWith('user'));
      await tester.enterText(find.byType(TextFormField).last, '');
      await tester.tap(find.text('Ouvrir la bibliothèque'));
      await tester.pump();
      expect(find.text('Ce dossier est obligatoire.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
      root.deleteSync(recursive: true);
    },
  );
  testWidgets(
    'Chargement après ouverture de la base, menus en un clic et statistiques MP3',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('index-boot-menus-');
      final data = Directory('${root.path}/data')..createSync();
      final opened = <String>[];
      final model = AppModel(
        portableDirectory: root,
        folderOpener: (path) async => opened.add(path),
      );
      await tester.runAsync(
        () => model.configure(
          data.path,
          Directory('../../MP3_Files').absolute.path,
          false,
        ),
      );
      expect(model.error, isEmpty);
      // État intermédiaire réel : session ouverte, initialisation encore en cours.
      model.opening = true;
      model.busy = true;
      model.needsSetup = true;
      await tester.pumpWidget(IndeXApp(model: model, window: FakeWindow()));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('N’allons pas trop vite...'), findsOneWidget);
      expect(find.byType(StartupPage), findsNothing);
      expect(find.text('Choisir le dossier MP3'), findsNothing);
      model.opening = false;
      model.busy = false;
      model.needsSetup = false;
      model.sort = CatalogSort.relevance;
      model.changed();
      await tester.pumpAndSettle();
      expect(find.text('716 / 716 épisodes'), findsOneWidget);
      expect(find.textContaining('MP3 absents'), findsNothing);
      final sort = find.byKey(const ValueKey('sort-filter'));
      final status = find.byKey(const ValueKey('status-filter'));
      await tester.tap(sort);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNWidgets(sortNames.length));
      await tester.tap(status);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('status-filter-ECOUTE')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('sort-filter-CatalogSort.titleAZ')),
        findsNothing,
      );
      await tester.tap(sort);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('status-filter-ECOUTE')), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('sort-filter-CatalogSort.titleAZ')),
      );
      await tester.pumpAndSettle();
      expect(model.sort, CatalogSort.titleAZ);
      await tester.tap(status);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('status-filter-ECOUTE')));
      await tester.pumpAndSettle();
      expect(model.status, 'ECOUTE');
      await tester.tap(find.text('Fichiers'));
      await tester.pumpAndSettle();
      expect(find.text('Catalogue : 716 épisodes'), findsOneWidget);
      expect(find.text('Dossier MP3 : 14 fichiers'), findsOneWidget);
      expect(find.text('Épisodes associés : 14'), findsOneWidget);
      expect(find.text('Épisodes manquants : 702'), findsOneWidget);
      final recursive = find.widgetWithText(
        CheckboxListTile,
        'Analyser aussi les sous-dossiers',
      );
      expect(tester.widget<CheckboxListTile>(recursive).value, isTrue);
      await tester.tap(find.text('Ouvrir le dossier MP3'));
      await waitForCondition(
        tester,
        () => !model.busy,
        'ouverture du dossier MP3',
      );
      await tester.pumpAndSettle();
      expect(opened, [Directory('../../MP3_Files').absolute.uri.toFilePath()]);
      await tester.tap(find.byKey(const ValueKey('audio-files-unassociated')));
      await tester.pumpAndSettle();
      expect(find.text('Aucun fichier pour ce filtre.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('audio-files-all')));
      await tester.pumpAndSettle();
      final remove = find.byTooltip('Enlever l’association').first;
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.text('Enlever cette association ?'), findsOneWidget);
      expect(find.textContaining('seront supprimés'), findsOneWidget);
      await tester.tap(find.text('Enlever'));
      await waitForCondition(tester, () => !model.busy, 'retrait du lien');
      await tester.pumpAndSettle();
      expect(model.availableAudioCount, 13);
      final reassociate = find.widgetWithText(OutlinedButton, 'Associer…');
      expect(reassociate, findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(reassociate)
            .style!
            .backgroundColor!
            .resolve({}),
        EditorialColors(false).controls,
      );
      expect(
        tester.widget<Card>(find.byType(Card).first).color,
        EditorialColors(false).missing,
      );
      final reason = find.textContaining(
        'Association retirée par l’utilisateur',
      );
      expect(
        tester.widget<Text>(reason).style!.color,
        Theme.of(tester.element(reason)).colorScheme.primary,
      );
      for (final entry in {
        'associated': 13,
        'unassociated': 1,
        'all': 14,
      }.entries) {
        await tester.tap(find.byKey(ValueKey('audio-files-${entry.key}')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ListView>(
                find.byKey(const ValueKey('scan-associations-list')),
              )
              .semanticChildCount,
          entry.value,
        );
      }
      expect(
        tester.widget<Card>(find.byType(Card).first).color,
        EditorialColors(false).missing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(model.release);
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
      final relatedButton = tester.widget<TextButton>(
        find
            .descendant(
              of: find.byType(EpisodeDetail),
              matching: find.byWidgetPredicate(
                (w) => w is TextButton && w.child is Row,
              ),
            )
            .first,
      );
      expect(
        (relatedButton.style!.shape!.resolve(
          {},
        ) as RoundedRectangleBorder).borderRadius,
        BorderRadius.zero,
      );
      final relatedDate = (relatedButton.child as Row).children.last as Text;
      final bodyStyle = Theme.of(tester.element(find.byType(EpisodeDetail)))
          .textTheme
          .bodyMedium!;
      expect(relatedDate.style!.fontWeight, bodyStyle.fontWeight);
      expect(relatedDate.style!.fontFamily, bodyStyle.fontFamily);
      expect(relatedDate.style!.fontSize, 11);
      expect(relatedDate.style!.color, EditorialColors(false).ink);

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
      expect(find.byType(FilterMenu<bool>), findsNothing);
      for (final dark in [true, false]) {
        final button = find.byKey(
          ValueKey(dark ? 'appearance-dark' : 'appearance-light'),
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(model.dark, dark);
        expect(model.session!.setting('theme'), dark ? 'dark' : 'light');
        expect(
          tester
              .widget<OutlinedButton>(button)
              .style!
              .backgroundColor!
              .resolve({}),
          Theme.of(tester.element(button)).colorScheme.primary,
        );
      }
      expect(find.text('Données utilisateur'), findsOneWidget);
      expect(find.text('Dossier contenant les MP3'), findsNothing);
      expect(find.text('Analyser aussi les sous-dossiers'), findsNothing);
      final skip = find.widgetWithText(
        CheckboxListTile,
        'Scanner le dossier MP3 à chaque ouverture',
      );
      final resumeTitle = find.text(
        'Reprendre à la dernière position sauvegardée',
      );
      final resumeDescription = find.text(
        'La lecture en arrière-plan est mise en pause avec sauvegarde de la position.',
      );
      expect(
        (tester.getTopLeft(resumeTitle).dx -
                tester.getTopLeft(resumeDescription).dx)
            .abs(),
        lessThan(1),
      );
      expect(tester.widget<CheckboxListTile>(skip).value, isTrue);
      await tester.ensureVisible(skip);
      await tester.pumpAndSettle();
      await tester.tap(skip);
      await tester.pump();
      expect(model.skipStartupScan, isTrue);
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
    'Fiche ancrée, flèches, recherche partielle et diagnostic défilant',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('index-ui-regression-');
      final portable = Directory('${root.path}/app')..createSync();
      final data = Directory('${root.path}/data')..createSync();
      final model = AppModel(portableDirectory: portable);
      await tester.runAsync(
        () => model.configure(
          data.path,
          Directory('../../MP3_Files').absolute.path,
          false,
        ),
      );
      await tester.pumpWidget(IndeXApp(model: model, window: FakeWindow()));
      await tester.pumpAndSettle();
      expect(find.text(model.folderLabel), findsNothing);
      final top = tester
          .getTopLeft(find.byKey(const ValueKey('index-brand')))
          .dy;
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('library-search-panel')))
            .dy,
        top,
      );
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('episode-detail-heading')))
            .dy,
        top,
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.text('Paramètres')),
      );
      await tester.pump();
      expect(
        tester.binding.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );
      await mouse.removePointer();
      final list = find.byKey(const ValueKey('episode-list'));
      await tester.tap(
        find.descendant(
          of: list,
          matching: find.text(model.visible.first.title),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(model.selected!.id, model.visible[1].id);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(model.selected!.id, model.visible.first.id);
      expect(find.text('Aucun épisode en lecture'), findsOneWidget);
      final noSource = model.catalog.firstWhere((e) => e.sources.isEmpty);
      model.select(noSource);
      await tester.pump();
      final title = find.byWidgetPredicate(
        (w) => w is SelectableText && w.data == noSource.title,
      );
      final titleTop = tester.getTopLeft(title).dy;
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('episode-detail-content')))
            .dy,
        closeTo(
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('episode-detail-divider')),
              )
              .dy,
          0.1,
        ),
      );

      await tester.tap(find.text('Sources').last);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(title).dy, titleTop);
      final searchField = find
          .descendant(
            of: find.byType(LibraryPage),
            matching: find.byType(TextField),
          )
          .first;
      await tester.enterText(searchField, 'Yo');
      await tester.pump(const Duration(milliseconds: 300));
      expect(model.visible, hasLength(716));
      await tester.enterText(searchField, 'Yougo');
      await tester.pump(const Duration(milliseconds: 300));
      expect(model.visible.length, inInclusiveRange(1, 715));
      expect(find.textContaining('Trouvé dans :'), findsWidgets);
      expect(find.text('Résultat de la recherche'), findsOneWidget);
      await tester.tap(find.byTooltip('Effacer la recherche'));
      await tester.pumpAndSettle();
      expect(model.query, isEmpty);
      expect(model.visible, hasLength(716));
      model.report = {
        'count': 100,
        'issues': [
          for (var i = 0; i < 100; i++)
            {'message': 'Erreur $i', 'source': 'fichier_$i.mp3'},
        ],
        'decisions': <Object>[],
      };
      await tester.tap(find.text('Fichiers'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Diagnostic du scan'),
      );
      await tester.pumpAndSettle();
      final diagnostics = find.byType(ScanDiagnostics);
      expect(
        find.descendant(of: diagnostics, matching: find.byType(SelectionArea)),
        findsOneWidget,
      );
      final scrollable = find.descendant(
        of: diagnostics,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Erreur 99'),
        250,
        scrollable: scrollable,
      );
      expect(find.text('Erreur 99'), findsOneWidget);
      File? exported;
      await tester.runAsync(() async {
        exported = await model.exportScanDiagnostic();
      });
      expect(
        FileSystemEntity.identicalSync(
          exported!.parent.path,
          Directory('${model.dataPath}/exports').path,
        ),
        isTrue,
      );
      expect(exported!.uri.pathSegments.last, isNot(contains(' ')));
      expect(exported!.readAsStringSync(), contains('Erreur 99'));
      expect(exported!.readAsStringSync(), contains('fichier_0.mp3'));
      tester.view.physicalSize = const Size(1024, 740);
      model.setTheme(true);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(model.release);
      model.dispose();
      root.deleteSync(recursive: true);
    },
  );

  testWidgets(
    'Correspondances : boutons persistants, changement d’onglet et focus du texte',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync(
        'index-match-navigation-',
      );
      final portable = Directory('${root.path}/app')..createSync();
      final data = Directory('${root.path}/data')..createSync();
      final model = AppModel(portableDirectory: portable);
      await tester.runAsync(() => model.configure(data.path, '', true));
      model.search('France');
      final candidate = model.visible.firstWhere((e) {
        final doc = EpisodeSearch(e, model.catalog);
        return doc.matches.any((m) => m.tab == 0) &&
            doc.matches.any((m) => m.tab == 1);
      });
      model.select(candidate);
      final document = EpisodeSearch(candidate, model.catalog);
      await tester.pumpWidget(IndeXApp(model: model, window: FakeWindow()));
      await tester.pumpAndSettle();
      final next = find.widgetWithText(OutlinedButton, 'Résultat suivant');
      final previous = find.widgetWithText(
        OutlinedButton,
        'Résultat précédent',
      );
      await tester.ensureVisible(next);
      final headingTop = tester.getTopLeft(
        find.byKey(const ValueKey('episode-detail-heading')),
      );
      final tabsTop = tester.getTopLeft(
        find.byKey(const ValueKey('episode-detail-tabs')),
      );
      final dividerBottom = tester
          .getBottomLeft(find.byKey(const ValueKey('episode-detail-divider')))
          .dy;
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('episode-detail-content')))
            .dy,
        closeTo(dividerBottom, 0.1),
      );
      final colors = EditorialColors(false);
      final theme = Theme.of(tester.element(find.byType(EpisodeDetail)));
      expect(colors.hitInk, theme.colorScheme.primary);
      expect(colors.hitBackground, colors.controls);
      final guide = tester.widget<Container>(
        find.byKey(const ValueKey('search-match-guide')),
      );
      expect((guide.decoration as BoxDecoration).color, colors.controls);
      final button = tester.widget<OutlinedButton>(next);
      expect(button.style!.backgroundColor!.resolve({}), colors.controls);
      expect(
        button.style!.foregroundColor!.resolve({}),
        theme.colorScheme.primary,
      );
      expect(
        find.text(
          'Correspondances encadrées en rouge, utilisez les boutons pour parcourir.',
        ),
        findsNothing,
      );
      for (
        var i = 0;
        i <= document.matches.indexWhere((m) => m.tab == 1);
        i++
      ) {
        await tester.tap(next);
        await tester.pumpAndSettle();
        final target = document.matches[i];
        final texts = tester.widgetList<DocumentText>(
          find.byType(DocumentText),
        );
        expect(
          texts.any(
            (w) => w.segment.id == target.segment && w.active == target.id,
          ),
          isTrue,
        );
        expect(next.hitTestable(), findsOneWidget);
        expect(
          tester.getTopLeft(
            find.byKey(const ValueKey('episode-detail-heading')),
          ),
          headingTop,
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('episode-detail-tabs'))),
          tabsTop,
        );

        final activeText = find.byWidgetPredicate(
          (w) =>
              w is DocumentText &&
              w.segment.id == target.segment &&
              w.active == target.id &&
              target.start >= w.start &&
              target.start < (w.end ?? w.segment.text.length),
        );
        final displayed = tester.widget<DocumentText>(activeText);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: activeText, matching: find.byType(RichText)),
        );
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(
                baseOffset: target.start - displayed.start,
                extentOffset:
                    target.end.clamp(
                      displayed.start,
                      displayed.end ?? displayed.segment.text.length,
                    ) -
                    displayed.start,
              ),
            )
            .first;
        final center = paragraph.localToGlobal(box.toRect().center);
        final viewport = tester.getRect(
          find.byKey(ValueKey('detail-${candidate.id}')),
        );
        expect(
          viewport.contains(center),
          isTrue,
          reason: 'La correspondance doit être visible après navigation.',
        );
      }
      await tester.tap(previous);
      await tester.pumpAndSettle();
      model.search('Portishead');
      await tester.pumpAndSettle();
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      final musicMatches = tester.widgetList<DocumentText>(
        find.byType(DocumentText),
      );
      expect(
        musicMatches.any(
          (w) => w.segment.id.startsWith('music/') && w.active != null,
        ),
        isTrue,
      );
      expect(next.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(model.release);
      model.dispose();
      root.deleteSync(recursive: true);
    },
  );

  testWidgets(
    'Rapport : fichiers à associer en premier, texte copiable et chemins lisibles',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('index-scan-cards-');
      final portable = Directory('${root.path}/app')..createSync();
      final data = Directory('${root.path}/data')..createSync();
      final model = AppModel(portableDirectory: portable);
      await tester.runAsync(() => model.configure(data.path, '', true));
      final path = File(
        [
          root.path,
          'dossier avec espaces',
          'inconnu.mp3',
        ].join(Platform.pathSeparator),
      ).absolute;
      model.report = {
        'count': 2,
        'issues': [
          {'source': path.uri.toString(), 'message': 'Nom inconnu'},
        ],
        'decisions': [
          {
            'audio_reference': 'file:///valide.mp3',
            'current_name': 'valide.mp3',
            'status': 'confirmed',
            'reason': 'Nom exact',
          },
          {
            'audio_reference': path.uri.toString(),
            'current_name': 'inconnu.mp3',
            'status': 'unknown',
            'reason': 'Nom inconnu',
          },
        ],
      };
      model.filesView = true;
      await tester.pumpWidget(IndeXApp(model: model, window: FakeWindow()));
      await tester.pumpAndSettle();
      final cards = find.byType(Card);
      expect(
        find.descendant(of: cards.first, matching: find.text('inconnu.mp3')),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: cards.first, matching: find.byType(SelectionArea)),
        findsOneWidget,
      );
      expect(
        tester.widget<Card>(cards.first).color,
        EditorialColors(false).missing,
      );
      expect(find.textContaining(path.path), findsOneWidget);
      expect(find.textContaining('%20'), findsNothing);
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Diagnostic du scan'),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ScanDiagnostics),
          matching: find.text(path.path),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Fermer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Associer…'));
      await tester.pumpAndSettle();
      expect(find.byType(ManualEpisodePicker), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      model.setTheme(true);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Card>(cards.first).color,
        EditorialColors(true).missing,
      );
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
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(SelectableText),
        ),
        findsOneWidget,
      );
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
