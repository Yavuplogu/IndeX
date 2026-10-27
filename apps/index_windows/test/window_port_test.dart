import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/window_port.dart';
import 'package:index_windows/app_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Ouverture native : dossier cible transmis séparément, antislashs et Unicode conservés', () async {
    const channel = MethodChannel('index/local_folders');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await openNativeFolder(
      "E:/Sauvegarde TAF-PERSO/Zik/Podcasts/Rendez-vous avec X/Été",
    );
    expect(calls.single.method, 'openDirectory');
    expect(
      calls.single.arguments,
      r'E:\Sauvegarde TAF-PERSO\Zik\Podcasts\Rendez-vous avec X\Été',
    );
    await openNativeFolder(r'\\serveur\partage MP3\été');
    expect(calls.last.arguments, r'\\serveur\partage MP3\été');
  });

  test(
    'Fermeture native autorisée puis WM_CLOSE, sans sortie forcée du plugin',
    () async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('window_manager');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await NativeWindowPort().destroy();
      expect(calls.map((c) => c.method), ['setPreventClose', 'close']);
      expect(calls.first.arguments, {'isPreventClose': false});
    },
  );
}
