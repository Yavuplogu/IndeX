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
    'Démarrage sans MP3 reproposé après réouverture, favoris conservés',
    () async {
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
      expect(model!.needsSetup, isTrue);
      expect(model!.catalog.firstWhere((e) => e.id == id).favorite, isTrue);
      expect(model!.dataPath, data.path);
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
    },
  );
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
