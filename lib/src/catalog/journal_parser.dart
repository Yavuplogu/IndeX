import 'dart:convert';

import '../diagnostic.dart';
import '../identity.dart';
import 'models.dart';

final class JournalRow {
  JournalRow(this.number, Map<String, String> fields)
    : fields = Map.unmodifiable(fields);
  final int number;
  final Map<String, String> fields;
  String? get originalName =>
      canonicalOriginalName(fields["FICHIER MP3 D'ORIGINE"] ?? '');
  String get status => fields['CORRESPONDANCE ID3']!.trim();
}

final class JournalResult {
  JournalResult(this.rows, this.issues, this.usable);
  final List<JournalRow> rows;
  final List<CatalogIssue> issues;
  final bool usable;
}

/// CSV strict à séparateur point-virgule, sans interprétation numérique des champs.
final class JournalParser {
  static const requiredHeaders = [
    "FICHIER MP3 D'ORIGINE",
    'TITRE SYSTEME',
    'TITRE WEB',
    'DATE DE DIFFUSION',
    'URL MP3',
    'FICHIER TXT',
    'CORRESPONDANCE ID3',
    'Statut',
    'Erreur',
    'DateExecution',
  ];
  static const statuses = {'CONFIRMEE', 'NON_VERIFIEE', 'CONFLIT', 'ABSENTE'};
  JournalParser({this.maxBytes = 16 * 1024 * 1024, this.maxRows = 10000});
  final int maxBytes;
  final int maxRows;

  JournalResult parse(List<int> bytes) {
    final issues = <CatalogIssue>[];
    JournalResult fail(String code, String message) => JournalResult([], [
      CatalogIssue(
        code,
        message,
        source: 'journal.csv',
        severity: Severity.error,
      ),
    ], false);
    if (bytes.length > maxBytes)
      return fail('csv_too_large', 'CSV trop volumineux.');
    late String text;
    try {
      text = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return fail('csv_invalid_utf8', 'Le CSV n’est pas en UTF-8 valide.');
    }
    late List<List<String>> table;
    try {
      table = _rows(text);
    } on FormatException catch (e) {
      return fail('csv_malformed', e.message);
    }
    if (table.isEmpty) return fail('csv_empty', 'CSV vide.');
    final headers = table.first.map((v) => v.trim()).toList();
    if (headers.toSet().length != headers.length ||
        headers.any((h) => h.isEmpty))
      return fail('csv_duplicate_header', 'En-têtes vides ou répétés.');
    if (!requiredHeaders.every(headers.contains))
      return fail('csv_missing_headers', 'En-têtes obligatoires absents.');
    final rows = <JournalRow>[];
    for (var i = 1; i < table.length; i++) {
      if (table[i].length != headers.length) {
        issues.add(
          CatalogIssue(
            'csv_column_count',
            'Nombre de colonnes incorrect à la ligne logique ${i + 1}.',
            source: 'journal.csv:${i + 1}',
            severity: Severity.error,
          ),
        );
        // Une ligne mal délimitée rend les associations globales incertaines.
        return JournalResult([], issues, false);
      }
      final row = JournalRow(i + 1, {
        for (var j = 0; j < headers.length; j++) headers[j]: table[i][j],
      });
      for (final h in [
        "FICHIER MP3 D'ORIGINE",
        'TITRE SYSTEME',
        'TITRE WEB',
        'DATE DE DIFFUSION',
        'FICHIER TXT',
      ]) {
        if (row.fields[h]!.trim().isEmpty)
          issues.add(
            CatalogIssue(
              'csv_empty_field',
              'Champ CSV vide : $h.',
              source: 'journal.csv:${i + 1}',
              originalName: row.originalName,
            ),
          );
      }
      final date = row.fields['DATE DE DIFFUSION']!.trim();
      final parsedDate = DateTime.tryParse(date);
      if (date.isNotEmpty &&
          (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
              parsedDate == null ||
              parsedDate.year < 1 ||
              parsedDate.toIso8601String().substring(0, 10) != date)) {
        issues.add(
          CatalogIssue(
            'csv_invalid_date',
            'Date ISO du journal invalide : $date.',
            source: 'journal.csv:${i + 1}',
            originalName: row.originalName,
            severity: Severity.error,
          ),
        );
      }
      if (row.originalName == null)
        issues.add(
          CatalogIssue(
            'csv_invalid_original_name',
            'Nom historique invalide.',
            source: 'journal.csv:${i + 1}',
            severity: Severity.error,
          ),
        );
      if (!statuses.contains(row.status))
        issues.add(
          CatalogIssue(
            'csv_invalid_id3_status',
            'Statut ID3 non reconnu : ${row.status}.',
            source: 'journal.csv:${i + 1}',
            originalName: row.originalName,
            severity: Severity.error,
          ),
        );
      if (row.fields['Erreur']!.trim().isNotEmpty)
        issues.add(
          CatalogIssue(
            'journal_source_error',
            row.fields['Erreur']!,
            source: 'journal.csv:${i + 1}',
            originalName: row.originalName,
          ),
        );
      rows.add(row);
    }
    return JournalResult(
      List.unmodifiable(rows),
      List.unmodifiable(issues),
      true,
    );
  }

  List<List<String>> _rows(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    var closed = false;
    var started = false;
    void finishField() {
      row.add(field.toString());
      field = StringBuffer();
      closed = false;
      started = false;
    }

    void finishRow() {
      final blank = !started && !closed && row.isEmpty && field.isEmpty;
      finishField();
      if (!blank) rows.add(row);
      row = [];
      if (rows.length > maxRows + 1)
        throw const FormatException('Trop de lignes CSV.');
    }

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (quoted) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
            closed = true;
          }
        } else {
          field.write(ch);
        }
        continue;
      }
      if (ch == ';') {
        finishField();
        continue;
      }
      if (ch == '\r' || ch == '\n') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        finishRow();
        continue;
      }
      if (closed)
        throw const FormatException('Texte après la fermeture d’un champ CSV.');
      if (ch == '"') {
        if (started)
          throw const FormatException(
            'Guillemet dans un champ CSV non encadré.',
          );
        quoted = true;
        started = true;
      } else {
        field.write(ch);
        started = true;
      }
    }
    if (quoted) throw const FormatException('Champ CSV non terminé.');
    if (started || closed || row.isNotEmpty || field.isNotEmpty) finishRow();
    return rows;
  }
}
