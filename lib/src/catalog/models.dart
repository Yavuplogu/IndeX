import 'dart:typed_data';

import '../diagnostic.dart';
import '../txt/txt_document.dart';

final class CatalogIssue {
  const CatalogIssue(
    this.code,
    this.message, {
    this.source,
    this.originalName,
    this.severity = Severity.warning,
  });
  final String code;
  final String message;
  final String? source;
  final String? originalName;
  final Severity severity;
  Map<String, Object?> toJson() => {
    'code': code,
    'severity': severity.name,
    'source': source,
    'original_name': originalName,
    'message': message,
  };
}

final class TxtInput {
  TxtInput(this.path, List<int> bytes, {this.readError})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  /// Chemin relatif de provenance, jamais une instruction d'accès disque.
  final String path;
  final Uint8List bytes;
  final String? readError;
}

final class SourceRecord {
  SourceRecord({
    required this.kind,
    required this.key,
    required this.disposition,
    this.originalName,
    List<int>? bytes,
    Map<String, String>? fields,
  }) : bytes = bytes == null
           ? null
           : Uint8List.fromList(bytes).asUnmodifiableView(),
       fields = fields == null ? null : Map.unmodifiable(fields);
  final String kind;
  final String key;
  final String disposition;
  final String? originalName;
  final Uint8List? bytes;
  final Map<String, String>? fields;
}

final class CatalogEpisode {
  const CatalogEpisode({
    required this.originalName,
    required this.document,
    required this.sourcePath,
    required this.sourceBytes,
    required this.fingerprint,
    required this.needsReview,
    this.systemName,
    this.journalStatus,
    this.journalFields,
  });
  final String originalName;
  String get id => 'mrx:$originalName';
  final TxtDocument document;
  final String sourcePath;
  final List<int> sourceBytes;
  final String fingerprint;
  final bool needsReview;
  final String? systemName;
  final String? journalStatus;
  final Map<String, String>? journalFields;
}

final class CatalogPlan {
  CatalogPlan({
    required List<CatalogEpisode> episodes,
    required List<CatalogIssue> issues,
    required List<SourceRecord> records,
    required this.sourceDigest,
    required this.txtCount,
    required this.journalRows,
    required this.canApply,
  }) : episodes = List.unmodifiable(episodes),
       issues = List.unmodifiable(issues),
       records = List.unmodifiable(records);
  final List<CatalogEpisode> episodes;
  final List<CatalogIssue> issues;
  final List<SourceRecord> records;
  final String sourceDigest;
  final int txtCount;
  final int? journalRows;
  final bool canApply;
  Map<String, Object?> summary() => {
    'txt_count': txtCount,
    'journal_rows': journalRows,
    'episodes': episodes.length,
    'review_episodes': episodes.where((e) => e.needsReview).length,
    'documented_episodes': episodes
        .where(
          (e) =>
              e.document.description?.trim().toLowerCase() != 'aucune donnée' &&
              (e.document.description?.isNotEmpty ?? false),
        )
        .length,
    'quarantined_txt': records
        .where((r) => r.kind == 'txt' && r.disposition == 'quarantined')
        .length,
    'errors': issues.where((i) => i.severity == Severity.error).length,
    'warnings': issues.where((i) => i.severity == Severity.warning).length,
    'source_digest': sourceDigest,
    'can_apply': canApply,
  };
}
