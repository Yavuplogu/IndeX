import 'package:index_core/index_core.dart';
import 'package:test/test.dart';

const a = 'mr_x_2013_04_27.mp3';
const b = 'mr_x_2013_11_23.mp3';
const c = 'mr_x_2009_05_09.mp3';

Id3ReadResult readComments(List<String> texts) => Id3ReadResult(
  status: Id3Status.readable,
  majorVersion: 3,
  issues: [],
  comments: [
    for (var i = 0; i < texts.length; i++)
      CommFrame(
        index: i,
        language: i.isEven ? 'eng' : 'fra',
        description: '',
        text: texts[i],
        encoding: 0,
        rawPayload: [],
      ),
  ],
);

void main() {
  const resolver = CommResolver();
  final cases = <(List<String>, CommResolutionStatus, String?)>[
    ([a, a, 'Durée : 38 minutes'], CommResolutionStatus.pair, a),
    ([a, a, b], CommResolutionStatus.pair, a),
    ([a, a, b, c], CommResolutionStatus.pair, a),
    ([a, a, b, b], CommResolutionStatus.conflict, null),
    ([a, a, a, b, b], CommResolutionStatus.conflict, null),
    ([a, b], CommResolutionStatus.conflict, null),
    ([a, 'Autre commentaire'], CommResolutionStatus.unique, a),
    (['Patrick PESNOT'], CommResolutionStatus.noCandidate, null),
    ([], CommResolutionStatus.noCandidate, null),
  ];
  for (var i = 0; i < cases.length; i++) {
    final (values, status, name) = cases[i];
    test('Règle COMM cas $i et indépendance de l’ordre', () {
      for (final order in [
        values,
        values.reversed.toList(),
        if (values.isNotEmpty) [...values.skip(1), values.first],
      ]) {
        final r = resolver.resolve(readComments(order));
        expect(r.status, status);
        expect(r.originalName, name);
        expect(
          r.allowsFilenameFallback,
          status == CommResolutionStatus.noCandidate,
        );
      }
    });
  }
  test('A/A/B : toutes les preuves, les valeurs écartées et leurs raisons', () {
    final r = resolver.resolve(readComments([a, a, b, 'Texte libre']));
    expect(r.evidenceRule, 'comm_pair_v1');
    expect(r.supportingFrames.map((f) => f.index), [0, 1]);
    expect(r.ignored.map((i) => i.frame.text), containsAll([b, 'Texte libre']));
    expect(r.ignored.every((i) => i.reason.isNotEmpty), isTrue);
    expect(r.candidates.keys, containsAll([a, b]));
    expect(() => r.supportingFrames.clear(), throwsUnsupportedError);
    expect(() => r.candidates[a]!.clear(), throwsUnsupportedError);
  });
  test('Deux occurrences dans une trame ne constituent pas une paire', () {
    final r = resolver.resolve(readComments(['$a $a']));
    expect(r.status, isNot(CommResolutionStatus.pair));
    expect(r.originalName, isNot(a));
  });
  test('Relire la même trame ne doit pas donner deux voix', () {
    final frame = readComments([a]).comments.single;
    final result = Id3ReadResult(
      status: Id3Status.readable,
      majorVersion: 3,
      comments: [frame, frame],
      issues: [],
    );
    expect(resolver.resolve(result).status, CommResolutionStatus.blocked);
  });
  test('Pas de distinction de langue obligatoire', () {
    final result = Id3ReadResult(
      status: Id3Status.readable,
      majorVersion: 3,
      comments: [
        CommFrame(
          index: 0,
          language: 'eng',
          description: '',
          text: a,
          encoding: 0,
          rawPayload: [],
        ),
        CommFrame(
          index: 1,
          language: 'eng',
          description: '',
          text: a,
          encoding: 0,
          rawPayload: [],
        ),
      ],
      issues: [],
    );
    expect(resolver.resolve(result).status, CommResolutionStatus.pair);
  });
  test('Tag partiellement lu : pas de preuve ni de repli autorisé', () {
    for (final status in [Id3Status.invalid, Id3Status.unsupported]) {
      final result = Id3ReadResult(
        status: status,
        majorVersion: 3,
        comments: readComments([a, a]).comments,
        issues: [const Diagnostic('erreur', 'Erreur simulée.')],
      );
      final r = resolver.resolve(result);
      expect(r.status, CommResolutionStatus.blocked);
      expect(r.allowsFilenameFallback, isFalse);
      expect(r.originalName, isNull);
    }
  });
  test('Normalisation prudente et NFC', () {
    expect(canonicalOriginalName(' "MR_X_2013_04_27.MP3" '), a);
    expect(canonicalOriginalName('Cafe\u0301.mp3'), 'Café.mp3');
    expect(
      canonicalOriginalName('Autre.mp3'),
      isNot(canonicalOriginalName('autre.mp3')),
    );
    final r = resolver.resolve(readComments([a, ' "MR_X_2013_04_27.MP3" ']));
    expect(r.status, CommResolutionStatus.pair);
    expect(r.supportingFrames.last.text, ' "MR_X_2013_04_27.MP3" ');
  });
  for (final invalid in [
    '../x.mp3',
    'C:\\audio.mp3',
    'http://host/audio.mp3',
    'a\nb.mp3',
    'audio.txt',
    'a.mp3\u0000',
    '',
  ]) {
    test('Nom refusé : ${invalid.replaceAll("\u0000", "NUL")}', () {
      expect(canonicalOriginalName(invalid), isNull);
    });
  }
}
