import 'package:sqlite3/sqlite3.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'search_engine.dart';

/// Utilise une connexion appartenant au CatalogStore ; ne la ferme jamais.
final class SqliteSearchEngine implements SearchEngine {
  SqliteSearchEngine(this.database);
  final Database database;
  static final _tokens = RegExp(
    r'[\p{L}\p{N}][\p{L}\p{N}\p{M}]*',
    unicode: true,
  );

  @override
  List<SearchHit> search(
    String query, {
    SearchOptions options = const SearchOptions(),
  }) {
    if (options.fields.isEmpty)
      throw ArgumentError('Choisir au moins un champ.');
    if (query.length > 512)
      throw ArgumentError('Requête limitée à 512 caractères.');
    if (options.limit < 1 ||
        options.limit > 100 ||
        options.offset < 0 ||
        options.offset > 10000) {
      throw ArgumentError('Pagination hors limites.');
    }
    String? date(DateTime? value) {
      if (value == null) return null;
      if (value.year < 1 || value.year > 9999)
        throw ArgumentError('Année invalide.');
      return '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
    }

    final from = date(options.fromDate), to = date(options.toDate);
    if (from != null && to != null && from.compareTo(to) > 0) {
      throw ArgumentError('Intervalle de dates inversé.');
    }
    final terms = _tokens
        .allMatches(unorm.nfc(query))
        .map((m) => m[0]!)
        .toList();
    if (terms.length > 32) throw ArgumentError('Requête limitée à 32 termes.');
    if (terms.isEmpty) return const [];
    // Chaque terme est cité ; aucune syntaxe SQL ou FTS utilisateur n'est exécutée.
    // Plusieurs termes sont combinés avec AND, sans imposer leur ordre.
    const columns = {
      SearchField.title: 'title',
      SearchField.description: 'description',
      SearchField.sources: 'sources_text',
      SearchField.music: 'music_text',
    };
    final selected = SearchField.values
        .where(options.fields.contains)
        .map((f) => columns[f]!)
        .join(' ');
    final match =
        '{$selected} : (' +
        terms.map((t) => '"$t"${options.prefix ? "*" : ""}').join(' AND ') +
        ')';
    final conditions = <String>['episodes_fts MATCH ?'];
    final parameters = <Object?>[match];
    if (from != null) {
      conditions.add('e.broadcast_date>=?');
      parameters.add(from);
    }
    if (to != null) {
      conditions.add('e.broadcast_date<=?');
      parameters.add(to);
    }
    if (options.audioAvailable != null) {
      conditions.add('COALESCE(l.available,0)=?');
      parameters.add(options.audioAvailable! ? 1 : 0);
    }
    if (options.hasSources != null) {
      conditions.add(
        '${options.hasSources! ? '' : 'NOT '}EXISTS(SELECT 1 FROM literary_sources s WHERE s.episode_id=e.id)',
      );
    }
    parameters.addAll([options.limit, options.offset]);
    return [
      for (final row in database.select('''
SELECT e.id,e.title,e.broadcast_date,COALESCE(l.available,0) AS audio_available,
 bm25(episodes_fts,10.0,1.0,2.0,1.0) AS score,
 snippet(episodes_fts,-1,'','',' … ',32) AS excerpt,
 snippet(episodes_fts,-1,char(1),char(2),' … ',32) AS marked_excerpt,
 ${[for (var i = 0; i < 4; i++) "instr(highlight(episodes_fts,$i,char(1),char(2)),char(1)) AS hit_$i"].join(',')}
FROM episodes_fts JOIN episodes e ON e.rowid=episodes_fts.rowid
LEFT JOIN local_audio_links l ON l.episode_id=e.id
WHERE ${conditions.join(' AND ')}
ORDER BY score,e.broadcast_date DESC,e.id LIMIT ? OFFSET ?
''', parameters))
        SearchHit(
          episodeId: row['id'] as String,
          title: row['title'] as String,
          broadcastDate: row['broadcast_date'] == null
              ? null
              : DateTime.parse(row['broadcast_date'] as String),
          excerpt: row['excerpt'] as String,
          markedExcerpt: row['marked_excerpt'] as String,
          matchedFields: {
            for (final (i, field) in SearchField.values.indexed)
              if ((row['hit_$i'] as int) > 0) field,
          },
          score: (row['score'] as num).toDouble(),
          audioAvailable: row['audio_available'] == 1,
        ),
    ];
  }

  /// Vérifie aussi la concordance de l'index externe avec les données documentaires.
  void checkIndex() => database.execute(
    "INSERT INTO episodes_fts(episodes_fts,rank) VALUES('integrity-check',1)",
  );

  /// Reconstruction atomique ; les métadonnées et données personnelles restent intactes.
  void rebuildIndex() {
    database.execute('BEGIN IMMEDIATE');
    try {
      database.execute(
        "INSERT INTO episodes_fts(episodes_fts) VALUES('rebuild')",
      );
      checkIndex();
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }
}
