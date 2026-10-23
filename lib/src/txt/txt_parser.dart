import 'dart:convert';

import '../diagnostic.dart';
import '../identity.dart';
import 'txt_document.dart';

/// Parse uniquement des octets fournis par l'appelant ; aucun accès réseau/fichier.
final class TxtParser {
  TxtParser({this.maxBytes = 2 * 1024 * 1024}) {
    if (maxBytes <= 0) throw ArgumentError.value(maxBytes, 'maxBytes');
  }
  final int maxBytes;
  static const headers = [
    'TITRE',
    'DATE DE DIFFUSION',
    'DATE ISO',
    "FICHIER MP3 D'ORIGINE",
    "PAGE DE L'EMISSION",
    'URL MP3',
    "DESCRIPTION DE L'EPISODE",
    'LIVRES ET SOURCES',
    'MUSIQUES DIFFUSÉES',
  ];
  static const _required = {
    'TITRE',
    "FICHIER MP3 D'ORIGINE",
    "DESCRIPTION DE L'EPISODE",
  };
  static final _header = RegExp(
    r"^([A-ZÀ-ÖØ-Þ][A-ZÀ-ÖØ-Þ0-9 '’_/-]*?)[ \t]*:[ \t]*(.*)$",
  );

  TxtParseResult parse(List<int> bytes) {
    final issues = <Diagnostic>[];
    if (bytes.length > maxBytes) {
      // Ne pas recopier une entrée excessive dans le résultat.
      return TxtParseResult(
        sourceBytes: const [],
        document: null,
        issues: const [
          Diagnostic(
            'txt_too_large',
            'La fiche TXT dépasse la taille autorisée.',
          ),
        ],
      );
    }
    late String text;
    try {
      text = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return TxtParseResult(
        sourceBytes: bytes,
        document: null,
        issues: const [
          Diagnostic(
            'txt_invalid_utf8',
            'Encodage UTF-8 invalide ; aucune conversion automatique.',
          ),
        ],
      );
    }
    final bom =
        bytes.length >= 3 &&
        bytes[0] == 0xef &&
        bytes[1] == 0xbb &&
        bytes[2] == 0xbf;
    // Le décodeur UTF-8 de Dart enlève le BOM initial, sourceBytes le conserve.
    final found = <({String label, int start, int content})>[];
    for (final line in _lines(text)) {
      final m = _header.firstMatch(line.text);
      if (m == null) continue;
      final label = m[1]!.trim();
      if (!headers.contains(label)) {
        // « CIA : un rôle... » peut être une phrase de la description, pas une rubrique.
        if (m[2]!.isNotEmpty && !headers.any((h) => _nearHeader(label, h)))
          continue;
        issues.add(
          Diagnostic(
            'txt_unknown_header',
            'Rubrique inconnue ou mal orthographiée : $label.',
          ),
        );
      }
      final content = m[2]!.isEmpty
          ? line.end
          : line.start + line.text.length - m[2]!.length;
      found.add((label: label, start: line.start, content: content));
    }
    final sections = <TxtSection>[];
    for (var i = 0; i < found.length; i++) {
      final end = i + 1 < found.length ? found[i + 1].start : text.length;
      sections.add(
        TxtSection(
          found[i].label,
          text.substring(found[i].content, end),
          found[i].start,
        ),
      );
    }
    if (found.isEmpty ||
        text.substring(0, found.first.start).trim().isNotEmpty) {
      issues.add(
        const Diagnostic(
          'txt_preamble',
          'Texte hors des rubriques ; contenu brut conservé.',
          severity: Severity.warning,
        ),
      );
    }
    String? value(String label) {
      final parts = sections.where((s) => s.label == label).toList();
      if (parts.isEmpty) {
        issues.add(
          Diagnostic(
            'txt_missing_header',
            'Rubrique absente : $label.',
            severity: _required.contains(label)
                ? Severity.error
                : Severity.warning,
          ),
        );
        return null;
      }
      if (parts.length > 1) {
        issues.add(
          Diagnostic(
            'txt_duplicate_header',
            'Rubrique répétée : $label ; aucun choix implicite.',
          ),
        );
        return null;
      }
      final result = parts.single.value;
      if (result.isEmpty) {
        issues.add(
          Diagnostic(
            'txt_empty_header',
            'Rubrique vide : $label.',
            severity: _required.contains(label)
                ? Severity.error
                : Severity.warning,
          ),
        );
      }
      return result;
    }

    final values = {for (final h in headers) h: value(h)};
    final original = values["FICHIER MP3 D'ORIGINE"];
    final canonical = original == null ? null : canonicalOriginalName(original);
    if (original != null && canonical == null) {
      issues.add(
        const Diagnostic(
          'txt_invalid_original_name',
          'Nom historique MP3 invalide.',
        ),
      );
    }
    final iso = _date(values['DATE ISO'], true, issues);
    final display = _date(values['DATE DE DIFFUSION'], false, issues);
    final mismatch = iso != null && display != null && iso != display;
    if (mismatch)
      issues.add(
        const Diagnostic(
          'txt_date_mismatch',
          'Les deux dates de diffusion divergent.',
        ),
      );
    if (iso == null && display == null)
      issues.add(
        const Diagnostic(
          'txt_missing_valid_date',
          'Aucune date de diffusion valide.',
        ),
      );
    if (text.contains('\u0085')) {
      issues.add(
        const Diagnostic(
          'txt_nel_preserved',
          'Caractères U+0085 conservés dans le texte.',
          severity: Severity.warning,
        ),
      );
    }
    return TxtParseResult(
      sourceBytes: bytes,
      issues: issues,
      document: TxtDocument(
        rawText: text,
        hadBom: bom,
        sections: sections,
        originalName: canonical,
        isoDate: iso,
        displayDate: display,
        broadcastDate: mismatch ? null : iso ?? display,
        sources: _sources(values['LIVRES ET SOURCES'], issues),
        music: _music(values['MUSIQUES DIFFUSÉES'], issues),
      ),
    );
  }

  static bool _nearHeader(String a, String b) {
    if ((a.length - b.length).abs() > 2) return false;
    var row = List.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final next = [i + 1];
      for (var j = 0; j < b.length; j++) {
        final insertion = next[j] + 1;
        final deletion = row[j + 1] + 1;
        final substitution = row[j] + (a[i] == b[j] ? 0 : 1);
        var best = insertion < deletion ? insertion : deletion;
        if (substitution < best) best = substitution;
        next.add(best);
      }
      row = next;
    }
    return row.last <= 2;
  }

  static DateTime? _date(String? value, bool iso, List<Diagnostic> issues) {
    if (value == null || value.isEmpty) return null;
    final m = RegExp(
      iso ? r'^(\d{4})-(\d{2})-(\d{2})$' : r'^(\d{2})/(\d{2})/(\d{4})$',
    ).firstMatch(value);
    if (m != null) {
      final y = int.parse(m[iso ? 1 : 3]!);
      final month = int.parse(m[2]!);
      final day = int.parse(m[iso ? 3 : 1]!);
      final d = DateTime.utc(y, month, day);
      if (y >= 1 && d.year == y && d.month == month && d.day == day) return d;
    }
    issues.add(Diagnostic('txt_invalid_date', 'Date invalide : $value.'));
    return null;
  }

  static bool _absent(String? text) =>
      text == null || text.isEmpty || text.toLowerCase() == 'aucune donnée';

  static List<LiterarySource> _sources(String? text, List<Diagnostic> issues) {
    if (_absent(text)) return [];
    final starts = RegExp(
      r'^Référence[ \t]*:',
      multiLine: true,
    ).allMatches(text!).map((m) => m.start).toList();
    if (starts.isEmpty) return [LiterarySource(rawText: text)];
    final result = <LiterarySource>[];
    if (text.substring(0, starts.first).trim().isNotEmpty) {
      result.add(LiterarySource(rawText: text.substring(0, starts.first)));
      issues.add(
        const Diagnostic(
          'txt_unstructured_source',
          'Préambule des sources conservé sans structuration.',
          severity: Severity.warning,
        ),
      );
    }
    for (var i = 0; i < starts.length; i++) {
      final raw = text.substring(
        starts[i],
        i + 1 < starts.length ? starts[i + 1] : text.length,
      );
      result.add(
        LiterarySource(
          rawText: raw,
          title: _attribute(raw, 'Référence', issues),
          author: _attribute(raw, 'Auteur', issues),
          publisher: _attribute(raw, 'Éditeur', issues),
        ),
      );
    }
    return result;
  }

  static String? _attribute(String raw, String name, List<Diagnostic> issues) {
    final found = _lines(raw)
        .map(
          (line) =>
              RegExp('^${RegExp.escape(name)}[ \\t]*:[ \\t]*(.*)\$')
                  .firstMatch(line.text),
        )
        .whereType<RegExpMatch>()
        .toList();
    if (found.length > 1) {
      issues.add(
        Diagnostic('txt_duplicate_attribute', 'Attribut répété : $name.'),
      );
      return null;
    }
    final value = found.isEmpty ? null : found.single[1]!.trim();
    return value == '' ? null : value;
  }

  static List<MusicTrack> _music(String? text, List<Diagnostic> issues) {
    if (_absent(text)) return [];
    final result = <MusicTrack>[];
    var start = 0;
    final seen = <String>{};
    void flush(int end) {
      final raw = text!.substring(start, end);
      if (raw.trim().isNotEmpty) {
        if (seen.isEmpty)
          issues.add(
            const Diagnostic(
              'txt_unstructured_music',
              'Bloc musical non structuré conservé.',
              severity: Severity.warning,
            ),
          );
        result.add(
          MusicTrack(
            rawText: raw,
            artist: _attribute(raw, 'Artiste', issues),
            title: _attribute(raw, 'Morceau', issues),
            album: _attribute(raw, 'Album', issues),
            label: _attribute(raw, 'Label', issues),
          ),
        );
      }
      seen.clear();
      start = end;
    }

    for (final line in _lines(text!)) {
      final m = RegExp(r'^(Artiste|Morceau|Album|Label)[ \t]*:')
          .firstMatch(line.text);
      if (line.text.trim().isEmpty) {
        flush(line.start);
        start = line.end;
      } else if (m != null) {
        if (seen.contains(m[1])) {
          issues.add(
            const Diagnostic(
              'txt_music_group_boundary',
              'Attribut musical répété : nouveau groupe explicite.',
              severity: Severity.warning,
            ),
          );
          flush(line.start);
        }
        seen.add(m[1]!);
      }
    }
    flush(text.length);
    return result;
  }
}

/// Découpe uniquement CR/LF : NEL ne doit pas devenir une fin de ligne.
Iterable<({String text, int start, int end})> _lines(String text) sync* {
  var start = 0;
  while (start < text.length) {
    var end = start;
    while (end < text.length &&
        text.codeUnitAt(end) != 10 &&
        text.codeUnitAt(end) != 13) {
      end++;
    }
    final contentEnd = end;
    if (end < text.length && text.codeUnitAt(end) == 13) end++;
    if (end < text.length && text.codeUnitAt(end) == 10) end++;
    yield (text: text.substring(start, contentEnd), start: start, end: end);
    start = end;
  }
}
