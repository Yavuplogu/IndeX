import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'app_model.dart';
import 'window_port.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  );
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
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  await model.boot();
}
