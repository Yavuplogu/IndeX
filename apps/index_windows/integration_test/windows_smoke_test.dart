import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';
import 'package:index_windows/window_port.dart';
import 'package:window_manager/window_manager.dart';

final class TestWindow implements WindowPort {
  @override
  Future<void> destroy() async {}
  @override
  Future<void> minimize() async {}
  @override
  Future<void> maximizeOrRestore() async {}
}

final class CloseProbe with WindowListener {
  final closed = Completer<void>();
  @override
  void onWindowClose() {
    if (!closed.isCompleted) closed.complete();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows natif : seed, FTS5, écriture/reprise, scan et interception fermeture',
    (tester) async {
      expect(Platform.isWindows, isTrue);
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(true);
      final probe = CloseProbe();
      windowManager.addListener(probe);
      final root = Directory.systemTemp.createTempSync('index-windows-smoke-');
      final portable = Directory('${root.path}/app')..createSync(),
          data = Directory('${root.path}/donnees')..createSync();
      var model = AppModel(portableDirectory: portable);
      try {
        await tester.runAsync(() => model.configure(data.path, '', true));
        expect(model.error, isEmpty);
        expect(model.catalog, hasLength(716));
        await tester.pumpWidget(IndeXApp(model: model, window: TestWindow()));
        await tester.pumpAndSettle();
        model.search('Pasolini');
        expect(model.visible, isNotEmpty);
        model.search('');
        final episode = model.catalog.first;
        model.favorite(episode);
        model.listened(model.catalog.firstWhere((e) => e.id == episode.id));
        const fixture = String.fromEnvironment('INDEX_TEST_MP3_DIR');
        expect(fixture, isNotEmpty);
        await tester.runAsync(() => model.scan(fixture));
        expect(model.error, isEmpty);
        expect(model.catalog.where((e) => e.audioAvailable), hasLength(6));
        await tester.runAsync(() => windowManager.close());
        await tester.runAsync(
          () => probe.closed.future.timeout(const Duration(seconds: 5)),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(model.closeSafely);
        model.dispose();
        model = AppModel(portableDirectory: portable);
        await tester.runAsync(model.boot);
        expect(model.error, isEmpty);
        final saved = model.catalog.firstWhere((e) => e.id == episode.id);
        expect(saved.favorite, isTrue);
        expect(saved.status, 'ECOUTE');
        expect(
          File('${data.path}/sauvegardes/IndeX_derniere_sauvegarde.sqlite')
              .existsSync(),
          isTrue,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(model.release);
        model.dispose();
        windowManager.removeListener(probe);
        await windowManager.setPreventClose(false);
        root.deleteSync(recursive: true);
      }
    },
  );
}
