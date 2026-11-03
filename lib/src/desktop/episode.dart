import 'package:unorm_dart/unorm_dart.dart' as unicode;

import '../search/search_engine.dart';

/// Clé de présentation uniquement ; ne jamais l'utiliser pour une identité métier.
String frenchTitleKey(String value) => unicode
    .nfd(value)
    .toLowerCase()
    .replaceAll(RegExp(r'\p{M}', unicode: true), '')
    .replaceAll('œ', 'oe')
    .replaceAll('æ', 'ae');

final class DesktopEpisode {
  const DesktopEpisode({
    required this.id,
    required this.title,
    required this.date,
    required this.description,
    required this.sourcesText,
    required this.musicText,
    required this.sources,
    required this.music,
    required this.originalName,
    required this.status,
    required this.favorite,
    required this.audioRef,
    required this.audioAvailable,
    required this.positionMs,
    this.downloadUrl,
    this.systemName,
    this.durationMs = 0,
    this.excerpt = '',
    this.markedExcerpt = '',
    this.matchedFields = const {},
    this.markedFields = const {},
  });
  final String id,
      title,
      description,
      sourcesText,
      musicText,
      originalName,
      status;
  final String? date, audioRef, downloadUrl, systemName;
  final bool favorite, audioAvailable;
  final int positionMs, durationMs;
  final String excerpt, markedExcerpt;
  final Set<SearchField> matchedFields;
  final Map<SearchField, String> markedFields;
  final List<Map<String, Object?>> sources, music;

  /// Actualise le suivi sans reconstruire les données documentaires/recherche.
  DesktopEpisode withListening({
    required int positionMs,
    required int durationMs,
    required String status,
  }) => DesktopEpisode(
    id: id,
    title: title,
    date: date,
    description: description,
    sourcesText: sourcesText,
    musicText: musicText,
    sources: sources,
    music: music,
    originalName: originalName,
    status: status,
    favorite: favorite,
    audioRef: audioRef,
    audioAvailable: audioAvailable,
    positionMs: positionMs,
    durationMs: durationMs,
    downloadUrl: downloadUrl,
    systemName: systemName,
    excerpt: excerpt,
    markedExcerpt: markedExcerpt,
    matchedFields: matchedFields,
    markedFields: markedFields,
  );
}
