import 'dart:typed_data';

import '../diagnostic.dart';

enum Id3Status { absent, readable, invalid, unsupported }

/// Source limitée au préfixe ; renvoie moins d'octets seulement à EOF.
/// Un adaptateur SAF pourra fournir le même contrat sans chemin de fichier.
abstract interface class TagByteSource {
  Future<Uint8List> readPrefix(int count);
}

final class CommFrame {
  CommFrame({
    required this.index,
    required this.language,
    required this.description,
    required this.text,
    required this.encoding,
    required List<int> rawPayload,
  }) : rawPayload = List.unmodifiable(rawPayload);

  /// Indice de la trame dans le tag, y compris les trames autres que COMM.
  final int index;
  final String language;
  final String description;
  final String text;
  final int encoding;

  /// Charge utile désynchronisée décodée, avant retrait des terminateurs texte.
  final List<int> rawPayload;
}

final class Id3ReadResult {
  Id3ReadResult({
    required this.status,
    required this.majorVersion,
    required List<CommFrame> comments,
    required List<Diagnostic> issues,
  }) : comments = List.unmodifiable(comments),
       issues = List.unmodifiable(issues);
  final Id3Status status;
  final int? majorVersion;
  final List<CommFrame> comments;
  final List<Diagnostic> issues;
  bool get isTrustworthy =>
      (status == Id3Status.readable || status == Id3Status.absent) &&
      !issues.any((i) => i.severity == Severity.error);
}
