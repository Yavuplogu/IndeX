import 'package:window_manager/window_manager.dart';

abstract interface class WindowPort {
  Future<void> minimize();
  Future<void> maximizeOrRestore();
  Future<void> destroy();
}

final class NativeWindowPort implements WindowPort {
  @override
  Future<void> minimize() => windowManager.minimize();
  @override
  Future<void> maximizeOrRestore() async {
    if (await windowManager.isMaximized())
      await windowManager.restore();
    else
      await windowManager.maximize();
  }

  @override
  Future<void> destroy() async {
    // La sauvegarde est déjà validée. Repasser par WM_CLOSE pour laisser le
    // runner détruire le moteur et les plugins avant de quitter la boucle.
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }
}
