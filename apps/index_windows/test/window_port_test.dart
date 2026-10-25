import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/window_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
