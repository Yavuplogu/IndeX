import 'package:index_core/index_core.dart';
import 'package:test/test.dart';

import 'support/catalog_fixtures.dart';

void main() {
  test(
    'Fusion CSV/TXT : contenu TXT intégral, métadonnées et preuve source',
    () {
      final p = plan();
      expect(p.canApply, isTrue);
      expect(p.episodes, hasLength(1));
      expect(p.episodes.single.id, firstId);
      expect(p.episodes.single.document.description, 'Description complète.');
      expect(p.episodes.single.systemName, '2013-04-27 Un titre.mp3');
      expect(p.episodes.single.journalStatus, 'CONFIRMEE');
      expect(
        p.records.where((r) => r.kind == 'txt').single.bytes,
        input().bytes,
      );
    },
  );
  test('Import TXT seul fonctionne, sans journal requis', () {
    final p = plan(withJournal: false);
    expect(p.canApply, isTrue);
    expect(p.episodes, hasLength(1));
    expect(p.episodes.single.journalStatus, isNull);
  });
  test('Descriptions et titre CSV ne remplacent jamais le TXT', () {
    final row = journalRow(title: 'Autre titre')
      ..["DESCRIPTION DE L'EPISODE"] = 'VIDE';
    final p = CatalogPlanner().plan([input()], journalBytes: csv([row]));
    expect(p.episodes.single.document.title, 'Un titre');
    expect(p.episodes.single.document.description, 'Description complète.');
    expect(p.issues.map((i) => i.code), contains('journal_title_mismatch'));
    expect(p.episodes.single.needsReview, isTrue);
  });
  test('CSV sans extension TXT : rapprochement historique, sans inventer un chemin', () {
    final p = CatalogPlanner().plan([
      input(path: 'réel.txt'),
    ], journalBytes: csv([journalRow(txtName: 'nom erroné')]));
    expect(p.episodes.single.sourcePath, 'réel.txt');
    expect(p.issues.map((i) => i.code), contains('journal_txt_name_mismatch'));
  });
  test(
    'Doublons de TXT ou du journal : aucun épisode choisi arbitrairement',
    () {
      final txtDuplicate = CatalogPlanner().plan([
        input(path: 'A.txt'),
        input(path: 'B.txt'),
      ]);
      expect(txtDuplicate.episodes, isEmpty);
      expect(
        txtDuplicate.records.where((r) => r.disposition == 'quarantined'),
        hasLength(2),
      );
      final csvDuplicate = CatalogPlanner().plan([
        input(),
      ], journalBytes: csv([journalRow(), journalRow()]));
      expect(csvDuplicate.episodes, isEmpty);
      expect(
        csvDuplicate.issues.map((i) => i.code),
        contains('duplicate_journal_identity'),
      );
    },
  );
  test('Chemins source répétés ne sont pas écrasés', () {
    final p = CatalogPlanner().plan([input(), input()]);
    expect(p.episodes, isEmpty);
    expect(p.issues.map((i) => i.code), contains('duplicate_source_path'));
  });
  test('Identifiant invalide isolé sans bloquer les autres fiches', () {
    final p = CatalogPlanner().plan([
      input(),
      input(original: 'mr_x_1998_04_25'),
    ]);
    expect(p.episodes, hasLength(1));
    expect(p.summary()['quarantined_txt'], 1);
    expect(
      p.records.singleWhere((r) => r.disposition == 'quarantined').bytes,
      isNotEmpty,
    );
  });
  test('Dates contradictoires conservées pour examen, sans date choisie implicitement', () {
    final p = CatalogPlanner().plan([input(display: '04/12/2013')]);
    expect(p.episodes.single.document.broadcastDate, isNull);
    expect(p.episodes.single.needsReview, isTrue);
    expect(p.issues.map((i) => i.code), contains('txt_date_mismatch'));
  });
  test(
    'TXT absent : diagnostic et journal conservé ; TXT orphelin conservé',
    () {
      final p = CatalogPlanner().plan([
        input(),
      ], journalBytes: csv([journalRow(original: secondOriginal)]));
      expect(p.episodes.single.originalName, firstOriginal);
      expect(
        p.issues.map((i) => i.code),
        containsAll(['journal_txt_missing', 'txt_not_in_journal']),
      );
    },
  );
  test('Statut journal illégal met la fiche en quarantaine', () {
    final p = CatalogPlanner().plan([
      input(),
    ], journalBytes: csv([journalRow(status: 'OK')]));
    expect(p.episodes, isEmpty);
  });
  test('Journal malformé bloque le plan, sans basculer silencieusement en mode sans CSV', () {
    final p = CatalogPlanner().plan([input()], journalBytes: [255]);
    expect(p.canApply, isFalse);
    expect(p.episodes, isEmpty);
  });
  test('Erreur de lecture d’une fiche isolée, autres fiches exploitables', () {
    final p = CatalogPlanner().plan([
      input(),
      TxtInput('refusé.txt', [], readError: 'Permission refusée'),
    ]);
    expect(p.episodes, hasLength(1));
    expect(p.issues.map((i) => i.code), contains('txt_read_error'));
  });
  test(
    'Empreintes stables, ordre des fichiers sans effet ; modification détectée',
    () {
      final inputs = [input(), input(original: secondOriginal)];
      final a = CatalogPlanner().plan(inputs),
          b = CatalogPlanner().plan(inputs.reversed.toList());
      expect(a.sourceDigest, b.sourceDigest);
      expect(a.episodes.map((e) => e.id), b.episodes.map((e) => e.id));
      expect(
        plan(description: 'Modifiée').sourceDigest,
        isNot(plan().sourceDigest),
      );
    },
  );
}
