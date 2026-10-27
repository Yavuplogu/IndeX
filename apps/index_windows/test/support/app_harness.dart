import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/window_port.dart';

final class FakeWindow implements WindowPort {
  FakeWindow({this.destroyGate});
  final Future<void>? destroyGate;
  bool closeRequested = false;
  int destroyed = 0;
  @override
  Future<void> destroy() async {
    closeRequested = true;
    if (destroyGate != null) await destroyGate;
    destroyed++;
  }

  @override
  Future<void> minimize() async {}
  @override
  Future<void> maximizeOrRestore() async {}
}

// pumpAndSettle ne fait pas attendre les E/S réelles : leur laisser progresser
// jusqu'à l'état attendu, avec un délai maximal, puis terminer les animations.
Future<void> waitForCondition(
  WidgetTester tester,
  bool Function() condition,
  String description,
) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 20)) {
      fail('État attendu non atteint : $description');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

Future<void> waitForWidget(WidgetTester tester, Finder finder) =>
    waitForCondition(
      tester,
      () => finder.evaluate().isNotEmpty,
      finder.toString(),
    );
