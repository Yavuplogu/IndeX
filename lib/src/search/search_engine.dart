/// Contrat interchangeable ; aucune dépendance SQLite ou interface graphique.
abstract interface class SearchEngine {
  List<SearchHit> search(
    String query, {
    SearchOptions options = const SearchOptions(),
  });
}

enum SearchField { title, description, sources, music }

final class SearchOptions {
  const SearchOptions({
    this.fields = const {
      SearchField.title,
      SearchField.description,
      SearchField.sources,
      SearchField.music,
    },
    this.limit = 30,
    this.offset = 0,
    this.fromDate,
    this.toDate,
    this.audioAvailable,
    this.hasSources,
    this.prefix = false,
  });
  final Set<SearchField> fields;
  final bool prefix;
  final int limit, offset;
  final DateTime? fromDate, toDate;
  final bool? audioAvailable, hasSources;
}

final class SearchHit {
  const SearchHit({
    required this.episodeId,
    required this.title,
    required this.broadcastDate,
    required this.excerpt,
    required this.score,
    required this.audioAvailable,
    this.markedExcerpt = '',
    this.matchedFields = const {},
  });
  final String episodeId, title;
  final DateTime? broadcastDate;

  /// Texte brut (aucun HTML). Les extraits ne doivent pas être interprétés comme du balisage.
  final String excerpt;

  /// Marqueurs FTS internes U+0001/U+0002, jamais du HTML.
  final String markedExcerpt;
  final Set<SearchField> matchedFields;

  /// BM25 SQLite : les valeurs les plus petites sont les plus pertinentes.
  final double score;
  final bool audioAvailable;
}
