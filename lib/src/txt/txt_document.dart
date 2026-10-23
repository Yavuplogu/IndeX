import '../diagnostic.dart';

final class TxtSection {
  const TxtSection(this.label, this.rawContent, this.offset);
  final String label;

  /// Contenu exact après le libellé ; CRLF/NEL et séparateurs finaux conservés.
  final String rawContent;
  final int offset;
  String get value => rawContent.trim();
}

final class LiterarySource {
  const LiterarySource({
    required this.rawText,
    this.title,
    this.author,
    this.publisher,
  });
  final String rawText;
  final String? title;
  final String? author;
  final String? publisher;
}

final class MusicTrack {
  const MusicTrack({
    required this.rawText,
    this.artist,
    this.title,
    this.album,
    this.label,
  });
  final String rawText;
  final String? artist;
  final String? title;
  final String? album;
  final String? label;
}

final class TxtDocument {
  TxtDocument({
    required this.rawText,
    required this.hadBom,
    required List<TxtSection> sections,
    required List<LiterarySource> sources,
    required List<MusicTrack> music,
    required this.originalName,
    required this.isoDate,
    required this.displayDate,
    required this.broadcastDate,
  }) : sections = List.unmodifiable(sections),
       sources = List.unmodifiable(sources),
       music = List.unmodifiable(music);
  final String rawText;
  final bool hadBom;
  final List<TxtSection> sections;
  final List<LiterarySource> sources;
  final List<MusicTrack> music;
  final String? originalName;
  final DateTime? isoDate;
  final DateTime? displayDate;

  /// Null en cas de contradiction entre les deux dates.
  final DateTime? broadcastDate;

  TxtSection? section(String label) {
    final found = sections.where((s) => s.label == label).toList();
    return found.length == 1 ? found.single : null;
  }

  String? value(String label) => section(label)?.value;
  String? get title => value('TITRE');
  String? get description => value("DESCRIPTION DE L'EPISODE");
  String? get sourceText => value('LIVRES ET SOURCES');
  String? get musicText => value('MUSIQUES DIFFUSÉES');
  String? get originalNameRaw => value("FICHIER MP3 D'ORIGINE");
  String? get pageUrl => value("PAGE DE L'EMISSION");
  String? get mp3Url => value('URL MP3');
}

final class TxtParseResult {
  TxtParseResult({
    required List<int> sourceBytes,
    required this.document,
    required List<Diagnostic> issues,
  }) : sourceBytes = List.unmodifiable(sourceBytes),
       issues = List.unmodifiable(issues);
  final List<int> sourceBytes;
  final TxtDocument? document;
  final List<Diagnostic> issues;
  bool get hasErrors => issues.any((i) => i.severity == Severity.error);
}
