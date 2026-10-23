import 'package:unorm_dart/unorm_dart.dart' as unicode;

/// N'altère ni chemin ni titre ; seul un nom complet .mp3 est candidat.
String? canonicalOriginalName(String raw) {
  var name = unicode.nfc(raw.trim());
  for (final pair in [('"', '"'), ("'", "'"), ('«', '»'), ('“', '”')]) {
    if (name.startsWith(pair.$1) &&
        name.endsWith(pair.$2) &&
        name.length >= 2) {
      name = name
          .substring(pair.$1.length, name.length - pair.$2.length)
          .trim();
      break;
    }
  }
  if (name.length > 255 ||
      RegExp(r'[\x00-\x1f\x7f/\\:*?"<>|]').hasMatch(name) ||
      name.contains('..') ||
      !RegExp(r'^.+\.[mM][pP]3$').hasMatch(name)) {
    return null;
  }
  // Les autres noms Unicode restent sensibles à la casse : pas de fusion large.
  if (RegExp(
    r'^mr_x_\d{4}_\d{2}_\d{2}\.mp3$',
    caseSensitive: false,
  ).hasMatch(name)) {
    return name.toLowerCase();
  }
  return name;
}
