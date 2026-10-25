import 'package:index_core/index_core.dart';
import 'package:index_core/index_desktop.dart';

import 'document_text.dart';

List<DesktopEpisode> relatedEpisodes(String raw, List<DesktopEpisode> catalog) {
  final byName = {for (final e in catalog) e.originalName: e};
  return [
    for (final ref in RegExp(r'\(([^()]+\.mp3)\)').allMatches(raw))
      if (byName.containsKey(ref[1])) byName[ref[1]]!,
  ];
}

/// Index the text actually displayed, using only words highlighted by FTS5 in
/// the corresponding selected field. Hidden filenames never become UI matches.
class EpisodeSearch {
  EpisodeSearch(DesktopEpisode episode, List<DesktopEpisode> catalog) {
    final words = <SearchField, Set<String>>{};
    for (final field in SearchField.values) {
      words[field] = {
        for (final marked in RegExp(
          '\u0001(.*?)\u0002',
          dotAll: true,
        ).allMatches(episode.markedFields[field] ?? ''))
          for (final word in tokens.allMatches(marked[1]!))
            frenchTitleKey(word[0]!),
      };
    }
    void add(String id, String value, SearchField field, int tab) {
      final found = <DocumentMatch>[];
      for (final word in tokens.allMatches(value)) {
        if (words[field]!.contains(frenchTitleKey(word[0]!))) {
          found.add(
            DocumentMatch('$id:${word.start}', id, tab, word.start, word.end),
          );
        }
      }
      segments[id] = TextSegment(id, value, found);
      matches.addAll(found);
    }

    add('title', episode.title, SearchField.title, 0);
    add('summary', episode.description, SearchField.description, 0);
    for (final (i, source) in episode.sources.indexed) {
      for (final field in ['title', 'author', 'publisher']) {
        add(
          'source/$i/$field',
          source[field]?.toString() ?? '',
          SearchField.sources,
          1,
        );
      }
      for (final (j, related) in relatedEpisodes(
        source['raw_text'] as String? ?? '',
        catalog,
      ).indexed) {
        add(
          'source/$i/related/$j/title',
          related.title,
          SearchField.sources,
          1,
        );
      }
    }
    for (final (i, music) in episode.music.indexed) {
      for (final field in ['title', 'artist', 'album', 'label']) {
        add(
          'music/$i/$field',
          music[field]?.toString() ?? '',
          SearchField.music,
          2,
        );
      }
    }
  }
  static final tokens = RegExp(
    r'[\p{L}\p{N}][\p{L}\p{N}\p{M}]*',
    unicode: true,
  );
  final segments = <String, TextSegment>{};
  final matches = <DocumentMatch>[];
}
