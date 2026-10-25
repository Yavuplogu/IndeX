import 'package:unorm_dart/unorm_dart.dart' as unicode;

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
    this.excerpt = '',
  });
  final String id,
      title,
      description,
      sourcesText,
      musicText,
      originalName,
      status;
  final String? date, audioRef;
  final bool favorite, audioAvailable;
  final int positionMs;
  final String excerpt;
  final List<Map<String, Object?>> sources, music;
}
