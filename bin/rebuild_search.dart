import 'dart:io';

import 'package:index_core/index_storage.dart';

void main(List<String> args) {
  if (args.length != 1) {
    throw ArgumentError(
      'Usage : dart run bin/rebuild_search.dart BASE_UTILISATEUR.sqlite',
    );
  }
  if (!File(args.single).existsSync()) {
    throw ArgumentError('Base existante requise.');
  }
  final store = CatalogStore.open(args.single);
  try {
    SqliteSearchEngine(store.database).rebuildIndex();
    stdout.writeln('Index FTS5 reconstruit et vérifié.');
  } finally {
    store.close();
  }
}
