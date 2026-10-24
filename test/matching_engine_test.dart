import 'package:index_core/index_core.dart';
import 'package:test/test.dart';

import 'support/catalog_fixtures.dart';
import 'support/matching_fixtures.dart';

void main() {
  const engine = MatchingEngine();
  test('Paire A/A/B prioritaire, même si le nom courant est celui de B', () {
    final eps = [
      episode(),
      episode(
        id: 'mrx:$secondOriginal',
        original: secondOriginal,
        title: 'Autre',
      ),
    ];
    final d = engine.match(eps, [
      audio(
        'local',
        name: secondOriginal,
        comments: [firstOriginal, firstOriginal, secondOriginal],
      ),
    ]).single;
    expect(d.episodeId, firstId);
    expect(d.status, MatchStatus.confirmed);
    expect(d.method, 'id3_comment');
    expect(d.id3Verified, isTrue);
    expect(d.proof.ignored.single.frame.text, secondOriginal);
  });
  test('Identifiant ID3 inconnu : aucun repli vers le nom connu', () {
    final d = engine
        .match(
          [episode()],
          [
            audio(
              'local',
              name: firstOriginal,
              comments: [secondOriginal, secondOriginal],
            ),
          ],
        )
        .single;
    expect(d.status, MatchStatus.unknown);
    expect(d.episodeId, isNull);
  });
  test('COMM contradictoires bloquent les replis', () {
    final d = engine
        .match(
          [episode()],
          [
            audio(
              'local',
              name: firstOriginal,
              comments: [firstOriginal, secondOriginal],
            ),
          ],
        )
        .single;
    expect(d.status, MatchStatus.conflict);
    expect(d.episodeId, isNull);
  });
  test('Tag invalide ne confirme pas un nom connu', () {
    final d = engine
        .match(
          [episode()],
          [
            AudioCandidate(
              reference: 'x',
              currentName: firstOriginal,
              tag: Id3Reader().parse([73, 68, 51]),
            ),
          ],
        )
        .single;
    expect(d.status, MatchStatus.blocked);
  });
  for (final status in ['CONFIRMEE', 'ABSENTE', 'NON_VERIFIEE', 'CONFLIT']) {
    test('Repli nom historique et statut journal $status', () {
      final d = engine
          .match([episode(status: status)], [audio('x', name: firstOriginal)])
          .single;
      expect(d.method, 'original_filename');
      expect(d.id3Verified, isFalse);
      expect(
        d.status,
        {'NON_VERIFIEE', 'CONFLIT'}.contains(status)
            ? MatchStatus.provisional
            : MatchStatus.confirmed,
      );
      expect(d.toJson()['local_verification_status'], 'ABSENTE');
    });
  }
  test('Repli nom du catalogue sans TXT local', () {
    final d = engine
        .match([episode()], [audio('x', name: '2013-04-27 Un titre.mp3')])
        .single;
    expect(d.method, 'catalog_filename');
    expect(d.status, MatchStatus.confirmed);
    expect(d.id3Verified, isFalse);
  });
  test('Titre normalisé reste provisoire ; date seule insuffisante', () {
    final d = engine
        .match(
          [episode(title: "Vietnam, l'impossible ? Episode 1/3")],
          [audio('x', name: 'Vietnam, l’impossible Episode 1-3.mp3')],
        )
        .single;
    expect(d.method, 'normalized_title');
    expect(d.status, MatchStatus.provisional);
    expect(
      engine
          .match([episode()], [audio('y', name: '2013-04-27 Autre chose.mp3')])
          .single
          .status,
      MatchStatus.unknown,
    );
  });
  test(
    'Deux MP3 pour une fiche : conflit sur les deux, sans prendre le premier',
    () {
      final ds = engine.match(
        [episode()],
        [
          audio('a', comments: [firstOriginal]),
          audio('b', name: firstOriginal),
        ],
      );
      expect(ds.every((d) => d.status == MatchStatus.conflict), isTrue);
    },
  );
  test('Deux fiches pour un identifiant ou deux titres égaux : conflit', () {
    final eps = [episode(), episode(id: 'autre')];
    expect(
      engine
          .match(eps, [
            audio('a', comments: [firstOriginal]),
          ])
          .single
          .status,
      MatchStatus.conflict,
    );
    expect(
      engine.match(eps, [audio('a', name: 'UN TITRE.mp3')]).single.status,
      MatchStatus.conflict,
    );
  });
  test('Références répétées refusées, noms égaux dans des dossiers distincts inspectés', () {
    expect(
      engine
          .match([episode()], [audio('a'), audio('a')])
          .every((d) => d.status == MatchStatus.conflict),
      isTrue,
    );
    expect(
      engine.match(
        [episode()],
        [audio('dossier1/a.mp3'), audio('dossier2/a.mp3')],
      ),
      hasLength(2),
    );
  });
}
