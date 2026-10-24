import 'dart:convert';

import 'package:index_core/index_core.dart';
import 'package:test/test.dart';

import 'support/catalog_fixtures.dart';

void main() {
  test('Champs vides et date impossible diagnostiqués sans perte des autres lignes', () {
    final row = journalRow()
      ..['TITRE SYSTEME'] = ''
      ..['DATE DE DIFFUSION'] = '2013-02-30';
    final r = JournalParser().parse(
      csv([row, journalRow(original: secondOriginal)]),
    );
    expect(r.rows, hasLength(2));
    expect(
      r.issues.map((i) => i.code),
      containsAll(['csv_empty_field', 'csv_invalid_date']),
    );
  });
  for (final bom in [false, true]) {
    test('CSV ${bom ? 'avec' : 'sans'} BOM : 13 colonnes et texte exact', () {
      final row = journalRow()
        ..['TITRE WEB'] = 'Titre; "cité"\nSur deux lignes'
        ..['Erreur'] = 'Erreur historique';
      final result = JournalParser().parse(csv([row], bom: bom));
      expect(result.usable, isTrue);
      expect(result.rows.single.fields, row);
      expect(result.issues.single.code, 'journal_source_error');
    });
  }
  test('Dix colonnes minimales, ordre inversé, colonnes supplémentaires conservées', () {
    final row = journalRow()..['Extra'] = '00042';
    final result = JournalParser().parse(
      csv([row], columns: [...JournalParser.requiredHeaders.reversed, 'Extra']),
    );
    expect(result.usable, isTrue);
    expect(result.rows.single.fields['Extra'], '00042');
  });
  for (final status in JournalParser.statuses) {
    test(
      'Statut journal $status conservé sans vérification locale inventée',
      () {
        final r = JournalParser().parse(csv([journalRow(status: status)]));
        expect(r.usable, isTrue);
        expect(r.rows.single.status, status);
        expect(
          r.rows.single.fields.containsKey('local_verification_status'),
          isFalse,
        );
      },
    );
  }
  test('Statut OK ne confirme pas la concordance ID3', () {
    final r = JournalParser().parse(csv([journalRow(status: 'INVENTE')]));
    expect(r.issues.map((i) => i.code), contains('csv_invalid_id3_status'));
  });
  test('Extension historique absente refusée et valeur brute conservée', () {
    final r = JournalParser().parse(
      csv([journalRow(original: 'mr_x_1998_04_25')]),
    );
    expect(r.rows.single.originalName, isNull);
    expect(r.rows.single.fields["FICHIER MP3 D'ORIGINE"], 'mr_x_1998_04_25');
    expect(r.issues.single.code, 'csv_invalid_original_name');
  });
  for (final malformed in ['"abc', 'a"b;c', '"a"x;b']) {
    test('CSV malformé refusé : $malformed', () {
      final r = JournalParser().parse(utf8.encode(malformed));
      expect(r.usable, isFalse);
      expect(r.issues.single.code, 'csv_malformed');
    });
  }
  test('En-têtes dupliqués ou absents et colonnes incomplètes refusés', () {
    expect(
      JournalParser().parse(utf8.encode('A;A\nx;y')).issues.single.code,
      'csv_duplicate_header',
    );
    expect(
      JournalParser().parse(utf8.encode('A;B\nx;y')).issues.single.code,
      'csv_missing_headers',
    );
    final bytes = csv([]);
    expect(
      JournalParser().parse([...bytes, ...utf8.encode('\n""')]).usable,
      isFalse,
    );
    expect(
      JournalParser()
          .parse([...bytes, ...utf8.encode('\nune;ligne')])
          .issues
          .single
          .code,
      'csv_column_count',
    );
  });
  test('UTF-8, taille, nombre de lignes et fichier vide contrôlés', () {
    expect(JournalParser().parse([255]).usable, isFalse);
    expect(
      JournalParser(maxBytes: 2).parse([1, 2, 3]).issues.single.code,
      'csv_too_large',
    );
    expect(
      JournalParser(maxRows: 1).parse(csv([journalRow(), journalRow()])).usable,
      isFalse,
    );
    expect(JournalParser().parse([]).issues.single.code, 'csv_empty');
  });
}
