import 'dart:convert';

import 'package:index_core/index_core.dart';

const firstOriginal = 'mr_x_2013_04_27.mp3';
const secondOriginal = 'mr_x_2013_11_23.mp3';
const firstId = 'mrx:$firstOriginal';

TxtInput input({
  String original = firstOriginal,
  String title = 'Un titre',
  String description = 'Description complète.',
  String? path,
  String iso = '2013-04-27',
  String display = '27/04/2013',
}) => TxtInput(
  path ?? '$original.txt',
  utf8.encode('''TITRE : $title
DATE DE DIFFUSION : $display
DATE ISO : $iso
FICHIER MP3 D'ORIGINE : $original
PAGE DE L'EMISSION : http://example.invalid/page
URL MP3 : http://example.invalid/$original

DESCRIPTION DE L'EPISODE :
$description

LIVRES ET SOURCES :
Référence : Un livre
Auteur : Un auteur
Éditeur : Une maison

MUSIQUES DIFFUSÉES :
Artiste : Un artiste
Morceau : Une chanson
Album : Un album
Label : Un label
'''),
);

Map<String, String> journalRow({
  String original = firstOriginal,
  String title = 'Un titre',
  String? txtName,
  String status = 'CONFIRMEE',
  String systemName = '2013-04-27 Un titre.mp3',
}) => {
  "FICHIER MP3 D'ORIGINE": original,
  'TITRE SYSTEME': systemName,
  'TITRE WEB': title,
  'DATE DE DIFFUSION': '2013-04-27',
  'URL MP3': 'http://example.invalid/$original',
  'FICHIER TXT': txtName ?? '$original.txt',
  'CORRESPONDANCE ID3': status,
  "DESCRIPTION DE L'EPISODE": 'OK',
  'LIVRES ET SOURCES': 'OK',
  'MUSIQUES DIFFUSÉES': 'OK',
  'Statut': 'OK',
  'Erreur': '',
  'DateExecution': '2026-10-24T00:00:00',
};

List<int> csv(
  List<Map<String, String>> rows, {
  bool bom = true,
  List<String>? columns,
}) {
  final headers = columns ?? journalRow().keys.toList();
  String quote(String v) => '"${v.replaceAll('"', '""')}"';
  return [
    if (bom) ...[239, 187, 191],
    ...utf8.encode(
      [
        headers.map(quote).join(';'),
        for (final row in rows)
          headers.map((h) => quote(row[h] ?? '')).join(';'),
      ].join('\r\n'),
    ),
  ];
}

CatalogPlan plan({
  String description = 'Description complète.',
  bool withJournal = true,
}) => CatalogPlanner().plan([
  input(description: description),
], journalBytes: withJournal ? csv([journalRow()]) : null);
