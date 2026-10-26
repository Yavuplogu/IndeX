import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root, portable, data;
  AppModel? model;
  setUp(() {
    root = Directory.systemTemp.createTempSync('index-model-');
    portable = Directory('${root.path}/app')..createSync();
    data = Directory('${root.path}/data')..createSync();
  });
  tearDown(() async {
    await model?.release();
    model?.dispose();
    root.deleteSync(recursive: true);
  });
  test(
    'Premier démarrage : dossier user proposé vide, autre emplacement conservé',
    () async {
      final defaultData = Directory('${root.path}/IndeX/user');
      model = AppModel(
        portableDirectory: portable,
        defaultDataDirectory: defaultData,
      );
      await model!.boot();
      expect(model!.needsSetup, isTrue);
      expect(model!.dataPath, defaultData.absolute.path);
      expect(defaultData.listSync(), isEmpty);
      expect(
        File('${portable.path}/index-portable.json').existsSync(),
        isFalse,
      );
      await model!.configure(data.path, '', true);
      expect(model!.error, isEmpty);
      expect(
        FileSystemEntity.identicalSync(model!.dataPath, data.path),
        isTrue,
      );
      expect(defaultData.listSync(), isEmpty);
    },
  );

  test('Scan au lancement optionnel, réglages persistants et scan manuel disponible', () async {
    final mp3 = Directory('${root.path}/mp3')..createSync();
    model = AppModel(portableDirectory: portable);
    await model!.configure(data.path, mp3.path, false);
    expect(model!.skipStartupScan, isFalse);
    final count = model!.session!.store.database
        .select('SELECT count(*) AS n FROM audio_scan_runs')
        .single['n'];
    model!.setSkipStartupScan(true);
    model!.setRecursive(true);
    await model!.closeSafely();
    model!.dispose();
    model = AppModel(portableDirectory: portable);
    await model!.boot();
    expect(model!.error, isEmpty);
    expect(model!.skipStartupScan, isTrue);
    expect(model!.recursive, isTrue);
    expect(
      model!.session!.store.database
          .select('SELECT count(*) AS n FROM audio_scan_runs')
          .single['n'],
      count,
    );
    final sub = Directory('${mp3.path}/sous dossier')..createSync();
    File('${sub.path}/inconnu.mp3').writeAsBytesSync([]);
    await model!.scan(mp3.path);
    expect(model!.report!['count'], 1);
    model!.setSkipStartupScan(false);
    await model!.closeSafely();
    model!.dispose();
    model = AppModel(portableDirectory: portable);
    await model!.boot();
    expect(model!.error, isEmpty);
    expect(model!.skipStartupScan, isFalse);
    expect(model!.report!['count'], 1);
    expect(
      model!.session!.store.database
          .select('SELECT count(*) AS n FROM audio_scan_runs')
          .single['n'],
      (count as int) + 2,
    );
  });

  test(
    'Compteurs MP3 globaux indépendants des filtres et chemins lisibles',
    () async {
      model = AppModel(portableDirectory: portable);
      await model!.configure(
        data.path,
        Directory('../../MP3_Files').absolute.path,
        false,
      );
      expect(model!.availableAudioCount, 6);
      expect(model!.missingAudioCount, 710);
      expect(model!.episodeCountLabel, '716 / 6 épisodes · 710 MP3 absents');
      model!.search('Masque');
      expect(model!.visible.length, lessThan(716));
      expect(
        model!.episodeCountLabel,
        '${model!.visible.length} / 6 épisodes · 710 MP3 absents',
      );
      final file = File(
        [
          root.path,
          'dossier avec espaces',
          'nom à copier.mp3',
        ].join(Platform.pathSeparator),
      );
      final ref = file.absolute.uri.toString();
      expect(ref, contains('%20'));
      expect(displayDiagnosticPath(ref), file.absolute.path);
      expect(displayDiagnosticPath('50% de progression'), '50% de progression');
      final literalPercent = File(
        [root.path, 'nom%20littéral.mp3'].join(Platform.pathSeparator),
      );
      expect(
        displayDiagnosticPath(literalPercent.absolute.uri.toString()),
        literalPercent.absolute.path,
      );
      model!.report = {
        'count': 1,
        'issues': [
          {'source': ref, 'message': 'Erreur de test'},
        ],
        'decisions': [
          {'audio_reference': ref, 'current_name': 'nom à copier.mp3'},
        ],
      };
      final exported = await model!.exportScanDiagnostic();
      final text = await exported.readAsString();
      expect(text, contains(file.absolute.path));
      expect(text, isNot(contains('%20')));
      expect(
        (model!.report!['decisions'] as List).single['audio_reference'],
        ref,
      );
    },
  );

  test('Réouverture sans MP3 sans formulaire, favoris conservés', () async {
    model = AppModel(portableDirectory: portable);
    await model!.configure(data.path, '', true);
    expect(model!.error, isEmpty);
    expect(model!.needsSetup, isFalse);
    final id = model!.catalog.first.id;
    model!.favorite(model!.catalog.first);
    await model!.closeSafely();
    model!.dispose();
    model = AppModel(portableDirectory: portable);
    await model!.boot();
    expect(model!.error, isEmpty);
    expect(model!.needsSetup, isFalse);
    expect(model!.catalog.firstWhere((e) => e.id == id).favorite, isTrue);
    expect(FileSystemEntity.identicalSync(model!.dataPath, data.path), isTrue);
    model!.sort = CatalogSort.titleAZ;
    model!.reload();
    final first = model!.visible.indexWhere((e) => e.title == "L'échange");
    final second = model!.visible.indexWhere(
      (e) => e.title == "L'espionnage chinois au Etats-Unis",
    );
    expect(first, greaterThanOrEqualTo(0));
    expect(second, greaterThan(first));
    model!.sort = CatalogSort.titleZA;
    model!.reload();
    expect(
      model!.visible.indexWhere((e) => e.title == "L'échange"),
      greaterThan(
        model!.visible.indexWhere(
          (e) => e.title == "L'espionnage chinois au Etats-Unis",
        ),
      ),
    );
  });
  test('Configuration invalide ne permet pas de créer un suivi vide', () async {
    File('${portable.path}/index-portable.json')
        .writeAsStringSync('{"version":99}');
    model = AppModel(portableDirectory: portable);
    await model!.boot();
    expect(model!.error, isNotEmpty);
    expect(model!.requireExisting, isTrue);
    await model!.configure(data.path, '', true);
    expect(model!.error, isNotEmpty);
    expect(File('${data.path}/index-utilisateur.sqlite').existsSync(), isFalse);
  });
  test(
    'Dossier connu scanné au démarrage et indisponibilité distincte',
    () async {
      final mp3 = Directory('../../MP3_Files').absolute.path;
      model = AppModel(portableDirectory: portable);
      await model!.configure(data.path, mp3, false);
      expect(model!.error, isEmpty);
      expect(model!.catalog.where((e) => e.audioAvailable), hasLength(6));
      await model!.closeSafely();
      model!.dispose();
      model = AppModel(portableDirectory: portable);
      await model!.boot();
      expect(model!.error, isEmpty);
      expect(model!.needsSetup, isFalse);
      expect(model!.report!['count'], 6);
      await model!.scan('${root.path}/disparu');
      expect(model!.audioState, AudioFolderState.unavailable);
      expect(model!.folderLabel, contains('inaccessible'));
    },
  );
}
