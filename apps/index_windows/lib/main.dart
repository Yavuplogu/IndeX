import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'app_model.dart';
import 'window_port.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    final path = await AppModel.androidChannel.invokeMethod<String>(
      'privateDirectory',
    );
    final directory = Directory(path!);
    final model = AppModel(
      portableDirectory: directory,
      defaultDataDirectory: directory,
      android: true,
    );
    final boot = model.boot();
    runApp(IndeXApp(model: model, window: AndroidWindowPort()));
    await boot;
    return;
  }
  if (!Platform.isWindows) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Ce livrable est destiné à Windows.')),
        ),
      ),
    );
    return;
  }
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  final model = AppModel(
    portableDirectory: File(Platform.resolvedExecutable).parent,
    defaultDataDirectory: Directory(
      '${File(Platform.resolvedExecutable).parent.parent.path}/user',
    ),
  );
  final boot = model.boot();
  runApp(
    IndeXApp(model: model, window: NativeWindowPort(), nativeWindow: true),
  );
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'IndeX',
      size: Size(1440, 900),
      minimumSize: Size(1024, 740),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    ),
  );
  // Ne montrer la fenêtre qu'après la création des widgets et l'enregistrement
  // du listener de fermeture, au lieu d'exposer un HWND encore en démarrage.
  await WidgetsBinding.instance.endOfFrame;
  await windowManager.show();
  await windowManager.focus();
  await boot;
}

final class AndroidWindowPort implements WindowPort {
  @override
  Future<void> destroy() => SystemNavigator.pop();
  @override
  Future<void> minimize() async {}
  @override
  Future<void> maximizeOrRestore() async {}
}
