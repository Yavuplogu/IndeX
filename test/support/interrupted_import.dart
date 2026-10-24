import 'dart:io';

import 'package:index_core/index_storage.dart';

import 'catalog_fixtures.dart';

void main(List<String> args) {
  final store = CatalogStore.open(args.single);
  store.importPlan(
    plan(description: 'Transaction interrompue'),
    afterEpisode: (_) {
      stdout.writeln('transaction-open');
      stdin.readLineSync();
    },
  );
  store.close();
}
