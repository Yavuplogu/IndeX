import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_windows/app.dart';
import 'package:index_windows/app_model.dart';

void main() {
  for (final width in [357.9997, 358.0, 200.0]) {
    testWidgets('Filtre : libellé long sans débordement pour largeur $width', (
      tester,
    ) async {
      CatalogSort selected = CatalogSort.audioFirst;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.08)),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: StatefulBuilder(
                  builder: (context, setState) => FilterMenu<CatalogSort>(
                    menuKey: 'regression-sort-filter',
                    value: selected,
                    labels: sortNames,
                    onChanged: (value) => setState(() => selected = value),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('regression-sort-filter')));
      await tester.pumpAndSettle();
      expect(find.text('MP3 · Disponibles d’abord'), findsWidgets);
      await tester.tap(
        find.byKey(
          const ValueKey('regression-sort-filter-CatalogSort.audioLast'),
        ),
      );
      await tester.pumpAndSettle();
      expect(selected, CatalogSort.audioLast);
      expect(tester.takeException(), isNull);
    });
  }
}
