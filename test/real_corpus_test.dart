import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:index_core/index_core.dart';
import 'package:index_core/index_io.dart';
import 'package:test/test.dart';

void main() {
  final baseline = jsonDecode(
    File('docs/lot0/audit-resultats.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final episodes = (baseline['episodes'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final oracle = jsonDecode(
    File('test/fixtures/id3-oracle.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final physicalTags = (oracle['episodes'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final episode in episodes) {
    test(
      'Fixture réelle ${episode["original_name"]} : TXT + COMM vs oracle Mutagen',
      () async {
        final txt = File('TXT_Files/${episode["txt_name"]}');
        final audio = File('MP3_Files/${episode["current_name"]}');
        final beforeTxt = await sha256.bind(txt.openRead()).first;
        final beforeMp3 = await sha256.bind(audio.openRead()).first;
        final parsed = TxtParser().parse(await txt.readAsBytes());
        expect(parsed.hasErrors, isFalse, reason: parsed.issues.toString());
        final d = parsed.document!;
        expect(d.originalName, episode['original_name']);
        expect(d.description!.length, episode['description_characters']);
        expect(d.sources, hasLength(episode['literary_references'] as int));
        expect(d.music, hasLength(episode['music_tracks'] as int));
        final tag = await Id3Reader().read(FileTagSource(audio));
        expect(tag.status, Id3Status.readable, reason: tag.issues.toString());
        final physical = physicalTags.singleWhere(
          (e) => e['file'] == episode['current_name'],
        );
        expect(beforeMp3.toString(), physical['sha256']);
        final expected = (physical['comments'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(tag.comments, hasLength(expected.length));
        for (final c in tag.comments) {
          final matches = expected
              .where(
                (e) =>
                    e['language'] == c.language &&
                    e['description'] == c.description,
              )
              .toList();
          expect(matches, hasLength(1));
          expect(c.text, (matches.single['texts'] as List<dynamic>).single);
        }
        final proof = const CommResolver().resolve(tag);
        expect(proof.status, CommResolutionStatus.pair);
        expect(proof.originalName, d.originalName);
        expect(proof.evidenceRule, 'comm_pair_v1');
        expect(proof.supportingFrames, hasLength(2));
        expect(
          proof.ignored,
          isEmpty,
          reason: 'Le commentaire ID3v1 n’est pas une trame COMM physique.',
        );
        // Ce contrôle prouve la concordance des identifiants, pas le matching inter-fichiers du Lot 2.
        final afterTxt = await sha256.bind(txt.openRead()).first;
        final afterMp3 = await sha256.bind(audio.openRead()).first;
        final hashes = baseline['source_sha256'] as Map<String, dynamic>;
        expect(beforeTxt.toString(), hashes[txt.path]);
        expect(beforeMp3.toString(), hashes[audio.path]);
        expect(afterTxt, beforeTxt);
        expect(afterMp3, beforeMp3);
      },
    );
  }
  test('Masque de fer : description intégrale, absence de source et deux morceaux exacts', () async {
    final episode = episodes.singleWhere(
      (e) => e['original_name'] == 'mr_x_2013_04_27.mp3',
    );
    final bytes = await File('TXT_Files/${episode["txt_name"]}').readAsBytes();
    final text = utf8.decode(bytes);
    final d = TxtParser().parse(bytes).document!;
    final start =
        text.indexOf("DESCRIPTION DE L'EPISODE :\n") +
        "DESCRIPTION DE L'EPISODE :\n".length;
    final end = text.indexOf('\n\nLIVRES ET SOURCES :');
    expect(d.description, text.substring(start, end));
    expect(d.sources, isEmpty);
    expect(d.music.map((m) => [m.artist, m.title, m.album, m.label]), [
      ['Yael Naim', 'Paris', 'Yael Naim', 'Wagram (2010)'],
      [
        'John Barry',
        'Diamonds are forever',
        'Diamonds are forever (BOF)',
        'Capitol Music (2003)',
      ],
    ]);
  });
}
