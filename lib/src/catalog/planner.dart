import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../diagnostic.dart';
import '../txt/txt_document.dart';
import '../txt/txt_parser.dart';
import 'journal_parser.dart';
import 'models.dart';

/// Préparation pure de l'import ; les sources ne sont jamais corrigées ni écrites.
final class CatalogPlanner {
  CatalogPlanner({TxtParser? txtParser, JournalParser? journalParser})
    : txtParser = txtParser ?? TxtParser(),
      journalParser = journalParser ?? JournalParser();
  final TxtParser txtParser;
  final JournalParser journalParser;

  CatalogPlan plan(List<TxtInput> inputs, {List<int>? journalBytes}) {
    final issues = <CatalogIssue>[];
    final records = <SourceRecord>[];
    final episodes = <CatalogEpisode>[];
    final sorted = inputs.toList()..sort((a, b) => a.path.compareTo(b.path));
    final parsed = <String, List<(TxtInput, TxtParseResult)>>{};
    final pathCounts = <String, int>{};
    for (final t in sorted) {
      pathCounts.update(t.path, (v) => v + 1, ifAbsent: () => 1);
    }
    final rowsById = <String, List<JournalRow>>{};
    final journal = journalBytes == null
        ? null
        : journalParser.parse(journalBytes);
    if (journal != null) {
      issues.addAll(journal.issues);
      records.add(
        SourceRecord(
          kind: 'journal',
          key: 'journal.csv',
          disposition: journal.usable ? 'accepted' : 'quarantined',
          bytes: journalBytes,
        ),
      );
      for (final row in journal.rows) {
        final id = row.originalName;
        if (id != null) (rowsById[id] ??= []).add(row);
        records.add(
          SourceRecord(
            kind: 'journal_row',
            key: 'journal.csv:${row.number}',
            disposition:
                id == null || !JournalParser.statuses.contains(row.status)
                ? 'quarantined'
                : 'accepted',
            originalName: id,
            fields: row.fields,
          ),
        );
      }
    }
    for (final input in sorted) {
      if (input.readError != null) {
        issues.add(
          CatalogIssue(
            'txt_read_error',
            input.readError!,
            source: input.path,
            severity: Severity.error,
          ),
        );
        records.add(
          SourceRecord(
            kind: 'txt',
            key: input.path,
            disposition: 'quarantined',
            bytes: input.bytes,
            fields: {'read_error': input.readError!},
          ),
        );
        continue;
      }
      final result = txtParser.parse(input.bytes);
      final id = result.document?.originalName;
      for (final d in result.issues) {
        issues.add(
          CatalogIssue(
            d.code,
            d.message,
            source: input.path,
            originalName: id,
            severity: d.severity,
          ),
        );
      }
      if (pathCounts[input.path] != 1) {
        issues.add(
          CatalogIssue(
            'duplicate_source_path',
            'Chemin de provenance répété.',
            source: input.path,
            severity: Severity.error,
          ),
        );
      } else if (id != null) {
        (parsed[id] ??= []).add((input, result));
      }
      if (id == null || pathCounts[input.path] != 1)
        records.add(
          SourceRecord(
            kind: 'txt',
            key: input.path,
            disposition: 'quarantined',
            bytes: input.bytes,
          ),
        );
    }
    for (final e in rowsById.entries) {
      if (e.value.length > 1)
        issues.add(
          CatalogIssue(
            'duplicate_journal_identity',
            'Identifiant historique répété dans le journal.',
            originalName: e.key,
            severity: Severity.error,
          ),
        );
      if (!parsed.containsKey(e.key))
        issues.add(
          CatalogIssue(
            'journal_txt_missing',
            'Aucun TXT lisible portant cet identifiant.',
            originalName: e.key,
            severity: Severity.error,
          ),
        );
    }
    for (final e in parsed.entries) {
      final rows = rowsById[e.key] ?? [];
      final conflicting =
          e.value.length > 1 ||
          rows.length > 1 ||
          rows.any((r) => !JournalParser.statuses.contains(r.status));
      if (e.value.length > 1)
        issues.add(
          CatalogIssue(
            'duplicate_txt_identity',
            'Plusieurs TXT portent cet identifiant ; aucun choix automatique.',
            originalName: e.key,
            severity: Severity.error,
          ),
        );
      for (final (input, result) in e.value) {
        if (conflicting || journal?.usable == false) {
          records.add(
            SourceRecord(
              kind: 'txt',
              key: input.path,
              disposition: 'quarantined',
              originalName: e.key,
              bytes: input.bytes,
            ),
          );
          continue;
        }
        final doc = result.document!;
        final row = rows.isEmpty ? null : rows.single;
        var review = result.hasErrors;
        void discrepancy(String code, String message) {
          review = true;
          issues.add(
            CatalogIssue(
              code,
              message,
              source: input.path,
              originalName: e.key,
            ),
          );
        }

        if (journal != null && row == null)
          discrepancy(
            'txt_not_in_journal',
            'TXT absent du journal ; ajout documentaire conservé.',
          );
        if (row != null) {
          final basename = input.path.split('/').last;
          if (row.fields['FICHIER TXT'] != basename)
            discrepancy(
              'journal_txt_name_mismatch',
              'Nom TXT déclaré différent du fichier découvert ; rapprochement par identifiant historique.',
            );
          if (row.fields['TITRE WEB'] != doc.title)
            discrepancy(
              'journal_title_mismatch',
              'Titre CSV différent du TXT ; contenu TXT conservé.',
            );
          if (doc.isoDate != null &&
              row.fields['DATE DE DIFFUSION'] != _date(doc.isoDate!))
            discrepancy(
              'journal_date_mismatch',
              'Date CSV différente de DATE ISO ; divergence conservée.',
            );
          if (row.fields['URL MP3'] != doc.mp3Url)
            discrepancy(
              'journal_url_mismatch',
              'URL CSV différente du TXT ; aucune URL n’est appelée.',
            );
        }
        // Sans titre, ne pas produire de fiche artificielle, même avec un identifiant.
        if (doc.title == null || doc.title!.isEmpty) {
          records.add(
            SourceRecord(
              kind: 'txt',
              key: input.path,
              disposition: 'quarantined',
              originalName: e.key,
              bytes: input.bytes,
            ),
          );
          continue;
        }
        final fields = row?.fields;
        final fingerprint = sha256
            .convert(
              utf8.encode(
                jsonEncode([
                  sha256.convert(input.bytes).toString(),
                  fields,
                  input.path,
                  review,
                  doc.title,
                  doc.broadcastDate?.toIso8601String(),
                  doc.description,
                  for (final s in doc.sources)
                    [s.rawText, s.title, s.author, s.publisher],
                  for (final m in doc.music)
                    [m.rawText, m.artist, m.title, m.album, m.label],
                ]),
              ),
            )
            .toString();
        episodes.add(
          CatalogEpisode(
            originalName: e.key,
            document: doc,
            sourcePath: input.path,
            sourceBytes: input.bytes,
            fingerprint: fingerprint,
            needsReview: review,
            systemName: fields?['TITRE SYSTEME'],
            journalStatus: row?.status,
            journalFields: fields,
          ),
        );
        records.add(
          SourceRecord(
            kind: 'txt',
            key: input.path,
            disposition: review ? 'review' : 'accepted',
            originalName: e.key,
            bytes: input.bytes,
          ),
        );
      }
    }
    episodes.sort((a, b) => a.id.compareTo(b.id));
    final digest = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              if (journalBytes != null)
                ['journal', sha256.convert(journalBytes).toString()],
              for (final t in sorted)
                [t.path, sha256.convert(t.bytes).toString(), t.readError],
            ]),
          ),
        )
        .toString();
    return CatalogPlan(
      episodes: episodes,
      issues: issues,
      records: records,
      sourceDigest: digest,
      txtCount: inputs.length,
      journalRows: journal?.rows.length,
      canApply: journal?.usable ?? true,
    );
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
