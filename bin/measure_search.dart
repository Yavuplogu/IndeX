import 'dart:convert';
import 'dart:io';

import 'package:index_core/index_storage.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.open('assets/catalogue.sqlite', mode: OpenMode.readOnly);
  try {
    final engine = SqliteSearchEngine(db);
    const queries = [
      'rwanda',
      'Pasolini',
      'guerre froide',
      'algerie',
      'espionnage',
      'Bizerte',
    ];
    for (var i = 0; i < 20; i++) {
      for (final query in queries) {
        engine.search(query);
      }
    }
    final times = <int>[];
    for (var i = 0; i < 100; i++) {
      for (final query in queries) {
        final watch = Stopwatch()..start();
        engine.search(query);
        times.add(watch.elapsedMicroseconds);
      }
    }
    times.sort();
    final report = {
      'platform': Platform.operatingSystem,
      'sqlite_version': sqlite3.version.libVersion,
      'catalog_version': db
          .select('SELECT version FROM catalog_versions')
          .single['version'],
      'queries': queries,
      'warmup_queries': 120,
      'measured_queries': times.length,
      'limit': 30,
      'unit': 'microseconds',
      'p50': times[(times.length * .5).ceil() - 1],
      'p95': times[(times.length * .95).ceil() - 1],
      'max': times.last,
      'scope': 'Moteur Dart natif sur hôte Linux cloud ; hors UI, hors plateformes cibles.',
    };
    File('docs/lot3/search-measurements.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
    stdout.writeln(jsonEncode(report));
  } finally {
    db.close();
  }
}
