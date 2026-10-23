import 'dart:convert';

import 'package:index_core/index_core.dart';
import 'package:test/test.dart';

String sheet({
  String description = 'Premier paragraphe.\n\nDeuxième : Israël, échiquier.',
  String sources = 'Aucune donnée',
  String music = 'Aucune donnée',
  String iso = '2013-04-27',
  String display = '27/04/2013',
}) =>
    '''TITRE : Le Masque de fer
DATE DE DIFFUSION : $display
DATE ISO : $iso
FICHIER MP3 D'ORIGINE : mr_x_2013_04_27.mp3
PAGE DE L'EMISSION : http://example.invalid/page
URL MP3 : http://example.invalid/audio.mp3

DESCRIPTION DE L'EPISODE :
$description

LIVRES ET SOURCES :
$sources

MUSIQUES DIFFUSÉES :
$music''';

List<String> codes(TxtParseResult result) =>
    result.issues.map((i) => i.code).toList();

void main() {
  final parser = TxtParser();
  for (final bom in [false, true]) {
    test('TXT UTF-8 ${bom ? "avec" : "sans"} BOM : valeurs et paragraphes', () {
      final bytes = [
        if (bom) ...[239, 187, 191],
        ...utf8.encode(sheet()),
      ];
      final r = parser.parse(bytes);
      expect(r.hasErrors, isFalse);
      final d = r.document!;
      expect(d.hadBom, bom);
      expect(r.sourceBytes, bytes);
      expect(d.title, 'Le Masque de fer');
      expect(d.originalName, 'mr_x_2013_04_27.mp3');
      expect(d.isoDate, DateTime.utc(2013, 4, 27));
      expect(d.displayDate, d.isoDate);
      expect(d.broadcastDate, d.isoDate);
      expect(
        d.description,
        'Premier paragraphe.\n\nDeuxième : Israël, échiquier.',
      );
      expect(d.sources, isEmpty);
      expect(d.music, isEmpty);
      expect(d.pageUrl, 'http://example.invalid/page');
      expect(d.mp3Url, 'http://example.invalid/audio.mp3');
      expect(() => d.sections.clear(), throwsUnsupportedError);
    });
  }
  test('CRLF et NEL préservés, y compris dans le brut de description', () {
    final text = sheet(description: ' A\u0085B\n\nC ').replaceAll('\n', '\r\n');
    final r = parser.parse(utf8.encode(text));
    expect(r.document!.rawText, text);
    expect(r.document!.description, 'A\u0085B\r\n\r\nC');
    expect(
      r.document!.section("DESCRIPTION DE L'EPISODE")!.rawContent,
      ' A\u0085B\r\n\r\nC \r\n\r\n',
    );
    expect(codes(r), contains('txt_nel_preserved'));
    expect(r.hasErrors, isFalse);
  });
  test('Rubriques dans un ordre variable', () {
    final text = sheet();
    final titleEnd = text.indexOf('\n');
    final rearranged =
        '${text.substring(titleEnd + 1)}\n\n${text.substring(0, titleEnd)}';
    final r = parser.parse(utf8.encode(rearranged));
    expect(r.document!.title, 'Le Masque de fer');
    expect(r.hasErrors, isFalse);
  });
  test(
    'Une phrase en majuscules avec deux-points reste dans la description',
    () {
      const description =
          'Un paragraphe.\nCIA : un rôle à examiner.\n\nLa suite.';
      final r = parser.parse(utf8.encode(sheet(description: description)));
      expect(r.hasErrors, isFalse);
      expect(r.document!.description, description);
    },
  );
  test('Rubrique répétée : conservation des deux valeurs sans choix', () {
    final r = parser.parse(utf8.encode('${sheet()}\nTITRE : Autre'));
    expect(codes(r), contains('txt_duplicate_header'));
    expect(r.document!.title, isNull);
    expect(r.document!.sections.where((s) => s.label == 'TITRE'), hasLength(2));
  });
  test('Rubrique absente et rubrique vide sont diagnostiquées', () {
    final r = parser.parse(
      utf8.encode(
        sheet()
            .replaceFirst('TITRE : Le Masque de fer\n', '')
            .replaceFirst(
              'URL MP3 : http://example.invalid/audio.mp3',
              'URL MP3 :',
            ),
      ),
    );
    expect(codes(r), containsAll(['txt_missing_header', 'txt_empty_header']));
    expect(r.document!.title, isNull);
    expect(r.document!.mp3Url, '');
    expect(r.hasErrors, isTrue);
  });
  test(
    'Rubrique mal orthographiée conservée et non reconnue implicitement',
    () {
      final r = parser.parse(
        utf8.encode(
          sheet().replaceFirst('LIVRES ET SOURCES', 'LIVRE ET SOURCES'),
        ),
      );
      expect(
        codes(r),
        containsAll(['txt_unknown_header', 'txt_missing_header']),
      );
      expect(
        r.document!.sections.any((s) => s.label == 'LIVRE ET SOURCES'),
        isTrue,
      );
      expect(r.document!.sourceText, isNull);
    },
  );
  for (final date in [
    '2013-02-29',
    '2013-13-01',
    '0000-01-01',
    '2013-04-31',
    'pas une date',
  ]) {
    test('Date invalide $date : pas de normalisation silencieuse', () {
      final r = parser.parse(utf8.encode(sheet(iso: date)));
      expect(codes(r), contains('txt_invalid_date'));
      expect(r.document!.isoDate, isNull);
    });
  }
  test('Année bissextile acceptée et divergence des dates bloquante', () {
    final valid = parser.parse(
      utf8.encode(sheet(iso: '2012-02-29', display: '29/02/2012')),
    );
    expect(valid.hasErrors, isFalse);
    final bad = parser.parse(utf8.encode(sheet(display: '28/04/2013')));
    expect(codes(bad), contains('txt_date_mismatch'));
    expect(bad.document!.broadcastDate, isNull);
  });
  test('Encodage divergent refusé, octets disponibles pour diagnostic', () {
    final r = parser.parse([0xff, 0xfe, 0x41, 0]);
    expect(r.document, isNull);
    expect(codes(r), ['txt_invalid_utf8']);
    expect(r.sourceBytes, [0xff, 0xfe, 0x41, 0]);
  });
  test('Taille bornée avant décodage', () {
    final r = TxtParser(maxBytes: 3).parse([65, 66, 67, 68]);
    expect(codes(r), ['txt_too_large']);
    expect(r.sourceBytes, isEmpty);
  });
  test('Fiche vide : diagnostics, aucun contenu inventé', () {
    final r = parser.parse([]);
    expect(r.hasErrors, isTrue);
    expect(r.document!.title, isNull);
    expect(r.document!.originalName, isNull);
  });
  test('Sources structurées sans perdre listes connexes et auteur vide', () {
    const sources = '''Référence : Premier livre
Auteur :
Éditeur : Éditions X (2004)
Liste des épisodes connexes :
Un autre épisode (mr_x_2000_01_01.mp3)

Référence : Deuxième livre
Auteur : Quelqu'un
Éditeur : Y''';
    final r = parser.parse(utf8.encode(sheet(sources: sources)));
    expect(r.hasErrors, isFalse);
    final list = r.document!.sources;
    expect(list, hasLength(2));
    expect(list.first.author, isNull);
    expect(list.first.title, 'Premier livre');
    expect(list.first.publisher, 'Éditions X (2004)');
    expect(
      list.first.rawText,
      contains('Un autre épisode (mr_x_2000_01_01.mp3)'),
    );
    expect(list.last.author, "Quelqu'un");
    expect(r.document!.sourceText, sources);
  });
  test('Source libre conservée sans structure inventée', () {
    final r = parser.parse(
      utf8.encode(sheet(sources: 'Une référence non structurée.')),
    );
    expect(r.document!.sources.single.rawText, 'Une référence non structurée.');
    expect(r.document!.sources.single.title, isNull);
  });
  test('Attribut de source répété sans choix arbitraire', () {
    final r = parser.parse(
      utf8.encode(sheet(sources: 'Référence : X\nAuteur : A\nAuteur : B')),
    );
    expect(codes(r), contains('txt_duplicate_attribute'));
    expect(r.document!.sources.single.author, isNull);
  });
  test('Plusieurs groupes musicaux, dont des attributs absents', () {
    final r = parser.parse(
      utf8.encode(
        sheet(
          music: 'Artiste : A\nMorceau : Paris\nAlbum : X\nLabel : Y\n\nMorceau : Seul\nLabel : Z',
        ),
      ),
    );
    expect(r.hasErrors, isFalse);
    expect(r.document!.music, hasLength(2));
    expect(r.document!.music.first.artist, 'A');
    expect(r.document!.music.first.album, 'X');
    expect(r.document!.music.last.artist, isNull);
    expect(r.document!.music.last.title, 'Seul');
  });
  test(
    'Deux artistes sans ligne blanche : frontière explicite et diagnostic',
    () {
      final r = parser.parse(
        utf8.encode(
          sheet(music: 'Artiste : A\nMorceau : X\nArtiste : B\nMorceau : Y'),
        ),
      );
      expect(r.document!.music.map((m) => m.artist), ['A', 'B']);
      expect(codes(r), contains('txt_music_group_boundary'));
    },
  );
  test('Nom historique invalide et URLs conservées sans requête', () {
    final r = parser.parse(
      utf8.encode(sheet().replaceFirst('mr_x_2013_04_27.mp3', '../audio.mp3')),
    );
    expect(codes(r), contains('txt_invalid_original_name'));
    expect(r.document!.originalName, isNull);
    expect(r.document!.mp3Url, startsWith('http://example.invalid/'));
  });
}
