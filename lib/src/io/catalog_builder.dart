import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import '../catalog/planner.dart';
import '../storage/catalog_store.dart';
import '../storage/migrations.dart';
import '../search/sqlite_search_engine.dart';
import 'catalog_sources.dart';

/// Génération de développement : aucune application ni audio ne doit être lancé.
Future<Map<String, Object?>> buildCatalog({
  required Directory txtDirectory,
  File? journal,
  required File output,
  required String version,
  required DateTime generatedAt,
  bool replace = false,
}) async {
  if (!output.path.toLowerCase().endsWith('.sqlite'))
    throw ArgumentError(
      'La sortie doit être un nouveau catalogue .sqlite, jamais un fichier source.',
    );
  final target = output.absolute.uri.normalizePath().toString();
  final txtRoot = txtDirectory.absolute.uri.normalizePath().toString();
  if (target.startsWith(txtRoot) ||
      target == journal?.absolute.uri.normalizePath().toString()) {
    throw ArgumentError(
      'La sortie ne doit pas remplacer une source ni être créée dans le dossier TXT.',
    );
  }
  if (version.trim().isEmpty) throw ArgumentError('Version de catalogue vide.');
  if (await output.exists() && !replace)
    throw StateError('Le catalogue existe ; utiliser explicitement --replace.');
  if (journal != null && await journal.length() > 16 * 1024 * 1024)
    throw const FormatException('CSV trop volumineux.');
  final inputs = await loadTxtDirectory(txtDirectory);
  final plan = CatalogPlanner().plan(
    inputs,
    journalBytes: journal == null ? null : await journal.readAsBytes(),
  );
  if (!plan.canApply || plan.episodes.isEmpty)
    throw const FormatException(
      'Aucun catalogue exploitable ; sources et catalogue existant inchangés.',
    );
  await output.parent.create(recursive: true);
  final temporary = await output.parent.createTemp('.index-build-');
  final file = File('${temporary.path}/catalogue.sqlite');
  final store = CatalogStore.open(file.path);
  var closed = false;
  try {
    final outcome = store.importPlan(
      plan,
      now: generatedAt,
      catalogVersion: version,
    );
    if (store.database.select('PRAGMA integrity_check').single.values.single !=
            'ok' ||
        store.database.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw StateError('Contrôle d’intégrité du catalogue échoué.');
    }
    SqliteSearchEngine(store.database).checkIndex();
    final counts = {
      for (final name in [
        'episodes',
        'literary_sources',
        'music_tracks',
        'local_audio_links',
        'user_episode_state',
        'source_records',
      ])
        name:
            store.database.select('SELECT count(*) AS n FROM $name').single['n']
                as int,
    };
    store.database.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    store.database.execute('PRAGMA journal_mode=DELETE');
    store.database.execute('VACUUM');
    store.close();
    closed = true;
    final checksum = (await sha256.bind(file.openRead()).first).toString();
    final report = <String, Object?>{
      'catalog_version': version,
      'schema_version': schemaVersion,
      'generated_at': generatedAt.toUtc().toIso8601String(),
      'sqlite_version': sqlite3.version.libVersion,
      'sqlite_sha256': checksum,
      'sqlite_bytes': await file.length(),
      'summary': {...plan.summary(), ...outcome.toJson(), ...counts},
      'issues': plan.issues.map((i) => i.toJson()).toList(),
      'capabilities': {
        'embedded_audio': false,
        'local_links_in_seed': false,
        'search_index': true,
      },
    };
    // Un fichier final n'est publié qu'après fermeture de SQLite et vérification.
    await file.rename(output.path);
    final manifest = File('${output.path}.manifest.json');
    await manifest.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
      flush: true,
    );
    return report;
  } finally {
    if (!closed) store.close();
    await temporary.delete(recursive: true);
  }
}
