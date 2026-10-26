import 'package:index_core/index_core.dart';
import 'package:test/test.dart';

import 'support/catalog_fixtures.dart';
import 'support/matching_fixtures.dart';

void main() {
  const engine = MatchingEngine();
  test('Nom d’origine prioritaire sur le nom système d’une autre fiche', () {
    final eps = [
      episode(),
      MatchEpisode(
        id: 'autre',
        originalName: secondOriginal,
        title: 'Autre',
        systemNames: [firstOriginal],
      ),
    ];
    final d = engine.match(eps, [audio('local', name: firstOriginal)]).single;
    expect(d.episodeId, firstId);
    expect(d.method, 'original_filename');
    expect(d.status, MatchStatus.confirmed);
    expect(d.toJson()['audio_content_verified'], isFalse);
    expect(d.toJson()['local_verification_status'], 'NON_VERIFIEE');
    expect(d.toJson().containsKey('comments'), isFalse);
  });
  for (final status in ['CONFIRMEE', 'ABSENTE', 'NON_VERIFIEE', 'CONFLIT']) {
    test('Le statut ID3 historique $status n’intervient pas', () {
      final d = engine.match([episode(status: status)], [audio('x')]).single;
      expect(d.status, MatchStatus.confirmed);
      expect(d.toJson()['local_verification_status'], 'NON_VERIFIEE');
    });
  }
  test('Nom système exact si le nom d’origine ne correspond pas', () {
    final d = engine
        .match([episode()], [audio('x', name: '2013-04-27 Un titre.mp3')])
        .single;
    expect(d.method, 'catalog_filename');
    expect(d.status, MatchStatus.confirmed);
  });
  test('Aucun repli par titre, date ou ponctuation approchante', () {
    for (final name in [
      'Un titre.mp3',
      '2013-04-27 Un-titre.mp3',
      '2013-04-27 Un titre .mp3',
      ' 2013-04-27 Un titre.mp3',
      '2013-04-27 Un  titre.mp3',
      'autre.mp3',
    ]) {
      expect(
        engine.match([episode()], [audio('x', name: name)]).single.status,
        MatchStatus.unknown,
        reason: name,
      );
    }
  });
  test('Casse et NFC seulement ; accents et doubles points conservés', () {
    final e = MatchEpisode(
      id: firstId,
      originalName: firstOriginal,
      title: 'Été C.I.A.',
      systemNames: ['2013-04-27 Été C.I.A..mp3'],
    );
    expect(
      engine
          .match([e], [audio('a', name: firstOriginal.toUpperCase())])
          .single
          .status,
      MatchStatus.confirmed,
    );
    expect(
      engine
          .match(
            [e],
            [audio('b', name: '2013-04-27 E\u0301TE\u0301 C.I.A..MP3')],
          )
          .single
          .status,
      MatchStatus.confirmed,
    );
    for (final name in [
      '2013-04-27 Ete C.I.A..mp3',
      '2013-04-27 Été C.I.A.mp3',
      '2013-04-27 Été C.I.A…mp3',
    ]) {
      expect(
        engine.match([e], [audio('c', name: name)]).single.status,
        MatchStatus.unknown,
      );
    }
  });
  test('Deux noms d’origine égaux bloquent le repli système', () {
    final d = engine
        .match(
          [
            episode(),
            episode(id: 'autre'),
            MatchEpisode(
              id: 'troisieme',
              originalName: secondOriginal,
              title: 'Autre',
              systemNames: [firstOriginal],
            ),
          ],
          [audio('x')],
        )
        .single;
    expect(d.status, MatchStatus.conflict);
    expect(d.method, 'original_filename');
    expect(d.episodeId, isNull);
  });
  test('Deux noms système égaux : conflit', () {
    final d = engine
        .match(
          [episode(), episode(id: 'autre', original: secondOriginal)],
          [audio('x', name: '2013-04-27 Un titre.mp3')],
        )
        .single;
    expect(d.status, MatchStatus.conflict);
    expect(d.episodeId, isNull);
  });
  test(
    'Deux fichiers, même épisode par deux conventions : tous en conflit',
    () {
      final ds = engine.match(
        [episode()],
        [audio('a'), audio('b', name: '2013-04-27 Un titre.mp3')],
      );
      expect(ds.every((d) => d.status == MatchStatus.conflict), isTrue);
    },
  );
  test('Même nom dans deux sous-dossiers : aucun fichier choisi', () {
    expect(
      engine
          .match(
            [episode()],
            [audio('dossier1/a.mp3'), audio('dossier2/a.mp3')],
          )
          .every((d) => d.status == MatchStatus.conflict),
      isTrue,
    );
  });
  test('Références répétées refusées', () {
    expect(
      engine
          .match([episode()], [audio('a'), audio('a')])
          .every((d) => d.status == MatchStatus.conflict),
      isTrue,
    );
  });
}
